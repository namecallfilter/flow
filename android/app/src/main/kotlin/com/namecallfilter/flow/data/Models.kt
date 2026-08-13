package com.namecallfilter.flow.data

import java.time.Instant

data class TwitchUser(
    val id: String,
    val login: String,
    val displayName: String,
    val profileImageUrl: String? = null,
)

data class TwitchFollowedStream(
    val id: String,
    val userId: String,
    val userLogin: String,
    val userName: String,
    val gameName: String,
    val title: String,
    val viewerCount: Int,
    val thumbnailUrl: String? = null,
    val startedAt: Instant? = null,
    val tags: List<String> = emptyList(),
    val gameId: String = "",
)

data class TwitchFollowedChannel(
    val broadcasterId: String,
    val broadcasterLogin: String,
    val broadcasterName: String,
    val followedAt: Instant? = null,
)

data class TwitchChannelInfo(
    val broadcasterId: String,
    val broadcasterName: String,
    val gameName: String,
    val title: String,
)

data class TwitchCategory(
    val id: String,
    val name: String,
    val boxArtUrl: String?,
    val viewerCount: Int,
)

data class TwitchSearchChannel(
    val id: String,
    val broadcasterLogin: String,
    val displayName: String,
    val gameName: String,
    val title: String,
    val isLive: Boolean,
    val thumbnailUrl: String? = null,
    val startedAt: Instant? = null,
)

data class TwitchChannelLiveStream(
    val id: String,
    val title: String,
    val categoryId: String,
    val category: String,
    val viewerCount: Int,
    val thumbnailUrl: String? = null,
    val startedAt: Instant? = null,
)

data class TwitchPastBroadcast(
    val id: String,
    val title: String,
    val categoryId: String,
    val category: String,
    val durationSeconds: Long,
    val viewCount: Int,
    val thumbnailUrl: String? = null,
    val publishedAt: Instant? = null,
    val createdAt: Instant? = null,
)

data class TwitchChannelDetails(
    val id: String,
    val login: String,
    val displayName: String,
    val description: String,
    val followers: Int,
    val pastBroadcasts: List<TwitchPastBroadcast>,
    val pastBroadcastsCursor: String?,
    val profileImageUrl: String? = null,
    val liveStream: TwitchChannelLiveStream? = null,
)

data class TwitchPage<T>(
    val data: List<T>,
    val cursor: String?,
)

data class TwitchAuthConnection(
    val user: TwitchUser,
    val followedStreams: List<TwitchFollowedStream>,
    val followedChannels: List<TwitchFollowedChannel>,
    val usersById: Map<String, TwitchUser> = emptyMap(),
    val channelInfoByBroadcasterId: Map<String, TwitchChannelInfo> = emptyMap(),
)

/** ARGB colors are stored as Ints so the domain layer remains independent of Compose. */
data class StreamChannel(
    val login: String,
    val name: String,
    val initials: String,
    val title: String,
    val category: String,
    val viewers: String,
    val avatarColors: List<Int>,
    val thumbnailColors: List<Int>,
    val id: String = "",
    val avatarImageUrl: String? = null,
    val thumbnailUrl: String? = null,
    val startedAt: Instant? = null,
    val categoryId: String = "",
)

data class OfflineChannel(
    val name: String,
    val initials: String,
    val lastLive: String,
    val category: String,
    val avatarColors: List<Int>,
    val id: String = "",
    val login: String = "",
    val avatarImageUrl: String? = null,
)

data class BrowseCategory(
    val id: String,
    val name: String,
    val viewerCount: Int,
    val viewers: String,
    val imageUrl: String?,
    val colors: List<Int>,
)

enum class FlowThemeMode { LIGHT, DARK, SYSTEM }

class TwitchApiException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    override fun toString(): String = "TwitchApiException: ${message.orEmpty()}"
}

class TwitchAuthException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    override fun toString(): String = "TwitchAuthException: ${message.orEmpty()}"
}
