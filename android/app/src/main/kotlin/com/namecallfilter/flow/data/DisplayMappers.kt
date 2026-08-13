package com.namecallfilter.flow.data

import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.Locale
import kotlin.math.floor
import kotlin.math.roundToInt

fun liveChannelsFromConnection(connection: TwitchAuthConnection): List<StreamChannel> =
    connection.followedStreams.map { stream ->
        streamChannelFromStream(stream, connection.usersById[stream.userId]?.profileImageUrl)
    }

fun offlineChannelsFromConnection(
    connection: TwitchAuthConnection,
    clock: Clock = Clock.systemDefaultZone(),
): List<OfflineChannel> {
    val liveUserIds = connection.followedStreams.mapTo(mutableSetOf()) { it.userId }
    return connection.followedChannels
        .asSequence()
        .filterNot { it.broadcasterId in liveUserIds }
        .sortedWith(
            compareByDescending<TwitchFollowedChannel> { it.followedAt }
                .thenBy(String.CASE_INSENSITIVE_ORDER) {
                    displayName(it.broadcasterName, it.broadcasterLogin)
                },
        )
        .map { channel ->
            val name = displayName(channel.broadcasterName, channel.broadcasterLogin)
            OfflineChannel(
                id = channel.broadcasterId,
                login = channel.broadcasterLogin,
                name = name,
                initials = initialsForName(name),
                lastLive = channel.followedAt?.let { "Followed ${relativeTime(it, clock)}" } ?: "Offline",
                category = offlineCategory(connection, channel),
                avatarColors = colorsForText(channel.broadcasterId),
                avatarImageUrl = connection.usersById[channel.broadcasterId]?.profileImageUrl,
            )
        }
        .toList()
}

fun streamChannelFromStream(
    stream: TwitchFollowedStream,
    avatarImageUrl: String? = null,
): StreamChannel {
    val name = displayName(stream.userName, stream.userLogin)
    return StreamChannel(
        id = stream.userId,
        login = stream.userLogin,
        name = name,
        initials = initialsForName(name),
        title = stream.title.ifEmpty { "Live now" },
        category = stream.gameName.ifEmpty { "Live" },
        viewers = formatCompactCount(stream.viewerCount),
        avatarColors = colorsForText(stream.userId),
        thumbnailColors = colorsForText(stream.id, count = 3),
        avatarImageUrl = avatarImageUrl,
        thumbnailUrl = twitchThumbnailUrl(stream.thumbnailUrl),
        startedAt = stream.startedAt,
        categoryId = stream.gameId,
    )
}

fun browseCategoryFromStream(channel: StreamChannel): BrowseCategory? {
    val id = channel.categoryId.trim()
    val name = channel.category.trim()
    if (id.isEmpty() || name.isEmpty()) return null
    return BrowseCategory(
        id = id,
        name = name,
        viewerCount = 0,
        viewers = "",
        imageUrl = null,
        colors = colorsForText(id),
    )
}

fun browseCategoryFromApi(category: TwitchCategory): BrowseCategory = BrowseCategory(
    id = category.id,
    name = category.name,
    viewerCount = category.viewerCount,
    viewers = formatCompactCount(category.viewerCount),
    imageUrl = twitchBoxArtUrl(category.boxArtUrl),
    colors = colorsForText(category.id),
)

fun browseErrorMessage(error: Throwable): String = when (error) {
    is TwitchApiException, is TwitchAuthException -> error.message.orEmpty()
    else -> error.toString()
}

fun offlineCategory(connection: TwitchAuthConnection, channel: TwitchFollowedChannel): String {
    val info = connection.channelInfoByBroadcasterId[channel.broadcasterId]
    return when {
        !info?.gameName.isNullOrEmpty() -> info.gameName
        !info?.title.isNullOrEmpty() -> info.title
        channel.broadcasterLogin.isEmpty() -> "Channel"
        else -> channel.broadcasterLogin
    }
}

fun displayName(primary: String, fallback: String): String = when {
    primary.isNotEmpty() -> primary
    fallback.isNotEmpty() -> fallback
    else -> "Channel"
}

fun initialsForName(name: String): String {
    val initials = name.trim()
        .split(Regex("\\s+"))
        .asSequence()
        .filter(String::isNotEmpty)
        .take(2)
        .joinToString("") { it.substring(0, 1).uppercase(Locale.ROOT) }
    return initials.ifEmpty { "CH" }
}

fun colorsForText(seed: String, count: Int = 2): List<Int> {
    val hash = seed.sumOf(Char::code)
    return List(count) { index ->
        hslToArgb(
            hue = (((hash * 37L) + (index * 52L)) % 360L).toDouble(),
            saturation = 0.72,
            lightness = if (index % 2 == 0) 0.42 else 0.58,
        )
    }
}

fun formatCompactCount(value: Int): String = when {
    value >= 1_000_000 -> "${compactDecimal(value / 1_000_000.0)}M"
    value >= 1_000 -> "${compactDecimal(value / 1_000.0)}K"
    else -> value.toString()
}

fun relativeTime(date: Instant, clock: Clock = Clock.systemDefaultZone()): String {
    val elapsedDays = Duration.between(date, clock.instant()).toDays()
    if (elapsedDays <= 0) return "today"
    if (elapsedDays == 1L) return "1 day ago"
    if (elapsedDays < 7) return "$elapsedDays days ago"
    if (elapsedDays < 30) {
        val weeks = floor(elapsedDays / 7.0).toLong()
        return if (weeks == 1L) "1 week ago" else "$weeks weeks ago"
    }
    val months = floor(elapsedDays / 30.0).toLong()
    if (months >= 12) {
        val years = floor(months / 12.0).toLong()
        return if (years == 1L) "1 year ago" else "$years years ago"
    }
    return if (months == 1L) "1 month ago" else "$months months ago"
}

fun twitchThumbnailUrl(template: String?): String? = template
    ?.takeIf(String::isNotEmpty)
    ?.replace("{width}", "320")
    ?.replace("{height}", "180")

fun twitchBoxArtUrl(template: String?): String? {
    if (template.isNullOrEmpty()) return null
    val templated = template.replace("{width}", "300").replace("{height}", "400")
    if (templated != template) return templated
    return Regex("-\\d+x\\d+(\\.[^/?#]+)([?#].*)?$").replace(template) { match ->
        "-300x400${match.groupValues[1]}${match.groupValues[2]}"
    }
}

private fun compactDecimal(value: Double): String = String.format(Locale.ROOT, "%.1f", value)
    .removeSuffix(".0")

private fun hslToArgb(hue: Double, saturation: Double, lightness: Double): Int {
    val chroma = (1 - kotlin.math.abs(2 * lightness - 1)) * saturation
    val huePrime = hue / 60.0
    val x = chroma * (1 - kotlin.math.abs(huePrime % 2 - 1))
    val (r1, g1, b1) = when (huePrime.toInt()) {
        0 -> Triple(chroma, x, 0.0)
        1 -> Triple(x, chroma, 0.0)
        2 -> Triple(0.0, chroma, x)
        3 -> Triple(0.0, x, chroma)
        4 -> Triple(x, 0.0, chroma)
        else -> Triple(chroma, 0.0, x)
    }
    val m = lightness - chroma / 2
    val r = ((r1 + m) * 255).roundToInt().coerceIn(0, 255)
    val g = ((g1 + m) * 255).roundToInt().coerceIn(0, 255)
    val b = ((b1 + m) * 255).roundToInt().coerceIn(0, 255)
    return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
}
