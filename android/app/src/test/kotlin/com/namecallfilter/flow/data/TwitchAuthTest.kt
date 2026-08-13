package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URI

class TwitchAuthTest {
    @Test fun `bundled OAuth configuration enables sign in`() {
        val config = TwitchAuthConfig.fromBuildConfig()
        assertEquals("deh8tdsvcsptv5sby686y9gamadiuo", config.clientId)
        assertEquals("https://twitch.tv/login", config.redirectUri)
        assertTrue(config.isConfigured)
    }

    @Test fun `callback reads fragment and validates state`() {
        val callback = TwitchAuthCallback.parse(
            URI("https://twitch.tv/login#access_token=token&scope=user%3Aread%3Afollows&state=expected"),
            "expected",
        )
        assertEquals("token", callback.accessToken)
        assertEquals("user:read:follows", callback.scope)
        assertTrue(TwitchAuthCallback.hasOAuthResponse(URI("https://twitch.tv/login?error=denied")))
    }

    @Test fun `redirect accepts Twitch www alias and trailing slash only`() {
        val config = TwitchAuthConfig("client")
        assertTrue(config.isRedirectUri(URI("https://www.twitch.tv/login/")))
        assertFalse(config.isRedirectUri(URI("https://evil.test/login")))
        assertFalse(config.isRedirectUri(URI("http://twitch.tv/login")))
    }

    @Test fun `complete auth validates both tokens and saves connection`() = runTest {
        val store = MemorySecureStore()
        val api = object : FakeTwitchApi() {
            override suspend fun fetchCurrentUser() = TwitchUser("viewer", "viewer", "Viewer")
            override suspend fun fetchFollowedStreams(userId: String) = listOf(
                TwitchFollowedStream("stream", "creator", "creator", "Creator", "Game", "Title", 4),
            )
            override suspend fun fetchFollowedChannels(userId: String) = listOf(
                TwitchFollowedChannel("creator", "creator", "Creator"),
            )
            override suspend fun fetchUsersByIds(ids: List<String>) = ids.associateWith {
                TwitchUser(it, it, it.replaceFirstChar(Char::uppercase))
            }
        }
        val controller = controller(store, api)
        val authUri = controller.createAuthorizationUri()
        assertEquals("fixed-state", query(authUri)["state"])
        val connection = controller.completeAuth(
            URI("https://twitch.tv/login#access_token=oauth-token&state=fixed-state"),
        )
        assertEquals("viewer", connection.user.id)
        assertEquals("oauth-token", store.accessToken)
        assertEquals("web-token", store.webToken)
        assertNull(store.pendingState)
    }

    @Test fun `sign out wins a validation race`() = runTest {
        val store = MemorySecureStore()
        val validationStarted = CompletableDeferred<Unit>()
        val finishValidation = CompletableDeferred<Unit>()
        val api = object : FakeTwitchApi() {
            override suspend fun validateAccessToken(token: String): Boolean {
                validationStarted.complete(Unit)
                finishValidation.await()
                return true
            }
        }
        val controller = controller(store, api)
        controller.createAuthorizationUri()
        val completion = async {
            runCatching {
                controller.completeAuth(
                    URI("https://twitch.tv/login#access_token=oauth-token&state=fixed-state"),
                )
            }
        }
        validationStarted.await()
        controller.signOut()
        finishValidation.complete(Unit)
        val error = completion.await().exceptionOrNull()
        assertTrue(error is TwitchAuthException)
        assertNull(store.accessToken)
        assertNull(store.webToken)
    }

    @Test fun `invalid saved token clears the entire session`() = runTest {
        val store = MemorySecureStore().apply {
            accessToken = "expired"
            webToken = "web"
        }
        val api = object : FakeTwitchApi() {
            override suspend fun validateAccessToken(token: String) = false
        }
        val restored = controller(store, api).loadSavedConnection()
        assertNull(restored)
        assertNull(store.accessToken)
        assertNull(store.webToken)
    }

    private fun controller(store: TwitchSecureStore, api: TwitchApi) = TwitchAuthController(
        config = TwitchAuthConfig("client"),
        secureStore = store,
        apiClientFactory = object : TwitchApiClientFactory {
            override fun create(accessToken: String, gqlAccessToken: String?) = api
        },
        cookieExtractor = TwitchCookieExtractor { "web-token" },
        stateGenerator = { "fixed-state" },
    )

    private fun query(uri: URI): Map<String, String> = uri.rawQuery.split('&').associate { part ->
        part.substringBefore('=') to java.net.URLDecoder.decode(part.substringAfter('='), "UTF-8")
    }
}
