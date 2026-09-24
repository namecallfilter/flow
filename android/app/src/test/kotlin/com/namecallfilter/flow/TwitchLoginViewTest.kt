package com.namecallfilter.flow

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class TwitchLoginViewTest {
    @Test
    fun preservesCookieScopeAndRejectsInvalidBridgeData() {
        val cookie = JSONObject("""{"domain":".twitch.tv","name":"auth-token","value":"example=value","path":"/","hostOnly":false,"secure":true,"httpOnly":true,"session":false,"expirationDate":1893456000,"sameSite":"lax"}""")
        assertEquals(
            "https://twitch.tv/" to "auth-token=example=value; Path=/; Domain=.twitch.tv; Secure; HttpOnly; Expires=Tue, 01 Jan 2030 00:00:00 GMT; SameSite=Lax",
            twitchCookieForWebView(cookie),
        )
        cookie.put("hostOnly", true).put("session", true).put("sameSite", "unspecified")
        assertEquals("auth-token=example=value; Path=/; Secure; HttpOnly", twitchCookieForWebView(cookie).second)
        for ((key, value) in listOf("domain" to "twitch.tv.attacker.test", "value" to "bad; Domain=other.test", "partitionKey" to JSONObject().put("topLevelSite", "https://example.com"))) {
            val invalid = JSONObject(cookie.toString()).put(key, value)
            assertThrows(IllegalArgumentException::class.java) { twitchCookieForWebView(invalid) }
        }
    }

    @Test
    fun consumesOnlyTheConfiguredOAuthRedirect() {
        val redirect = "https://twitch.tv/login"
        assertTrue(isTwitchLoginCallback("https://www.twitch.tv/login/#access_token=example&state=test", redirect))
        assertTrue(isTwitchLoginCallback("https://twitch.tv/login?error=access_denied", redirect))
        for (url in listOf("https://twitch.tv/login", "https://twitch.tv/login?state=test", "https://twitch.tv.attacker.test/login#access_token=example", "https://twitch.tv/other#access_token=example", "https://twitch.tv:8443/login#access_token=example")) {
            assertFalse(isTwitchLoginCallback(url, redirect))
        }
        assertFalse(isTwitchLoginCallback("/#access_token=example", null))
        assertFalse(isTwitchLoginCallback("/#access_token=example", "/"))
    }
}
