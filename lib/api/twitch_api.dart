import "dart:math" as math;

import "package:flow/graphql/FlowChannelDetails.graphql.dart";
import "package:flow/graphql/FlowChannelSubscription.graphql.dart";
import "package:flow/graphql/FlowCurrentUser.graphql.dart";
import "package:flow/graphql/FlowFollowedLiveUsers.graphql.dart";
import "package:flow/graphql/FlowFollowedUsers.graphql.dart";
import "package:flow/graphql/FlowGameStreams.graphql.dart";
import "package:flow/graphql/FlowPlaybackAccessToken.graphql.dart";
import "package:flow/graphql/FlowSearchCategories.graphql.dart";
import "package:flow/graphql/FlowSearchChannels.graphql.dart";
import "package:flow/graphql/FlowTopGames.graphql.dart";
import "package:flow/graphql/FlowTopStreams.graphql.dart";
import "package:flow/graphql/FlowUsers.graphql.dart";
import "package:graphql/client.dart" as graphql;
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

class TwitchChannelDetails {
  const TwitchChannelDetails({
    required this.id,
    required this.login,
    required this.displayName,
    required this.description,
    required this.followers,
    required this.pastBroadcasts,
    required this.pastBroadcastsCursor,
    this.profileImageUrl,
    this.liveStream,
  });

  final String id;
  final String login;
  final String displayName;
  final String description;
  final int followers;
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
    required this.category,
    required this.viewerCount,
    this.thumbnailUrl,
    this.startedAt,
  });

  final String id;
  final String title;
  final String category;
  final int viewerCount;
  final String? thumbnailUrl;
  final DateTime? startedAt;
}

class TwitchPastBroadcast {
  const TwitchPastBroadcast({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    required this.viewCount,
    this.thumbnailUrl,
    this.publishedAt,
    this.createdAt,
  });

  final String id;
  final String title;
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

class TwitchApiClient {
  TwitchApiClient({
    required this.clientId,
    required this.accessToken,
    String? graphQlClientId,
    this.gqlAccessToken,
    http.Client? httpClient,
  }) : graphQlClientId = _nonEmptyValue(graphQlClientId) ?? defaultGraphQlClientId,
       _httpClient = httpClient ?? http.Client();

  static const _gqlEndpoint = "https://gql.twitch.tv/gql/";
  static const _maxPageSize = 100;
  static const _maxTopStreamsPageSize = 30;
  static const defaultGraphQlClientId = "ue6666qo983tsx6so1t0vnawi233wa";

  final String clientId;
  final String graphQlClientId;
  final String accessToken;
  final String? gqlAccessToken;
  final http.Client _httpClient;

  late final graphql.GraphQLClient _graphQlClient = _graphQlClientWithHeaders(
    _graphQlHeaders(includeToken: false),
  );

  late final graphql.GraphQLClient _tokenGraphQlClient = _graphQlClientWithHeaders(
    _graphQlHeaders(includeToken: true),
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
    );
    final user = _mapValue(data.toJson()["currentUser"]);
    if (user == null) {
      throw TwitchApiException("Twitch returned no current user.");
    }

    return _userFromGraphQlUser(user);
  }

  Future<List<TwitchFollowedStream>> fetchFollowedStreams(String userId) async {
    final streams = <TwitchFollowedStream>[];
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
      );
      final currentUser = _mapValue(data.toJson()["currentUser"]);
      final connection = _mapValue(currentUser?["followedLiveUsers"]);

      for (final edge in _edgeList(connection)) {
        final node = _mapValue(edge["node"]);
        final stream = _mapValue(node?["stream"]);
        if (node != null && stream != null) {
          streams.add(_streamFromGraphQlStream(stream, fallbackBroadcaster: node));
        }
      }

