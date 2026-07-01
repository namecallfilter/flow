import "package:flow/api/twitch_api.dart";

typedef TwitchApiClientLoader = Future<TwitchApiClient> Function();

class TwitchApiCache {
  TwitchApiCache({required this.clientLoader});

  final TwitchApiClientLoader clientLoader;
  final _values = <String, Object?>{};
  final _inFlight = <String, Object>{};
  int _revision = 0;

  void clear() {
    _revision++;
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
      "gameIds": _normalizedValues(gameIds),
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
      return _values[key]! as T;
    }

    if (!refresh) {
      final pending = _inFlight[key];
      if (pending is Future<Object?>) {
        return (await pending) as T;
      }
    }

    final revision = _revision;
    final future = _loadValue(load);
    _inFlight[key] = future;

    try {
      final value = await future;
      if (revision == _revision) {
        _values[key] = value;
      }
      return value as T;
    } finally {
      if (revision == _revision && identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  Future<Object?> _loadValue<T>(
    Future<T> Function(TwitchApiClient client) load,
  ) async {
    final client = await clientLoader();
    final value = await load(client);
    return value;
  }
}

String _cacheKey(String namespace, Map<String, Object?> values) {
  final entries = values.entries.toList()..sort((left, right) => left.key.compareTo(right.key));
  final parts = [
    namespace,
    for (final entry in entries) "${entry.key}=${_cacheValue(entry.value)}",
  ];
  return parts.join("|");
}

String _cacheValue(Object? value) {
  if (value == null) {
    return "";
  }
  if (value is Iterable<String>) {
    return _normalizedValues(value).join(",");
  }
  return value.toString();
}

List<String> _normalizedValues(Iterable<String> values) => [
  for (final value in values)
    if (value.trim().isNotEmpty) value.trim(),
]..sort();
