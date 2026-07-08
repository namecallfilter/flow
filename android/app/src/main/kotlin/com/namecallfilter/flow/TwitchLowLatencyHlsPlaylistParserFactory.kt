package com.namecallfilter.flow

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParser
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParserFactory
import androidx.media3.exoplayer.upstream.ParsingLoadable
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.roundToLong

internal object TwitchLatencyMetadata {
    private val availableEndMsByBaseUri = ConcurrentHashMap<String, Long>()

    @Volatile
    private var serverOffsetMs: Long? = null

    @Synchronized
    fun resetServerOffset() {
        serverOffsetMs = null
        availableEndMsByBaseUri.clear()
    }

    @Synchronized
    fun tryRecordServerTime(serverTimeSeconds: Double, clientTimeMs: Long): Boolean {
        if (serverOffsetMs != null) {
            return false
        }

        serverOffsetMs = (serverTimeSeconds * 1000.0).roundToLong() - clientTimeMs
        return true
    }

    fun latestServerOffsetMs(): Long? = serverOffsetMs

    fun recordAvailableEnd(baseUri: String, availableEndMs: Long) {
        availableEndMsByBaseUri[baseUri] = availableEndMs
    }

    fun availableEndMsFor(baseUri: String): Long? = availableEndMsByBaseUri[baseUri]
}

@OptIn(UnstableApi::class)
class TwitchLowLatencyHlsPlaylistParserFactory : HlsPlaylistParserFactory {
    override fun createPlaylistParser(): ParsingLoadable.Parser<HlsPlaylist> {
        return TwitchLowLatencyHlsPlaylistParser(HlsPlaylistParser())
    }

    override fun createPlaylistParser(
        multivariantPlaylist: HlsMultivariantPlaylist,
        previousMediaPlaylist: HlsMediaPlaylist?,
    ): ParsingLoadable.Parser<HlsPlaylist> {
        return TwitchLowLatencyHlsPlaylistParser(
            HlsPlaylistParser(multivariantPlaylist, previousMediaPlaylist),
        )
    }
}

@OptIn(UnstableApi::class)
private class TwitchLowLatencyHlsPlaylistParser(
    private val delegate: ParsingLoadable.Parser<HlsPlaylist>,
) : ParsingLoadable.Parser<HlsPlaylist> {
    override fun parse(uri: Uri, inputStream: InputStream): HlsPlaylist {
        val playlist = inputStream.bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
        val serverTimeSeconds = extractServerTimeSeconds(playlist)
        val clientTimeMs = System.currentTimeMillis()
        val prefetchSegmentCount = countTwitchPrefetchSegments(playlist)
        val rewrittenPlaylist = rewriteTwitchPrefetchSegments(playlist)
        val parsedPlaylist = delegate.parse(
            uri,
            ByteArrayInputStream(rewrittenPlaylist.toByteArray(StandardCharsets.UTF_8)),
        )

        if (parsedPlaylist is HlsMediaPlaylist) {
            val playlistDurationMs = parsedPlaylist.durationUs.div(1000L).coerceAtLeast(0L)
            TwitchLatencyMetadata.recordAvailableEnd(
                baseUri = parsedPlaylist.baseUri,
                availableEndMs =
                    (
                        playlistDurationMs -
                            prefetchSegmentCount * TWITCH_PREFETCH_DURATION_MS
                    ).coerceAtLeast(0L),
            )
            if (serverTimeSeconds != null) {
                TwitchLatencyMetadata.tryRecordServerTime(
                    serverTimeSeconds = serverTimeSeconds,
                    clientTimeMs = clientTimeMs,
                )
            }
        }

        return parsedPlaylist
    }

    private fun extractServerTimeSeconds(playlist: String): Double? =
        Regex("""X-SERVER-TIME="?([0-9]+(?:\.[0-9]+)?)"?""")
            .find(playlist)
            ?.groupValues
            ?.getOrNull(1)
            ?.toDoubleOrNull()

    private fun countTwitchPrefetchSegments(playlist: String): Long =
        playlist.lineSequence().count { it.startsWith("#EXT-X-TWITCH-PREFETCH:") }.toLong()

    private fun rewriteTwitchPrefetchSegments(playlist: String): String {
        val output = StringBuilder(playlist.length)

        for (line in playlist.lineSequence()) {
            when {
                line.startsWith("#EXT-X-TARGETDURATION:") -> {
                    val duration = line.substringAfter(":").trim().toIntOrNull()
                    if (duration != null && duration < 10) {
                        output.append("#EXT-X-TARGETDURATION:2\n")
                    } else {
                        output.append(line).append('\n')
                    }
                }

                line.startsWith("#EXT-X-TWITCH-PREFETCH:") -> {
                    val segmentUri = line
                        .substringAfter(":")
                        .trim()
                        .replace("-unmuted", "-muted")

                    if (segmentUri.isNotEmpty()) {
                        output.append("#EXTINF:2.000,\n")
                        output.append(segmentUri).append('\n')
                    }
                }

                line.isNotBlank() && !line.startsWith("#") -> {
                    output.append(line.replace("-unmuted", "-muted")).append('\n')
                }

                else -> output.append(line).append('\n')
            }
        }

        return output.toString()
    }

    private companion object {
        const val TWITCH_PREFETCH_DURATION_MS = 2000L
    }
}
