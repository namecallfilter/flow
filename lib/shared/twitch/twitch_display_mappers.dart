import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flutter/material.dart";

List<StreamChannel> liveChannelsFromConnection(
  TwitchAuthConnection connection,
) => [
  for (final stream in connection.followedStreams)
    streamChannelFromStream(
      stream,
      avatarImageUrl: connection.usersById[stream.userId]?.profileImageUrl,
    ),
];

List<OfflineChannel> offlineChannelsFromConnection(
  TwitchAuthConnection connection,
) {
  final liveUserIds = {
    for (final stream in connection.followedStreams) stream.userId,
  };

  return [
    for (final channel in connection.followedChannels)
      if (!liveUserIds.contains(channel.broadcasterId))
        OfflineChannel(
          name: displayName(channel.broadcasterName, channel.broadcasterLogin),
          initials: initialsForName(
            displayName(channel.broadcasterName, channel.broadcasterLogin),
          ),
          lastLive: channel.followedAt == null
              ? "Offline"
              : "Followed ${relativeTime(channel.followedAt!)}",
          category: offlineCategory(connection, channel),
          avatarColors: colorsForText(channel.broadcasterId),
          avatarImageUrl: connection.usersById[channel.broadcasterId]?.profileImageUrl,
        ),
  ];
}

StreamChannel streamChannelFromStream(
  TwitchFollowedStream stream, {
  String? avatarImageUrl,
}) {
  final name = displayName(stream.userName, stream.userLogin);
  return StreamChannel(
    name: name,
    initials: initialsForName(name),
    title: stream.title.isEmpty ? "Live now" : stream.title,
    category: stream.gameName.isEmpty ? "Live" : stream.gameName,
    viewers: formatCompactCount(stream.viewerCount),
    avatarColors: colorsForText(stream.userId),
    thumbnailColors: colorsForText(stream.id, count: 3),
    avatarImageUrl: avatarImageUrl,
    thumbnailUrl: twitchThumbnailUrl(stream.thumbnailUrl),
  );
}

Future<BrowseCategory> browseCategoryFromApi(
  TwitchApiCache apiCache,
  TwitchCategory category, {
  bool refresh = false,
}) async {
  final streams = await apiCache.fetchLiveStreamsPage(
    first: 100,
    gameIds: [category.id],
    refresh: refresh,
  );
  final viewerCount = streams.data.fold<int>(
    0,
    (total, stream) => total + stream.viewerCount,
  );

  return BrowseCategory(
    id: category.id,
    name: category.name,
    viewerCount: viewerCount,
    viewers: formatCompactCount(viewerCount),
    imageUrl: twitchBoxArtUrl(category.boxArtUrl),
    colors: colorsForText(category.id),
  );
}

String browseErrorMessage(Object error) {
  if (error is TwitchApiException) {
    return error.message;
  }
  if (error is TwitchAuthException) {
    return error.message;
  }
  return error.toString();
}

String offlineCategory(
  TwitchAuthConnection connection,
  TwitchFollowedChannel channel,
) {
  final info = connection.channelInfoByBroadcasterId[channel.broadcasterId];
  if (info != null && info.gameName.isNotEmpty) {
    return info.gameName;
  }
  if (info != null && info.title.isNotEmpty) {
    return info.title;
  }
  return channel.broadcasterLogin.isEmpty ? "Channel" : channel.broadcasterLogin;
}

String displayName(String primary, String fallback) {
  if (primary.isNotEmpty) {
    return primary;
  }
  return fallback.isEmpty ? "Channel" : fallback;
}

String initialsForName(String name) {
  final words = name.trim().split(RegExp(r"\s+"));
  final initials = [
    for (final word in words)
      if (word.isNotEmpty) word.substring(0, 1).toUpperCase(),
  ].take(2).join();
  return initials.isEmpty ? "CH" : initials;
}

List<Color> colorsForText(String seed, {int count = 2}) {
  final hash = seed.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return [
    for (var index = 0; index < count; index++)
      HSLColor.fromAHSL(
        1,
        ((hash * 37) + (index * 52)) % 360,
        0.72,
        index.isEven ? 0.42 : 0.58,
      ).toColor(),
  ];
}

String formatCompactCount(int value) {
  if (value >= 1000000) {
    return "${_compactDecimal(value / 1000000)}M";
  }
  if (value >= 1000) {
    return "${_compactDecimal(value / 1000)}K";
  }
  return value.toString();
}

String relativeTime(DateTime date) {
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inDays <= 0) {
    return "today";
  }
  if (elapsed.inDays == 1) {
    return "1 day ago";
  }
  if (elapsed.inDays < 7) {
    return "${elapsed.inDays} days ago";
  }
  if (elapsed.inDays < 30) {
    final weeks = (elapsed.inDays / 7).floor();
    return weeks == 1 ? "1 week ago" : "$weeks weeks ago";
  }
  final months = (elapsed.inDays / 30).floor();
  return months == 1 ? "1 month ago" : "$months months ago";
}

String? twitchThumbnailUrl(String? template) {
  if (template == null || template.isEmpty) {
    return null;
  }
  return template.replaceAll("{width}", "320").replaceAll("{height}", "180");
}

String? twitchBoxArtUrl(String? template) {
  if (template == null || template.isEmpty) {
    return null;
  }
  const width = "1200";
  const height = "1600";
  final templatedUrl = template.replaceAll("{width}", width).replaceAll("{height}", height);
  if (templatedUrl != template) {
    return templatedUrl;
  }

  return template.replaceFirstMapped(
    RegExp(r"-\d+x\d+(\.[^/?#]+)([?#].*)?$"),
    (match) => "-${width}x$height${match[1]}${match[2] ?? ""}",
  );
}

String _compactDecimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith(".0") ? text.substring(0, text.length - 2) : text;
}
