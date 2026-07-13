package com.namecallfilter.flow

import java.net.URI
import kotlin.math.roundToLong

/** The identifying fields of an HLS variant, deliberately excluding bitrate. */
internal data class TwitchVariantKey(
    val resolution: String?,
    val frameRateMilliFps: Long?,
    val codecs: String?,
    val videoGroupId: String?,
    val audioGroupId: String?,
    val subtitlesGroupId: String?,
    val captionsGroupId: String?,
)

internal data class TwitchMasterVariant(
    val stableVariantId: String?,
    val key: TwitchVariantKey,
    val playlistUri: URI,
)

/**
 * Resolves and indexes the media playlists advertised by one Twitch master
 * playlist.  Query identity ignores only the LL-HLS cursor parameters.
 */
internal class TwitchVariantIndex private constructor(
    val variants: List<TwitchMasterVariant>,
    val trustedMediaPlaylistUris: Set<URI>,
) {
    fun logicalVariant(requestUri: URI): TwitchMasterVariant? =
        variants.singleOrNull { it.playlistUri == logicalMediaPlaylistUri(requestUri) }

    fun isTrustedMediaPlaylist(requestUri: URI): Boolean =
        logicalMediaPlaylistUri(requestUri) in trustedMediaPlaylistUris

    /** Returns a proxy variant only when its identity is unambiguous. */
    fun matchProxyVariant(
        requestedVariant: TwitchMasterVariant,
        proxyIndex: TwitchVariantIndex,
    ): TwitchMasterVariant? {
        requestedVariant.stableVariantId?.let { stableId ->
            val stableMatches = proxyIndex.variants.filter { it.stableVariantId == stableId }
            when (stableMatches.size) {
                1 -> return stableMatches.single()
                in 2..Int.MAX_VALUE -> return null
            }
        }
        return proxyIndex.variants.singleOrNull { it.key == requestedVariant.key }
    }

    fun matchProxyVariant(requestUri: URI, proxyIndex: TwitchVariantIndex): TwitchMasterVariant? =
        logicalVariant(requestUri)?.let { matchProxyVariant(it, proxyIndex) }

    companion object {
        fun parse(masterPlaylist: String, baseUri: URI): TwitchVariantIndex {
            val variants = mutableListOf<TwitchMasterVariant>()
            val trustedUris = linkedSetOf<URI>()
            val lines = masterPlaylist.lineSequence().map(String::trim).toList()
            var index = 0
            while (index < lines.size) {
                val line = lines[index]
                when {
                    line.startsWith(STREAM_INF_PREFIX, ignoreCase = true) -> {
                        val attributes = parseHlsAttributeList(line)
                        val uri = lines.drop(index + 1).firstOrNull { it.isNotEmpty() }?.takeUnless {
                            it.startsWith('#')
                        }
                        if (uri != null) {
                            val playlistUri = logicalMediaPlaylistUri(baseUri.resolve(uri))
                            variants += TwitchMasterVariant(
                                stableVariantId = attributes["STABLE-VARIANT-ID"]?.trim()?.takeIf(String::isNotEmpty),
                                key = attributes.toVariantKey(),
                                playlistUri = playlistUri,
                            )
                            trustedUris += playlistUri
                        }
                    }
                    line.startsWith(MEDIA_PREFIX, ignoreCase = true) -> {
                        parseHlsAttributeList(line)["URI"]?.trim()?.takeIf(String::isNotEmpty)?.let {
                            trustedUris += logicalMediaPlaylistUri(baseUri.resolve(it))
                        }
                    }
                }
                index++
            }
            return TwitchVariantIndex(variants, trustedUris)
        }

        fun parse(masterPlaylist: String, baseUri: String): TwitchVariantIndex =
            parse(masterPlaylist, URI(baseUri))
    }
}

/** Removes only LL-HLS cursor parameters and the fragment for playlist identity. */
internal fun logicalMediaPlaylistUri(uri: URI): URI =
    uri.normalize().withoutFragmentAndWithQuery(
        uri.rawQuery
            ?.split('&')
            ?.filterNot { it.parameterName() in TRANSIENT_LL_HLS_PARAMETERS }
            ?.joinToString("&"),
    )

/**
 * Keeps the proxy's ordinary query parameters, replacing its LL-HLS cursor
 * values with exactly those from the request (including repeated raw values).
 */
internal fun mapReplacementUri(replacementUri: URI, logicalRequestUri: URI): URI {
    val replacement = replacementUri.rawQuery
        ?.split('&')
        ?.filterNot { it.parameterName() in TRANSIENT_LL_HLS_PARAMETERS }
        .orEmpty()
    val requestTransient = logicalRequestUri.rawQuery
        ?.split('&')
        ?.filter { it.parameterName() in TRANSIENT_LL_HLS_PARAMETERS }
        .orEmpty()
    return replacementUri.withoutFragmentAndWithQuery((replacement + requestTransient).joinToString("&"))
}

private fun Map<String, String>.toVariantKey(): TwitchVariantKey = TwitchVariantKey(
    resolution = this["RESOLUTION"]?.trim()?.lowercase()?.takeIf(String::isNotEmpty),
    frameRateMilliFps = this["FRAME-RATE"]?.trim()?.toDoubleOrNull()
        ?.takeIf { it.isFinite() && it >= 0 }
        ?.let { (it * 1_000).roundToLong() },
    codecs = this["CODECS"]?.split(',')?.joinToString(",") { it.trim().lowercase() }?.takeIf(String::isNotEmpty),
    videoGroupId = this["VIDEO"]?.trim()?.takeIf(String::isNotEmpty),
    audioGroupId = this["AUDIO"]?.trim()?.takeIf(String::isNotEmpty),
    subtitlesGroupId = this["SUBTITLES"]?.trim()?.takeIf(String::isNotEmpty),
    captionsGroupId = this["CLOSED-CAPTIONS"]?.trim()?.takeIf(String::isNotEmpty),
)

private fun String.parameterName(): String = substringBefore('=')

private fun URI.withoutFragmentAndWithQuery(rawQuery: String?): URI {
    val withoutFragment = toString().substringBefore('#')
    val withoutQuery = withoutFragment.substringBefore('?')
    return URI(if (rawQuery.isNullOrEmpty()) withoutQuery else "$withoutQuery?$rawQuery")
}

private const val STREAM_INF_PREFIX = "#EXT-X-STREAM-INF:"
private const val MEDIA_PREFIX = "#EXT-X-MEDIA:"
private val TRANSIENT_LL_HLS_PARAMETERS = setOf("_HLS_msn", "_HLS_part", "_HLS_skip")
