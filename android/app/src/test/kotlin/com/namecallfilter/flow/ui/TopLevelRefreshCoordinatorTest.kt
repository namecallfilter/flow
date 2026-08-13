package com.namecallfilter.flow.ui

import com.namecallfilter.flow.data.BrowseRepository
import com.namecallfilter.flow.data.FakeTwitchApi
import com.namecallfilter.flow.data.FollowingRepository
import com.namecallfilter.flow.data.MemorySecureStore
import com.namecallfilter.flow.data.TwitchApi
import com.namecallfilter.flow.data.TwitchApiCache
import com.namecallfilter.flow.data.TwitchApiClientFactory
import com.namecallfilter.flow.data.TwitchAuthConfig
import com.namecallfilter.flow.data.TwitchAuthController
import com.namecallfilter.flow.data.TwitchCategory
import com.namecallfilter.flow.data.TwitchCookieExtractor
import com.namecallfilter.flow.data.TwitchFollowedStream
import com.namecallfilter.flow.data.TwitchPage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.time.Duration.Companion.seconds
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TopLevelRefreshCoordinatorTest {
    @Test fun `concurrent non-refresh callers share one pass`() = runTest {
        val api = PendingBrowseApi()
        val coordinator = coordinator(api)

        val leader = async { coordinator.refresh(refresh = false) }
        runCurrent()
        val follower = async { coordinator.refresh(refresh = false) }
        runCurrent()

        assertEquals(1, api.categoryRequests.size)
        assertEquals(1, api.liveRequests.size)
        assertFalse(leader.isCompleted)
        assertFalse(follower.isCompleted)

        api.completePass(0)
        leader.await()
        follower.await()

        assertEquals(1, api.categoryRequests.size)
        assertEquals(1, api.liveRequests.size)
    }

    @Test fun `forced callers queue one trailing pass and await it`() = runTest {
        val api = PendingBrowseApi()
        val coordinator = coordinator(api)

        val leader = async { coordinator.refresh(refresh = false) }
        runCurrent()
        val firstForced = async { coordinator.refresh(refresh = true) }
        val duplicateForced = async { coordinator.refresh(refresh = true) }
        runCurrent()

        api.completePass(0)
        runCurrent()

        assertEquals(2, api.categoryRequests.size)
        assertEquals(2, api.liveRequests.size)
        assertFalse(leader.isCompleted)
        assertFalse(firstForced.isCompleted)
        assertFalse(duplicateForced.isCompleted)

        api.completePass(1)
        leader.await()
        firstForced.await()
        duplicateForced.await()

        assertEquals(2, api.categoryRequests.size)
        assertEquals(2, api.liveRequests.size)
    }

    @Test fun `forced overlap starts following refresh before stalled browse releases`() = runTest(timeout = 5.seconds) {
        val api = PendingBrowseApi()
        val browseRepository = BrowseRepository(TwitchApiCache({ api }))
        val followingRequests = mutableListOf<Pair<Boolean, CompletableDeferred<Unit>>>()
        val coordinator = TopLevelRefreshCoordinator(
            followingRepository = followingRepository(api),
            browseRepository = browseRepository,
            refreshScope = this,
            refreshFollowing = { refresh ->
                val pending = CompletableDeferred<Unit>()
                followingRequests += refresh to pending
                pending.await()
            },
        )

        val leader = async { coordinator.refresh(refresh = false) }
        runCurrent()
        assertEquals(listOf(false), followingRequests.map { it.first })
        assertEquals(1, api.categoryRequests.size)

        val forced = async { coordinator.refresh(refresh = true) }
        runCurrent()
        assertEquals(listOf(false, true), followingRequests.map { it.first })
        assertEquals(1, api.categoryRequests.size)
        assertFalse(forced.isCompleted)

        followingRequests[0].second.complete(Unit)
        api.completePass(0)
        runCurrent()
        assertEquals(2, api.categoryRequests.size)

        followingRequests[1].second.complete(Unit)
        api.completePass(1)
        leader.await()
        forced.await()
        assertTrue(leader.isCompleted)
        assertTrue(forced.isCompleted)
    }

    @Test fun `non-refresh pass skips browse sections that are already loaded`() = runTest {
        val api = CountingBrowseApi()
        val browseRepository = BrowseRepository(TwitchApiCache({ api }))
        browseRepository.loadCategories(reset = true)
        browseRepository.loadLiveChannels(reset = true)
        assertEquals(1, api.categoryCalls)
        assertEquals(1, api.liveCalls)

        TopLevelRefreshCoordinator(followingRepository(api), browseRepository)
            .refresh(refresh = false)

        assertEquals(1, api.categoryCalls)
        assertEquals(1, api.liveCalls)
    }

    @Test fun `leader cancellation releases joiners and permits a later pass`() = runTest {
        val api = PendingBrowseApi()
        val coordinator = coordinator(api)

        val leader = async { coordinator.refresh(refresh = false) }
        runCurrent()
        val follower = async {
            try {
                coordinator.refresh(refresh = true)
                null
            } catch (error: CancellationException) {
                error
            }
        }
        runCurrent()

        leader.cancelAndJoin()
        runCurrent()
        assertTrue(follower.await() is CancellationException)

        val retry = async { coordinator.refresh(refresh = false) }
        runCurrent()
        assertEquals(2, api.categoryRequests.size)
        assertEquals(2, api.liveRequests.size)
        api.completePass(1)
        retry.await()
    }

    private fun coordinator(api: TwitchApi): TopLevelRefreshCoordinator {
        val browseRepository = BrowseRepository(TwitchApiCache({ api }))
        return TopLevelRefreshCoordinator(followingRepository(api), browseRepository)
    }

    private fun followingRepository(api: TwitchApi): FollowingRepository {
        val controller = TwitchAuthController(
            config = TwitchAuthConfig(clientId = ""),
            secureStore = MemorySecureStore(),
            apiClientFactory = object : TwitchApiClientFactory {
                override fun create(accessToken: String, gqlAccessToken: String?) = api
            },
            cookieExtractor = TwitchCookieExtractor { null },
        )
        return FollowingRepository(controller)
    }

    private class PendingBrowseApi : FakeTwitchApi() {
        val categoryRequests = mutableListOf<CompletableDeferred<TwitchPage<TwitchCategory>>>()
        val liveRequests = mutableListOf<CompletableDeferred<TwitchPage<TwitchFollowedStream>>>()

        override suspend fun fetchTopCategoriesPage(
            first: Int,
            cursor: String?,
        ): TwitchPage<TwitchCategory> = CompletableDeferred<TwitchPage<TwitchCategory>>()
            .also(categoryRequests::add)
            .await()

        override suspend fun fetchLiveStreamsPage(
            first: Int,
            gameIds: List<String>,
            userLogins: List<String>,
            cursor: String?,
        ): TwitchPage<TwitchFollowedStream> = CompletableDeferred<TwitchPage<TwitchFollowedStream>>()
            .also(liveRequests::add)
            .await()

        fun completePass(index: Int) {
            assertTrue(categoryRequests[index].complete(TwitchPage(emptyList(), null)))
            assertTrue(liveRequests[index].complete(TwitchPage(emptyList(), null)))
        }
    }

    private class CountingBrowseApi : FakeTwitchApi() {
        var categoryCalls = 0
        var liveCalls = 0

        override suspend fun fetchTopCategoriesPage(
            first: Int,
            cursor: String?,
        ): TwitchPage<TwitchCategory> {
            categoryCalls += 1
            return TwitchPage(emptyList(), null)
        }

        override suspend fun fetchLiveStreamsPage(
            first: Int,
            gameIds: List<String>,
            userLogins: List<String>,
            cursor: String?,
        ): TwitchPage<TwitchFollowedStream> {
            liveCalls += 1
            return TwitchPage(emptyList(), null)
        }
    }
}
