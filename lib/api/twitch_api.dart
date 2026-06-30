import "dart:convert";

import "package:http/http.dart" as http;

class TwitchApiException implements Exception {
  TwitchApiException(this.message);

  final String message;

  @override
  String toString() => "TwitchApiException: $message";
}

class TwitchUser {
  const TwitchUser({
    required this.id,
    required this.login,
    required this.displayName,
    this.profileImageUrl,
  });

  final String id;
  final String login;
  final String displayName;
  final String? profileImageUrl;
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
    this.thumbnailUrl,
    this.startedAt,
    this.tags = const [],
  });

  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String gameName;
  final String title;
  final int viewerCount;
  final String? thumbnailUrl;
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
  });

  final String broadcasterId;
  final String broadcasterName;
  final String gameName;
  final String title;
}

class TwitchCategory {
  const TwitchCategory({
    required this.id,
    required this.name,
    required this.boxArtUrl,
  });

  final String id;
  final String name;
  final String? boxArtUrl;
}

class TwitchSearchChannel {
  const TwitchSearchChannel({
    required this.id,
    required this.broadcasterLogin,
    required this.displayName,
    required this.gameName,
    required this.title,
    required this.isLive,
    this.thumbnailUrl,
    this.startedAt,
  });

  final String id;
  final String broadcasterLogin;
  final String displayName;
  final String gameName;
  final String title;
  final bool isLive;
  final String? thumbnailUrl;
  final DateTime? startedAt;
}

class TwitchPage<T> {
  const TwitchPage({required this.data, required this.cursor});

  final List<T> data;
  final String? cursor;
}

class TwitchApiClient {
  TwitchApiClient({
    required this.clientId,
    required this.accessToken,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String clientId;
  final String accessToken;
  final http.Client _httpClient;

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
      );
    }

