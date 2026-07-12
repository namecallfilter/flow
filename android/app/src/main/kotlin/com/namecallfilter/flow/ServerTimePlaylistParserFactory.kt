package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.hls.playlist.DefaultHlsPlaylistParserFactory
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParserFactory
import androidx.media3.exoplayer.upstream.ParsingLoadable
import java.io.ByteArrayInputStream
import java.nio.charset.StandardCharsets

@UnstableApi
internal class ServerTimePlaylistParserFactory(
    private val latencySession: TwitchLatencySession,
    private val onAdCues: (List<TwitchAdCue>) -> Unit = {},
    private val delegate: HlsPlaylistParserFactory = DefaultHlsPlaylistParserFactory(),
) : HlsPlaylistParserFactory {
    override fun createPlaylistParser(): ParsingLoadable.Parser<HlsPlaylist> =
        inspecting(delegate.createPlaylistParser())

    override fun createPlaylistParser(
        multivariantPlaylist: HlsMultivariantPlaylist,
        previousMediaPlaylist: HlsMediaPlaylist?,
    ): ParsingLoadable.Parser<HlsPlaylist> = inspecting(
        delegate.createPlaylistParser(multivariantPlaylist, previousMediaPlaylist),
    )

    private fun inspecting(
        parser: ParsingLoadable.Parser<HlsPlaylist>,
    ): ParsingLoadable.Parser<HlsPlaylist> = ParsingLoadable.Parser { uri, inputStream ->
        val playlistText = inputStream.readBytes().toString(StandardCharsets.UTF_8)
        val rewrittenPlaylist = rewriteTwitchLowLatencyPlaylist(playlistText)
        parser.parse(
            uri,
            ByteArrayInputStream(rewrittenPlaylist.toByteArray(StandardCharsets.UTF_8)),
        ).also { playlist -> capturePlaylistMetadata(playlist, playlistText) }
    }

    private fun capturePlaylistMetadata(playlist: HlsPlaylist, originalPlaylist: String) {
        val tags = originalPlaylist.lineSequence().filter { it.startsWith('#') }.toList()
        captureServerTime(tags)
        if (playlist is HlsMediaPlaylist) {
            onAdCues(tags.mapNotNull(::parseTwitchAdCue).distinctBy(TwitchAdCue::id))
        }
    }

    private fun captureServerTime(tags: List<String>) {
        for (tag in tags) {
            val value = parseTwitchServerTimeSeconds(tag)
            if (value != null) {
                latencySession.captureServerTimeEpochSeconds(value)
                return
            }
        }
    }

}

internal fun parseTwitchServerTimeSeconds(tag: String): Double? {
    val attributes = parseHlsAttributeList(tag)
    return X_SERVER_TIME.find(tag)
        ?.groupValues
        ?.getOrNull(1)
        ?.toDoubleOrNull()
        ?: attributes["VALUE"]
            ?.takeIf { attributes["DATA-ID"].equals("SERVER-TIME", ignoreCase = true) }
            ?.toDoubleOrNull()
}

internal fun rewriteTwitchLowLatencyPlaylist(playlist: String): String {
    if (playlist.lineSequence().any { it.startsWith(END_LIST_TAG, ignoreCase = true) }) {
        return playlist
    }
    var changed = false
    val rewritten = buildList {
        playlist.lineSequence().forEach { line ->
            when {
                line.startsWith(TARGET_DURATION_PREFIX, ignoreCase = true) -> {
                    val targetDuration = line.substringAfter(':').trim().toIntOrNull()
                    if (
                        targetDuration != null &&
                        targetDuration in 1 until STANDARD_HLS_TARGET_SECONDS &&
                        targetDuration != TWITCH_SEGMENT_SECONDS
                    ) {
                        add("$TARGET_DURATION_PREFIX$TWITCH_SEGMENT_SECONDS")
                        changed = true
                    } else {
                        add(line)
                    }
                }

                line.startsWith(TWITCH_PREFETCH_PREFIX, ignoreCase = true) -> {
                    val uri = line.substringAfter(':').trim()
                    if (uri.isNotEmpty()) {
                        add("#EXTINF:$TWITCH_SEGMENT_SECONDS.000,")
                        add(uri)
                        changed = true
                    } else {
                        add(line)
                    }
                }

                else -> add(line)
            }
        }
    }
    if (!changed) {
        return playlist
    }
    return rewritten.joinToString(separator = "\n", postfix = if (playlist.endsWith('\n')) "\n" else "")
}

private const val TARGET_DURATION_PREFIX = "#EXT-X-TARGETDURATION:"
private const val TWITCH_PREFETCH_PREFIX = "#EXT-X-TWITCH-PREFETCH:"
private const val TWITCH_SEGMENT_SECONDS = 2
private const val STANDARD_HLS_TARGET_SECONDS = 10
private const val END_LIST_TAG = "#EXT-X-ENDLIST"
private val X_SERVER_TIME = Regex(
    """X-SERVER-TIME\s*=\s*\"?(-?\d+(?:\.\d+)?)\"?""",
    RegexOption.IGNORE_CASE,
)
