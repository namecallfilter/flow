import "dart:async";
import "dart:convert";
import "dart:math" as math;

import "package:flow/api/twitch_chat_message.dart";
import "package:flow/api/twitch_cookie_extractor.dart";
import "package:flow/graphql/FlowAvailableChannelPoints.graphql.dart";
import "package:flow/graphql/FlowBlockUser.graphql.dart";
import "package:flow/graphql/FlowChannelDetails.graphql.dart";
import "package:flow/graphql/FlowChannelSubscription.graphql.dart";
import "package:flow/graphql/FlowChatAccess.graphql.dart";
import "package:flow/graphql/FlowChatAssets.graphql.dart";
import "package:flow/graphql/FlowChatReplies.graphql.dart";
import "package:flow/graphql/FlowChatUser.graphql.dart";
import "package:flow/graphql/FlowChatters.graphql.dart";
import "package:flow/graphql/FlowClaimChannelPoints.graphql.dart";
import "package:flow/graphql/FlowCurrentUser.graphql.dart";
import "package:flow/graphql/FlowFollowUser.graphql.dart";
import "package:flow/graphql/FlowFollowedLiveUsers.graphql.dart";
import "package:flow/graphql/FlowFollowedUsers.graphql.dart";
import "package:flow/graphql/FlowGameStreams.graphql.dart";
import "package:flow/graphql/FlowPinnedChat.graphql.dart";
import "package:flow/graphql/FlowPlaybackAccessToken.graphql.dart";
import "package:flow/graphql/FlowRecentChat.graphql.dart";
import "package:flow/graphql/FlowSearchCategories.graphql.dart";
import "package:flow/graphql/FlowSearchChannels.graphql.dart";
import "package:flow/graphql/FlowTopGames.graphql.dart";
import "package:flow/graphql/FlowTopStreams.graphql.dart";
import "package:flow/graphql/FlowUnfollowUser.graphql.dart";
import "package:flow/graphql/FlowUnlockedChatEmotes.graphql.dart";
import "package:flow/graphql/FlowUsers.graphql.dart";
import "package:flow/graphql/FlowVodChat.graphql.dart";
import "package:flow/graphql/FlowVodSeekMetadata.graphql.dart";
import "package:flow/graphql/schema.graphqls.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:graphql/client.dart" as graphql;
import "package:http/http.dart" as http;

class TwitchApiException implements Exception {
  TwitchApiException(this.message, {this.isTransient = false});

  final String message;
  final bool isTransient;

  @override
  String toString() => "TwitchApiException: $message";
}

class TwitchUser {
  const TwitchUser({
    required this.id,
    required this.login,
    required this.displayName,
    this.profileImageUrl,
    this.createdAt,
    this.chatColor,
    this.badges = const [],
    this.isSubscribed,
    this.subscriptionTier,
    this.subscriptionMonths,
    this.subscriptionIsPrime,
  });

  final String id;
  final String login;
  final String displayName;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final String? chatColor;
  final List<TwitchUserBadge> badges;
  final bool? isSubscribed;
  final String? subscriptionTier;
  final int? subscriptionMonths;
  final bool? subscriptionIsPrime;
}

class TwitchUserBadge {
  const TwitchUserBadge({required this.id, required this.title, required this.imageUrl});

  final String id;
  final String title;
  final String imageUrl;
}

class TwitchFollowedStream {
  const TwitchFollowedStream({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.userName,
    required this.gameName,
    required this.title,
    required this.viewerCount,
    this.isPartner = false,
    this.gameId = "",
    this.thumbnailUrl,
    this.profileImageUrl,
    this.startedAt,
    this.tags = const [],
  });

  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String gameName;
  final String gameId;
  final String title;
  final int viewerCount;
  final bool isPartner;
  final String? thumbnailUrl;
  final String? profileImageUrl;
  final DateTime? startedAt;
  final List<String> tags;
}

class TwitchFollowedChannel {
  const TwitchFollowedChannel({
    required this.broadcasterId,
    required this.broadcasterLogin,
    required this.broadcasterName,
    this.followedAt,
  });

  final String broadcasterId;
  final String broadcasterLogin;
  final String broadcasterName;
  final DateTime? followedAt;
}

class TwitchChannelInfo {
  const TwitchChannelInfo({
    required this.broadcasterId,
    required this.broadcasterName,
    required this.gameName,
    required this.title,
    this.gameId = "",
    this.lastBroadcastStartedAt,
  });

  final String broadcasterId;
  final String broadcasterName;
  final String gameName;
  final String gameId;
  final String title;
  final DateTime? lastBroadcastStartedAt;
}

class TwitchCategory {
  const TwitchCategory({
    required this.id,
    required this.name,
    required this.boxArtUrl,
    required this.viewerCount,
  });

  final String id;
  final String name;
  final String? boxArtUrl;
  final int viewerCount;
}

class TwitchSearchChannel {
  const TwitchSearchChannel({
    required this.id,
    required this.broadcasterLogin,
    required this.displayName,
    required this.gameName,
    required this.title,
    required this.isLive,
    this.isPartner = false,
    this.gameId = "",
    this.thumbnailUrl,
    this.startedAt,
  });

  final String id;
  final String broadcasterLogin;
  final String displayName;
  final String gameName;
  final String gameId;
  final String title;
  final bool isLive;
  final bool isPartner;
  final String? thumbnailUrl;
  final DateTime? startedAt;
}

class TwitchChannelDetails {
  const TwitchChannelDetails({
    required this.id,
    required this.login,
    required this.displayName,
    required this.description,
    required this.followers,
    required this.pastBroadcasts,
    required this.pastBroadcastsCursor,
    this.isPartner = false,
    this.profileImageUrl,
    this.liveStream,
  });

  final String id;
  final String login;
  final String displayName;
  final String description;
  final int followers;
  final bool isPartner;
  final String? profileImageUrl;
  final TwitchChannelLiveStream? liveStream;
  final List<TwitchPastBroadcast> pastBroadcasts;
  final String? pastBroadcastsCursor;

  TwitchChannelDetails withPastBroadcasts({
    required List<TwitchPastBroadcast> pastBroadcasts,
    required String? pastBroadcastsCursor,
  }) => TwitchChannelDetails(
    id: id,
    login: login,
    displayName: displayName,
    description: description,
    followers: followers,
    isPartner: isPartner,
    profileImageUrl: profileImageUrl,
    liveStream: liveStream,
    pastBroadcasts: pastBroadcasts,
    pastBroadcastsCursor: pastBroadcastsCursor,
  );
}

class TwitchChannelLiveStream {
  const TwitchChannelLiveStream({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.category,
    required this.viewerCount,
    this.thumbnailUrl,
    this.startedAt,
  });

  final String id;
  final String title;
  final String categoryId;
  final String category;
  final int viewerCount;
  final String? thumbnailUrl;
  final DateTime? startedAt;
}

