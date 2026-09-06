package com.namecallfilter.flow

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TwitchCookieExtractorTest {
    @Test
    fun fallsBackWhenApexHasOtherCookiesButNotTheRequestedCookie() {
        val cookies = mapOf(
            "https://twitch.tv" to "theme=dark; unrelated_unique_id=wrong",
            "https://www.twitch.tv" to "auth-token=web-token; unique_id=web-device",
        )

        assertEquals("web-token", extractTwitchCookie("auth-token", cookies::get))
        assertEquals("web-device", extractTwitchCookie("unique_id", cookies::get))
        assertNull(extractTwitchCookie("missing", cookies::get))
    }

    @Test
    fun keepsApexCookiePrecedenceAndPreservesTheFullValue() {
        val cookies = mapOf(
            "https://twitch.tv" to "theme=dark; auth-token=apex=token",
            "https://www.twitch.tv" to "auth-token=www-token",
        )

        assertEquals("apex=token", extractTwitchCookie("auth-token", cookies::get))
    }
}
