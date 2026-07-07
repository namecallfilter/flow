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
        val rewrittenPlaylist = rewriteTwitchPrefetchSegments(playlist)
        return delegate.parse(
            uri,
            ByteArrayInputStream(rewrittenPlaylist.toByteArray(StandardCharsets.UTF_8)),
        )
    }

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
}