      after = _connectionCursor(connection);
    } while (after != null && after.isNotEmpty);

    return streams;
  }

  Future<List<TwitchFollowedChannel>> fetchFollowedChannels(
    String userId,
  ) async {
    final channels = <TwitchFollowedChannel>[];
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
      );
      final currentUser = _mapValue(data.toJson()["currentUser"]);
      final connection = _mapValue(currentUser?["follows"]);

      for (final edge in _edgeList(connection)) {
        final node = _mapValue(edge["node"]);
        if (node == null) {
          continue;
        }
        channels.add(
          TwitchFollowedChannel(
            broadcasterId: _stringValue(node["id"]),
            broadcasterLogin: _stringValue(node["login"]),
            broadcasterName: _stringValue(node["displayName"]),
            followedAt: _dateTimeValue(edge["followedAt"]),
          ),
        );
      }

      after = _connectionCursor(connection);
    } while (after != null && after.isNotEmpty);

    return channels;
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
          title: _stringValue(broadcastSettings?["title"]),
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
    final data = await _query(
      () => _graphQlClient.query$FlowTopGames(
        Options$Query$FlowTopGames(
          variables: Variables$Query$FlowTopGames(
            first: _boundedFirst(first),
            after: _nonEmptyValue(cursor),
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowTopGames",
    );

    return _categoryPageFromConnection(_mapValue(data.toJson()["games"]));
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
    final normalizedGameIds = _nonEmptyValues(gameIds);
    final normalizedUserLogins = _nonEmptyValues(userLogins);

    if (normalizedGameIds.isNotEmpty) {
      return _fetchGameStreamsPage(
        gameId: normalizedGameIds.first,
        first: first,
        cursor: cursor,
        userLogins: normalizedUserLogins,
      );
    }

    if (normalizedUserLogins.isNotEmpty) {
      return _fetchUserStreamsPage(normalizedUserLogins);
    }

    final data = await _query(
      () => _graphQlClient.query$FlowTopStreams(
        Options$Query$FlowTopStreams(
          variables: Variables$Query$FlowTopStreams(
            first: _boundedFirst(first, max: _maxTopStreamsPageSize),
            after: _nonEmptyValue(cursor),
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowTopStreams",
    );

    return _streamPageFromConnection(_mapValue(data.toJson()["streams"]));
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
        "supported_codecs": "h264",
        "token": token,
        "type": "any",
      },
    );
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
  }) async {
    final data = await _query(
      () => _graphQlClient.query$FlowGameStreams(
        Options$Query$FlowGameStreams(
          variables: Variables$Query$FlowGameStreams(
            id: gameId,
            first: _boundedFirst(first),
            after: _nonEmptyValue(cursor),
          ),
          fetchPolicy: graphql.FetchPolicy.noCache,
        ),
      ),
      "FlowGameStreams",
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
    List<String> userLogins,
  ) async {
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

    return TwitchPage<TwitchFollowedStream>(data: streams, cursor: null);
  }

  Future<T> _query<T>(
    Future<graphql.QueryResult<T>> Function() request,
    String operationName,
  ) async {
    final result = await request();
    final exception = result.exception;
    if (exception != null) {
      throw TwitchApiException(
        "Twitch GraphQL $operationName failed: ${_graphQlExceptionMessage(exception)}",
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

  graphql.GraphQLClient _graphQlClientWithHeaders(
    Map<String, String> headers,
  ) => graphql.GraphQLClient(
    cache: graphql.GraphQLCache(store: graphql.InMemoryStore()),
    link: graphql.HttpLink(
      _gqlEndpoint,
      defaultHeaders: headers,
      httpClient: _httpClient,
    ),
  );

  graphql.GraphQLClient get _authenticatedGraphQlClient {
    if (_nonEmptyValue(gqlAccessToken) == null) {
      throw TwitchApiException("Twitch GraphQL auth token is missing.");
    }
    return _tokenGraphQlClient;
  }

  Future<Query$FlowPlaybackAccessToken> _fetchPlaybackAccessToken(String login) async {
    final options = Options$Query$FlowPlaybackAccessToken(
      variables: Variables$Query$FlowPlaybackAccessToken(
        login: login,
        platform: "web",
        playerType: "site",
      ),
      fetchPolicy: graphql.FetchPolicy.noCache,
    );
    Future<Query$FlowPlaybackAccessToken> query(graphql.GraphQLClient client) => _query(
      () => client.query$FlowPlaybackAccessToken(options),
      "FlowPlaybackAccessToken",
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
    };
    final token = _nonEmptyValue(gqlAccessToken);
    if (includeToken && token != null) {
      headers["Authorization"] = _oauthAuthorizationHeader(token);
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
    Map<String, Object?>? connection,
  ) => TwitchPage<TwitchCategory>(
    data: [
      for (final edge in _edgeList(connection))
        if (_mapValue(edge["node"]) case final node?)
          TwitchCategory(
            id: _stringValue(node["id"]),
            name: _stringValue(node["displayName"]),
            boxArtUrl: node["boxArtURL"] as String?,
          ),
    ],
    cursor: _connectionCursor(connection),
  );

  static TwitchPage<TwitchFollowedStream> _streamPageFromConnection(
    Map<String, Object?>? connection,
  ) => TwitchPage<TwitchFollowedStream>(
    data: [
      for (final edge in _edgeList(connection))
        if (_mapValue(edge["node"]) case final node?) _streamFromGraphQlStream(node),
    ],
    cursor: _connectionCursor(connection),
  );

  static List<Map<String, Object?>> _edgeList(
    Map<String, Object?>? connection,
  ) => _mapList(connection?["edges"]);

  static String? _connectionCursor(Map<String, Object?>? connection) {
    final pageInfo = _mapValue(connection?["pageInfo"]);
    if (pageInfo?["hasNextPage"] != true) {
      return null;
    }

    final edges = _edgeList(connection);
    if (edges.isEmpty) {
      return null;
    }
    return _nonEmptyValue(edges.last["cursor"]?.toString());
  }

  static TwitchUser _userFromGraphQlUser(Map<String, Object?> user) => TwitchUser(
    id: _stringValue(user["id"]),
    login: _stringValue(user["login"]),
    displayName: _stringValue(user["displayName"]),
    profileImageUrl: user["profileImageURL"] as String?,
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
      title: _stringValue(broadcastSettings?["title"]),
      viewerCount: _intValue(stream["viewersCount"]),
      thumbnailUrl: stream["previewImageURL"] as String?,
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
    final uniqueValues = values.where((value) => value.isNotEmpty).toSet();
    final items = uniqueValues.toList();
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
