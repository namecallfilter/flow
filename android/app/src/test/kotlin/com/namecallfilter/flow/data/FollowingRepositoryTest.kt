package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.runCurrent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FollowingRepositoryTest {
    @Test fun `duplicate restores share one request and forced refreshes coalesce behind it`() = runTest {
        val api = DelayedConnectionApi()
        val repository = FollowingRepository(controller(MemorySecureStore().withCredentials(), api))

        val restore = async { repository.loadSavedConnection() }
        runCurrent()
        val duplicateRestore = async { repository.loadSavedConnection() }
        val refresh = async { repository.loadSavedConnection(refresh = true) }
        val duplicateRefresh = async { repository.loadSavedConnection(refresh = true) }
        runCurrent()
        assertEquals(1, api.validateCalls)

        api.firstValidation.complete(Unit)
        runCurrent()
        assertEquals(2, api.validateCalls)

        api.secondValidation.complete(Unit)
        listOf(restore, duplicateRestore, refresh, duplicateRefresh).awaitAll()

        assertEquals(2, api.validateCalls)
        assertEquals("fresh-user", repository.state.value.connection?.user?.id)
        assertEquals(TwitchSessionStatus.AUTHENTICATED, repository.state.value.sessionStatus)
    }

    @Test fun `completed login wins over an older restore and its queued refresh`() = runTest {
        val api = DelayedConnectionApi()
        val repository = FollowingRepository(controller(MemorySecureStore().withCredentials(), api))
        val restore = async { repository.loadSavedConnection() }
        val duplicateRestore = async { repository.loadSavedConnection() }
        val queuedRefresh = async { repository.loadSavedConnection(refresh = true) }
        runCurrent()
        val login = connection("new-user")

        repository.applyConnection(login)
        api.firstValidation.complete(Unit)
        listOf(restore, duplicateRestore, queuedRefresh).awaitAll()

        assertEquals(1, api.validateCalls)
        assertSame(login, repository.state.value.connection)
        assertEquals(TwitchSessionStatus.AUTHENTICATED, repository.state.value.sessionStatus)
        assertFalse(repository.state.value.isLoadingFollowing)
    }

    @Test fun `refresh requested after login still runs when the older restore finishes`() = runTest {
        val api = DelayedConnectionApi()
        val repository = FollowingRepository(controller(MemorySecureStore().withCredentials(), api))
        val restore = async { repository.loadSavedConnection() }
        runCurrent()
        val login = connection("new-user")

        repository.applyConnection(login)
        val refresh = async { repository.loadSavedConnection(refresh = true) }
        runCurrent()
        api.firstValidation.complete(Unit)
        runCurrent()
        assertEquals(2, api.validateCalls)

        api.secondValidation.complete(Unit)
        listOf(restore, refresh).awaitAll()

        assertEquals("fresh-user", repository.state.value.connection?.user?.id)
        assertEquals(TwitchSessionStatus.AUTHENTICATED, repository.state.value.sessionStatus)
    }

    @Test fun `sign out wins over an older restore`() = runTest {
        val api = DelayedConnectionApi()
        val repository = FollowingRepository(controller(MemorySecureStore().withCredentials(), api))
        val restore = async { repository.loadSavedConnection() }
        runCurrent()

        repository.signOut()
        assertEquals(TwitchSessionStatus.LOGGED_OUT, repository.state.value.sessionStatus)
        api.firstValidation.complete(Unit)
        restore.await()

        assertEquals(1, api.validateCalls)
        assertEquals(0, api.currentUserCalls)
        assertEquals(null, repository.state.value.connection)
        assertEquals(TwitchSessionStatus.LOGGED_OUT, repository.state.value.sessionStatus)
    }

    @Test fun `failed secure sign out keeps authenticated state`() = runTest {
        val repository = FollowingRepository(controller(FailingClearStore(), FakeTwitchApi()))
        val current = connection("current-user")
        repository.applyConnection(current)

        val error = runCatching { repository.signOut() }.exceptionOrNull()

        assertTrue(error is IllegalStateException)
        assertEquals("Secure storage is unavailable.", error?.message)
        assertSame(current, repository.state.value.connection)
        assertEquals(TwitchSessionStatus.AUTHENTICATED, repository.state.value.sessionStatus)
        assertTrue(repository.state.value.followingError.orEmpty().contains("Secure storage is unavailable."))
    }

    @Test fun `account replacement and sign out preserve offline expansion override`() = runTest {
        val api = FakeTwitchApi()
        val repository = FollowingRepository(
            authController = controller(MemorySecureStore(), api),
        )
        val connection = connectionWithLiveChannel("first")

        repository.applyConnection(connection)
        repository.toggleOfflineExpanded()
        assertTrue(repository.state.value.offlineExpandedOverride == true)

        repository.applyConnection(connectionWithLiveChannel("second"))
        assertTrue(repository.state.value.offlineExpandedOverride == true)

        repository.signOut()
        assertEquals(TwitchSessionStatus.LOGGED_OUT, repository.state.value.sessionStatus)
        assertTrue(repository.state.value.offlineExpandedOverride == true)
    }

    private fun connectionWithLiveChannel(login: String): TwitchAuthConnection {
        val user = TwitchUser("viewer", "viewer", "Viewer")
        return TwitchAuthConnection(
            user = user,
            followedStreams = listOf(
                TwitchFollowedStream(
                    id = "stream-$login",
                    userId = login,
                    userLogin = login,
                    userName = login,
                    gameName = "Game",
                    title = "Live",
                    viewerCount = 1,
                ),
            ),
            followedChannels = emptyList(),
            usersById = mapOf(user.id to user),
        )
    }

    private fun connection(id: String) = TwitchAuthConnection(
        user = TwitchUser(id, id, id),
        followedStreams = emptyList(),
        followedChannels = emptyList(),
    )

    private fun controller(store: TwitchSecureStore, api: TwitchApi) = TwitchAuthController(
        config = TwitchAuthConfig(clientId = "client"),
        secureStore = store,
        apiClientFactory = object : TwitchApiClientFactory {
            override fun create(accessToken: String, gqlAccessToken: String?) = api
        },
        cookieExtractor = TwitchCookieExtractor { null },
    )

    private fun MemorySecureStore.withCredentials() = apply {
        accessToken = "access-token"
        webToken = "web-token"
    }

    private class DelayedConnectionApi : FakeTwitchApi() {
        val firstValidation = CompletableDeferred<Unit>()
        val secondValidation = CompletableDeferred<Unit>()
        var validateCalls = 0
        var currentUserCalls = 0

        override suspend fun validateAccessToken(token: String): Boolean {
            when (++validateCalls) {
                1 -> firstValidation.await()
                2 -> secondValidation.await()
                else -> error("Unexpected saved connection load.")
            }
            return true
        }

        override suspend fun fetchCurrentUser(): TwitchUser {
            val id = if (++currentUserCalls == 1) "stale-user" else "fresh-user"
            return TwitchUser(id, id, id)
        }

        override suspend fun fetchUsersByIds(ids: List<String>): Map<String, TwitchUser> =
            ids.associateWith { TwitchUser(it, it, it) }
    }

    private class FailingClearStore : TwitchSecureStore {
        override suspend fun savePendingState(state: String) = Unit
        override suspend fun readPendingState(): String? = null
        override suspend fun clearPendingState() = Unit
        override suspend fun saveAccessToken(token: String) = Unit
        override suspend fun readAccessToken(): String? = null
        override suspend fun saveWebSessionToken(token: String) = Unit
        override suspend fun readWebSessionToken(): String? = null
        override suspend fun clearSession(): Unit = error("Secure storage is unavailable.")
    }
}
