package com.namecallfilter.flow

import androidx.media3.common.C
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
        val playlist = parser.parse(
            uri,
            ByteArrayInputStream(rewrittenPlaylist.toByteArray(StandardCharsets.UTF_8)),
        )
        capturePlaylistMetadata(playlist, playlistText)
        if (
            playlist is HlsMediaPlaylist && !playlist.hasEndTag && !playlist.preciseStart &&
            playlist.startOffsetUs == C.TIME_UNSET &&
            playlistText.lineSequence().any {
                it.startsWith(TWITCH_PREFETCH_PREFIX, ignoreCase = true) &&
                    it.substringAfter(':').isNotBlank()
            }
        ) {
            // Keep Media3's moving live default, without rounding it back to a
            // full segment on LIVE/resume. EXT-X-START only exists at cold start.
            playlist.withPreciseStart()
        } else {
            playlist
        }
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

@UnstableApi
private fun HlsMediaPlaylist.withPreciseStart() = HlsMediaPlaylist(
    playlistType, baseUri, tags, startOffsetUs, true, startTimeUs,
    hasDiscontinuitySequence, discontinuitySequence, mediaSequence, version,
    targetDurationUs, partTargetDurationUs, hasIndependentSegments, hasEndTag,
    hasProgramDateTime, protectionSchemes, segments, trailingParts, serverControl,
    renditionReports, interstitials, lastSeenInitSegment,
)

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

// Fetch a completed segment once so Auto measures capacity instead of the
// server-paced prefetch rate. Native precise start skips to its final 500ms,
// keeping startup close to live without a subsequent correction seek.
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
    val offset = maxOf(lastCompleteStartSeconds ?: return null, durationSeconds - 0.5)
    return lines.filterNot { it.startsWith("#EXT-X-START:", ignoreCase = true) }
        .toMutableList().apply {
            add(1, "#EXT-X-START:TIME-OFFSET=$offset,PRECISE=YES")
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
    var promotedPrefetch = false
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
                        promotedPrefetch = true
                    } else {
                        add(line)
                    }
                }

                else -> add(line)
            }
        }
        // Twitch's transcoder aligns rendition segments at IDR frames. Signal
        // that contract so Media3 switches forward instead of rereading a segment.
        // https://blog.twitch.tv/en/2017/10/23/live-video-transmuxing-transcoding-f-fmpeg-vs-twitch-transcoder-part-ii-4973f475f8a3/
        if (promotedPrefetch && none { it.equals(INDEPENDENT_SEGMENTS_TAG, ignoreCase = true) }) {
            add(1, INDEPENDENT_SEGMENTS_TAG)
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
private const val INDEPENDENT_SEGMENTS_TAG = "#EXT-X-INDEPENDENT-SEGMENTS"
private val X_SERVER_TIME = Regex(
    """X-SERVER-TIME\s*=\s*\"?(-?\d+(?:\.\d+)?)\"?""",
    RegexOption.IGNORE_CASE,
)
