package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class ServerTimePlaylistParserFactoryTest {
    @Test
    fun everyLoadStartsAtLastCompletedSegmentBeforePrefetchAndAnchorsOnlyOnce() {
        val factory = ServerTimePlaylistParserFactory(
            latencySession = TwitchLatencySession(onAcceptedLatency = {}),
        )
        val master = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000\nindex.m3u8"
        assertEquals(master, factory.rewritePlaylist(master))
        val playlist = """
            #EXTM3U
            #EXT-X-TARGETDURATION:2
            #EXT-X-START:TIME-OFFSET=-1.65,PRECISE=NO
            #EXT-X-MEDIA-SEQUENCE:40
            #EXT-X-PROGRAM-DATE-TIME:2026-09-05T12:00:00.000Z
            #EXTINF:2.010,
            segment-40.ts
            #EXTINF:1.990,
            segment-41.ts
            #EXT-X-TWITCH-PREFETCH:segment-42.ts
            #EXT-X-TWITCH-PREFETCH:segment-43.ts
        """.trimIndent()

        val first = factory.rewritePlaylist(playlist)

        assertEquals(1, first.lineSequence().count { it.startsWith("#EXT-X-START:") })
        assertTrue(first.contains("#EXT-X-START:TIME-OFFSET=2.01,PRECISE=NO"))
        assertTrue(first.contains("#EXT-X-PROGRAM-DATE-TIME:2026-09-05T12:00:00.000Z"))
        assertEquals(40L, mediaSequence(first))
        assertEquals(41L, segmentSequence(first, "segment-41.ts"))
        assertEquals(42L, segmentSequence(first, "segment-42.ts"))
        // The anchor is a completed transfer, while promoted prefetch stays excluded.
        val segments = TwitchPrefetchSegments()
        val base = "https://example.com/live/index.m3u8"
        segments.update(base, playlist)
        assertEquals(0, segments.flagsFor("https://example.com/live/segment-41.ts", 0))
        assertEquals(DataSpec.FLAG_MIGHT_NOT_USE_FULL_NETWORK_SPEED,
            segments.flagsFor("https://example.com/live/segment-42.ts", 0))
        // Future refreshes and variant switches use native live-edge positioning.
        val refreshed = playlist.replace("#EXT-X-START:TIME-OFFSET=-1.65,PRECISE=NO\n", "")
        assertEquals(rewriteTwitchLowLatencyPlaylist(refreshed), factory.rewritePlaylist(refreshed))
        assertFalse(factory.rewritePlaylist(refreshed).contains("#EXT-X-START:"))
    }

    @Test
    fun vodKeepsItsOriginalStartAndEmptyPlaylistsDoNotConsumeAnchor() {
        val live = "#EXTM3U\n#EXTINF:2.0,\ncomplete.ts\n#EXT-X-TWITCH-PREFETCH:next.ts"
        val factory = ServerTimePlaylistParserFactory(
            latencySession = TwitchLatencySession(onAcceptedLatency = {}),
        )
        val vod = "$live\n#EXT-X-ENDLIST"
        assertEquals(vod, factory.rewritePlaylist(vod))
        val noComplete = "#EXTM3U\n#EXT-X-TWITCH-PREFETCH:next.ts"
        assertEquals(rewriteTwitchLowLatencyPlaylist(noComplete), factory.rewritePlaylist(noComplete))
        assertTrue(factory.rewritePlaylist(live).contains("#EXT-X-START:TIME-OFFSET=0.0,PRECISE=NO"))
    }

    @Test
    fun prefetchTransfersAreExcludedFromBandwidthUntilTheSegmentIsPublished() {
        val segments = TwitchPrefetchSegments()
        val base = "https://example.com/live/index.m3u8"
        val pacedFlag = DataSpec.FLAG_MIGHT_NOT_USE_FULL_NETWORK_SPEED
        val existingFlag = DataSpec.FLAG_ALLOW_GZIP
        segments.update(base, """
            #EXTM3U
            #EXTINF:2.0,
            complete.ts
            #EXT-X-TWITCH-PREFETCH:prefetch.ts
            #EXT-X-TWITCH-PREFETCH:https://cdn.example.com/next.ts
        """.trimIndent())

        assertEquals(existingFlag, segments.flagsFor("https://example.com/live/complete.ts", existingFlag))
        assertEquals(existingFlag or pacedFlag, segments.flagsFor("https://example.com/live/prefetch.ts", existingFlag))
        assertEquals(pacedFlag, segments.flagsFor("https://cdn.example.com/next.ts", 0))
        segments.update(base, "#EXTM3U\n#EXTINF:2.0,\nprefetch.ts")
        assertEquals(existingFlag, segments.flagsFor("https://example.com/live/prefetch.ts", existingFlag))

        // Disappearing playlists cannot retain unbounded URIs across quality switches.
        for (index in 0..256) {
            segments.update(base, "#EXT-X-TWITCH-PREFETCH:$index.ts")
        }
        assertEquals(0, segments.flagsFor("https://example.com/live/0.ts", 0))
        assertEquals(pacedFlag, segments.flagsFor("https://example.com/live/256.ts", 0))
    }

    @Test
    fun recognizesBothCurrentTwitchServerTimeTagForms() {
        assertEquals(
            1_783_659_939.38,
            parseTwitchServerTimeSeconds(
                "#EXT-X-SESSION-DATA:DATA-ID=\"SERVER-TIME\",VALUE=\"1783659939.38\"",
            )!!,
            0.0001,
        )
        assertEquals(
            1_783_659_939.62,
            parseTwitchServerTimeSeconds(
                "#EXT-X-DATERANGE:ID=\"playlist-creation\",X-SERVER-TIME=\"1783659939.62\"",
            )!!,
            0.0001,
        )
    }

    @Test
    fun rewritesOnlyLiveTwitchTargetAndPrefetchLines() {
        val playlist = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-MEDIA-SEQUENCE:40
            #EXT-X-PROGRAM-DATE-TIME:2026-07-28T12:00:00.000Z
            #EXTINF:2.000,live
            segment-40.ts
            #EXT-X-DATERANGE:ID="stitched-ad-1",CLASS="twitch-stitched-ad"
            #EXT-X-TWITCH-PREFETCH:segment-41.ts
            #EXT-X-TWITCH-PREFETCH:segment-42.ts
        """.trimIndent()

        val rewritten = rewriteTwitchLowLatencyPlaylist(playlist)

        assertTrue(rewritten.contains("#EXT-X-TARGETDURATION:2"))
        assertTrue(rewritten.contains("#EXT-X-MEDIA-SEQUENCE:40"))
        assertEquals(3, "#EXTINF:2.000,".toRegex().findAll(rewritten).count())
        assertTrue(rewritten.contains("segment-41.ts\n#EXTINF:2.000,\nsegment-42.ts"))
        assertTrue(rewritten.contains("ID=\"stitched-ad-1\""))
        assertTrue(rewritten.contains("#EXT-X-PROGRAM-DATE-TIME:2026-07-28T12:00:00.000Z"))
        assertFalse(rewritten.contains("#EXT-X-TWITCH-PREFETCH:"))

        val vod = "$playlist\n#EXT-X-ENDLIST"
        assertEquals(vod, rewriteTwitchLowLatencyPlaylist(vod))
        val alreadyNormalized = playlist.replace("TARGETDURATION:6", "TARGETDURATION:2")
            .replace("#EXT-X-TWITCH-PREFETCH:segment-41.ts\n", "")
            .replace("#EXT-X-TWITCH-PREFETCH:segment-42.ts", "")
        assertEquals(alreadyNormalized, rewriteTwitchLowLatencyPlaylist(alreadyNormalized))
    }

    @Test
    fun promotedPrefetchSegmentsKeepTheirMediaSequenceAcrossRefreshes() {
        val first = rewriteTwitchLowLatencyPlaylist(
            """
                #EXTM3U
                #EXT-X-TARGETDURATION:2
                #EXT-X-MEDIA-SEQUENCE:40
                #EXTINF:2.000,live
                segment-40.ts
                #EXT-X-TWITCH-PREFETCH:segment-41.ts
                #EXT-X-TWITCH-PREFETCH:segment-42.ts
            """.trimIndent(),
        )
        val second = rewriteTwitchLowLatencyPlaylist(
            """
                #EXTM3U
                #EXT-X-TARGETDURATION:2
                #EXT-X-MEDIA-SEQUENCE:41
                #EXTINF:2.000,live
                segment-41.ts
                #EXTINF:2.000,live
                segment-42.ts
                #EXT-X-TWITCH-PREFETCH:segment-43.ts
            """.trimIndent(),
        )

        assertEquals(40L, mediaSequence(first))
        assertEquals(41L, mediaSequence(second))
        assertEquals(41L, segmentSequence(first, "segment-41.ts"))
        assertEquals(41L, segmentSequence(second, "segment-41.ts"))
        assertEquals(42L, segmentSequence(first, "segment-42.ts"))
        assertEquals(42L, segmentSequence(second, "segment-42.ts"))
    }

    private fun mediaSequence(playlist: String): Long = playlist.lineSequence()
        .first { it.startsWith("#EXT-X-MEDIA-SEQUENCE:") }
        .substringAfter(':')
        .toLong()

    private fun segmentSequence(playlist: String, uri: String): Long {
        val segmentUris = playlist.lineSequence()
            .filter { it.isNotBlank() && !it.startsWith('#') }
            .toList()
        val index = segmentUris.indexOf(uri)
        require(index >= 0) { "Missing segment URI: $uri" }
        return mediaSequence(playlist) + index
    }
}
