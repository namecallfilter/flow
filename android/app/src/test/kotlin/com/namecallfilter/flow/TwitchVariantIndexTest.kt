package com.namecallfilter.flow

import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TwitchVariantIndexTest {
    @Test
    fun parsesVariantsAndTrustedRenditionsRelativeToBase() {
        val index = TwitchVariantIndex.parse(
            """
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="English",URI="audio/en.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,FRAME-RATE=59.94,CODECS="AVC1.640020, MP4A.40.2",AUDIO="aud",STABLE-VARIANT-ID="720p60"
            video/720.m3u8?token=a
            """.trimIndent(),
            "https://usher.ttvnw.net/api/channel/hls/master.m3u8",
        )

        assertEquals(1, index.variants.size)
        assertEquals("https://usher.ttvnw.net/api/channel/hls/video/720.m3u8?token=a", index.variants.single().playlistUri.toString())
        assertTrue(index.isTrustedMediaPlaylist(URI("https://usher.ttvnw.net/api/channel/hls/audio/en.m3u8?_HLS_msn=4")))
        assertTrue(index.isTrustedMediaPlaylist(URI("https://usher.ttvnw.net/api/channel/hls/video/720.m3u8?token=a&_HLS_part=2#ignored")))
        assertFalse(index.isTrustedMediaPlaylist(URI("https://usher.ttvnw.net/api/channel/hls/video/720.m3u8?other=a")))
    }

    @Test
    fun matchesStableIdThenStructuralKeyWithoutBitrateOrOrdinalFallback() {
        val request = TwitchVariantIndex.parse(master("one", "1280x720", "59.940", "AVC1.640020,mp4a.40.2"), BASE)
        val proxy = TwitchVariantIndex.parse(master("one", "1280x720", "59.94", "avc1.640020, MP4A.40.2", bandwidth = 1), BASE)

        assertEquals("one.m3u8", request.matchProxyVariant(URI("${BASE}one.m3u8?_HLS_msn=9"), proxy)?.playlistUri?.path?.substringAfterLast('/'))

        val duplicateId = TwitchVariantIndex.parse(
            master("one", "1280x720", "60", "avc1") + master("one", "640x360", "30", "avc1"), BASE,
        )
        assertNull(request.matchProxyVariant(URI("${BASE}one.m3u8"), duplicateId))

        val differentOnlyByBitrate = TwitchVariantIndex.parse(master(null, "854x480", "30", "avc1", bandwidth = 2), BASE)
        assertNull(request.matchProxyVariant(URI("${BASE}one.m3u8"), differentOnlyByBitrate))
    }

    @Test
    fun structuralMatchMustBeUnique() {
        val request = TwitchVariantIndex.parse(master(null, "1280x720", "60", "avc1"), BASE)
        val proxy = TwitchVariantIndex.parse(
            master(null, "1280x720", "60", "avc1") + master(null, "1280x720", "60", "avc1"), BASE,
        )

        assertNull(request.matchProxyVariant(URI("${BASE}none.m3u8"), proxy))
    }

    @Test
    fun replacementUriOverlaysOnlyTransientParametersAndPreservesRepeats() {
        assertEquals(
            "https://proxy.test/v.m3u8?token=p&tag=a%2Bb&_HLS_msn=7&_HLS_part=1&_HLS_part=2",
            mapReplacementUri(
                URI("https://proxy.test/v.m3u8?token=p&_HLS_msn=old&tag=a%2Bb"),
                URI("https://origin.test/v.m3u8?keep=no&_HLS_msn=7&_HLS_part=1&_HLS_part=2#x"),
            ).toString(),
        )
    }

    private fun master(id: String?, resolution: String, frameRate: String, codecs: String, bandwidth: Int = 3): String =
        "#EXT-X-STREAM-INF:BANDWIDTH=${bandwidth}000000,RESOLUTION=$resolution,FRAME-RATE=$frameRate,CODECS=\"$codecs\"" +
            (id?.let { ",STABLE-VARIANT-ID=\"$it\"" }.orEmpty()) + "\n" + (id ?: "none") + ".m3u8\n"

    private companion object {
        const val BASE = "https://origin.test/live/"
    }
}
