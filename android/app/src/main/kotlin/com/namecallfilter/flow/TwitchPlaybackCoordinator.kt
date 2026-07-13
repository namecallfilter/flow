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

/**
 * Keeps clean playback direct. A proxy is consulted only after a trusted media
 * playlist was fetched directly, parsed successfully, and contains a stitched ad.
 * Ad-bearing playlists are never returned as fallback content.
 */
internal class TwitchPlaybackSession(
    rootUsherUri: String,
    private val proxyCount: Int,
    private val onEvent: (String) -> Unit = {},
) {
    private val rootUri = URI(rootUsherUri)
    private val stateLock = Any()
    private val replacementLock = Any()
    private var directIndex: TwitchVariantIndex? = null
    private val replacementUris = mutableMapOf<URI, URI>()

    fun resolve(
        requestUri: String,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload {
        val requestedUri = URI(requestUri)
        if (requestedUri == rootUri) {
            return resolveRoot(fetch)
        }

        val index = synchronized(stateLock) { directIndex }
        if (index == null || !index.isTrustedMediaPlaylist(requestedUri)) {
            return fetch(TwitchManifestRoute.Direct, requestUri)
        }

        val logicalUri = logicalMediaPlaylistUri(requestedUri)
        val mappedUri = synchronized(stateLock) { replacementUris[logicalUri] }
        var targetUri = mappedUri?.let { mapReplacementUri(it, requestedUri) } ?: requestedUri
        var directResponse = try {
            fetch(TwitchManifestRoute.Direct, targetUri.toString())
        } catch (error: IOException) {
            if (mappedUri != null) {
                synchronized(stateLock) {
                    replacementUris.remove(logicalUri, mappedUri)
                }
            }
            throw error
        }
        if (!isUsableTwitchMediaPlaylist(directResponse.text)) {
            if (mappedUri != null) {
                synchronized(stateLock) {
                    replacementUris.remove(logicalUri, mappedUri)
                }
            }
            throw IOException("Direct Twitch media playlist was unusable")
        }
        if (mappedUri != null && containsTwitchStitchedAd(directResponse.text)) {
            synchronized(stateLock) {
                replacementUris.remove(logicalUri, mappedUri)
            }
            // Delta cursors belong to the expired replacement assignment. Use
            // a full direct snapshot to re-establish the current live window.
            targetUri = logicalUri
            directResponse = fetch(TwitchManifestRoute.Direct, targetUri.toString())
        }
        if (!isUsableTwitchMediaPlaylist(directResponse.text)) {
            throw IOException("Direct Twitch media playlist was unusable")
        }
        if (!containsTwitchStitchedAd(directResponse.text)) {
            return directResponse
        }
        onEvent("stitched ad detected in direct playlist")

        var lastError: IOException? = null
        val requestedVariant = index.logicalVariant(requestedUri)
        repeat(proxyCount) { proxyIndex ->
            val result = runCatching {
                fetch(TwitchManifestRoute.Proxy(proxyIndex), targetUri.toString())
            }
            val response = result.getOrNull()
            if (response != null) {
                val containsAd = containsTwitchStitchedAd(response.text)
                val isUsable = isUsableTwitchMediaPlaylist(response.text)
                if (
                    !containsAd &&
                    isUsable
                ) {
                    onEvent("proxy ${proxyIndex + 1} returned a clean playlist")
                    return response
                }
                if (!isUsable) {
                    lastError = IOException("Proxy returned an unusable Twitch playlist")
                }
            } else if (result.exceptionOrNull() is IOException) {
                lastError = result.exceptionOrNull() as IOException
            } else {
                throw requireNotNull(result.exceptionOrNull())
            }
            if (requestedVariant != null) {
                try {
                    return resolveReplacement(
                        requestedUri = requestedUri,
                        logicalUri = logicalUri,
                        proxyNumber = proxyIndex,
                        fetch = fetch,
                    )
                } catch (error: IOException) {
                    lastError = error
                }
            }
        }
        if (requestedVariant == null) {
            throw IOException("No clean replacement exists for this Twitch rendition")
        }
        throw lastError.orDefault("No proxy returned a clean matching Twitch rendition")
    }

    private fun resolveRoot(
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload {
        val response = fetch(TwitchManifestRoute.Direct, rootUri.toString())
        val index = TwitchVariantIndex.parse(response.text, response.finalUri)
        if (
            response.text.lineSequence().firstOrNull()?.trim()?.equals("#EXTM3U", ignoreCase = true) != true ||
            index.variants.isEmpty()
        ) {
            throw IOException("Direct Twitch master playlist was unusable")
        }
        synchronized(stateLock) {
            directIndex = index
            replacementUris.clear()
        }
        return response
    }

    private fun resolveReplacement(
        requestedUri: URI,
        logicalUri: URI,
        proxyNumber: Int,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload = synchronized(replacementLock) {
        val index = synchronized(stateLock) { directIndex }
            ?: throw IOException("Twitch master playlist is unavailable")

        synchronized(stateLock) { replacementUris[logicalUri] }?.let { existing ->
            val existingResponse = try {
                fetch(
                    TwitchManifestRoute.Direct,
                    mapReplacementUri(existing, requestedUri).toString(),
                )
            } catch (_: IOException) {
                null
            }
            if (
                existingResponse != null &&
                !containsTwitchStitchedAd(existingResponse.text) &&
                isUsableTwitchMediaPlaylist(existingResponse.text)
            ) {
                return@synchronized existingResponse
            }
            synchronized(stateLock) {
                replacementUris.remove(logicalUri, existing)
            }
        }

        val route = TwitchManifestRoute.Proxy(proxyNumber)
        try {
            val proxyMaster = fetch(route, rootUri.toString())
            val proxyIndex = TwitchVariantIndex.parse(proxyMaster.text, proxyMaster.finalUri)
            val replacements = index.matchProxyVariants(proxyIndex)
            val replacementUri = replacements[logicalUri]
                ?: throw IOException("Proxy did not provide the requested Twitch rendition")
            // A new assignment must start with a full snapshot. LL-HLS
            // cursors from the old assignment are used only on later loads.
            val replacementResponse = fetch(route, replacementUri.toString())
            if (containsTwitchStitchedAd(replacementResponse.text)) {
                throw IOException("Proxy returned another stitched-ad playlist")
            }
            if (!isUsableTwitchMediaPlaylist(replacementResponse.text)) {
                throw IOException("Proxy returned an unusable Twitch playlist")
            }
            synchronized(stateLock) {
                replacementUris.putAll(replacements)
            }
            onEvent("proxy ${proxyNumber + 1} supplied a clean replacement assignment")
            replacementResponse
        } catch (error: IOException) {
            onEvent("proxy ${proxyNumber + 1} could not supply a replacement assignment")
            throw error
        }
    }
}

@UnstableApi
internal class TwitchPlaybackCoordinator(
    rootUsherUri: String,
    private val directFactory: DataSource.Factory,
    private val proxyFactories: List<DataSource.Factory>,
    private val fetcher: TwitchManifestFetcher = Media3TwitchManifestFetcher,
    onEvent: (String) -> Unit = {},
) : TwitchManifestResolver {
    private val session = TwitchPlaybackSession(rootUsherUri, proxyFactories.size, onEvent)

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

private fun IOException?.orDefault(message: String): IOException = this ?: IOException(message)

internal fun containsTwitchStitchedAd(playlist: String): Boolean = playlist.lineSequence().any { line ->
    if (!line.startsWith("#EXT-X-DATERANGE:")) {
        return@any false
    }
    val attributes = parseHlsAttributeList(line)
    attributes["CLASS"] == "twitch-stitched-ad"
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
