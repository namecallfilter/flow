package com.namecallfilter.flow

import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import java.io.IOException
import java.net.URI
import java.nio.charset.StandardCharsets

internal sealed interface TwitchManifestRoute {
    data object Direct : TwitchManifestRoute

    data class Proxy(val index: Int) : TwitchManifestRoute
}

internal data class TwitchManifestPayload(
    val bytes: ByteArray,
    val finalUri: String,
    val responseHeaders: Map<String, List<String>> = emptyMap(),
) {
    val text: String
        get() = bytes.toString(StandardCharsets.UTF_8)
}

private data class RoutedTwitchManifest(
    val route: TwitchManifestRoute,
    val payload: TwitchManifestPayload,
)

private data class TwitchAdResponseState(
    var consecutiveAds: Int = 0,
    var cleanCooldown: Int = 0,
)

/**
 * Proxies only the initial Twitch assignment requests. The Usher master and the
 * first request to each trusted media playlist use the proxy chain with direct
 * fallback; ordinary playlist refreshes and all non-manifest data stay direct.
 */
internal class TwitchPlaybackSession(
    rootUsherUri: String,
    private val proxyCount: Int,
    private val freshRootUsherUri: () -> String = { rootUsherUri },
    private val onEvent: (String) -> Unit = {},
) {
    private val rootUri = URI(rootUsherUri)
    private val stateLock = Any()
    private val replacementLock = Any()
    private var variantIndex: TwitchVariantIndex? = null
    private val firstPlaylistRequests = mutableSetOf<URI>()
    private val replacementUris = mutableMapOf<URI, URI>()
    private val adResponseState = TwitchAdResponseState()

    fun resolve(
        requestUri: String,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload {
        val requestedUri = URI(requestUri)
        if (requestedUri == rootUri) {
            return resolveRoot(fetch)
        }

        val request = synchronized(stateLock) {
            val index = variantIndex ?: return@synchronized null
            val requestedLogicalUri = logicalMediaPlaylistUri(requestedUri)
            val logicalUri = when {
                index.isTrustedMediaPlaylist(requestedUri) -> requestedLogicalUri
                else -> replacementUris.entries.singleOrNull {
                    it.value == requestedLogicalUri
                }?.key
            } ?: return@synchronized null
            val replacementUri = replacementUris[logicalUri]
            val targetUri = if (requestedLogicalUri == logicalUri && replacementUri != null) {
                mapReplacementUri(replacementUri, requestedUri)
            } else {
                requestedUri
            }
            MediaPlaylistRequest(
                logicalUri = logicalUri,
                targetUri = targetUri,
                currentReplacementUri = replacementUri,
                useProxyChain = firstPlaylistRequests.add(logicalUri),
            )
        } ?: return fetch(TwitchManifestRoute.Direct, requestUri)

        val routedResponse = try {
            if (request.useProxyChain) {
                fetchThroughProxyChain(request.targetUri.toString(), fetch)
            } else {
                RoutedTwitchManifest(
                    TwitchManifestRoute.Direct,
                    fetch(TwitchManifestRoute.Direct, request.targetUri.toString()),
                )
            }
        } catch (error: IOException) {
            clearFailedReplacement(request)
            throw error
        }
        if (!isUsableTwitchMediaPlaylist(routedResponse.payload.text)) {
            clearFailedReplacement(request)
            throw IOException("Twitch media playlist was unusable")
        }
        if (!containsTwitchStitchedAd(routedResponse.payload.text)) {
            recordCleanResponse()
            return routedResponse.payload
        }

        val adNumber = recordAdResponse()
        onEvent("stitched ad detected on ${routedResponse.route.description()}")
        if (adNumber != 1) {
            synchronized(replacementLock) {
                findConcurrentReplacement(request, fetch)
            }?.let { return it }
            return if (adNumber == 2) {
                preferOriginalAssignment(request, routedResponse.payload, fetch)
            } else {
                routedResponse.payload
            }
        }
        return resolveReplacement(
            request = request,
            adResponse = routedResponse,
            fetch = fetch,
        )
    }

    private fun resolveRoot(
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload {
        val response = fetchThroughProxyChain(rootUri.toString(), fetch)
        val index = parseMaster(response.payload, "Twitch master playlist was unusable")
        synchronized(stateLock) {
            variantIndex = index
            firstPlaylistRequests.clear()
            replacementUris.clear()
            adResponseState.consecutiveAds = 0
            adResponseState.cleanCooldown = 0
        }
        onEvent("initial master loaded on ${response.route.description()}")
        return response.payload
    }

    private fun resolveReplacement(
        request: MediaPlaylistRequest,
        adResponse: RoutedTwitchManifest,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload = synchronized(replacementLock) {
        findConcurrentReplacement(request, fetch)?.let {
            return@synchronized it
        }

        val index = synchronized(stateLock) { variantIndex }
            ?: return@synchronized adResponse.payload
        try {
            val freshRootUri = freshRootUsherUri()
            val useProxyChain = adResponse.route == TwitchManifestRoute.Direct
            val replacementMaster = if (useProxyChain) {
                fetchThroughProxyChain(freshRootUri, fetch)
            } else {
                RoutedTwitchManifest(
                    TwitchManifestRoute.Direct,
                    fetch(TwitchManifestRoute.Direct, freshRootUri),
                )
            }
            val replacementIndex = parseMaster(
                replacementMaster.payload,
                "Replacement Twitch master playlist was unusable",
            )
            val replacements = index.matchProxyVariants(replacementIndex)
            val replacementUri = replacements[request.logicalUri]
                ?: throw IOException("Replacement did not provide the requested Twitch rendition")
            val replacementResponse = if (useProxyChain) {
                fetchThroughProxyChain(replacementUri.toString(), fetch)
            } else {
                RoutedTwitchManifest(
                    TwitchManifestRoute.Direct,
                    fetch(TwitchManifestRoute.Direct, replacementUri.toString()),
                )
            }
            if (!isUsableTwitchMediaPlaylist(replacementResponse.payload.text)) {
                throw IOException("Replacement Twitch media playlist was unusable")
            }
            if (containsTwitchStitchedAd(replacementResponse.payload.text)) {
                recordAdResponse()
                return@synchronized preferProxiedAdResponse(
                    original = adResponse,
                    replacement = replacementResponse,
                    replacements = replacements,
                )
            }

            synchronized(stateLock) {
                replacementUris.putAll(replacements)
            }
            recordCleanResponse()
            onEvent(
                "fresh assignment loaded on ${replacementResponse.route.description()}",
            )
            replacementResponse.payload
        } catch (error: IOException) {
            onEvent("fresh assignment failed: ${error.message.orEmpty()}")
            adResponse.payload
        }
    }

    private fun findConcurrentReplacement(
        request: MediaPlaylistRequest,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload? {
        val replacementUri = synchronized(stateLock) {
            replacementUris[request.logicalUri]
        } ?: return null
        if (replacementUri == request.currentReplacementUri) {
            return null
        }
        val response = try {
            fetch(
                TwitchManifestRoute.Direct,
                mapReplacementUri(replacementUri, request.targetUri).toString(),
            )
        } catch (_: IOException) {
            return null
        }
        if (
            !isUsableTwitchMediaPlaylist(response.text) ||
            containsTwitchStitchedAd(response.text)
        ) {
            return null
        }
        recordCleanResponse()
        return response
    }

    private fun preferOriginalAssignment(
        request: MediaPlaylistRequest,
        fallback: TwitchManifestPayload,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload {
        val replacementUri = request.currentReplacementUri ?: return fallback
        synchronized(stateLock) {
            replacementUris.remove(request.logicalUri, replacementUri)
        }
        val original = try {
            fetch(TwitchManifestRoute.Direct, request.logicalUri.toString())
        } catch (_: IOException) {
            return fallback
        }
        if (!isUsableTwitchMediaPlaylist(original.text)) {
            return fallback
        }
        if (!containsTwitchStitchedAd(original.text)) {
            recordCleanResponse()
        }
        onEvent("replacement still contained ads; restored the original assignment")
        return original
    }

    private fun preferProxiedAdResponse(
        original: RoutedTwitchManifest,
        replacement: RoutedTwitchManifest,
        replacements: Map<URI, URI>,
    ): TwitchManifestPayload {
        if (replacement.route is TwitchManifestRoute.Proxy) {
            synchronized(stateLock) {
                replacementUris.putAll(replacements)
            }
            onEvent("both assignments contained ads; keeping the proxied replacement")
            return replacement.payload
        }
        if (original.route is TwitchManifestRoute.Proxy) {
            onEvent("both assignments contained ads; keeping the proxied original")
            return original.payload
        }
        onEvent("both direct assignments contained ads")
        return original.payload
    }

    private fun fetchThroughProxyChain(
        uri: String,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): RoutedTwitchManifest {
        var lastError: IOException? = null
        repeat(proxyCount) { proxyIndex ->
            try {
                return RoutedTwitchManifest(
                    TwitchManifestRoute.Proxy(proxyIndex),
                    fetch(TwitchManifestRoute.Proxy(proxyIndex), uri),
                )
            } catch (error: IOException) {
                lastError = error
            }
        }
        return try {
            RoutedTwitchManifest(
                TwitchManifestRoute.Direct,
                fetch(TwitchManifestRoute.Direct, uri),
            )
        } catch (error: IOException) {
            if (proxyCount == 0) {
                throw error
            }
            lastError?.let(error::addSuppressed)
            throw error
        }
    }

    private fun parseMaster(
        response: TwitchManifestPayload,
        errorMessage: String,
    ): TwitchVariantIndex {
        val index = TwitchVariantIndex.parse(response.text, response.finalUri)
        if (
            response.text.lineSequence().firstOrNull()?.trim()?.equals("#EXTM3U", ignoreCase = true) != true ||
            index.variants.isEmpty()
        ) {
            throw IOException(errorMessage)
        }
        return index
    }

    private fun clearFailedReplacement(request: MediaPlaylistRequest) {
        val replacementUri = request.currentReplacementUri ?: return
        synchronized(stateLock) {
            replacementUris.remove(request.logicalUri, replacementUri)
        }
    }

    private fun recordAdResponse(): Int = synchronized(stateLock) {
        adResponseState.consecutiveAds++
        adResponseState.cleanCooldown = AD_RESPONSE_CLEAN_COOLDOWN
        adResponseState.consecutiveAds
    }

    private fun recordCleanResponse() {
        synchronized(stateLock) {
            if (adResponseState.cleanCooldown > 0) {
                adResponseState.cleanCooldown--
            } else {
                adResponseState.consecutiveAds = 0
            }
        }
    }

    private data class MediaPlaylistRequest(
        val logicalUri: URI,
        val targetUri: URI,
        val currentReplacementUri: URI?,
        val useProxyChain: Boolean,
    )

    private companion object {
        const val AD_RESPONSE_CLEAN_COOLDOWN = 15
    }
}

@UnstableApi
internal class TwitchPlaybackCoordinator(
    rootUsherUri: String,
    private val directFactory: DataSource.Factory,
    private val proxyFactories: List<DataSource.Factory>,
    private val freshRootUsherUri: () -> String = { rootUsherUri },
    private val fetcher: TwitchManifestFetcher = Media3TwitchManifestFetcher,
    onEvent: (String) -> Unit = {},
) : TwitchManifestResolver {
    private val session = TwitchPlaybackSession(
        rootUsherUri = rootUsherUri,
        proxyCount = proxyFactories.size,
        freshRootUsherUri = freshRootUsherUri,
        onEvent = onEvent,
    )

    override fun resolve(
        dataSpec: DataSpec,
        transferListeners: List<TransferListener>,
    ): ResolvedManifest {
        val response = session.resolve(dataSpec.uri.toString()) { route, uri ->
            val routedSpec = dataSpec.buildUpon().setUri(Uri.parse(uri)).build()
            val resolved = fetcher.fetch(
                factory = when (route) {
                    TwitchManifestRoute.Direct -> directFactory
                    is TwitchManifestRoute.Proxy -> proxyFactories[route.index]
                },
                dataSpec = routedSpec,
                transferListeners = transferListeners,
            )
            TwitchManifestPayload(
                bytes = resolved.bytes,
                finalUri = resolved.finalUri.toString(),
                responseHeaders = resolved.responseHeaders,
            )
        }
        return ResolvedManifest(
            bytes = response.bytes,
            finalUri = Uri.parse(response.finalUri),
            responseHeaders = response.responseHeaders,
        )
    }
}

internal fun containsTwitchStitchedAd(playlist: String): Boolean =
    playlist.contains("stitched-ad", ignoreCase = true)

private fun TwitchManifestRoute.description(): String = when (this) {
    TwitchManifestRoute.Direct -> "direct"
    is TwitchManifestRoute.Proxy -> "proxy ${index + 1}"
}

private fun isUsableTwitchMediaPlaylist(playlist: String): Boolean {
    val lines = rewriteTwitchLowLatencyPlaylist(playlist)
        .lineSequence()
        .map(String::trim)
        .toList()
    if (
        lines.firstOrNull()?.equals("#EXTM3U", ignoreCase = true) != true ||
        lines.any { it.startsWith("#EXT-X-STREAM-INF:", ignoreCase = true) }
    ) {
        return false
    }
    if (parseSequenceTag(lines, "#EXT-X-MEDIA-SEQUENCE:") == null) {
        return false
    }
    if (
        lines.any { it.startsWith("#EXT-X-DISCONTINUITY-SEQUENCE:", ignoreCase = true) } &&
        parseSequenceTag(lines, "#EXT-X-DISCONTINUITY-SEQUENCE:") == null
    ) {
        return false
    }
    var segmentCount = 0
    var expectsSegmentUri = false
    for (line in lines.drop(1)) {
        when {
            line.startsWith("#EXTINF:", ignoreCase = true) -> {
                if (expectsSegmentUri) {
                    return false
                }
                expectsSegmentUri = true
            }

            line.isNotEmpty() && !line.startsWith('#') -> {
                if (!expectsSegmentUri) {
                    return false
                }
                segmentCount++
                expectsSegmentUri = false
            }
        }
    }
    return !expectsSegmentUri && segmentCount > 0
}

private fun parseSequenceTag(lines: List<String>, prefix: String): Long? {
    val values = lines.filter { it.startsWith(prefix, ignoreCase = true) }
    if (values.size > 1) {
        return null
    }
    return values.singleOrNull()
        ?.substringAfter(':')
        ?.trim()
        ?.toLongOrNull()
        ?.takeIf { it >= 0 }
}
