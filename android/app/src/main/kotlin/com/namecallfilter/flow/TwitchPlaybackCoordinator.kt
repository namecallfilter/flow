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
 * playlist contains a stitched ad (or a direct manifest request fails).
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
        var directResult = runCatching {
            fetch(TwitchManifestRoute.Direct, targetUri.toString())
        }
        val mappedResponse = directResult.getOrNull()
        if (
            mappedUri != null &&
            (
                mappedResponse == null ||
                    containsTwitchStitchedAd(mappedResponse.text) ||
                    !isUsableTwitchMediaPlaylist(mappedResponse.text)
            )
        ) {
            synchronized(stateLock) {
                replacementUris.remove(logicalUri, mappedUri)
            }
            // Delta cursors belong to the expired replacement assignment. Use
            // a full direct snapshot to re-establish the current live window.
            targetUri = logicalUri
            directResult = runCatching {
                fetch(TwitchManifestRoute.Direct, targetUri.toString())
            }
        }
        directResult.getOrNull()?.let { response ->
            if (!containsTwitchStitchedAd(response.text)) {
                return response
            }
            onEvent("stitched ad detected in direct playlist")
        }
        directResult.exceptionOrNull()?.let { error ->
            if (error !is IOException) {
                throw error
            }
        }
        val directResponse = directResult.getOrNull()
        var lastAdResponse = directResponse
        var lastError = directResult.exceptionOrNull() as? IOException
        repeat(proxyCount) { proxyIndex ->
            val result = runCatching {
                fetch(TwitchManifestRoute.Proxy(proxyIndex), targetUri.toString())
            }
            val response = result.getOrNull()
            if (response != null) {
                val containsAd = containsTwitchStitchedAd(response.text)
                if (
                    !containsAd &&
                    isUsableTwitchMediaPlaylist(response.text) &&
                    (
                        directResponse == null ||
                            twitchMediaPlaylistsOverlap(directResponse.text, response.text)
                    )
                ) {
                    onEvent("proxy ${proxyIndex + 1} returned a clean playlist")
                    return response
                }
                if (containsAd) {
                    lastAdResponse = response
                }
            } else if (result.exceptionOrNull() is IOException) {
                lastError = result.exceptionOrNull() as IOException
            } else {
                throw requireNotNull(result.exceptionOrNull())
            }
        }
        val directFallback = directResponse
        val adResponse = lastAdResponse
            ?: throw lastError.orDefault("No ad proxy could load the Twitch playlist")
        if (index.logicalVariant(requestedUri) == null) {
            return directFallback ?: adResponse
        }
        return try {
            resolveReplacement(
                requestedUri = requestedUri,
                logicalUri = logicalUri,
                adResponse = adResponse,
                fetch = fetch,
            )
        } catch (error: IOException) {
            directFallback?.also {
                onEvent("no clean replacement was available; using the direct playlist")
            } ?: throw error
        }
    }

    private fun resolveRoot(
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload {
        val response = try {
            fetch(TwitchManifestRoute.Direct, rootUri.toString())
        } catch (directError: IOException) {
            var lastError = directError
            var proxyResponse: TwitchManifestPayload? = null
            repeat(proxyCount) { proxyIndex ->
                if (proxyResponse != null) return@repeat
                try {
                    proxyResponse = fetch(TwitchManifestRoute.Proxy(proxyIndex), rootUri.toString())
                } catch (proxyError: IOException) {
                    lastError = proxyError.apply { addSuppressed(directError) }
                }
            }
            proxyResponse ?: throw lastError
        }
        val index = TwitchVariantIndex.parse(response.text, response.finalUri)
        synchronized(stateLock) {
            directIndex = index
            replacementUris.clear()
        }
        return response
    }

    private fun resolveReplacement(
        requestedUri: URI,
        logicalUri: URI,
        adResponse: TwitchManifestPayload,
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload = synchronized(replacementLock) {
        val index = synchronized(stateLock) { directIndex }
            ?: throw IOException("Twitch master playlist is unavailable")

        synchronized(stateLock) { replacementUris[logicalUri] }?.let { existing ->
            val existingResponse = fetch(
                TwitchManifestRoute.Direct,
                mapReplacementUri(existing, requestedUri).toString(),
            )
            if (
                !containsTwitchStitchedAd(existingResponse.text) &&
                isUsableTwitchMediaPlaylist(existingResponse.text) &&
                twitchMediaPlaylistsOverlap(adResponse.text, existingResponse.text)
            ) {
                return@synchronized existingResponse
            }
        }

        var lastError: IOException? = null
        repeat(proxyCount) { proxyNumber ->
            val route = TwitchManifestRoute.Proxy(proxyNumber)
            try {
                val proxyMaster = fetch(route, rootUri.toString())
                val proxyIndex = TwitchVariantIndex.parse(proxyMaster.text, proxyMaster.finalUri)
                val replacement = index.matchProxyVariant(requestedUri, proxyIndex)
                    ?: throw IOException("Proxy did not provide the requested Twitch rendition")
                // A new assignment must start with a full snapshot. LL-HLS
                // cursors from the old assignment are used only on later loads.
                val replacementResponse = fetch(route, replacement.playlistUri.toString())
                if (containsTwitchStitchedAd(replacementResponse.text)) {
                    throw IOException("Proxy returned another stitched-ad playlist")
                }
                if (!twitchMediaPlaylistsOverlap(adResponse.text, replacementResponse.text)) {
                    throw IOException("Replacement Twitch playlist is not aligned with the current stream")
                }
                synchronized(stateLock) {
                    replacementUris[logicalUri] = replacement.playlistUri
                }
                onEvent("proxy ${proxyNumber + 1} supplied a clean replacement assignment")
                return@synchronized replacementResponse
            } catch (error: IOException) {
                onEvent("proxy ${proxyNumber + 1} could not supply a replacement assignment")
                lastError = error
            }
        }
        throw lastError.orDefault("No proxy returned a clean matching Twitch rendition")
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
    if (!line.startsWith("#EXT-X-DATERANGE:", ignoreCase = true)) {
        return@any false
    }
    val attributes = parseHlsAttributeList(line)
    attributes["ID"]?.startsWith("stitched-ad-", ignoreCase = true) == true ||
        attributes["CLASS"].equals("twitch-stitched-ad", ignoreCase = true)
}

internal fun twitchMediaPlaylistsOverlap(first: String, second: String): Boolean {
    val firstWindow = parsePlaylistWindow(rewriteTwitchLowLatencyPlaylist(first)) ?: return false
    val secondWindow = parsePlaylistWindow(rewriteTwitchLowLatencyPlaylist(second)) ?: return false
    if (
        firstWindow.discontinuitySequence != null &&
        secondWindow.discontinuitySequence != null &&
        firstWindow.discontinuitySequence != secondWindow.discontinuitySequence
    ) {
        return false
    }
    return firstWindow.sequenceRange.first <= secondWindow.sequenceRange.last &&
        secondWindow.sequenceRange.first <= firstWindow.sequenceRange.last
}

private data class PlaylistWindow(
    val discontinuitySequence: Long?,
    val sequenceRange: LongRange,
)

private fun isUsableTwitchMediaPlaylist(playlist: String): Boolean =
    parsePlaylistWindow(rewriteTwitchLowLatencyPlaylist(playlist)) != null

private fun parsePlaylistWindow(playlist: String): PlaylistWindow? {
    val lines = playlist.lineSequence().map(String::trim).toList()
    if (
        lines.firstOrNull()?.equals("#EXTM3U", ignoreCase = true) != true ||
        lines.any { it.startsWith("#EXT-X-STREAM-INF:", ignoreCase = true) }
    ) {
        return null
    }
    val mediaSequence = parseSequenceTag(lines, "#EXT-X-MEDIA-SEQUENCE:") ?: return null
    val discontinuityTags = lines.filter {
        it.startsWith("#EXT-X-DISCONTINUITY-SEQUENCE:", ignoreCase = true)
    }
    val discontinuitySequence = when (discontinuityTags.size) {
        0 -> null
        1 -> discontinuityTags.single().substringAfter(':').trim().toLongOrNull()
            ?.takeIf { it >= 0 }
            ?: return null
        else -> return null
    }
    var segmentCount = 0L
    var expectsSegmentUri = false
    for (line in lines.drop(1)) {
        when {
            line.startsWith("#EXTINF:", ignoreCase = true) -> {
                if (expectsSegmentUri) {
                    return null
                }
                expectsSegmentUri = true
            }

            line.isNotEmpty() && !line.startsWith('#') -> {
                if (!expectsSegmentUri) {
                    return null
                }
                segmentCount++
                expectsSegmentUri = false
            }
        }
    }
    if (expectsSegmentUri || segmentCount == 0L) {
        return null
    }
    val lastSequence = try {
        Math.addExact(mediaSequence, segmentCount - 1)
    } catch (_: ArithmeticException) {
        return null
    }
    return PlaylistWindow(
        discontinuitySequence = discontinuitySequence,
        sequenceRange = mediaSequence..lastSequence,
    )
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