    return true;
  }

  Future<TwitchUser> fetchCurrentUser() async {
    final payload = await _get("/helix/users");
    final data = _dataList(payload);

    if (data.isEmpty) {
      throw TwitchApiException("Twitch returned no current user.");
    }

    final user = data.first;
    return TwitchUser(
      id: _stringValue(user["id"]),
      login: _stringValue(user["login"]),
      displayName: _stringValue(user["display_name"]),
      profileImageUrl: user["profile_image_url"] as String?,
    );
  }

  Future<List<TwitchFollowedStream>> fetchFollowedStreams(String userId) async {
    final data = await _getPaginatedData("/helix/streams/followed", {
      "user_id": userId,
    });

    return [for (final item in data) _streamFromItem(item)];
  }

  Future<List<TwitchFollowedChannel>> fetchFollowedChannels(
    String userId,
  ) async {
    final data = await _getPaginatedData("/helix/channels/followed", {
      "user_id": userId,
    });

    return [
      for (final item in data)
        TwitchFollowedChannel(
          broadcasterId: _stringValue(item["broadcaster_id"]),
          broadcasterLogin: _stringValue(item["broadcaster_login"]),
          broadcasterName: _stringValue(item["broadcaster_name"]),
          followedAt: _dateTimeValue(item["followed_at"]),
        ),
    ];
  }

  Future<Map<String, TwitchUser>> fetchUsersByIds(List<String> ids) async {
    final users = <String, TwitchUser>{};
    for (final batch in _batches(ids)) {
      final payload = await _get("/helix/users", {"id": batch});
      for (final item in _dataList(payload)) {
        final user = TwitchUser(
          id: _stringValue(item["id"]),
          login: _stringValue(item["login"]),
          displayName: _stringValue(item["display_name"]),
          profileImageUrl: item["profile_image_url"] as String?,
        );
        users[user.id] = user;
      }
    }
    return users;
  }

  Future<Map<String, TwitchChannelInfo>> fetchChannelInfoByBroadcasterIds(
    List<String> broadcasterIds,
  ) async {
    final channels = <String, TwitchChannelInfo>{};
    for (final batch in _batches(broadcasterIds)) {
      final payload = await _get("/helix/channels", {"broadcaster_id": batch});
      for (final item in _dataList(payload)) {
        final channel = TwitchChannelInfo(
          broadcasterId: _stringValue(item["broadcaster_id"]),
          broadcasterName: _stringValue(item["broadcaster_name"]),
          gameName: _stringValue(item["game_name"]),
          title: _stringValue(item["title"]),
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
  }) async {
    final queryParameters = <String, dynamic>{"first": _boundedFirst(first)};
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters["after"] = cursor;
    }

    final payload = await _get("/helix/games/top", queryParameters);

    return TwitchPage<TwitchCategory>(
      data: [for (final item in _dataList(payload)) _categoryFromItem(item)],
      cursor: _paginationCursor(payload),
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

    final queryParameters = <String, dynamic>{
      "query": normalizedQuery,
      "first": _boundedFirst(first),
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters["after"] = cursor;
    }

    final payload = await _get("/helix/search/categories", queryParameters);

    return TwitchPage<TwitchCategory>(
      data: [for (final item in _dataList(payload)) _categoryFromItem(item)],
      cursor: _paginationCursor(payload),
    );
  }

  Future<List<TwitchFollowedStream>> fetchLiveStreams({
    int first = 20,
    List<String> gameIds = const [],
    List<String> userLogins = const [],
  }) async {
    final page = await fetchLiveStreamsPage(
      first: first,
      gameIds: gameIds,
      userLogins: userLogins,
    );
    return page.data;
  }

  Future<TwitchPage<TwitchFollowedStream>> fetchLiveStreamsPage({
    int first = 20,
    List<String> gameIds = const [],
    List<String> userLogins = const [],
    String? cursor,
  }) async {
    final queryParameters = <String, dynamic>{
      "first": _boundedFirst(first),
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters["after"] = cursor;
    }
    final normalizedGameIds = _nonEmptyValues(gameIds);
    final normalizedUserLogins = _nonEmptyValues(userLogins);
    if (normalizedGameIds.isNotEmpty) {
      queryParameters["game_id"] = normalizedGameIds;
    }
    if (normalizedUserLogins.isNotEmpty) {
      queryParameters["user_login"] = normalizedUserLogins;
    }

    final payload = await _get("/helix/streams", queryParameters);
    return TwitchPage<TwitchFollowedStream>(
      data: [for (final item in _dataList(payload)) _streamFromItem(item)],
      cursor: _paginationCursor(payload),
    );
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

    final queryParameters = <String, dynamic>{
      "query": normalizedQuery,
      "first": _boundedFirst(first),
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters["after"] = cursor;
    }
    if (liveOnly) {
      queryParameters["live_only"] = "true";
    }

    final payload = await _get("/helix/search/channels", queryParameters);

    return TwitchPage<TwitchSearchChannel>(
      data: [
        for (final item in _dataList(payload))
          TwitchSearchChannel(
            id: _stringValue(item["id"]),
            broadcasterLogin: _stringValue(item["broadcaster_login"]),
            displayName: _stringValue(item["display_name"]),
            gameName: _stringValue(item["game_name"]),
            title: _stringValue(item["title"]),
            thumbnailUrl: item["thumbnail_url"] as String?,
            startedAt: _dateTimeValue(item["started_at"]),
            isLive: item["is_live"] == true || _stringValue(item["is_live"]) == "true",
          ),
      ],
      cursor: _paginationCursor(payload),
    );
  }

  Future<Map<String, Object?>> _get(
    String path, [
    Map<String, dynamic> queryParameters = const {},
  ]) async {
    final uri = Uri.https("api.twitch.tv", path, queryParameters);
    final response = await _httpClient.get(uri, headers: _headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TwitchApiException(
        "Twitch request failed (${response.statusCode}): ${response.body}",
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, Object?>) {
      throw TwitchApiException("Twitch returned an unexpected response.");
    }

    return body;
  }

  Future<List<Map<String, Object?>>> _getPaginatedData(
    String path,
    Map<String, String> queryParameters,
  ) async {
    final data = <Map<String, Object?>>[];
    String? after;

    do {
      final pageQueryParameters = {...queryParameters, "first": "100"};
      if (after != null) {
        pageQueryParameters["after"] = after;
      }

      final payload = await _get(path, pageQueryParameters);
      data.addAll(_dataList(payload));
      after = _paginationCursor(payload);
    } while (after != null && after.isNotEmpty);

    return data;
  }

  Map<String, String> get _headers => {
    "Authorization": "Bearer $accessToken",
    "Client-ID": clientId,
  };

  static List<Map<String, Object?>> _dataList(Map<String, Object?> payload) {
    final data = payload["data"];
    if (data is! List) {
      return const [];
    }

    return [
      for (final item in data)
        if (item is Map<String, Object?>) item,
    ];
  }

  static String? _paginationCursor(Map<String, Object?> payload) {
    final pagination = payload["pagination"];
    if (pagination is! Map<String, Object?>) {
      return null;
    }
    return pagination["cursor"] as String?;
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item != null) item.toString(),
    ];
  }

  static Iterable<List<String>> _batches(List<String> values) sync* {
    final uniqueValues = values.where((value) => value.isNotEmpty).toSet();
    final items = uniqueValues.toList();
    for (var index = 0; index < items.length; index += 100) {
      yield items.skip(index).take(100).toList();
    }
  }

  static String _boundedFirst(int value) => value.clamp(1, 100).toString();

  static TwitchCategory _categoryFromItem(Map<String, Object?> item) => TwitchCategory(
    id: _stringValue(item["id"]),
    name: _stringValue(item["name"]),
    boxArtUrl: item["box_art_url"] as String?,
  );

  static List<String> _nonEmptyValues(List<String> values) => [
    for (final value in values)
      if (value.trim().isNotEmpty) value.trim(),
  ];

  static TwitchFollowedStream _streamFromItem(Map<String, Object?> item) => TwitchFollowedStream(
    id: _stringValue(item["id"]),
    userId: _stringValue(item["user_id"]),
    userLogin: _stringValue(item["user_login"]),
    userName: _stringValue(item["user_name"]),
    gameName: _stringValue(item["game_name"]),
    title: _stringValue(item["title"]),
    viewerCount: item["viewer_count"] is int
        ? item["viewer_count"]! as int
        : int.tryParse('${item['viewer_count']}') ?? 0,
    thumbnailUrl: item["thumbnail_url"] as String?,
    startedAt: _dateTimeValue(item["started_at"]),
    tags: _stringList(item["tags"]),
  );

  static String _stringValue(Object? value) => value?.toString() ?? "";
}
