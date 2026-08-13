package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import java.util.Locale

enum class BrowseSection { CATEGORIES, LIVE_CHANNELS }

data class BrowseState(
    val categories: List<BrowseCategory> = emptyList(),
    val liveChannels: List<StreamChannel> = emptyList(),
    val selectedSection: BrowseSection = BrowseSection.CATEGORIES,
    val categoriesLoaded: Boolean = false,
    val liveChannelsLoaded: Boolean = false,
    val isLoadingCategories: Boolean = false,
    val isLoadingLiveChannels: Boolean = false,
    val categoriesCursor: String? = null,
    val liveChannelsCursor: String? = null,
    val categoriesError: String? = null,
    val liveChannelsError: String? = null,
    val categoriesScrollOffset: Float = 0f,
    val liveChannelsScrollOffset: Float = 0f,
) {
    val activeLoading: Boolean
        get() = if (selectedSection == BrowseSection.CATEGORIES) isLoadingCategories else isLoadingLiveChannels
    val activeItemsEmpty: Boolean
        get() = if (selectedSection == BrowseSection.CATEGORIES) categories.isEmpty() else liveChannels.isEmpty()
    val activeError: String?
        get() = if (selectedSection == BrowseSection.CATEGORIES) categoriesError else liveChannelsError
}

class BrowseRepository(val apiCache: TwitchApiCache) {
    private val categoriesLock = Any()
    private val liveChannelsLock = Any()
    private var categoriesFirstPageLength = 0
    private var liveChannelsFirstPageLength = 0
    private var categoriesLoad: CompletableDeferred<Unit>? = null
    private var categoriesRefreshQueued = false
    private var categoriesQueuedPreserveTail = true
    private var liveChannelsLoad: CompletableDeferred<Unit>? = null
    private var liveChannelsRefreshQueued = false
    private var liveChannelsQueuedPreserveTail = true
    private val mutableState = MutableStateFlow(BrowseState())
    val state: StateFlow<BrowseState> = mutableState.asStateFlow()

    fun selectSection(section: BrowseSection?) {
        if (section != null) mutableState.update { it.copy(selectedSection = section) }
    }

    fun scrollOffsetFor(section: BrowseSection): Float = when (section) {
        BrowseSection.CATEGORIES -> mutableState.value.categoriesScrollOffset
        BrowseSection.LIVE_CHANNELS -> mutableState.value.liveChannelsScrollOffset
    }

    fun setScrollOffsetFor(section: BrowseSection, offset: Float) = mutableState.update { state ->
        when (section) {
            BrowseSection.CATEGORIES -> state.copy(categoriesScrollOffset = offset)
            BrowseSection.LIVE_CHANNELS -> state.copy(liveChannelsScrollOffset = offset)
        }
    }

    suspend fun loadCategories(
        reset: Boolean = false,
        refresh: Boolean = false,
        preserveTail: Boolean = false,
    ) {
        val ownership = synchronized(categoriesLock) {
            categoriesLoad?.let { active ->
                if (refresh) queueCategoriesRefresh(preserveTail)
                return@synchronized LoadOwnership(active, leader = false)
            }
            val current = mutableState.value
            if (!reset && current.categoriesLoaded && current.categoriesCursor == null) return
            LoadOwnership(
                CompletableDeferred<Unit>().also { categoriesLoad = it },
                leader = true,
            )
        }
        if (!ownership.leader) {
            ownership.operation.await()
            return
        }

        var nextReset = reset
        var nextRefresh = refresh
        var nextPreserveTail = preserveTail
        try {
            while (true) {
                loadCategoriesOnce(nextReset, nextRefresh, nextPreserveTail)
                val queuedTail = synchronized(categoriesLock) {
                    if (categoriesRefreshQueued) {
                        categoriesRefreshQueued = false
                        categoriesQueuedPreserveTail.also { categoriesQueuedPreserveTail = true }
                    } else {
                        if (categoriesLoad === ownership.operation) categoriesLoad = null
                        null
                    }
                } ?: break
                nextReset = true
                nextRefresh = true
                nextPreserveTail = queuedTail
            }
        } finally {
            synchronized(categoriesLock) {
                if (categoriesLoad === ownership.operation) categoriesLoad = null
            }
            ownership.operation.complete(Unit)
        }
    }

