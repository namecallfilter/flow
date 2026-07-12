package com.namecallfilter.flow

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ServerTimePlaylistParserFactoryTest {
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
