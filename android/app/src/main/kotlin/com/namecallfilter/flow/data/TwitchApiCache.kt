package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import java.net.URI
import java.util.Locale

/** Small session-scoped LRU with request coalescing; playback/subscription are intentionally uncached. */
class TwitchApiCache(
    private val clientLoader: suspend () -> TwitchApi,
    val maxEntries: Int = 128,
) {
    init {
        require(maxEntries > 0)
    }

    private val lock = Any()
    private val values = LinkedHashMap<String, Any?>(16, 0.75f, true)
    private val inFlight = mutableMapOf<String, CompletableDeferred<Any?>>()
    private var revision = 0

    fun clear() {
        synchronized(lock) {
            revision += 1
            values.clear()
            inFlight.clear()
        }
    }

    suspend fun fetchTopCategoriesPage(
        first: Int = 12,
        cursor: String? = null,
        refresh: Boolean = false,
    ): TwitchPage<TwitchCategory> = cached(
        cacheKey("topCategories", mapOf("first" to first, "cursor" to cursor)),
        refresh,
    ) { it.fetchTopCategoriesPage(first, cursor) }

    suspend fun fetchLiveStreamsPage(
        first: Int = 20,
        gameIds: List<String> = emptyList(),
        userLogins: List<String> = emptyList(),
        cursor: String? = null,
        refresh: Boolean = false,
    ): TwitchPage<TwitchFollowedStream> = cached(
        cacheKey(
            "liveStreams",
            mapOf(
                "first" to first,
                "gameIds" to normalizedValues(gameIds),
                "userLogins" to normalizedValues(userLogins),
                "cursor" to cursor,
            ),
        ),
        refresh,
    ) { it.fetchLiveStreamsPage(first, gameIds, userLogins, cursor) }

    suspend fun fetchUsersByIds(
        ids: List<String>,
        refresh: Boolean = false,
    ): Map<String, TwitchUser> = cached(
        cacheKey("usersByIds", mapOf("ids" to normalizedValues(ids))),
        refresh,
    ) { it.fetchUsersByIds(ids) }

    suspend fun searchChannelsPage(
        query: String,
        first: Int = 20,
        cursor: String? = null,
        liveOnly: Boolean = false,
        refresh: Boolean = false,
    ): TwitchPage<TwitchSearchChannel> = cached(
        cacheKey(
            "searchChannels",
            mapOf(
                "query" to query.trim().lowercase(Locale.ROOT),
                "first" to first,
                "cursor" to cursor,
                "liveOnly" to liveOnly,
            ),
        ),
        refresh,
    ) { it.searchChannelsPage(query, first, cursor, liveOnly) }

    suspend fun fetchChannelDetails(
        login: String,
        videosFirst: Int = 30,
        videosCursor: String? = null,
        refresh: Boolean = false,
    ): TwitchChannelDetails = cached(
        cacheKey(
            "channelDetails",
            mapOf(
                "login" to login.trim().lowercase(Locale.ROOT),
                "videosFirst" to videosFirst,
                "videosCursor" to videosCursor,
            ),
        ),
        refresh,
    ) { it.fetchChannelDetails(login, videosFirst, videosCursor) }

    suspend fun searchCategoriesPage(
        query: String,
        first: Int = 20,
        cursor: String? = null,
        refresh: Boolean = false,
    ): TwitchPage<TwitchCategory> = cached(
        cacheKey(
            "searchCategories",
            mapOf(
                "query" to query.trim().lowercase(Locale.ROOT),
                "first" to first,
                "cursor" to cursor,
            ),
        ),
        refresh,
    ) { it.searchCategoriesPage(query, first, cursor) }

    suspend fun fetchLivePlaybackUri(login: String): URI =
        clientLoader().fetchLivePlaybackUri(login)

    suspend fun fetchChannelSubscriptionStatus(login: String): Boolean =
        clientLoader().fetchChannelSubscriptionStatus(login)

    @Suppress("UNCHECKED_CAST")
    private suspend fun <T> cached(
        key: String,
        refresh: Boolean,
        load: suspend (TwitchApi) -> T,
    ): T {
        var leader = false
        var loadRevision = 0
        val deferred = synchronized(lock) {
            if (!refresh && values.containsKey(key)) {
                return values[key] as T
            }
            if (!refresh) inFlight[key]?.let { return@synchronized it }

            leader = true
            loadRevision = revision
            CompletableDeferred<Any?>().also { inFlight[key] = it }
        }
        if (!leader) return deferred.await() as T

        try {
            val value = load(clientLoader())
            deferred.complete(value)
            synchronized(lock) {
                if (loadRevision == revision) {
                    values.remove(key)
                    values[key] = value
                    while (values.size > maxEntries) {
                        values.remove(values.entries.first().key)
                    }
                }
            }
            return value
        } catch (error: Throwable) {
            deferred.completeExceptionally(error)
            throw error
        } finally {
            synchronized(lock) {
                if (loadRevision == revision && inFlight[key] === deferred) inFlight.remove(key)
            }
        }
    }
}

internal fun cacheKey(namespace: String, values: Map<String, Any?>): String = buildList {
    add(namespace)
    values.toSortedMap().forEach { (key, value) -> add("$key=${cacheValue(value)}") }
}.joinToString("|")

private fun cacheValue(value: Any?): String = when (value) {
    null -> ""
    is Iterable<*> -> normalizedValues(value.filterIsInstance<String>()).joinToString(",")
    else -> value.toString()
}

private fun normalizedValues(values: Iterable<String>): List<String> = values
    .map(String::trim)
    .filter(String::isNotEmpty)
    .sorted()
