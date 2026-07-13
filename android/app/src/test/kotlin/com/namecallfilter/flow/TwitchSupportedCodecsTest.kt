package com.namecallfilter.flow

import okhttp3.HttpUrl.Companion.toHttpUrl
import org.junit.Assert.assertEquals
import org.junit.Test

class TwitchSupportedCodecsTest {
    @Test
    fun codecParameterReflectsReportedDecoderSupport() {
        val cases = mapOf(
            emptySet<String>() to "h264",
            setOf("video/hevc") to "h264,h265",
            setOf("video/av01") to "h264,av1",
            setOf("video/hevc", "video/av01") to "h264,h265,av1",
        )

        cases.forEach { (decoderMimeTypes, expectedCodecs) ->
            val result = withSupportedTwitchCodecs(ROOT, decoderMimeTypes).toHttpUrl()

            assertEquals(expectedCodecs, result.queryParameter("supported_codecs"))
            assertEquals("signature", result.queryParameter("sig"))
            assertEquals("{\"foo\":\"a+b\"}", result.queryParameter("token"))
            assertEquals(1, result.queryParameterValues("supported_codecs").size)
        }
    }

    private companion object {
        const val ROOT = "https://usher.ttvnw.net/api/v2/channel/hls/test.m3u8" +
            "?sig=signature&token=%7B%22foo%22%3A%22a%2Bb%22%7D&supported_codecs=old"
    }
}
