import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";

typedef TwitchApiClientLoader = Future<TwitchApiClient> Function();

class TwitchApiCache {
  TwitchApiCache({
    required this.clientLoader,
    this.maxEntries = 128,
  }) : assert(maxEntries > 0);

  final TwitchApiClientLoader clientLoader;
  final int maxEntries;
  final _values = <String, Object?>{};
  final _inFlight = <String, Future<Object?>>{};
  void clear() {
    _values.clear();
    _inFlight.clear();
  }

  Future<TwitchPage<TwitchCategory>> fetchTopCategoriesPage({
    int first = 12,
    String? cursor,
    bool refresh = false,
  }) => _cached(
    _cacheKey("topCategories", {
      "first": first,
      "cursor": cursor,
    }),
    (client) => client.fetchTopCategoriesPage(first: first, cursor: cursor),
    refresh: refresh,
  );

  Future<TwitchPage<TwitchFollowedStream>> fetchLiveStreamsPage({
    int first = 20,
    List<String> gameIds = const <String>[],
    List<String> userLogins = const <String>[],
    String? cursor,
    bool refresh = false,
  }) => _cached(
    _cacheKey("liveStreams", {
      "first": first,
      "gameIds": gameIds,
      "userLogins": _normalizedValues(userLogins),
      "cursor": cursor,
    }),
    (client) => client.fetchLiveStreamsPage(
      first: first,
      gameIds: gameIds,
      userLogins: userLogins,
      cursor: cursor,
    ),
    refresh: refresh,
  );

  Future<Map<String, TwitchUser>> fetchUsersByIds(
    List<String> ids, {
    bool refresh = false,
  }) => _cached(
    _cacheKey("usersByIds", {"ids": _normalizedValues(ids)}),
    (client) => client.fetchUsersByIds(ids),
    refresh: refresh,
  );

  Future<TwitchPage<TwitchSearchChannel>> searchChannelsPage(
    String query, {
    int first = 20,
    String? cursor,
    bool liveOnly = false,
    bool refresh = false,
  }) => _cached(
    _cacheKey("searchChannels", {
      "query": query.trim().toLowerCase(),
      "first": first,
      "cursor": cursor,
      "liveOnly": liveOnly,
    }),
    (client) => client.searchChannelsPage(
      query,
      first: first,
      cursor: cursor,
      liveOnly: liveOnly,
    ),
    refresh: refresh,
  );

  Future<TwitchChannelDetails> fetchChannelDetails(
    String login, {
    int videosFirst = 30,
    String? videosCursor,
    bool refresh = false,
  }) => _cached(
    _cacheKey("channelDetails", {
      "login": login.trim().toLowerCase(),
      "videosFirst": videosFirst,
      "videosCursor": videosCursor,
    }),
    (client) => client.fetchChannelDetails(
      login,
      videosFirst: videosFirst,
      videosCursor: videosCursor,
    ),
    refresh: refresh,
  );

  Future<Uri> fetchLivePlaybackUri(String login) async {
    final client = await clientLoader();
    return client.fetchLivePlaybackUri(login);
  }

  Future<bool> fetchChannelSubscriptionStatus(String login) async {
    final client = await clientLoader();
    return client.fetchChannelSubscriptionStatus(login);
  }

  Future<TwitchPage<TwitchCategory>> searchCategoriesPage(
    String query, {
    int first = 20,
    String? cursor,
    bool refresh = false,
  }) => _cached(
    _cacheKey("searchCategories", {
      "query": query.trim().toLowerCase(),
      "first": first,
      "cursor": cursor,
    }),
    (client) => client.searchCategoriesPage(query, first: first, cursor: cursor),
    refresh: refresh,
  );

  Future<T> _cached<T>(
    String key,
    Future<T> Function(TwitchApiClient client) load, {
    required bool refresh,
  }) async {
    if (!refresh && _values.containsKey(key)) {
      final value = _values.remove(key);
      _values[key] = value;
      return value as T;
    }

    if (!refresh) {
      final pending = _inFlight[key];
      if (pending != null) {
        return (await pending) as T;
      }
    }

    final future = _loadValue(load);
    _inFlight[key] = future;

    try {
      final value = await future;
      if (identical(_inFlight[key], future)) {
        _values.remove(key);
        _values[key] = value;
        while (_values.length > maxEntries) {
          _values.remove(_values.keys.first);
        }
      }
      return value;
    } finally {
      if (identical(_inFlight[key], future)) {
        unawaited(_inFlight.remove(key));
      }
    }
  }

  Future<T> _loadValue<T>(
    Future<T> Function(TwitchApiClient client) load,
  ) async => load(await clientLoader());
}

String _cacheKey(String namespace, Map<String, Object?> values) => jsonEncode([namespace, values]);

List<String> _normalizedValues(Iterable<String> values) => {
  for (final value in values)
    if (value.trim().isNotEmpty) value.trim(),
}.toList()..sort();