    private suspend fun loadCategoriesOnce(
        reset: Boolean,
        refresh: Boolean,
        preserveTail: Boolean,
    ) {
        val before = mutableState.value
        val preservedCursor = before.categoriesCursor
        val tailStart = categoriesFirstPageLength.coerceAtMost(before.categories.size)
        val tail = if (preserveTail) before.categories.drop(tailStart) else emptyList()
        mutableState.update {
            it.copy(
                isLoadingCategories = true,
                categoriesError = null,
                categoriesCursor = if (reset && !preserveTail) null else it.categoriesCursor,
            )
        }
        try {
            val page = apiCache.fetchTopCategoriesPage(
                cursor = if (reset) null else mutableState.value.categoriesCursor,
                refresh = refresh,
            )
            val next = page.data.map(::browseCategoryFromApi)
            if (reset) {
                val firstPage = mergeCategories(emptyList(), next)
                val all = if (preserveTail) uniqueCategories(firstPage + tail) else firstPage
                categoriesFirstPageLength = firstPage.size
                mutableState.update {
                    it.copy(
                        categories = all,
                        categoriesCursor = if (all.size > firstPage.size) preservedCursor else page.cursor,
                        categoriesLoaded = true,
                    )
                }
            } else {
                mutableState.update {
                    it.copy(
                        categories = mergeCategories(it.categories, next),
                        categoriesCursor = page.cursor,
                        categoriesLoaded = true,
                    )
                }
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            mutableState.update { it.copy(categoriesError = browseErrorMessage(error)) }
        } finally {
            mutableState.update { it.copy(isLoadingCategories = false) }
        }
    }

    private fun queueCategoriesRefresh(preserveTail: Boolean) {
        categoriesQueuedPreserveTail = if (categoriesRefreshQueued) {
            categoriesQueuedPreserveTail && preserveTail
        } else {
            preserveTail
        }
        categoriesRefreshQueued = true
    }

    suspend fun loadLiveChannels(
        reset: Boolean = false,
        refresh: Boolean = false,
        preserveTail: Boolean = false,
    ) {
        val ownership = synchronized(liveChannelsLock) {
            liveChannelsLoad?.let { active ->
                if (refresh) queueLiveChannelsRefresh(preserveTail)
                return@synchronized LoadOwnership(active, leader = false)
            }
            val current = mutableState.value
            if (!reset && current.liveChannelsLoaded && current.liveChannelsCursor == null) return
            LoadOwnership(
                CompletableDeferred<Unit>().also { liveChannelsLoad = it },
                leader = true,
            )
        }
        if (!ownership.leader) {
            ownership.operation.await()
            return
        }

        var nextReset = reset
        var nextRefresh = refresh
        var nextPreserveTail = preserveTail
        try {
            while (true) {
                loadLiveChannelsOnce(nextReset, nextRefresh, nextPreserveTail)
                val queuedTail = synchronized(liveChannelsLock) {
                    if (liveChannelsRefreshQueued) {
                        liveChannelsRefreshQueued = false
                        liveChannelsQueuedPreserveTail.also { liveChannelsQueuedPreserveTail = true }
                    } else {
                        if (liveChannelsLoad === ownership.operation) liveChannelsLoad = null
                        null
                    }
                } ?: break
                nextReset = true
                nextRefresh = true
                nextPreserveTail = queuedTail
            }
        } finally {
            synchronized(liveChannelsLock) {
                if (liveChannelsLoad === ownership.operation) liveChannelsLoad = null
            }
            ownership.operation.complete(Unit)
        }
    }

    private suspend fun loadLiveChannelsOnce(
        reset: Boolean,
        refresh: Boolean,
        preserveTail: Boolean,
    ) {
        val before = mutableState.value
        val preservedCursor = before.liveChannelsCursor
        val tailStart = liveChannelsFirstPageLength.coerceAtMost(before.liveChannels.size)
        val tail = if (preserveTail) before.liveChannels.drop(tailStart) else emptyList()
        mutableState.update {
            it.copy(
                isLoadingLiveChannels = true,
                liveChannelsError = null,
                liveChannelsCursor = if (reset && !preserveTail) null else it.liveChannelsCursor,
            )
        }
        try {
            val page = apiCache.fetchLiveStreamsPage(
                cursor = if (reset) null else mutableState.value.liveChannelsCursor,
                refresh = refresh,
            )
            val users = apiCache.fetchUsersByIds(page.data.map(TwitchFollowedStream::userId), refresh)
            val next = page.data.mapNotNull { stream ->
                users[stream.userId]?.let { streamChannelFromStream(stream, it.profileImageUrl) }
            }
            if (reset) {
                val firstPage = mergeLiveChannels(emptyList(), next)
                val all = if (preserveTail) uniqueLiveChannels(firstPage + tail) else firstPage
                liveChannelsFirstPageLength = firstPage.size
                mutableState.update {
                    it.copy(
                        liveChannels = all,
                        liveChannelsCursor = if (all.size > firstPage.size) preservedCursor else page.cursor,
                        liveChannelsLoaded = true,
                    )
                }
            } else {
                mutableState.update {
                    it.copy(
                        liveChannels = mergeLiveChannels(it.liveChannels, next),
                        liveChannelsCursor = page.cursor,
                        liveChannelsLoaded = true,
                    )
                }
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            mutableState.update { it.copy(liveChannelsError = browseErrorMessage(error)) }
        } finally {
            mutableState.update { it.copy(isLoadingLiveChannels = false) }
        }
    }

    private fun queueLiveChannelsRefresh(preserveTail: Boolean) {
        liveChannelsQueuedPreserveTail = if (liveChannelsRefreshQueued) {
            liveChannelsQueuedPreserveTail && preserveTail
        } else {
            preserveTail
        }
        liveChannelsRefreshQueued = true
    }

    suspend fun refreshActiveSection() {
        if (mutableState.value.selectedSection == BrowseSection.CATEGORIES) {
            loadCategories(reset = true, refresh = true)
        } else {
            loadLiveChannels(reset = true, refresh = true)
        }
    }

    suspend fun refreshCategoriesFirstPage() =
        loadCategories(reset = true, refresh = true, preserveTail = true)

    suspend fun refreshLiveChannelsFirstPage() =
        loadLiveChannels(reset = true, refresh = true, preserveTail = true)

    private data class LoadOwnership(
        val operation: CompletableDeferred<Unit>,
        val leader: Boolean,
    )
}

data class BrowseSearchState(
    val query: String = "",
    val channels: List<TwitchSearchChannel> = emptyList(),
    val categories: List<BrowseCategory> = emptyList(),
    val searchHistory: List<String> = emptyList(),
    val isSearching: Boolean = false,
    val errorMessage: String? = null,
)

class BrowseSearchRepository(
    val apiCache: TwitchApiCache,
    val preferences: FlowPreferences,
) {
    private val generationLock = Any()
    private var searchGeneration = 0
    private val mutableState = MutableStateFlow(BrowseSearchState())
    val state: StateFlow<BrowseSearchState> = mutableState.asStateFlow()

    suspend fun loadSearchHistory() {
        if (mutableState.value.searchHistory.isEmpty()) {
            mutableState.update { it.copy(searchHistory = preferences.readBrowseSearchHistory()) }
        }
    }

    fun clearSearch() {
        nextGeneration()
        mutableState.value = mutableState.value.copy(
            query = "",
            channels = emptyList(),
            categories = emptyList(),
            isSearching = false,
            errorMessage = null,
        )
    }

    fun invalidatePendingSearch() {
        nextGeneration()
        mutableState.update { it.copy(isSearching = false, errorMessage = null) }
    }

    suspend fun clearSearchHistory() {
        mutableState.update { it.copy(searchHistory = emptyList()) }
        preferences.clearBrowseSearchHistory()
    }

    suspend fun saveQueryToHistory(query: String) {
        val history = updatedSearchHistory(query)
        mutableState.update { it.copy(searchHistory = history) }
        preferences.saveBrowseSearchHistory(history)
    }

    suspend fun search(query: String) {
        val normalized = query.trim()
        val generation = nextGeneration()
        if (normalized.isEmpty()) {
            clearSearch()
            return
        }
        mutableState.update { it.copy(query = normalized, isSearching = true, errorMessage = null) }
        try {
            val channelPage = apiCache.searchChannelsPage(normalized, first = 8)
            val categoryPage = apiCache.searchCategoriesPage(normalized, first = 8)
            val users = apiCache.fetchUsersByIds(channelPage.data.map(TwitchSearchChannel::id))
            val liveLogins = channelPage.data
                .filter { it.isLive && it.id in users }
                .map(TwitchSearchChannel::broadcasterLogin)
            val viewerCounts = if (liveLogins.isEmpty()) {
                emptyMap()
            } else {
                apiCache.fetchLiveStreamsPage(userLogins = liveLogins).data.associate {
                    it.userLogin.lowercase(Locale.ROOT) to it.viewerCount
                }
            }
            val channels = channelPage.data.filter { it.id in users }.sortedWith { left, right ->
                if (left.isLive != right.isLive) {
                    if (left.isLive) -1 else 1
                } else {
                    val count = (viewerCounts[right.broadcasterLogin.lowercase(Locale.ROOT)] ?: 0)
                        .compareTo(viewerCounts[left.broadcasterLogin.lowercase(Locale.ROOT)] ?: 0)
                    if (count != 0) count else left.displayName.lowercase(Locale.ROOT)
                        .compareTo(right.displayName.lowercase(Locale.ROOT))
                }
            }
            val categories = categoryPage.data.map(::browseCategoryFromApi).sortedWith { left, right ->
                val count = right.viewerCount.compareTo(left.viewerCount)
                if (count != 0) count else left.name.lowercase(Locale.ROOT)
                    .compareTo(right.name.lowercase(Locale.ROOT))
            }
            if (!isCurrent(generation)) return
            mutableState.update {
                it.copy(channels = channels, categories = categories, isSearching = false)
            }
            saveQueryToHistory(normalized)
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            if (!isCurrent(generation)) return
            mutableState.update {
                it.copy(errorMessage = browseErrorMessage(error), isSearching = false)
            }
        }
    }

    fun updatedSearchHistory(query: String): List<String> =
        normalizeBrowseSearchHistory(listOf(query) + mutableState.value.searchHistory)

    private fun nextGeneration(): Int = synchronized(generationLock) { ++searchGeneration }
    private fun isCurrent(generation: Int) = synchronized(generationLock) { generation == searchGeneration }
}

data class CategoryStreamsState(
    val channels: List<StreamChannel> = emptyList(),
    val isLoading: Boolean = false,
    val loaded: Boolean = false,
    val cursor: String? = null,
    val errorMessage: String? = null,
) {
    /** Keeps the first frame in Flutter's loading presentation until data or an error arrives. */
    val isInitialLoading: Boolean
        get() = channels.isEmpty() && !loaded && errorMessage == null
}

class CategoryStreamsRepository(
    val apiCache: TwitchApiCache,
    val category: BrowseCategory,
) {
    private val mutex = Mutex()
    private val mutableState = MutableStateFlow(CategoryStreamsState())
    val state: StateFlow<CategoryStreamsState> = mutableState.asStateFlow()

    suspend fun loadStreams(reset: Boolean = false, refresh: Boolean = false) {
        // The Flutter store drops overlapping triggers rather than queuing another page or
        // refresh behind the active request.
        if (!mutex.tryLock()) return
        try {
            val current = mutableState.value
            if (!reset && current.loaded && current.cursor == null) return
            mutableState.update {
                it.copy(isLoading = true, errorMessage = null, cursor = if (reset) null else it.cursor)
            }
            try {
                val page = apiCache.fetchLiveStreamsPage(
                    gameIds = listOf(category.id),
                    cursor = if (reset) null else mutableState.value.cursor,
                    refresh = refresh,
                )
                val users = apiCache.fetchUsersByIds(page.data.map(TwitchFollowedStream::userId), refresh)
                val channels = page.data.mapNotNull { stream ->
                    users[stream.userId]?.let { streamChannelFromStream(stream, it.profileImageUrl) }
                }
                mutableState.update {
                    it.copy(
                        channels = if (reset) channels else it.channels + channels,
                        cursor = page.cursor,
                        loaded = true,
                    )
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                mutableState.update { it.copy(errorMessage = browseErrorMessage(error)) }
            } finally {
                mutableState.update { it.copy(isLoading = false) }
            }
        } finally {
            mutex.unlock()
        }
    }
}

private fun uniqueCategories(values: List<BrowseCategory>): List<BrowseCategory> =
    values.distinctBy(BrowseCategory::id)

private fun mergeCategories(current: List<BrowseCategory>, next: List<BrowseCategory>): List<BrowseCategory> {
    val merged = LinkedHashMap<String, BrowseCategory>()
    (current + next).forEach { merged[it.id] = it }
    return merged.values.toList()
}

private fun uniqueLiveChannels(values: List<StreamChannel>): List<StreamChannel> =
    values.distinctBy(::liveChannelIdentity)

private fun mergeLiveChannels(current: List<StreamChannel>, next: List<StreamChannel>): List<StreamChannel> {
    val merged = LinkedHashMap<String, StreamChannel>()
    (current + next).forEach { merged[liveChannelIdentity(it)] = it }
    return merged.values.toList()
}

private fun liveChannelIdentity(channel: StreamChannel): String = when {
    channel.id.isNotBlank() -> "id:${channel.id.trim()}"
    channel.login.isNotBlank() -> "login:${channel.login.trim().lowercase(Locale.ROOT)}"
    else -> "name:${channel.name.trim().lowercase(Locale.ROOT)}"
}
