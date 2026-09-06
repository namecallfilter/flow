package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.media3.exoplayer.hls.playlist.DefaultHlsPlaylistParserFactory
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParserFactory
import androidx.media3.exoplayer.upstream.ParsingLoadable
import java.io.ByteArrayInputStream
import java.nio.charset.StandardCharsets
import java.net.URI

@UnstableApi
internal class ServerTimePlaylistParserFactory(
    private val latencySession: TwitchLatencySession,
    private val onAdCues: (List<TwitchAdCue>) -> Unit = {},
    private val prefetchSegments: TwitchPrefetchSegments? = null,
    private val delegate: HlsPlaylistParserFactory = DefaultHlsPlaylistParserFactory(),
) : HlsPlaylistParserFactory {
    private var needsStartupAnchor = true

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
        prefetchSegments?.update(uri.toString(), playlistText)
        val rewrittenPlaylist = rewritePlaylist(playlistText)
        parser.parse(
            uri,
            ByteArrayInputStream(rewrittenPlaylist.toByteArray(StandardCharsets.UTF_8)),
        ).also { playlist -> capturePlaylistMetadata(playlist, playlistText) }
    }

    @Synchronized
    internal fun rewritePlaylist(playlist: String): String {
        val anchored = if (needsStartupAnchor) {
            anchorTwitchStartupPlaylist(playlist)?.also { needsStartupAnchor = false } ?: playlist
        } else {
            playlist
        }
        return rewriteTwitchLowLatencyPlaylist(anchored)
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

// Promoting Twitch prefetch to EXTINF hides its server-paced nature from Media3.
// Preserve that information so the native bandwidth meter ignores waits for
// video being produced, just as it does for native HLS preload hints.
@UnstableApi
internal class TwitchPrefetchSegments {
    private val uris = linkedSetOf<String>()

    @Synchronized
    fun update(playlistUri: String, playlist: String) {
        val base = runCatching { URI(playlistUri) }.getOrNull() ?: return
        for (rawLine in playlist.lineSequence()) {
            val line = rawLine.trim()
            if (line.startsWith(TWITCH_PREFETCH_PREFIX, ignoreCase = true)) {
                val value = line.substringAfter(':').trim()
                if (value.isNotEmpty()) {
                    runCatching { base.resolve(value).toString() }.getOrNull()?.let(uris::add)
                }
            } else if (line.isNotEmpty() && !line.startsWith('#')) {
                // The next playlist may publish an earlier prefetch as complete.
                runCatching { base.resolve(line).toString() }.getOrNull()?.let(uris::remove)
            }
        }
        while (uris.size > 256) {
            uris.remove(uris.first())
        }
    }

    @Synchronized
    fun flagsFor(uri: String, flags: Int): Int =
        if (uri in uris) flags or DataSpec.FLAG_MIGHT_NOT_USE_FULL_NETWORK_SPEED else flags
}

// A startup inside server-paced prefetch cannot measure connection capacity.
// Ask native HLS to start at the newest completed segment once; the existing
// transc_r correction then advances playback to the normal 1.65-second target.
// Do this for manual quality too, so a later switch to Auto has an estimate.
private fun anchorTwitchStartupPlaylist(playlist: String): String? {
    val lines = playlist.lines()
    if (
        lines.any { it.startsWith(END_LIST_TAG, ignoreCase = true) } ||
        lines.none { it.startsWith(TWITCH_PREFETCH_PREFIX, ignoreCase = true) }
    ) {
        return null
    }
    var durationSeconds = 0.0
    var segmentDurationSeconds: Double? = null
    var lastCompleteStartSeconds: Double? = null
    for (line in lines) {
        if (line.startsWith("#EXTINF:", ignoreCase = true)) {
            segmentDurationSeconds = line.substringAfter(':').substringBefore(',')
                .toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 }
        } else if (line.isNotBlank() && !line.startsWith('#')) {
            segmentDurationSeconds?.let { duration ->
                lastCompleteStartSeconds = durationSeconds
                durationSeconds += duration
            }
            segmentDurationSeconds = null
        }
    }
    val offset = lastCompleteStartSeconds ?: return null
    return lines.filterNot { it.startsWith("#EXT-X-START:", ignoreCase = true) }
        .toMutableList().apply {
            add(1, "#EXT-X-START:TIME-OFFSET=$offset,PRECISE=NO")
        }.joinToString("\n")
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
