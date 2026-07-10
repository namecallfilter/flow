package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.hls.playlist.DefaultHlsPlaylistParserFactory
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParserFactory
import androidx.media3.exoplayer.upstream.ParsingLoadable

@UnstableApi
internal class ServerTimePlaylistParserFactory(
    private val latencySession: TwitchLatencySession,
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
        parser.parse(uri, inputStream).also(::captureServerTime)
    }

    private fun captureServerTime(playlist: HlsPlaylist) {
        for (tag in playlist.tags) {
            val value = X_SERVER_TIME.find(tag)?.groupValues?.getOrNull(1)?.toDoubleOrNull()
            if (value != null) {
                latencySession.captureServerTimeEpochSeconds(value)
                return
            }
        }
    }

    private companion object {
        val X_SERVER_TIME = Regex(
            """X-SERVER-TIME\s*=\s*\"?(-?\d+(?:\.\d+)?)\"?""",
            RegexOption.IGNORE_CASE,
        )
    }
}
