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
        val rawDirectResponse = directResult.getOrNull()
        val directResponse = rawDirectResponse?.takeIf {
            isUsableTwitchMediaPlaylist(it.text)
        }
        rawDirectResponse?.let { response ->
            val containsAd = containsTwitchStitchedAd(response.text)
            if (!containsAd && directResponse != null) {
                return response
            }
            onEvent(
                if (containsAd) {
                    "stitched ad detected in direct playlist"
                } else {
                    "direct playlist was unusable"
                },
            )
        }
        directResult.exceptionOrNull()?.let { error ->
            if (error !is IOException) {
                throw error
            }
        }
        var foundUsableAd = directResponse?.let { containsTwitchStitchedAd(it.text) } == true
        var lastError = directResult.exceptionOrNull() as? IOException
            ?: if (rawDirectResponse != null && directResponse == null) {
                IOException("Direct Twitch playlist was unusable")
            } else {
                null
            }
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
                if (containsAd && isUsable) {
                    foundUsableAd = true
                } else if (!isUsable) {
                    lastError = IOException("Proxy returned an unusable Twitch playlist")
                }
            } else if (result.exceptionOrNull() is IOException) {
                lastError = result.exceptionOrNull() as IOException
            } else {
                throw requireNotNull(result.exceptionOrNull())
            }
        }
        if (!foundUsableAd) {
            throw lastError.orDefault("No ad proxy could load the Twitch playlist")
        }
        if (index.logicalVariant(requestedUri) == null) {
            throw IOException("No clean replacement exists for this Twitch rendition")
        }
        return resolveReplacement(
            requestedUri = requestedUri,
            logicalUri = logicalUri,
            fetch = fetch,
        )
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
        fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload,
    ): TwitchManifestPayload = synchronized(replacementLock) {
        val index = synchronized(stateLock) { directIndex }
            ?: throw IOException("Twitch master playlist is unavailable")

        var lastError: IOException? = null
        synchronized(stateLock) { replacementUris[logicalUri] }?.let { existing ->
            val existingResponse = try {
                fetch(
                    TwitchManifestRoute.Direct,
                    mapReplacementUri(existing, requestedUri).toString(),
                )
            } catch (error: IOException) {
                lastError = error
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
                if (!isUsableTwitchMediaPlaylist(replacementResponse.text)) {
                    throw IOException("Proxy returned an unusable Twitch playlist")
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
