package com.namecallfilter.flow.data

import java.net.URI

open class FakeTwitchApi : TwitchApi {
    override suspend fun validateAccessToken(token: String) = true
    override suspend fun fetchCurrentUser() = TwitchUser("viewer", "viewer", "Viewer")
    override suspend fun fetchFollowedStreams(userId: String) = emptyList<TwitchFollowedStream>()
    override suspend fun fetchFollowedChannels(userId: String) = emptyList<TwitchFollowedChannel>()
    override suspend fun fetchUsersByIds(ids: List<String>) = emptyMap<String, TwitchUser>()
    override suspend fun fetchChannelInfoByBroadcasterIds(broadcasterIds: List<String>) =
        emptyMap<String, TwitchChannelInfo>()
    override suspend fun fetchTopCategories(first: Int) = fetchTopCategoriesPage(first).data
    override suspend fun fetchTopCategoriesPage(first: Int, cursor: String?) =
        TwitchPage<TwitchCategory>(emptyList(), null)
    override suspend fun searchCategories(query: String, first: Int) =
        searchCategoriesPage(query, first).data
    override suspend fun searchCategoriesPage(query: String, first: Int, cursor: String?) =
        TwitchPage<TwitchCategory>(emptyList(), null)
    override suspend fun fetchLiveStreams(
        first: Int,
        gameIds: List<String>,
        userLogins: List<String>,
    ) = fetchLiveStreamsPage(first, gameIds, userLogins).data
    override suspend fun fetchLiveStreamsPage(
        first: Int,
        gameIds: List<String>,
        userLogins: List<String>,
        cursor: String?,
    ) = TwitchPage<TwitchFollowedStream>(emptyList(), null)
    override suspend fun searchLiveChannels(query: String, first: Int) =
        searchChannelsPage(query, first, liveOnly = true).data
    override suspend fun searchChannelsPage(
        query: String,
        first: Int,
        cursor: String?,
        liveOnly: Boolean,
    ) = TwitchPage<TwitchSearchChannel>(emptyList(), null)
    override suspend fun fetchChannelDetails(login: String, videosFirst: Int, videosCursor: String?) =
        TwitchChannelDetails(login, login, login, "", 0, emptyList(), null)
    override suspend fun fetchLivePlaybackUri(login: String) = URI("https://example.test/$login.m3u8")
    override suspend fun fetchChannelSubscriptionStatus(login: String) = false
}

class MemorySecureStore : TwitchSecureStore {
    var pendingState: String? = null
    var accessToken: String? = null
    var webToken: String? = null

    override suspend fun savePendingState(state: String) { pendingState = state }
    override suspend fun readPendingState() = pendingState
    override suspend fun clearPendingState() { pendingState = null }
    override suspend fun saveAccessToken(token: String) { accessToken = token }
    override suspend fun readAccessToken() = accessToken
    override suspend fun saveWebSessionToken(token: String) { webToken = token }
    override suspend fun readWebSessionToken() = webToken
    override suspend fun clearSession() {
        pendingState = null
        accessToken = null
        webToken = null
    }
}
