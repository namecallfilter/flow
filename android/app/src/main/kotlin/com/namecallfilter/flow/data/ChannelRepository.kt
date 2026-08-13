package com.namecallfilter.flow.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class ChannelState(
    val channel: TwitchChannelDetails? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val isLoadingPastBroadcasts: Boolean = false,
    val pastBroadcastsError: String? = null,
) {
    /** Flutter enters loading synchronously from initState, before its first route frame is painted. */
    val isInitialLoading: Boolean get() = channel == null && errorMessage == null
    val canLoadMorePastBroadcasts: Boolean get() = channel?.pastBroadcastsCursor != null
}

class ChannelRepository(
    val apiCache: TwitchApiCache,
    val login: String,
) {
    private val lock = Any()
    private var generation = 0
    private val loadedPastBroadcastCursors = mutableSetOf<String>()
    private val mutableState = MutableStateFlow(ChannelState())
    val state: StateFlow<ChannelState> = mutableState.asStateFlow()

    suspend fun load(refresh: Boolean = false) {
        val currentGeneration = synchronized(lock) {
            generation += 1
            loadedPastBroadcastCursors.clear()
            generation
        }
        mutableState.update {
            it.copy(
                isLoading = true,
                isLoadingPastBroadcasts = false,
                errorMessage = null,
                pastBroadcastsError = null,
            )
        }
        try {
            val channel = apiCache.fetchChannelDetails(login, refresh = refresh)
            if (!isCurrent(currentGeneration)) return
            mutableState.update { it.copy(channel = channel, errorMessage = null) }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            if (!isCurrent(currentGeneration)) return
            mutableState.update { it.copy(errorMessage = browseErrorMessage(error)) }
        } finally {
            if (isCurrent(currentGeneration)) mutableState.update { it.copy(isLoading = false) }
        }
    }

    suspend fun loadMorePastBroadcasts() {
        val currentChannel = mutableState.value.channel ?: return
        val cursor = currentChannel.pastBroadcastsCursor ?: return
        val currentGeneration = synchronized(lock) {
            if (mutableState.value.isLoadingPastBroadcasts || cursor in loadedPastBroadcastCursors) {
                return
            }
            generation
        }
        mutableState.update { it.copy(isLoadingPastBroadcasts = true, pastBroadcastsError = null) }
        try {
            val nextPage = apiCache.fetchChannelDetails(login, videosCursor = cursor)
            if (!isCurrent(currentGeneration) || mutableState.value.channel !== currentChannel) return
            synchronized(lock) { loadedPastBroadcastCursors += cursor }
            val seenIds = currentChannel.pastBroadcasts.mapTo(mutableSetOf()) { it.id }
            val broadcasts = currentChannel.pastBroadcasts + nextPage.pastBroadcasts.filter {
                seenIds.add(it.id)
            }
            val nextCursor = nextPage.pastBroadcastsCursor?.takeUnless { next ->
                synchronized(lock) { next in loadedPastBroadcastCursors }
            }
            mutableState.update {
                it.copy(
                    channel = currentChannel.copy(
                        pastBroadcasts = broadcasts,
                        pastBroadcastsCursor = nextCursor,
                    ),
                )
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            if (!isCurrent(currentGeneration) || mutableState.value.channel !== currentChannel) return
            mutableState.update { it.copy(pastBroadcastsError = browseErrorMessage(error)) }
        } finally {
            if (isCurrent(currentGeneration)) {
                mutableState.update { it.copy(isLoadingPastBroadcasts = false) }
            }
        }
    }

    private fun isCurrent(value: Int) = synchronized(lock) { value == generation }
}