class TwitchPastBroadcast {
  const TwitchPastBroadcast({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.category,
    required this.duration,
    required this.viewCount,
    this.thumbnailUrl,
    this.publishedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String categoryId;
  final String category;
  final Duration duration;
  final int viewCount;
  final String? thumbnailUrl;
  final DateTime? publishedAt;
  final DateTime? createdAt;
}

class TwitchPage<T> {
  const TwitchPage({required this.data, required this.cursor});

  final List<T> data;
  final String? cursor;
}

class TwitchVodChatPage {
  const TwitchVodChatPage({
    required this.messages,
    required this.cursor,
    required this.hasNextPage,
  });

  final List<TwitchChatMessage> messages;
  final String? cursor;
  final bool hasNextPage;
}

class TwitchNativeChatAssets {
  const TwitchNativeChatAssets({
    required this.channelId,
    required this.badgeUrls,
    required this.emoteIdsByName,
    this.broadcaster,
    this.badgeTitles = const {},
    this.globalEmoteIdsByName = const {},
    this.channelEmoteIdsByName = const {},
  });

  final String channelId;
  final TwitchUser? broadcaster;
  final Map<String, String> badgeUrls;
  final Map<String, String> badgeTitles;
  final Map<String, String> emoteIdsByName;
  final Map<String, String> globalEmoteIdsByName;
  final Map<String, String> channelEmoteIdsByName;
}

class TwitchChatAccess {
  const TwitchChatAccess({
    required this.channelId,
    required this.channelDisplayName,
    required this.rules,
    this.isFollowing = false,
    this.followedAt,
    this.isModerator = false,
    this.isVip = false,
    this.isSlowModeRestricted,
    this.lastRecentChatMessageAt,
  });

  final String channelId;
  final String channelDisplayName;
  final List<String> rules;
  final bool isFollowing;
  final DateTime? followedAt;
  final bool isModerator;
  final bool isVip;
  final bool? isSlowModeRestricted;
  final DateTime? lastRecentChatMessageAt;
}

class TwitchChatters {
  const TwitchChatters({required this.count, required this.groups});

  final int count;
  final Map<String, List<String>> groups;

  int get listedCount =>
      groups.values.expand((group) => group).map((login) => login.toLowerCase()).toSet().length;
  bool get isPartial => listedCount < count;
}

class TwitchMutedSegment {
  const TwitchMutedSegment({required this.offset, required this.duration});

  final Duration offset;
  final Duration duration;
  Duration get end => offset + duration;
}

class TwitchVodSeekMetadata {
  const TwitchVodSeekMetadata({this.mutedSegments = const [], this.storyboard});

  final List<TwitchMutedSegment> mutedSegments;
  final TwitchVodStoryboard? storyboard;
}

class TwitchVodStoryboard {
  const TwitchVodStoryboard({
    required this.imageUrls,
    required this.width,
    required this.height,
    required this.columns,
    required this.rows,
    required this.count,
    required this.interval,
  });

  final List<String> imageUrls;
  final int width;
  final int height;
  final int columns;
  final int rows;
  final int count;
  final Duration interval;

  ({String imageUrl, int column, int row})? frameAt(Duration position) {
    final frameCount = math.min(count, imageUrls.length * columns * rows);
    if (frameCount <= 0 || columns <= 0 || rows <= 0 || interval <= Duration.zero) {
      return null;
    }
    final frame = (position.inMicroseconds ~/ interval.inMicroseconds).clamp(0, frameCount - 1);
    final cell = frame % (columns * rows);
    return (
      imageUrl: imageUrls[frame ~/ (columns * rows)],
      column: cell % columns,
      row: cell ~/ columns,
    );
  }
}

class TwitchApiClient {
  TwitchApiClient({
    required this.clientId,
    required this.accessToken,
    String? graphQlClientId,
    this.gqlAccessToken,
    http.Client? httpClient,
    Future<Map<String, String>?> Function(String authorization)? integrityContextLoader,
  }) : graphQlClientId = _nonEmptyValue(graphQlClientId) ?? defaultGraphQlClientId,
       _httpClient = httpClient ?? http.Client(),
       _integrityContextLoader =
           integrityContextLoader ??
           const MethodChannelTwitchCookieExtractor().getTwitchIntegrityContext;

  static const _gqlEndpoint = "https://gql.twitch.tv/gql";
  static const _maxPageSize = 100;
  static const _maxTopStreamsPageSize = 30;
  static const defaultGraphQlClientId = "ue6666qo983tsx6so1t0vnawi233wa";
  // auth-token cookies are issued to Twitch's web client.
  static const _webSessionGraphQlClientId = "kimne78kx3ncx6brgo4mv6wki5h1ko";
  // Directory cursors and recommendation context share this identity across API clients.
  static final _deviceId = _requestId().replaceAll("-", "");
  static String? _webSessionDeviceId;
  static int _webSessionRevision = 0;
  static ({String authorization, String token, Map<String, String> headers})? _integrityGrant;
  static ({String authorization, int revision, Future<bool> future})? _integrityRefresh;
  static final _recommendationRequestId = _requestId();

  static void restoreWebSessionDeviceId(String? deviceId) {
    final normalized = _nonEmptyValue(deviceId);
    if (normalized == null || normalized != _webSessionDeviceId) {
      _webSessionRevision++;
      _integrityGrant = null;
    }
    _webSessionDeviceId = normalized;
  }

  final String clientId;
  final String graphQlClientId;
  final String accessToken;
  final String? gqlAccessToken;
  final http.Client _httpClient;
  final Future<Map<String, String>?> Function(String authorization) _integrityContextLoader;

  late final graphql.GraphQLClient _graphQlClient = _graphQlClientWithHeaders(includeToken: false);
  late final graphql.GraphQLClient _tokenGraphQlClient = _graphQlClientWithHeaders(
    includeToken: true,
  );

  Future<bool> validateAccessToken(String token) async {
    final uri = Uri.https("id.twitch.tv", "/oauth2/validate");
    final response = await _httpClient.get(
      uri,
      headers: {"Authorization": "Bearer $token", "Client-ID": clientId},
    );

    if (response.statusCode == 401) {
      return false;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TwitchApiException(
        "Twitch token validation failed (${response.statusCode}): ${response.body}",
        isTransient: _isTransientHttpStatus(response.statusCode),
      );
    }

    return true;
  }

  Future<TwitchUser> fetchCurrentUser() async {
    final data = await _query(
      () => _authenticatedGraphQlClient.query$FlowCurrentUser(
        Options$Query$FlowCurrentUser(
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowCurrentUser",
      retryIntegrityChallenge: true,
    );
    final user = _mapValue(data.toJson()["currentUser"]);
    if (user == null) {
      throw TwitchApiException("Twitch returned no current user.");
    }

    return _userFromGraphQlUser(user);
  }

  Future<void> reportMinuteWatched({
    required TwitchFollowedStream stream,
    required String userId,
  }) async {
    final viewerId = int.tryParse(userId);
    if (_nonEmptyValue(gqlAccessToken) == null ||
        viewerId == null ||
        viewerId <= 0 ||
        !RegExp(r"^\d+$").hasMatch(stream.id) ||
        !RegExp(r"^\d+$").hasMatch(stream.userId)) {
      throw TwitchApiException("Signed-in live playback is required to report watch time.");
    }
    final response = await _httpClient
        .post(
          Uri.https("spade.twitch.tv", "/track"),
          headers: {"Origin": "https://www.twitch.tv"},
          body: {
            "data": base64Encode(
              utf8.encode(
                jsonEncode([
                  {
                    "event": "minute-watched",
                    "properties": {
                      "channel_id": stream.userId,
                      "broadcast_id": stream.id,
                      "player": "site",
                      "user_id": viewerId,
                      "live": true,
                      "channel": stream.userLogin,
                      "game": stream.gameName,
                      "game_id": stream.gameId,
                    },
                  },
                ]),
              ),
            ),
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TwitchApiException("Twitch watch time report failed (${response.statusCode}).");
    }
  }

  Future<List<TwitchFollowedStream>> fetchFollowedStreams(String userId) async {
    final streams = <String, TwitchFollowedStream>{};
    final cursors = <String>{};
    String? after;

    do {
      final data = await _query(
        () => _authenticatedGraphQlClient.query$FlowFollowedLiveUsers(
          Options$Query$FlowFollowedLiveUsers(
            variables: Variables$Query$FlowFollowedLiveUsers(
              first: 100,
              after: after,
            ),
            fetchPolicy: graphql.FetchPolicy.noCache,
          ),
        ),
        "FlowFollowedLiveUsers",
        retryIntegrityChallenge: true,
      );
      final currentUser = _mapValue(data.toJson()["currentUser"]);
      final connection = _mapValue(currentUser?["followedLiveUsers"]);
      _requireFollowingConnection(connection, "FlowFollowedLiveUsers");

      for (final edge in _edgeList(connection)) {
        final node = _mapValue(edge["node"]);
        final stream = _mapValue(node?["stream"]);
        if (node != null && stream != null) {
          final followedStream = _streamFromGraphQlStream(stream, fallbackBroadcaster: node);
          streams[followedStream.userId] = followedStream;
        }
      }

      after = _connectionCursor(connection);
    } while (after != null && cursors.add(after));

    return streams.values.toList();
  }

  Future<List<TwitchFollowedChannel>> fetchFollowedChannels(
    String userId,
  ) async {
    final channels = <String, TwitchFollowedChannel>{};
    final cursors = <String>{};
    String? after;

    do {
      final data = await _query(
        () => _authenticatedGraphQlClient.query$FlowFollowedUsers(
          Options$Query$FlowFollowedUsers(
            variables: Variables$Query$FlowFollowedUsers(
              first: 100,
              after: after,
            ),
            fetchPolicy: graphql.FetchPolicy.noCache,
          ),
        ),
        "FlowFollowedUsers",
        retryIntegrityChallenge: true,
      );
      final currentUser = _mapValue(data.toJson()["currentUser"]);
      final connection = _mapValue(currentUser?["follows"]);
      _requireFollowingConnection(connection, "FlowFollowedUsers");

      for (final edge in _edgeList(connection)) {
        final node = _mapValue(edge["node"]);
        if (node == null) {
          continue;
        }
        final id = _stringValue(node["id"]);
        channels[id] = TwitchFollowedChannel(
          broadcasterId: id,
          broadcasterLogin: _stringValue(node["login"]),
          broadcasterName: _stringValue(node["displayName"]),
          followedAt: _dateTimeValue(edge["followedAt"]),
        );
      }

      after = _connectionCursor(connection);
    } while (after != null && cursors.add(after));

    return channels.values.toList();
  }

  Future<Map<String, TwitchUser>> fetchUsersByIds(List<String> ids) async {
    final users = <String, TwitchUser>{};
    for (final batch in _batches(ids)) {
      final data = await _query(
        () => _graphQlClient.query$FlowUsers(
          Options$Query$FlowUsers(
            variables: Variables$Query$FlowUsers(ids: batch),
            fetchPolicy: graphql.FetchPolicy.noCache,
          ),
        ),
        "FlowUsers",
      );
      for (final item in _mapList(data.toJson()["users"])) {
        final user = _userFromGraphQlUser(item);
        users[user.id] = user;
      }
    }
    return users;
  }

  Future<TwitchUser?> fetchChatUser({
    String? userId,
    String? login,
    String? channelId,
    String? channelLogin,
  }) async {
    final id = _nonEmptyValue(userId);
    final normalizedLogin = _nonEmptyValue(login)?.toLowerCase();
    if (id == null && normalizedLogin == null) {
      return null;
    }
    if (normalizedLogin != null && _nonEmptyValue(channelLogin) != null) {
      final signedIn = _nonEmptyValue(gqlAccessToken) != null;
      var incomplete = false;
      final data = await _query(
        () async {
          final response = await (signedIn ? _authenticatedGraphQlClient : _graphQlClient)
              .query$FlowChatUser(
                Options$Query$FlowChatUser(
                  variables: Variables$Query$FlowChatUser(
                    userID: id,
                    lookupLogin: id == null ? normalizedLogin : null,
                    login: normalizedLogin,
                    channelID: _nonEmptyValue(channelId),
                    channelLogin: channelLogin!.trim().toLowerCase(),
                    withRelationship: signedIn && _nonEmptyValue(channelId) != null,
                  ),
                  fetchPolicy: graphql.FetchPolicy.noCache,
                  errorPolicy: graphql.ErrorPolicy.all,
                ),
              );
          incomplete = response.hasException;
          return response;
        },
        "FlowChatUser",
        retryIntegrityChallenge: signedIn,
        allowPartialData: true,
      );
      final result = data.toJson();
      final target = _mapValue(result["targetUser"]);
      if (target == null ||
          (id != null
              ? target["id"] != id
              : target["login"]?.toString().toLowerCase() != normalizedLogin)) {
        return null;
      }
      final relationship = _mapValue(target["relationship"]);
      final benefit = _mapValue(relationship?["subscriptionBenefit"]);
      final badges = <String, TwitchUserBadge>{};
      for (final badge in [
        ..._mapList(target["displayBadges"]),
        if (target["login"]?.toString().toLowerCase() == normalizedLogin)
          ..._mapList(_mapValue(result["channelViewer"])?["earnedBadges"]),
      ]) {
        final url = _nonEmptyValue(badge["imageURL"] as String?);
        if (url != null) {
          final badgeId = "${_stringValue(badge['setID'])}/${_stringValue(badge['version'])}";
          badges.putIfAbsent(
            badgeId,
            () => TwitchUserBadge(
              id: badgeId,
              title: _nonEmptyValue(badge["title"] as String?) ?? _stringValue(badge["setID"]),
              imageUrl: url,
            ),
          );
        }
      }
      return TwitchUser(
        id: _stringValue(target["id"]),
        login: _stringValue(target["login"]),
        displayName: _stringValue(target["displayName"]),
        profileImageUrl: target["profileImageURL"] as String?,
        createdAt: _dateTimeValue(target["createdAt"]),
        chatColor: _nonEmptyValue(target["chatColor"] as String?),
        badges: badges.values.toList(),
        isSubscribed: benefit != null
            ? true
            : relationship == null || incomplete
            ? null
            : false,
        subscriptionTier: _nonEmptyValue(benefit?["tier"] as String?),
        subscriptionMonths: int.tryParse(
          _mapValue(relationship?["cumulativeTenure"])?["months"]?.toString() ?? "",
        ),
        subscriptionIsPrime: benefit?["purchasedWithPrime"] as bool?,
      );
    }
    final data = await _query(
      () => _graphQlClient.query$FlowUsers(
        Options$Query$FlowUsers(
          variables: Variables$Query$FlowUsers(
            ids: id == null ? null : [id],
            logins: id == null ? [normalizedLogin!] : null,
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowUsers",
    );
    for (final item in _mapList(data.toJson()["users"])) {
      final user = _userFromGraphQlUser(item);
      if (id != null ? user.id == id : user.login.toLowerCase() == normalizedLogin) {
        return user;
      }
    }
    return null;
  }

  Future<void> blockUser(String userId) async {
    final id = userId.trim();
    if (!RegExp(r"^\d+$").hasMatch(id)) {
      throw TwitchApiException("Choose a valid Twitch user to block.");
    }
    if (_nonEmptyValue(gqlAccessToken) == null) {
      throw TwitchApiException("Sign in to Twitch before blocking a user.");
    }
    final result = await _query(
      () => _authenticatedGraphQlClient.mutate$FlowBlockUser(
        Options$Mutation$FlowBlockUser(
          variables: Variables$Mutation$FlowBlockUser(targetUserID: id),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowBlockUser",
      retryIntegrityChallenge: true,
    );
    if (result.blockUser?.targetUser?.id != id) {
      throw TwitchApiException("Twitch did not confirm that the user was blocked.");
    }
  }

  Future<DateTime> followChannel(String channelId) async {
    final id = channelId.trim();
    if (!RegExp(r"^\d+$").hasMatch(id)) {
      throw TwitchApiException("Choose a valid Twitch channel to follow.");
    }
    if (_nonEmptyValue(gqlAccessToken) == null) {
      throw TwitchApiException("Sign in to Twitch before following a channel.");
    }
    final result = await _query(
      () => _authenticatedGraphQlClient.mutate$FlowFollowUser(
        Options$Mutation$FlowFollowUser(
          variables: Variables$Mutation$FlowFollowUser(targetID: id),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowFollowUser",
      retryIntegrityChallenge: true,
    );
    final follow = result.followUser?.follow;
    final followedAt = _dateTimeValue(follow?.followedAt);
    if (result.followUser?.error != null || follow?.user?.id != id || followedAt == null) {
      throw TwitchApiException("Twitch did not confirm that the channel was followed.");
    }
    return followedAt;
  }

  Future<void> unfollowChannel(String channelId) async {
    final id = channelId.trim();
    if (!RegExp(r"^\d+$").hasMatch(id)) {
      throw TwitchApiException("Choose a valid Twitch channel to unfollow.");
    }
    if (_nonEmptyValue(gqlAccessToken) == null) {
      throw TwitchApiException("Sign in to Twitch before unfollowing a channel.");
    }
    final result = await _query(
      () => _authenticatedGraphQlClient.mutate$FlowUnfollowUser(
        Options$Mutation$FlowUnfollowUser(
          variables: Variables$Mutation$FlowUnfollowUser(targetID: id),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowUnfollowUser",
      retryIntegrityChallenge: true,
    );
    if (result.unfollowUser?.follow?.user?.id != id) {
      throw TwitchApiException("Twitch did not confirm that the channel was unfollowed.");
    }
  }

  Future<TwitchChatAccess> fetchChatAccess(String login) async {
    final normalizedLogin = login.trim().toLowerCase();
    final signedIn = _nonEmptyValue(gqlAccessToken) != null;
    final data = await _query(
      () => (signedIn ? _authenticatedGraphQlClient : _graphQlClient).query$FlowChatAccess(
        Options$Query$FlowChatAccess(
          variables: Variables$Query$FlowChatAccess(login: normalizedLogin),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowChatAccess",
      retryIntegrityChallenge: signedIn,
    );
    final user = _mapValue(data.toJson()["user"]);
    final rules = _mapValue(user?["chatSettings"])?["rules"];
    final self = _mapValue(user?["self"]);
    if (_nonEmptyValue(user?["id"] as String?) == null ||
        user?["login"] != normalizedLogin ||
        rules is! List ||
        (signedIn && (self == null || self["isModerator"] is! bool || self["isVIP"] is! bool))) {
      throw TwitchApiException("Could not load channel rules and follower status. Try again.");
    }
    final follower = _mapValue(self?["follower"]);
    return TwitchChatAccess(
      channelId: user!["id"]! as String,
      channelDisplayName: _nonEmptyValue(user["displayName"] as String?) ?? normalizedLogin,
      rules: List.unmodifiable(rules.whereType<String>().where((rule) => rule.trim().isNotEmpty)),
      isFollowing: follower != null,
      followedAt: _dateTimeValue(follower?["followedAt"]),
      isModerator: self?["isModerator"] == true,
      isVip: self?["isVIP"] == true,
      isSlowModeRestricted: (self?["chatRestrictedReasons"] as List?)?.contains("SLOW_MODE"),
      lastRecentChatMessageAt: _dateTimeValue(self?["lastRecentChatMessageAt"]),
    );
  }

  Future<({String channelId, String claimId})?> fetchAvailableChannelPointsClaim(
    String login,
  ) async {
    if (_nonEmptyValue(gqlAccessToken) == null) {
      return null;
    }
    final normalizedLogin = login.trim().toLowerCase();
    final result = await _query(
      () => _authenticatedGraphQlClient.query$FlowAvailableChannelPoints(
        Options$Query$FlowAvailableChannelPoints(
          variables: Variables$Query$FlowAvailableChannelPoints(login: normalizedLogin),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowAvailableChannelPoints",
      retryIntegrityChallenge: true,
    );
    final user = result.user;
    final channelId = user?.channel?.id;
    if (user?.login != normalizedLogin || channelId == null || channelId != user?.id) {
      throw TwitchApiException("Could not check channel point bonuses.");
    }
    final claimId = _nonEmptyValue(user?.channel?.self?.communityPoints?.availableClaim?.id);
    return claimId == null ? null : (channelId: channelId, claimId: claimId);
  }

  Future<int> claimChannelPoints(String channelId, String claimId) async {
    final id = channelId.trim();
    final claim = claimId.trim();
    if (!RegExp(r"^\d+$").hasMatch(id) || claim.isEmpty) {
      throw TwitchApiException("Choose a valid channel point bonus to claim.");
    }
    if (_nonEmptyValue(gqlAccessToken) == null) {
      throw TwitchApiException("Sign in to Twitch before claiming channel points.");
    }
    final result = await _query(
      () => _authenticatedGraphQlClient.mutate$FlowClaimChannelPoints(
        Options$Mutation$FlowClaimChannelPoints(
          variables: Variables$Mutation$FlowClaimChannelPoints(channelID: id, claimID: claim),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowClaimChannelPoints",
      retryIntegrityChallenge: true,
    );
    final payload = result.claimCommunityPoints;
    final amount = payload?.claim?.pointsEarnedTotal;
    if (payload?.error != null || payload?.claim?.id != claim || amount == null || amount <= 0) {
      throw TwitchApiException("Twitch did not confirm that channel points were claimed.");
    }
    return amount;
  }

  Future<Map<String, TwitchChannelInfo>> fetchChannelInfoByBroadcasterIds(
    List<String> broadcasterIds,
  ) async {
    final channels = <String, TwitchChannelInfo>{};
    for (final batch in _batches(broadcasterIds)) {
      final data = await _query(
        () => _graphQlClient.query$FlowUsers(
          Options$Query$FlowUsers(
            variables: Variables$Query$FlowUsers(ids: batch),
            fetchPolicy: graphql.FetchPolicy.noCache,
          ),
        ),
        "FlowUsers",
      );
      for (final item in _mapList(data.toJson()["users"])) {
        final broadcastSettings = _mapValue(item["broadcastSettings"]);
        final game = _mapValue(broadcastSettings?["game"]);
        final channel = TwitchChannelInfo(
          broadcasterId: _stringValue(item["id"]),
          broadcasterName: _stringValue(item["displayName"]),
          gameName: _stringValue(game?["displayName"]),
          gameId: _stringValue(game?["id"]),
          title: _stringValue(broadcastSettings?["title"]),
          lastBroadcastStartedAt: _dateTimeValue(_mapValue(item["lastBroadcast"])?["startedAt"]),
        );
        channels[channel.broadcasterId] = channel;
      }
    }
    return channels;
  }

  Future<List<TwitchCategory>> fetchTopCategories({int first = 12}) async {
    final page = await fetchTopCategoriesPage(first: first);
    return page.data;
  }

  Future<TwitchPage<TwitchCategory>> fetchTopCategoriesPage({
    int first = 12,
    String? cursor,
    CategorySort sort = CategorySort.recommendedForYou,
  }) async {
    final data = await _query(
      () =>
          (sort == CategorySort.recommendedForYou && _nonEmptyValue(gqlAccessToken) != null
                  ? _tokenGraphQlClient
                  : _graphQlClient)
              .query$FlowTopGames(
                Options$Query$FlowTopGames(
                  variables: Variables$Query$FlowTopGames(
                    first: sort == CategorySort.recommendedForYou
                        ? (cursor == null ? 12 : 36)
                        : _boundedFirst(first),
                    after: _nonEmptyValue(cursor),
                    options: sort == CategorySort.recommendedForYou
                        ? Input$GameOptions(
                            sort: Enum$GameSort.RELEVANCE,
                            recommendationsContext: Input$RecommendationsContext(
                              platform: "mobile_web",
                            ),
                          )
                        : Input$GameOptions(sort: Enum$GameSort.VIEWER_COUNT),
                  ),
                  fetchPolicy: graphql.FetchPolicy.noCache,
                ),
              ),
      "FlowTopGames",
      retryIntegrityChallenge: sort == CategorySort.recommendedForYou,
    );

    return _categoryPageFromConnection(
      _mapValue(data.toJson()["games"]),
      cursorOverlap: sort == CategorySort.recommendedForYou ? 4 : 0,
    );
  }

  Future<List<TwitchCategory>> searchCategories(
    String query, {
    int first = 20,
  }) async {
    final page = await searchCategoriesPage(query, first: first);
    return page.data;
  }

  Future<TwitchPage<TwitchCategory>> searchCategoriesPage(
    String query, {
    int first = 20,
    String? cursor,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const TwitchPage<TwitchCategory>(data: [], cursor: null);
    }

    final data = await _query(
      () => _graphQlClient.query$FlowSearchCategories(
        Options$Query$FlowSearchCategories(
          variables: Variables$Query$FlowSearchCategories(
            query: normalizedQuery,
            first: _boundedFirst(first),
            after: _nonEmptyValue(cursor),
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowSearchCategories",
    );

    return _categoryPageFromConnection(
      _mapValue(data.toJson()["searchCategories"]),
    );
  }

  Future<List<TwitchFollowedStream>> fetchLiveStreams({
    int first = 20,
    List<String> gameIds = const [],
    List<String> userLogins = const [],
    StreamSort sort = StreamSort.recommendedForYou,
  }) async {
    final page = await fetchLiveStreamsPage(
      first: first,
      gameIds: gameIds,
      userLogins: userLogins,
      sort: sort,
    );
    return page.data;
  }

  Future<TwitchPage<TwitchFollowedStream>> fetchLiveStreamsPage({
    int first = 20,
    List<String> gameIds = const [],
    List<String> userLogins = const [],
    String? cursor,
    StreamSort sort = StreamSort.recommendedForYou,
  }) async {
    final normalizedGameIds = _nonEmptyValues(gameIds);
    final normalizedUserLogins = _nonEmptyValues(userLogins);

    if (normalizedGameIds.isNotEmpty) {
      return _fetchGameStreamsPage(
        gameId: normalizedGameIds.first,
        first: first,
        cursor: cursor,
        userLogins: normalizedUserLogins,
        sort: sort,
      );
    }

    if (normalizedUserLogins.isNotEmpty) {
      return _fetchUserStreamsPage(normalizedUserLogins, sort: sort);
    }

    final data = await _query(
      () =>
          (sort == StreamSort.recommendedForYou && _nonEmptyValue(gqlAccessToken) != null
                  ? _tokenGraphQlClient
                  : _graphQlClient)
              .query$FlowTopStreams(
                Options$Query$FlowTopStreams(
                  variables: Variables$Query$FlowTopStreams(
                    first: sort == StreamSort.recommendedForYou
                        ? (cursor == null ? 8 : 24)
                        : _boundedFirst(first, max: _maxTopStreamsPageSize),
                    after: _nonEmptyValue(cursor),
                    options: sort == StreamSort.recommendedForYou
                        ? Input$StreamOptions(
                            sort: Enum$StreamSort.RELEVANCE,
                            broadcasterLanguages: const [],
                            includeRestricted: _nonEmptyValue(gqlAccessToken) != null
                                ? const [Enum$StreamRestrictionType.SUB_ONLY_LIVE]
                                : null,
                            recommendationsContext: Input$RecommendationsContext(
                              platform: "mobile_web",
                            ),
                          )
                        : Input$StreamOptions(sort: _graphQlStreamSort(sort)),
                  ),
                  fetchPolicy: graphql.FetchPolicy.noCache,
                ),
              ),
      "FlowTopStreams",
      retryIntegrityChallenge: sort == StreamSort.recommendedForYou,
    );

    final page = _streamPageFromConnection(
      _mapValue(data.toJson()["streams"]),
      cursorOverlap: sort == StreamSort.recommendedForYou ? 4 : 0,
    );
    return page;
  }

  Future<List<TwitchSearchChannel>> searchLiveChannels(
    String query, {
    int first = 20,
  }) async {
    final page = await searchChannelsPage(query, first: first, liveOnly: true);
    return page.data;
  }

  Future<TwitchPage<TwitchSearchChannel>> searchChannelsPage(
    String query, {
    int first = 20,
    String? cursor,
    bool liveOnly = false,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const TwitchPage<TwitchSearchChannel>(data: [], cursor: null);
    }

    final data = await _query(
      () => _graphQlClient.query$FlowSearchChannels(
        Options$Query$FlowSearchChannels(
          variables: Variables$Query$FlowSearchChannels(
            queryFragment: normalizedQuery,
            withOfflineChannelContent: !liveOnly,
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowSearchChannels",
    );
    final channels = <TwitchSearchChannel>[];
    final suggestions = _mapValue(data.toJson()["searchSuggestions"]);
    for (final edge in _mapList(suggestions?["edges"])) {
      final node = _mapValue(edge["node"]);
      final content = _mapValue(node?["content"]);
      if (content?["__typename"] != "SearchSuggestionChannel") {
        continue;
      }
      final channel = _searchChannelFromGraphQlContent(
        content!,
        fallbackDisplayName: _stringValue(node?["text"]),
      );
      if (!liveOnly || channel.isLive) {
        channels.add(channel);
      }
      if (channels.length >= _boundedFirst(first)) {
        break;
      }
    }

    return TwitchPage<TwitchSearchChannel>(data: channels, cursor: null);
  }

  Future<TwitchChannelDetails> fetchChannelDetails(
    String login, {
    int videosFirst = 30,
    String? videosCursor,
  }) async {
    final normalizedLogin = _nonEmptyValue(login);
    if (normalizedLogin == null) {
      throw TwitchApiException("Channel login is required.");
    }

    final data = await _query(
      () => _graphQlClient.query$FlowChannelDetails(
        Options$Query$FlowChannelDetails(
          variables: Variables$Query$FlowChannelDetails(
            login: normalizedLogin,
            videosFirst: _boundedFirst(videosFirst),
            videosAfter: _nonEmptyValue(videosCursor),
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowChannelDetails",
    );
    final user = _mapValue(data.toJson()["user"]);
    if (user == null) {
      throw TwitchApiException("Twitch returned no channel for $normalizedLogin.");
    }

    return _channelDetailsFromGraphQlUser(user);
  }

  Future<Uri> fetchLivePlaybackUri(String login) async {
    final normalizedLogin = _nonEmptyValue(login);
    if (normalizedLogin == null) {
      throw TwitchApiException("Channel login is required.");
    }

    final data = await _fetchPlaybackAccessToken(normalizedLogin);
    final access = data.streamPlaybackAccessToken;
    final authorization = access?.authorization;
    if (authorization?.isForbidden == true) {
      final reason = _nonEmptyValue(authorization?.forbiddenReasonCode);
      throw TwitchApiException(
        reason == null
            ? "This stream is not available."
            : "This stream is not available ($reason).",
      );
    }

    final token = _nonEmptyValue(access?.value);
    final signature = _nonEmptyValue(access?.signature);
    if (token == null || signature == null) {
      throw TwitchApiException("Twitch returned no playback access token for $normalizedLogin.");
    }

    return Uri(
      scheme: "https",
      host: "usher.ttvnw.net",
      pathSegments: ["api", "v2", "channel", "hls", "$normalizedLogin.m3u8"],
      queryParameters: {
        "allow_audio_only": "true",
        "allow_source": "true",
        "fast_bread": "true",
        "playlist_include_framerate": "true",
        "player": "twitchweb",
        "p": math.Random().nextInt(10_000_000).toString(),
        "sig": signature,
        "token": token,
        "type": "any",
      },
    );
  }

  Future<Uri> fetchVodPlaybackUri(String videoId) async {
    final normalizedVideoId = _nonEmptyValue(videoId);
    if (normalizedVideoId == null) {
      throw TwitchApiException("Video ID is required.");
    }

    final data = await _fetchPlaybackAccessToken(normalizedVideoId, isVod: true);
    final access = data.videoPlaybackAccessToken;
    final token = _nonEmptyValue(access?.value);
    final signature = _nonEmptyValue(access?.signature);
    if (token == null || signature == null) {
      throw TwitchApiException(
        "Twitch returned no playback access token for video $normalizedVideoId.",
      );
    }

    return Uri(
      scheme: "https",
      host: "usher.ttvnw.net",
      pathSegments: ["vod", "v2", "$normalizedVideoId.m3u8"],
      queryParameters: {
        "allow_audio_only": "true",
        "allow_source": "true",
        "playlist_include_framerate": "true",
        "player": "twitchweb",
        "p": math.Random().nextInt(10_000_000).toString(),
        "nauthsig": signature,
        "nauth": token,
        "type": "any",
      },
    );
  }

  Future<TwitchNativeChatAssets> fetchChatAssets(String login) async {
    final data = await _query(
      () => _graphQlClient.query$FlowChatAssets(
        Options$Query$FlowChatAssets(
          variables: Variables$Query$FlowChatAssets(login: login.trim().toLowerCase()),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowChatAssets",
    );
    final result = data.toJson();
    final user = _mapValue(result["user"]);
    final channelId = _nonEmptyValue(user?["id"] as String?);
    if (channelId == null || result["badges"] is! List<Object?>) {
      throw TwitchApiException("Twitch chat badges are unavailable.");
    }
    final channel = _mapValue(user?["channel"]);
    final globalEmotes = <String, String>{
      for (final emote in _mapList(_mapValue(result["emoteSet"])?["emotes"]))
        if (emote["token"] is String && emote["id"] is String)
          emote["token"]! as String: emote["id"]! as String,
    };
    final channelEmotes = <String, String>{
      for (final emote in [
        for (final product in _mapList(user?["subscriptionProducts"]))
          ..._mapList(product["emotes"]),
        for (final set in _mapList(channel?["localEmoteSets"])) ..._mapList(set["emotes"]),
      ])
        if (emote["token"] is String && emote["id"] is String)
          emote["token"]! as String: emote["id"]! as String,
    };
    return TwitchNativeChatAssets(
      channelId: channelId,
      broadcaster: _userFromGraphQlUser(user!),
      badgeUrls: {
        for (final badge in [..._mapList(result["badges"]), ..._mapList(user["broadcastBadges"])])
          if (badge["setID"] is String && badge["version"] is String && badge["imageURL"] is String)
            "${badge["setID"]}/${badge["version"]}": badge["imageURL"]! as String,
      },
      badgeTitles: {
        for (final badge in [..._mapList(result["badges"]), ..._mapList(user["broadcastBadges"])])
          if (badge["setID"] is String && badge["version"] is String && badge["title"] is String)
            "${badge["setID"]}/${badge["version"]}": badge["title"]! as String,
      },
      emoteIdsByName: {...globalEmotes, ...channelEmotes},
      globalEmoteIdsByName: globalEmotes,
      channelEmoteIdsByName: channelEmotes,
    );
  }

  Future<Map<String, String>> fetchUnlockedChatEmotes(String channelId) async {
    if (_nonEmptyValue(gqlAccessToken) == null) {
      return const {};
    }
    final emotes = <String, String>{};
    final cursors = <String>{};
    String? cursor;
    while (true) {
      final data = await _query(
        () => _authenticatedGraphQlClient.query$FlowUnlockedChatEmotes(
          Options$Query$FlowUnlockedChatEmotes(
            variables: Variables$Query$FlowUnlockedChatEmotes(channelID: channelId, cursor: cursor),
            fetchPolicy: graphql.FetchPolicy.noCache,
          ),
        ),
        "FlowUnlockedChatEmotes",
        retryIntegrityChallenge: true,
      );
      final channel = _mapValue(data.toJson()["channel"]);
      final connection = _mapValue(_mapValue(channel?["self"])?["availableEmoteSetsPaginated"]);
      final edges = connection?["edges"];
      final hasNextPage = _mapValue(connection?["pageInfo"])?["hasNextPage"];
      if (channel?["id"] != channelId || edges is! List || hasNextPage is! bool) {
        throw TwitchApiException("Could not load your unlocked Twitch emotes. Try again.");
      }
      for (final edge in _mapList(edges)) {
        for (final emote in _mapList(_mapValue(edge["node"])?["emotes"])) {
          final name = _nonEmptyValue(emote["token"] as String?);
          final id = _nonEmptyValue(emote["id"] as String?);
          if (name != null && id != null) {
            emotes[name] = id;
          }
        }
      }
      if (!hasNextPage) {
        break;
      }
      cursor = edges.isEmpty ? null : _nonEmptyValue(_mapValue(edges.last)?["cursor"] as String?);
      if (cursor == null || !cursors.add(cursor)) {
        throw TwitchApiException("Twitch emote pagination did not advance.");
      }
    }
    return emotes;
  }

  Future<TwitchChatters> fetchChatters(String login) async {
    final signedIn = _nonEmptyValue(gqlAccessToken) != null;
    final data = await _query(
      () => (signedIn ? _authenticatedGraphQlClient : _graphQlClient).query$FlowChatters(
        Options$Query$FlowChatters(
          variables: Variables$Query$FlowChatters(login: login.trim().toLowerCase()),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowChatters",
      retryIntegrityChallenge: signedIn,
    );
    final user = _mapValue(data.toJson()["user"]);
    final chatters = _mapValue(_mapValue(user?["channel"])?["chatters"]);
    if (chatters == null || chatters["count"] is! int) {
      throw TwitchApiException("The chatter list is unavailable right now.");
    }
    return TwitchChatters(
      count: _intValue(chatters["count"]),
      groups: {
        for (final role in ["broadcasters", "moderators", "vips", "staff", "chatbots", "viewers"])
          role: [
            for (final viewer in _mapList(chatters[role]))
              ?_nonEmptyValue(viewer["login"] as String?),
          ],
      },
    );
  }

  Future<TwitchPinnedChat?> fetchPinnedChat(String channelId) async {
    final data = await _query(
      () => _graphQlClient.query$FlowPinnedChat(
        Options$Query$FlowPinnedChat(
          variables: Variables$Query$FlowPinnedChat(channelID: channelId),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowPinnedChat",
    );
    final channel = _mapValue(data.toJson()["channel"]);
    final edges = _mapValue(channel?["pinnedChatMessages"])?["edges"];
    if (channel?["id"] != channelId || edges is! List) {
      throw TwitchApiException("Pinned chat is unavailable for this channel.");
    }
    if (edges.isEmpty) {
      return null;
    }
    final pin = _mapValue(_mapValue(edges.first)?["node"]);
    final message = _mapValue(pin?["pinnedMessage"]);
    final id = _nonEmptyValue(pin?["id"] as String?);
    if (id == null || message == null) {
      throw TwitchApiException("Twitch returned an incomplete pinned message.");
    }
    final pinner = _mapValue(pin?["pinnedBy"]);
    final pinnerId = _nonEmptyValue(pinner?["id"] as String?);
    return TwitchPinnedChat(
      id: id,
      message: _chatMessageFromGraphQl(message),
      startsAt: _dateTimeValue(pin?["startsAt"]),
      endsAt: _dateTimeValue(pin?["endsAt"]),
      pinnedBy: pinnerId == null
          ? null
          : (
              id: pinnerId,
              login: _stringValue(pinner?["login"]),
              displayName:
                  _nonEmptyValue(pinner?["displayName"] as String?) ??
                  _stringValue(pinner?["login"]),
            ),
    );
  }

  Future<List<TwitchChatMessage>> fetchRecentChat(String channelId) async {
    if (_nonEmptyValue(gqlAccessToken) == null) {
      return const [];
    }
    final id = channelId.trim();
    if (!RegExp(r"^\d+$").hasMatch(id)) {
      throw TwitchApiException("Choose a valid channel to load recent chat.");
    }
    final data = await _query(
      () => _authenticatedGraphQlClient.query$FlowRecentChat(
        Options$Query$FlowRecentChat(
          variables: Variables$Query$FlowRecentChat(channelID: id),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowRecentChat",
      retryIntegrityChallenge: true,
    );
    final channel = _mapValue(data.toJson()["channel"]);
    final messages = channel?["recentChatMessages"];
    if (channel?["id"] != id || messages is! List) {
      throw TwitchApiException("Recent chat is unavailable for this channel.");
    }
    return [for (final message in _mapList(messages)) _chatMessageFromGraphQl(message)];
  }

  Future<List<TwitchChatMessage>> fetchChatReplyThread(String messageId) async {
    var requestedId = messageId.trim();
    if (requestedId.isEmpty) {
      return const [];
    }
    final visited = <String>{};
    late Map<String, Object?> root;
    while (true) {
      if (!visited.add(requestedId)) {
        throw TwitchApiException("Twitch returned an invalid reply thread.");
      }
      final data = await _query(
        () => _graphQlClient.query$FlowChatReplies(
          Options$Query$FlowChatReplies(
            variables: Variables$Query$FlowChatReplies(messageID: requestedId),
            fetchPolicy: graphql.FetchPolicy.noCache,
          ),
        ),
        "FlowChatReplies",
      );
      final message = _mapValue(data.toJson()["message"]);
      if (message == null) {
        return const [];
      }
      root = message;
      final ancestorId =
          _nonEmptyValue(_mapValue(root["threadParentMessage"])?["id"] as String?) ??
          _nonEmptyValue(_mapValue(root["parentMessage"])?["id"] as String?);
      if (ancestorId == null || ancestorId == requestedId) {
        break;
      }
      requestedId = ancestorId;
    }
    final rootId = _stringValue(root["id"]);
    final rootLogin = _stringValue(_mapValue(root["sender"])?["login"]);
    return [
      _chatMessageFromGraphQl(root),
      for (final reply in _mapList(_mapValue(root["replies"])?["nodes"]))
        _chatMessageFromGraphQl(reply, threadRootId: rootId, threadRootLogin: rootLogin),
    ];
  }

  Future<TwitchVodChatPage> fetchVodChatPage(
    String videoId, {
    int? offsetSeconds,
    String? cursor,
  }) async {
    final normalizedVideoId = _nonEmptyValue(videoId);
    if (normalizedVideoId == null) {
      throw TwitchApiException("Video ID is required.");
    }
    final normalizedCursor = _nonEmptyValue(cursor);
    final data = await _query(
      () => _graphQlClient.query$FlowVodChat(
        Options$Query$FlowVodChat(
          variables: Variables$Query$FlowVodChat(
            videoId: normalizedVideoId,
            offsetSeconds: normalizedCursor == null ? math.max(0, offsetSeconds ?? 0) : null,
            cursor: normalizedCursor,
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowVodChat",
    );
    final video = _mapValue(data.toJson()["video"]);
    final comments = _mapValue(video?["comments"]);
    final edges = comments?["edges"];
    final hasNextPage = _mapValue(comments?["pageInfo"])?["hasNextPage"];
    if (edges is! List<Object?> || hasNextPage is! bool) {
      throw TwitchApiException("Chat replay is unavailable for this video.");
    }
    final messages = <TwitchChatMessage>[];
    for (final edge in edges) {
      final node = _mapValue(_mapValue(edge)?["node"]);
      final id = _nonEmptyValue(node?["id"] as String?);
      final offset = node?["contentOffsetSeconds"];
      final message = _mapValue(node?["message"]);
      final fragments = message?["fragments"];
      if (id == null || offset is! num || offset < 0 || fragments is! List<Object?>) {
        throw TwitchApiException("Chat replay contains an incomplete message.");
      }
      final text = StringBuffer();
      final emotes = <TwitchChatEmote>[];
      for (final fragment in fragments) {
        final part = _mapValue(fragment);
        final content = part?["text"];
        if (content is! String) {
          throw TwitchApiException("Chat replay contains an incomplete message.");
        }
        final emoteId = _nonEmptyValue(_mapValue(part?["emote"])?["emoteID"] as String?);
        if (emoteId != null && content.isNotEmpty) {
          emotes.add(
            TwitchChatEmote(id: emoteId, start: text.length, end: text.length + content.length),
          );
        }
        text.write(content);
      }
      final commenter = _mapValue(node?["commenter"]);
      final login = _stringValue(commenter?["login"]);
      final displayName =
          _nonEmptyValue(commenter?["displayName"] as String?) ??
          _nonEmptyValue(login) ??
          "Deleted user";
      final recordedText = text.toString();
      final match = _vodNoticePattern.firstMatch(recordedText);
      final notice =
          match != null &&
              {login.toLowerCase(), displayName.toLowerCase()}.contains(match[1]!.toLowerCase())
          ? match
          : null;
      final bodyStart = notice?.end ?? 0;
      final subscription = notice?[2];
      messages.add(
        TwitchChatMessage(
          id: id,
          login: login,
          userId: _nonEmptyValue(commenter?["id"] as String?),
          displayName: displayName,
          text: recordedText.substring(bodyStart),
          noticeType: notice == null
              ? null
              : subscription == null
              ? "watch-streak"
              : subscription.contains("They've subscribed for")
              ? "resub"
              : "sub",
          noticeText: notice == null ? null : recordedText.substring(0, bodyStart).trimRight(),
          isPrimeSubscription: subscription?.startsWith("subscribed with Prime.") ?? false,
          color: message?["userColor"] as String?,
          emotes: bodyStart == 0
              ? emotes
              : [
                  for (final emote in emotes)
                    if (emote.start >= bodyStart)
                      TwitchChatEmote(
                        id: emote.id,
                        start: emote.start - bodyStart,
                        end: emote.end - bodyStart,
                      ),
                ],
          badges: [
            for (final badge in _mapList(message?["userBadges"]))
              if (_nonEmptyValue(badge["setID"] as String?) case final setId?)
                "$setId/${_stringValue(badge["version"])}",
          ],
          offsetSeconds: offset.toDouble(),
          timestamp: _dateTimeValue(node?["createdAt"]),
        ),
      );
    }
    messages.sort((a, b) => a.offsetSeconds!.compareTo(b.offsetSeconds!));
    final nextCursor = hasNextPage && edges.isNotEmpty
        ? _nonEmptyValue(_mapValue(edges.last)?["cursor"] as String?)
        : null;
    if (hasNextPage && (nextCursor == null || nextCursor == normalizedCursor)) {
      throw TwitchApiException("Chat replay pagination did not advance.");
    }
    return TwitchVodChatPage(
      messages: await _enrichVodChatMessages(messages),
      cursor: nextCursor,
      hasNextPage: hasNextPage,
    );
  }

  // Twitch's replay adapter drops notice tags and prepends the generated English notice.
  static final _vodNoticePattern = RegExp(
    r"^(\S+) (?:(subscribed (?:at Tier [123](?: for [1-9]\d* months in advance)?|with Prime)\."
    r"(?: They've subscribed for [1-9]\d* months?(?:, currently on a [1-9]\d* month streak)?!)?)"
    r"|watched [1-9]\d* consecutive streams and sparked a watch streak!)(?: |$)",
  );

  Future<List<TwitchChatMessage>> _enrichVodChatMessages(List<TwitchChatMessage> messages) async {
    final enriched = {for (final message in messages) message.id: message};
    for (final ids in _batches([
      for (final message in messages)
        if (message.noticeType == null) message.id,
    ])) {
      // Replay fragments omit GIFs and replies; original message IDs retain them.
      final document = graphql.gql('''
        query FlowVodChatDetails {
          ${[for (var index = 0; index < ids.length; index++) 'm$index: message(id: ${jsonEncode(ids[index])}) { ...ReplayMessage }'].join('\n')}
        }
        fragment ReplayMessage on Message {
          id
          deletedAt
          content { ...ReplayContent }
          parentMessage {
            id
            sender { id login displayName }
            content { ...ReplayContent }
          }
          threadParentMessage { id sender { login } }
        }
        fragment ReplayContent on MessageContent {
          text
          fragments {
            text
            content {
              __typename
              ... on Emote { emoteID: id }
              ... on GifContent { gifID: id gifURL: url }
            }
          }
        }
      ''');
      try {
        final details = await _query(
          () => _graphQlClient.query(
            graphql.QueryOptions<Map<String, dynamic>>(
              document: document,
              fetchPolicy: graphql.FetchPolicy.noCache,
              errorPolicy: graphql.ErrorPolicy.all,
              parserFn: (data) => data,
            ),
          ),
          "FlowVodChatDetails",
          allowPartialData: true,
        ).timeout(const Duration(seconds: 3));
        for (final value in details.values) {
          final detail = _mapValue(value);
          final recorded = enriched[detail?["id"]];
          if (detail != null &&
              recorded != null &&
              _mapValue(detail["content"])?["text"] == recorded.text) {
            enriched[recorded.id] = _chatMessageFromGraphQl(detail, replay: recorded);
          }
        }
      } on Object {
        // Older messages may no longer be retained by the live-message service.
      }
    }
    return [for (final message in messages) enriched[message.id]!];
  }

  Future<TwitchVodSeekMetadata> fetchVodSeekMetadata(String videoId) async {
    final normalizedVideoId = _nonEmptyValue(videoId);
    if (normalizedVideoId == null) {
      throw TwitchApiException("Video ID is required.");
    }
    final data = await _query(
      () => _graphQlClient.query$FlowVodSeekMetadata(
        Options$Query$FlowVodSeekMetadata(
          variables: Variables$Query$FlowVodSeekMetadata(videoId: normalizedVideoId),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowVodSeekMetadata",
    );
    final video = _mapValue(data.toJson()["video"]);
    final muteInfo = _mapValue(video?["muteInfo"]);
    final connection = _mapValue(muteInfo?["mutedSegmentConnection"]);
    return TwitchVodSeekMetadata(
      mutedSegments: [
        for (final node in _mapList(connection?["nodes"]))
          if (node["offset"] != null &&
              _intValue(node["offset"]) >= 0 &&
              _intValue(node["duration"]) > 0)
            TwitchMutedSegment(
              offset: Duration(seconds: _intValue(node["offset"])),
              duration: Duration(seconds: _intValue(node["duration"])),
            ),
      ],
      storyboard: await _fetchVodStoryboard(video?["seekPreviewsURL"] as String?),
    );
  }

  Future<TwitchVodStoryboard?> _fetchVodStoryboard(String? url) async {
    final uri = Uri.tryParse(url ?? "");
    if (uri == null || (uri.scheme != "https" && uri.scheme != "http")) {
      return null;
    }
    try {
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      TwitchVodStoryboard? selected;
      for (final spec in _mapList(jsonDecode(response.body))) {
        final width = _intValue(spec["width"]);
        final height = _intValue(spec["height"]);
        final columns = _intValue(spec["cols"]);
        final rows = _intValue(spec["rows"]);
        final count = _intValue(spec["count"]);
        final seconds = double.tryParse(spec["interval"]?.toString() ?? "") ?? 0;
        final images = spec["images"];
        if (width <= 0 ||
            height <= 0 ||
            columns <= 0 ||
            rows <= 0 ||
            count <= 0 ||
            !seconds.isFinite ||
            seconds <= 0 ||
            images is! List<Object?> ||
            images.isEmpty ||
            images.any((image) => image is! String || image.trim().isEmpty)) {
          continue;
        }
        final interval = Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());
        if (interval <= Duration.zero || (selected != null && selected.width >= width)) {
          continue;
        }
        selected = TwitchVodStoryboard(
          imageUrls: [for (final image in images.cast<String>()) uri.resolve(image).toString()],
          width: width,
          height: height,
          columns: columns,
          rows: rows,
          count: count,
          interval: interval,
        );
      }
      return selected;
    } on Object {
      // Storyboards can be unavailable while a VOD is still processing.
      return null;
    }
  }

  Future<bool> fetchChannelSubscriptionStatus(String login) async {
    final normalizedLogin = _nonEmptyValue(login);
    if (normalizedLogin == null) {
      throw TwitchApiException("Channel login is required.");
    }

    final data = await _query(
      () => _authenticatedGraphQlClient.query$FlowChannelSubscription(
        Options$Query$FlowChannelSubscription(
          variables: Variables$Query$FlowChannelSubscription(login: normalizedLogin),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowChannelSubscription",
      retryIntegrityChallenge: true,
    );
    final user = _mapValue(data.toJson()["user"]);
    final self = _mapValue(user?["self"]);
    return _mapValue(self?["subscriptionBenefit"]) != null;
  }

  Future<TwitchPage<TwitchFollowedStream>> _fetchGameStreamsPage({
    required String gameId,
    required int first,
    required String? cursor,
    required List<String> userLogins,
    required StreamSort sort,
  }) async {
    final data = await _query(
      () =>
          (sort == StreamSort.recommendedForYou && _nonEmptyValue(gqlAccessToken) != null
                  ? _tokenGraphQlClient
                  : _graphQlClient)
              .query$FlowGameStreams(
                Options$Query$FlowGameStreams(
                  variables: Variables$Query$FlowGameStreams(
                    id: gameId,
                    first: _boundedFirst(first),
                    after: _nonEmptyValue(cursor),
                    options: Input$GameStreamOptions(
                      sort: _graphQlStreamSort(sort),
                      recommendationsContext: sort == StreamSort.recommendedForYou
                          ? Input$RecommendationsContext(platform: "mobile_web")
                          : null,
                      requestID: sort == StreamSort.recommendedForYou
                          ? _recommendationRequestId
                          : null,
                    ),
                  ),
                  fetchPolicy: graphql.FetchPolicy.noCache,
                ),
              ),
      "FlowGameStreams",
      retryIntegrityChallenge: sort == StreamSort.recommendedForYou,
    );
    final game = _mapValue(data.toJson()["game"]);
    final page = _streamPageFromConnection(_mapValue(game?["streams"]));
    if (userLogins.isEmpty) {
      return page;
    }

    final allowedLogins = userLogins.map((value) => value.toLowerCase()).toSet();
    return TwitchPage<TwitchFollowedStream>(
      data: [
        for (final stream in page.data)
          if (allowedLogins.contains(stream.userLogin.toLowerCase())) stream,
      ],
      cursor: page.cursor,
    );
  }

  Future<TwitchPage<TwitchFollowedStream>> _fetchUserStreamsPage(
    List<String> userLogins, {
    required StreamSort sort,
  }) async {
    final streams = <TwitchFollowedStream>[];
    for (final batch in _batches(userLogins)) {
      final data = await _query(
        () => _graphQlClient.query$FlowUsers(
          Options$Query$FlowUsers(
            variables: Variables$Query$FlowUsers(logins: batch),
            fetchPolicy: graphql.FetchPolicy.noCache,
          ),
        ),
        "FlowUsers",
      );
      for (final user in _mapList(data.toJson()["users"])) {
        final stream = _mapValue(user["stream"]);
        if (stream != null) {
          streams.add(_streamFromGraphQlStream(stream, fallbackBroadcaster: user));
        }
      }
    }

    if (sort == StreamSort.recentlyStarted) {
      streams.sort(
        (left, right) => (right.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          left.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    } else if (sort != StreamSort.recommendedForYou) {
      streams.sort(
        (left, right) => sort == StreamSort.viewersLowToHigh
            ? left.viewerCount.compareTo(right.viewerCount)
            : right.viewerCount.compareTo(left.viewerCount),
      );
    }
    return TwitchPage<TwitchFollowedStream>(data: streams, cursor: null);
  }

  Future<T> _query<T>(
    Future<graphql.QueryResult<T>> Function() request,
    String operationName, {
    bool retryIntegrityChallenge = false,
    bool allowPartialData = false,
  }) async {
    final revision = _webSessionRevision;
    final attemptedGrant = _integrityGrant;
    var result = await request();
    if (retryIntegrityChallenge &&
        revision == _webSessionRevision &&
        _nonEmptyValue(gqlAccessToken) != null &&
        result.exception?.graphqlErrors.any(
              (error) => error.message.toLowerCase().contains("failed integrity check"),
            ) ==
            true) {
      final currentGrant = _integrityGrant;
      final alreadyRefreshed =
          currentGrant != null &&
          currentGrant != attemptedGrant &&
          currentGrant.authorization == _oauthAuthorizationHeader(gqlAccessToken!);
      if ((alreadyRefreshed || await _refreshIntegrityGrant()) && revision == _webSessionRevision) {
        result = await request();
      }
    }
    final exception = result.exception;
    if (exception != null &&
        !(allowPartialData && exception.linkException == null && result.parsedData != null)) {
      throw TwitchApiException(
        "Twitch GraphQL $operationName failed: ${_graphQlExceptionMessage(exception)}",
        isTransient: _isTransientGraphQlException(exception),
      );
    }

    final data = result.parsedData;
    if (data == null) {
      throw TwitchApiException(
        "Twitch GraphQL $operationName returned no data.",
      );
    }
    return data;
  }

  Future<bool> _refreshIntegrityGrant() async {
    final revision = _webSessionRevision;
    final authorization = _oauthAuthorizationHeader(gqlAccessToken!);
    final pending = _integrityRefresh;
    if (pending != null && pending.revision == revision && pending.authorization == authorization) {
      return pending.future;
    }
    final future = _loadIntegrityGrant(authorization, revision);
    _integrityRefresh = (authorization: authorization, revision: revision, future: future);
    try {
      return await future;
    } finally {
      if (identical(_integrityRefresh?.future, future)) {
        _integrityRefresh = null;
      }
    }
  }

  Future<bool> _loadIntegrityGrant(String authorization, int revision) async {
    _integrityGrant = null;
    try {
      final observed = await _integrityContextLoader(authorization);
      const contextKeys = ["Client-Id", "X-Device-ID", "Client-Session-Id", "Client-Version"];
      if (revision != _webSessionRevision ||
          observed == null ||
          contextKeys.any((key) => _nonEmptyValue(observed[key]) == null) ||
          observed["Client-Id"] != _webSessionGraphQlClientId) {
        return false;
      }
      final sessionHeaders = {
        for (final key in contextKeys) key: observed[key]!,
      };
      for (final key in ["User-Agent", "Origin", "Referer"]) {
        if (_nonEmptyValue(observed[key]) case final value?) {
          sessionHeaders[key] = value;
        }
      }
      if (_nonEmptyValue(observed["Client-Integrity"]) case final issuedToken?) {
        _integrityGrant = (
          authorization: authorization,
          token: issuedToken,
          headers: sessionHeaders,
        );
        return true;
      }
      return false;
    } on Object {
      return false;
    }
  }

  graphql.GraphQLClient _graphQlClientWithHeaders({required bool includeToken}) =>
      graphql.GraphQLClient(
        cache: graphql.GraphQLCache(store: graphql.InMemoryStore()),
        link: graphql.Link.function(
          (request, [forward]) => forward!(
            request.updateContextEntry<graphql.HttpLinkHeaders>(
              (_) => graphql.HttpLinkHeaders(headers: _graphQlHeaders(includeToken: includeToken)),
            ),
          ),
        ).concat(graphql.HttpLink(_gqlEndpoint, httpClient: _httpClient)),
      );

  graphql.GraphQLClient get _authenticatedGraphQlClient {
    if (_nonEmptyValue(gqlAccessToken) == null) {
      throw TwitchApiException("Twitch GraphQL auth token is missing.");
    }
    return _tokenGraphQlClient;
  }

  static Enum$StreamSort _graphQlStreamSort(StreamSort sort) => switch (sort) {
    StreamSort.recommendedForYou => Enum$StreamSort.RELEVANCE,
    StreamSort.viewersHighToLow => Enum$StreamSort.VIEWER_COUNT,
    StreamSort.viewersLowToHigh => Enum$StreamSort.VIEWER_COUNT_ASC,
    StreamSort.recentlyStarted => Enum$StreamSort.RECENT,
  };

  static String _requestId() {
    final random = math.Random();
    final hex = List.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, "0"),
    ).join();
    return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}";
  }

  Future<Query$FlowPlaybackAccessToken> _fetchPlaybackAccessToken(
    String channelOrVideoId, {
    bool isVod = false,
  }) async {
    final options = Options$Query$FlowPlaybackAccessToken(
      variables: Variables$Query$FlowPlaybackAccessToken(
        login: isVod ? "" : channelOrVideoId,
        isLive: !isVod,
        vodID: isVod ? channelOrVideoId : "",
        isVod: isVod,
        platform: "web",
        playerType: "site",
      ),
      fetchPolicy: graphql.FetchPolicy.noCache,
    );
    Future<Query$FlowPlaybackAccessToken> query(graphql.GraphQLClient client) => _query(
      () => client.query$FlowPlaybackAccessToken(options),
      "FlowPlaybackAccessToken",
      retryIntegrityChallenge: identical(client, _tokenGraphQlClient),
    );

    if (_nonEmptyValue(gqlAccessToken) == null) {
      return query(_graphQlClient);
    }
    try {
      return await query(_tokenGraphQlClient);
    } on TwitchApiException {
      return query(_graphQlClient);
    }
  }

  Map<String, String> _graphQlHeaders({required bool includeToken}) {
    final headers = {
      "Client-Id": graphQlClientId,
      "Content-Type": "application/json",
      "X-Device-ID": _deviceId,
    };
    final token = _nonEmptyValue(gqlAccessToken);
    if (includeToken && token != null) {
      headers["Client-Id"] = _webSessionGraphQlClientId;
      headers["X-Device-ID"] = _webSessionDeviceId ?? _deviceId;
      headers["Authorization"] = _oauthAuthorizationHeader(token);
      final grant = _integrityGrant;
      if (grant != null && grant.authorization == headers["Authorization"]) {
        headers.addAll(grant.headers);
        headers["Client-Integrity"] = grant.token;
      }
    }
    return headers;
  }

  static String _oauthAuthorizationHeader(String token) {
    final trimmedToken = token.trim();
    if (trimmedToken.toLowerCase().startsWith("oauth ")) {
      return trimmedToken;
    }
    return "OAuth $trimmedToken";
  }

  static TwitchPage<TwitchCategory> _categoryPageFromConnection(
    Map<String, Object?>? connection, {
    int cursorOverlap = 0,
  }) => TwitchPage<TwitchCategory>(
    data: [
      for (final edge in _edgeList(connection))
        if (_mapValue(edge["node"]) case final node?)
          TwitchCategory(
            id: _stringValue(node["id"]),
            name: _stringValue(node["displayName"]),
            boxArtUrl: node["boxArtURL"] as String?,
            viewerCount: _intValue(node["viewersCount"]),
          ),
    ],
    cursor: _connectionCursor(connection, overlap: cursorOverlap),
  );

  static TwitchPage<TwitchFollowedStream> _streamPageFromConnection(
    Map<String, Object?>? connection, {
    int cursorOverlap = 0,
  }) => TwitchPage<TwitchFollowedStream>(
    data: [
      for (final edge in _edgeList(connection))
        if (_mapValue(edge["node"]) case final node?) _streamFromGraphQlStream(node),
    ],
    cursor: _connectionCursor(connection, overlap: cursorOverlap),
  );

  static List<Map<String, Object?>> _edgeList(
    Map<String, Object?>? connection,
  ) => _mapList(connection?["edges"]);

  static void _requireFollowingConnection(Map<String, Object?>? connection, String operationName) {
    final hasNextPage = _mapValue(connection?["pageInfo"])?["hasNextPage"];
    if (connection?["edges"] is! List<Object?> ||
        hasNextPage is! bool ||
        (hasNextPage && _connectionCursor(connection) == null)) {
      throw TwitchApiException(
        "Twitch GraphQL $operationName returned incomplete Following data.",
        isTransient: true,
      );
    }
  }

  static String? _connectionCursor(Map<String, Object?>? connection, {int overlap = 0}) {
    final pageInfo = _mapValue(connection?["pageInfo"]);
    if (pageInfo?["hasNextPage"] != true) {
      return null;
    }

    final edges = _edgeList(connection);
    if (edges.isEmpty) {
      return null;
    }
    final edge = edges.length > overlap ? edges[edges.length - 1 - overlap] : edges.last;
    return _nonEmptyValue(edge["cursor"]?.toString());
  }

  static TwitchUser _userFromGraphQlUser(Map<String, Object?> user) => TwitchUser(
    id: _stringValue(user["id"]),
    login: _stringValue(user["login"]),
    displayName: _stringValue(user["displayName"]),
    profileImageUrl: user["profileImageURL"] as String?,
    chatColor: user["chatColor"] as String?,
  );

  static TwitchFollowedStream _streamFromGraphQlStream(
    Map<String, Object?> stream, {
    Map<String, Object?>? fallbackBroadcaster,
  }) {
    final broadcaster = <String, Object?>{
      ...?fallbackBroadcaster,
      ...?_mapValue(stream["broadcaster"]),
    };
    final broadcastSettings =
        _mapValue(broadcaster["broadcastSettings"]) ?? _mapValue(stream["broadcastSettings"]);
    final game = _mapValue(stream["game"]);
    final tags = <String>[];
    for (final tag in _mapList(stream["freeformTags"])) {
      final name = _nonEmptyValue(tag["name"]?.toString());
      if (name != null) {
        tags.add(name);
      }
    }

    return TwitchFollowedStream(
      id: _stringValue(stream["id"]),
      userId: _stringValue(broadcaster["id"]),
      userLogin: _stringValue(broadcaster["login"]),
      userName: _stringValue(broadcaster["displayName"]),
      gameName: _stringValue(game?["displayName"]),
      gameId: _stringValue(game?["id"]),
      title: _stringValue(broadcastSettings?["title"]),
      viewerCount: _intValue(stream["viewersCount"]),
      isPartner: broadcaster["isPartner"] == true,
      thumbnailUrl: stream["previewImageURL"] as String?,
      profileImageUrl: broadcaster["profileImageURL"] as String?,
      startedAt: _dateTimeValue(stream["createdAt"]),
      tags: tags,
    );
  }

  static TwitchSearchChannel _searchChannelFromGraphQlContent(
    Map<String, Object?> content, {
    String fallbackDisplayName = "",
  }) {
    final user = _mapValue(content["user"]);
    final stream = _mapValue(user?["stream"]);
    final game = _mapValue(stream?["game"]);
    final broadcaster = _mapValue(stream?["broadcaster"]);
    final broadcastSettings = _mapValue(broadcaster?["broadcastSettings"]);
    final isLive = content["isLive"] == true || stream != null;

    return TwitchSearchChannel(
      id: _stringValue(content["id"]),
      broadcasterLogin: _stringValue(content["login"]),
      displayName: _stringValue(
        user?["displayName"] ??
            (fallbackDisplayName.isEmpty ? content["login"] : fallbackDisplayName),
      ),
      gameName: _stringValue(game?["displayName"]),
      title: _stringValue(broadcastSettings?["title"]),
      gameId: _stringValue(game?["id"]),
      isPartner: user?["isPartner"] == true,
      thumbnailUrl: content["profileImageURL"] as String?,
      startedAt: _dateTimeValue(stream?["createdAt"]),
      isLive: isLive,
    );
  }

  static TwitchChannelDetails _channelDetailsFromGraphQlUser(
    Map<String, Object?> user,
  ) {
    final followers = _mapValue(user["followers"]);
    final liveStream = _mapValue(user["stream"]);
    final videosConnection = _mapValue(user["videos"]);

    return TwitchChannelDetails(
      id: _stringValue(user["id"]),
      login: _stringValue(user["login"]),
      displayName: _stringValue(user["displayName"]),
      description: _stringValue(user["description"]),
      followers: _intValue(followers?["totalCount"]),
      isPartner: user["isPartner"] == true,
      profileImageUrl: user["profileImageURL"] as String?,
      liveStream: liveStream == null ? null : _channelLiveStreamFromGraphQl(liveStream),
      pastBroadcastsCursor: _connectionCursor(videosConnection),
      pastBroadcasts: [
        for (final edge in _edgeList(videosConnection))
          if (_mapValue(edge["node"]) case final video?) _pastBroadcastFromGraphQlVideo(video),
      ],
    );
  }

  static TwitchChannelLiveStream _channelLiveStreamFromGraphQl(
    Map<String, Object?> stream,
  ) {
    final game = _mapValue(stream["game"]);
    final broadcaster = _mapValue(stream["broadcaster"]);
    final broadcastSettings = _mapValue(broadcaster?["broadcastSettings"]);
    final title = _stringValue(broadcastSettings?["title"]);

    return TwitchChannelLiveStream(
      id: _stringValue(stream["id"]),
      title: title.isEmpty ? "Live now" : title,
      categoryId: _stringValue(game?["id"]),
      category: _gameName(game, fallback: "Live"),
      viewerCount: _intValue(stream["viewersCount"]),
      thumbnailUrl: stream["previewImageURL"] as String?,
      startedAt: _dateTimeValue(stream["createdAt"]),
    );
  }

  static TwitchPastBroadcast _pastBroadcastFromGraphQlVideo(
    Map<String, Object?> video,
  ) {
    final game = _mapValue(video["game"]);
    final title = _stringValue(video["title"]);

    return TwitchPastBroadcast(
      id: _stringValue(video["id"]),
      title: title.isEmpty ? "Past broadcast" : title,
      categoryId: _stringValue(game?["id"]),
      category: _gameName(game, fallback: "Broadcast"),
      duration: Duration(seconds: _intValue(video["lengthSeconds"])),
      thumbnailUrl: video["previewThumbnailURL"] as String?,
      publishedAt: _dateTimeValue(video["publishedAt"]),
      createdAt: _dateTimeValue(video["createdAt"]),
      viewCount: _intValue(video["viewCount"]),
    );
  }

  static String _gameName(
    Map<String, Object?>? game, {
    required String fallback,
  }) {
    final displayName = _stringValue(game?["displayName"]);
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final name = _stringValue(game?["name"]);
    return name.isEmpty ? fallback : name;
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  static Iterable<List<String>> _batches(List<String> values) sync* {
    final items = _nonEmptyValues(values).toSet().toList();
    for (var index = 0; index < items.length; index += 100) {
      yield items.skip(index).take(100).toList();
    }
  }

  static int _boundedFirst(int value, {int max = _maxPageSize}) => value.clamp(1, max);

  static List<String> _nonEmptyValues(List<String> values) => [
    for (final value in values)
      if (value.trim().isNotEmpty) value.trim(),
  ];

  static String? _nonEmptyValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static TwitchChatMessage _chatMessageFromGraphQl(
    Map<String, Object?> message, {
    String? threadRootId,
    String? threadRootLogin,
    TwitchChatMessage? replay,
  }) {
    final sender = _mapValue(message["sender"]);
    final content = _mapValue(message["content"]);
    final fragments = _mapList(content?["fragments"]);
    final buffer = StringBuffer();
    final emotes = <TwitchChatEmote>[];
    final gifs = <TwitchChatGif>[];
    for (final fragment in fragments) {
      final text = _stringValue(fragment["text"]);
      final media = _mapValue(fragment["content"]);
      final emoteId = _nonEmptyValue(media?["emoteID"] as String?);
      if (emoteId != null && text.isNotEmpty) {
        emotes.add(
          TwitchChatEmote(id: emoteId, start: buffer.length, end: buffer.length + text.length),
        );
      }
      final gifId = _nonEmptyValue(media?["gifID"] as String?);
      final gifUrl = media?["gifURL"] as String?;
      final uri = gifUrl == null ? null : Uri.tryParse(gifUrl);
      if (gifId != null && text.isNotEmpty && uri?.scheme == "https" && uri!.host.isNotEmpty) {
        gifs.add(
          TwitchChatGif(
            id: gifId,
            url: gifUrl!,
            start: buffer.length,
            end: buffer.length + text.length,
          ),
        );
      }
      buffer.write(text);
    }
    final text = content?["text"] as String? ?? buffer.toString();
    final parent = _mapValue(message["parentMessage"]);
    final parentMessage = parent == null ? null : _chatMessageFromGraphQl(parent);
    final parentSender = _mapValue(parent?["sender"]);
    final thread = _mapValue(message["threadParentMessage"]);
    return TwitchChatMessage(
      id: _stringValue(message["id"]),
      login: replay?.login ?? _stringValue(sender?["login"]),
      displayName:
          replay?.displayName ??
          _nonEmptyValue(sender?["displayName"] as String?) ??
          _nonEmptyValue(sender?["login"] as String?) ??
          "Deleted user",
      userId: replay?.userId ?? _nonEmptyValue(sender?["id"] as String?),
      text: text,
      color:
          replay?.color ?? message["senderChatColor"] as String? ?? sender?["chatColor"] as String?,
      badges:
          replay?.badges ??
          [
            for (final badge in _mapList(message["senderBadges"] ?? sender?["displayBadges"]))
              if (_nonEmptyValue(badge["setID"] as String?) case final setId?)
                "$setId/${_stringValue(badge["version"])}",
          ],
      emotes: replay?.emotes ?? (buffer.toString() == text ? emotes : const []),
      gifs: buffer.toString() == text ? gifs : const [],
      timestamp: replay?.timestamp ?? _dateTimeValue(message["sentAt"]),
      offsetSeconds: replay?.offsetSeconds,
      isDeleted: replay?.isDeleted ?? message["deletedAt"] != null,
      moderation: replay != null
          ? replay.moderation
          : message["deletedAt"] != null
          ? TwitchChatModeration.deleted
          : null,
      moderatedAt: _dateTimeValue(message["deletedAt"]) ?? replay?.moderatedAt,
      parentMessageId: parent?["id"] as String?,
      parentUserId: parentSender?["id"] as String?,
      parentLogin: parentSender?["login"] as String?,
      parentDisplayName: parentSender?["displayName"] as String?,
      parentText: _mapValue(parent?["content"])?["text"] as String?,
      parentEmotes: parentMessage?.emotes ?? const [],
      parentGifs: parentMessage?.gifs ?? const [],
      threadRootId: thread?["id"] as String? ?? threadRootId,
      threadRootLogin: _mapValue(thread?["sender"])?["login"] as String? ?? threadRootLogin,
    );
  }

  static Map<String, Object?>? _mapValue(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static List<Map<String, Object?>> _mapList(Object? value) {
    if (value is! List) {
      return const [];
    }
    final maps = <Map<String, Object?>>[];
    for (final item in value) {
      final map = _mapValue(item);
      if (map != null) {
        maps.add(map);
      }
    }
    return maps;
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  static String _stringValue(Object? value) => value?.toString() ?? "";

  static bool _isTransientHttpStatus(int? status) =>
      status == 408 || status == 429 || (status != null && status >= 500 && status < 600);

  static bool _isTransientGraphQlException(graphql.OperationException exception) {
    if (exception.graphqlErrors.isNotEmpty) {
      return false;
    }
    final linkException = exception.linkException;
    final status = switch (linkException) {
      graphql.ServerException(:final statusCode) => statusCode,
      graphql.HttpLinkParserException(:final response) => response.statusCode,
      _ => null,
    };
    return linkException is graphql.NetworkException ||
        linkException?.originalException is http.ClientException ||
        linkException?.originalException is TimeoutException ||
        _isTransientHttpStatus(status);
  }

  static String _graphQlExceptionMessage(graphql.OperationException exception) {
    if (exception.graphqlErrors.isNotEmpty) {
      return exception.graphqlErrors.map((error) => error.message).join("; ");
    }

    final linkException = exception.linkException;
    if (linkException != null) {
      return linkException.toString();
    }

    return exception.toString();
  }
}
