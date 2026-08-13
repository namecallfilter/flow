package com.namecallfilter.flow.ui

import com.namecallfilter.flow.data.BrowseSearchRepository
import com.namecallfilter.flow.data.CategoryStreamsState
import com.namecallfilter.flow.data.ChannelState
import com.namecallfilter.flow.data.DefaultFlowPreferences
import com.namecallfilter.flow.data.FakeTwitchApi
import com.namecallfilter.flow.data.FlowPreferencesStore
import com.namecallfilter.flow.data.TwitchApiCache
import com.namecallfilter.flow.data.TwitchChannelDetails
import com.namecallfilter.flow.data.TwitchPage
import com.namecallfilter.flow.data.TwitchSearchChannel
import com.namecallfilter.flow.ui.components.shouldConsumePullMovement
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ChromeInteractionParityTest {
    @Test fun `new category and channel routes show loading on their first presentation`() {
        assertTrue(CategoryStreamsState().isInitialLoading)
        assertFalse(CategoryStreamsState(errorMessage = "failed").isInitialLoading)
        assertFalse(CategoryStreamsState(loaded = true).isInitialLoading)

        assertTrue(ChannelState().isInitialLoading)
        assertFalse(ChannelState(errorMessage = "failed").isInitialLoading)
        assertFalse(ChannelState(channel = channelDetails()).isInitialLoading)
    }

    @Test fun `query change enters loading presentation synchronously`() = runTest {
        val repository = searchRepository(FakeTwitchApi())
        val input = BrowseSearchInputCoordinator(
            repository = repository,
            debounceScope = this,
            requestScope = this,
        )

        input.updateQuery("speedrun")

        assertEquals("speedrun", input.query)
        assertTrue(input.isDebouncing)
        assertTrue(input.showsLoading(repository.state.value))

        input.updateQuery("  ")
        assertFalse(input.isDebouncing)
        assertFalse(input.showsLoading(repository.state.value))
    }

    @Test fun `popping search cancels only debounce and lets a started request finish`() = runTest {
        val channels = CompletableDeferred<TwitchPage<TwitchSearchChannel>>()
        var channelSearchCalls = 0
        val api = object : FakeTwitchApi() {
            override suspend fun searchChannelsPage(
                query: String,
                first: Int,
                cursor: String?,
                liveOnly: Boolean,
            ): TwitchPage<TwitchSearchChannel> {
                channelSearchCalls += 1
                return channels.await()
            }
        }
        val repository = searchRepository(api)
        val input = BrowseSearchInputCoordinator(
            repository = repository,
            debounceScope = this,
            requestScope = this,
        )

        input.updateQuery("speedrun")
        testScheduler.advanceTimeBy(300)
        testScheduler.runCurrent()
        assertEquals(1, channelSearchCalls)
        assertTrue(repository.state.value.isSearching)

        input.dispose()
        channels.complete(TwitchPage(emptyList(), null))
        testScheduler.advanceUntilIdle()

        assertFalse(repository.state.value.isSearching)
        assertEquals("speedrun", repository.state.value.query)
        assertEquals(listOf("speedrun"), repository.state.value.searchHistory)
    }

    @Test fun `popping search still cancels a debounce that has not fired`() = runTest {
        var channelSearchCalls = 0
        val api = object : FakeTwitchApi() {
            override suspend fun searchChannelsPage(
                query: String,
                first: Int,
                cursor: String?,
                liveOnly: Boolean,
            ): TwitchPage<TwitchSearchChannel> {
                channelSearchCalls += 1
                return TwitchPage(emptyList(), null)
            }
        }
        val repository = searchRepository(api)
        val input = BrowseSearchInputCoordinator(
            repository = repository,
            debounceScope = this,
            requestScope = this,
        )

        input.updateQuery("speedrun")
        input.dispose()
        testScheduler.advanceUntilIdle()

        assertEquals(0, channelSearchCalls)
        assertEquals("", repository.state.value.query)
    }

    @Test fun `refreshing consumes list movement`() {
        assertTrue(
            shouldConsumePullMovement(
                refreshing = true,
                intercepting = true,
                atTop = true,
                deltaY = 24f,
            ),
        )
        assertTrue(
            shouldConsumePullMovement(
                refreshing = true,
                intercepting = false,
                atTop = false,
                deltaY = -24f,
            ),
        )
        assertTrue(
            shouldConsumePullMovement(
                refreshing = false,
                intercepting = false,
                atTop = true,
                deltaY = 24f,
            ),
        )
    }

    private fun searchRepository(api: FakeTwitchApi): BrowseSearchRepository = BrowseSearchRepository(
        TwitchApiCache(clientLoader = { api }),
        DefaultFlowPreferences(MemoryPreferencesStore()),
    )

    private fun channelDetails() = TwitchChannelDetails(
        id = "creator",
        login = "creator",
        displayName = "Creator",
        description = "",
        followers = 0,
        pastBroadcasts = emptyList(),
        pastBroadcastsCursor = null,
    )
}

private class MemoryPreferencesStore : FlowPreferencesStore {
    private val strings = mutableMapOf<String, String>()
    private val lists = mutableMapOf<String, List<String>>()

    override suspend fun getString(key: String): String? = strings[key]

    override suspend fun putString(key: String, value: String) {
        strings[key] = value
    }

    override suspend fun getStringList(key: String): List<String>? = lists[key]

    override suspend fun putStringList(key: String, value: List<String>) {
        lists[key] = value
    }

    override suspend fun remove(key: String) {
        strings.remove(key)
        lists.remove(key)
    }
}
