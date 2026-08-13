package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BrowseRepositoriesTest {
    @Test fun `category repository drops an overlapping load instead of queuing it`() = runTest {
        val response = CompletableDeferred<TwitchPage<TwitchFollowedStream>>()
        var calls = 0
        val api = object : FakeTwitchApi() {
            override suspend fun fetchLiveStreamsPage(
                first: Int,
                gameIds: List<String>,
                userLogins: List<String>,
                cursor: String?,
            ): TwitchPage<TwitchFollowedStream> {
                calls += 1
                return response.await()
            }
        }
        val repository = CategoryStreamsRepository(
            TwitchApiCache({ api }),
            BrowseCategory("game", "Game", 0, "0", null, emptyList()),
        )

        val initial = async { repository.loadStreams(reset = true) }
        testScheduler.runCurrent()
        val overlappingRefresh = async {
            repository.loadStreams(reset = true, refresh = true)
        }
        testScheduler.runCurrent()

        assertTrue(overlappingRefresh.isCompleted)
        assertEquals(1, calls)

        response.complete(TwitchPage(emptyList(), null))
        initial.await()
        overlappingRefresh.await()
        assertEquals(1, calls)
    }

    @Test fun `queues one category refresh during pagination and preserves its tail`() = runTest {
        data class Pending(
            val cursor: String?,
            val result: CompletableDeferred<TwitchPage<TwitchCategory>>,
        )
        val pending = mutableListOf<Pending>()
        val api = object : FakeTwitchApi() {
            override suspend fun fetchTopCategoriesPage(
                first: Int,
                cursor: String?,
            ): TwitchPage<TwitchCategory> {
                val request = Pending(cursor, CompletableDeferred())
                pending += request
                return request.result.await()
            }
        }
        val repository = BrowseRepository(TwitchApiCache({ api }))

        val initial = async { repository.loadCategories(reset = true) }
        testScheduler.runCurrent()
        pending.single().result.complete(
            TwitchPage(listOf(category("1", "First"), category("2", "Second")), "page-2"),
        )
        initial.await()

        val pagination = async { repository.loadCategories() }
        testScheduler.runCurrent()
        val refresh = async { repository.refreshCategoriesFirstPage() }
        val duplicateRefresh = async { repository.refreshCategoriesFirstPage() }
        testScheduler.runCurrent()
        assertEquals(listOf<String?>(null, "page-2"), pending.map(Pending::cursor))

        pending[1].result.complete(
            TwitchPage(listOf(category("2", "Updated second"), category("3", "Third")), null),
        )
        testScheduler.runCurrent()
        assertEquals(listOf<String?>(null, "page-2", null), pending.map(Pending::cursor))
        pending[2].result.complete(
            TwitchPage(listOf(category("2", "Updated again"), category("4", "Fourth")), "fresh-page-2"),
        )
        pagination.await()
        refresh.await()
        duplicateRefresh.await()

        assertEquals(listOf("2", "4", "3"), repository.state.value.categories.map(BrowseCategory::id))
        assertEquals(null, repository.state.value.categoriesCursor)
    }

    @Test fun `channel repository deduplicates paginated broadcasts`() = runTest {
        var call = 0
        val first = broadcast("one")
        val duplicate = first.copy(title = "duplicate")
        val second = broadcast("two")
        val api = object : FakeTwitchApi() {
            override suspend fun fetchChannelDetails(
                login: String,
                videosFirst: Int,
                videosCursor: String?,
            ): TwitchChannelDetails {
                call += 1
                return TwitchChannelDetails(
                    id = "creator",
                    login = login,
                    displayName = "Creator",
                    description = "",
                    followers = 1,
                    pastBroadcasts = if (videosCursor == null) listOf(first) else listOf(duplicate, second),
                    pastBroadcastsCursor = if (videosCursor == null) "next" else null,
                )
            }
        }
        val repository = ChannelRepository(TwitchApiCache({ api }), "creator")
        repository.load()
        repository.loadMorePastBroadcasts()
        assertEquals(listOf("one", "two"), repository.state.value.channel?.pastBroadcasts?.map { it.id })
        assertEquals(2, call)
    }

    private fun category(id: String, name: String) = TwitchCategory(id, name, null, 1)

    private fun broadcast(id: String) = TwitchPastBroadcast(
        id = id,
        title = id,
        categoryId = "game",
        category = "Game",
        durationSeconds = 1,
        viewCount = 1,
    )
}
