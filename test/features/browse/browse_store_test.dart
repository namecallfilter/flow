import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("merges overlapping live-channel pages by broadcaster", () async {
    final store = BrowseStore(apiCache: _OverlappingLiveChannelsCache());

    await store.loadLiveChannels(reset: true);
    await store.loadLiveChannels();

    expect(
      store.liveChannels.map((channel) => channel.id),
      ["creator-1", "creator-2", "creator-3"],
    );
    expect(store.liveChannels[1].title, "Updated second stream");
  });

  test("first-page category refresh preserves the paginated tail and cursor", () async {
    final cache = _PaginatedCategoriesCache();
    final store = BrowseStore(apiCache: cache);

    await store.loadCategories(reset: true);
    await store.loadCategories();
    expect(store.categories.map((category) => category.id), ["1", "2", "3"]);
    expect(store.categoriesCursor, isNull);

    await store.refreshCategoriesFirstPage();

    expect(store.categories.map((category) => category.id), ["2", "4", "3"]);
    expect(store.categories.first.name, "Updated second");
    expect(store.categoriesCursor, isNull);
    expect(cache.refreshRequests, 1);
  });

  test("first-page refresh adopts the fresh cursor when no tail was loaded", () async {
    final cache = _PaginatedCategoriesCache();
    final store = BrowseStore(apiCache: cache);

    await store.loadCategories(reset: true);
    await store.refreshCategoriesFirstPage();

    expect(store.categories.map((category) => category.id), ["2", "4"]);
    expect(store.categoriesCursor, "fresh-page-2");
  });

  test("first-page category refresh adopts the fresh cursor when it promotes the tail", () async {
    final cache = _DelayedCategoriesCache();
    final store = BrowseStore(apiCache: cache);
    final initialLoad = store.loadCategories(reset: true);

    cache.requests.single.response.complete(
      const TwitchPage(
        data: [_firstCategory, _secondCategory],
        cursor: "page-2",
      ),
    );
    await initialLoad;
    final pagination = store.loadCategories();
    cache.requests[1].response.complete(
      const TwitchPage(data: [_thirdCategory], cursor: null),
    );
    await pagination;

    final refresh = store.refreshCategoriesFirstPage();
    cache.requests[2].response.complete(
      const TwitchPage(
        data: [_thirdCategory, _fourthCategory],
        cursor: "fresh-page-2",
      ),
    );
    await refresh;

    expect(store.categories.map((category) => category.id), ["3", "4"]);
    expect(store.categoriesCursor, "fresh-page-2");
  });

  test("first-page live refresh preserves the paginated tail and cursor", () async {
    final cache = _OverlappingLiveChannelsCache();
    final store = BrowseStore(apiCache: cache);

    await store.loadLiveChannels(reset: true);
    await store.loadLiveChannels();
    await store.refreshLiveChannelsFirstPage();

    expect(
      store.liveChannels.map((channel) => channel.id),
      ["creator-1", "creator-2", "creator-3"],
    );
    expect(store.liveChannelsCursor, isNull);
    expect(cache.refreshRequests, 1);
  });

  test("first-page live refresh adopts the fresh cursor when it promotes the tail", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = BrowseStore(apiCache: cache);
    final initialLoad = store.loadLiveChannels(reset: true);

    cache.requests.single.response.complete(
      const TwitchPage(
        data: [_firstStream, _secondStream],
        cursor: "page-2",
      ),
    );
    await initialLoad;
    final pagination = store.loadLiveChannels();
    cache.requests[1].response.complete(
      const TwitchPage(data: [_thirdStream], cursor: null),
    );
    await pagination;

    final refresh = store.refreshLiveChannelsFirstPage();
    cache.requests[2].response.complete(
      const TwitchPage(
        data: [_thirdStream, _firstStream],
        cursor: "fresh-page-2",
      ),
    );
    await refresh;

    expect(
      store.liveChannels.map((channel) => channel.id),
      ["creator-3", "creator-1"],
    );
    expect(store.liveChannelsCursor, "fresh-page-2");
  });

  test("queues one category refresh during pagination and preserves its tail", () async {
    final cache = _DelayedCategoriesCache();
    final store = BrowseStore(apiCache: cache);
    final initialLoad = store.loadCategories(reset: true);

    cache.requests.single.response.complete(
      const TwitchPage(
        data: [_firstCategory, _secondCategory],
        cursor: "page-2",
      ),
    );
    await initialLoad;

    final pagination = store.loadCategories();
    final refresh = store.refreshCategoriesFirstPage();
    final duplicateRefresh = store.refreshCategoriesFirstPage();

    expect(
      cache.requests.map((request) => (request.cursor, request.refresh)),
      [(null, false), ("page-2", false)],
    );

    cache.requests[1].response.complete(
      const TwitchPage(
        data: [_updatedSecondCategory, _thirdCategory],
        cursor: null,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      cache.requests.map((request) => (request.cursor, request.refresh)),
      [(null, false), ("page-2", false), (null, true)],
    );
    cache.requests[2].response.complete(
      const TwitchPage(
        data: [_updatedSecondCategory, _fourthCategory],
        cursor: "fresh-page-2",
      ),
    );
    await Future.wait([pagination, refresh, duplicateRefresh]);

    expect(store.categories.map((category) => category.id), ["2", "4", "3"]);
    expect(store.categoriesCursor, isNull);
  });

  test("a queued full category refresh overrides tail preservation", () async {
    final cache = _DelayedCategoriesCache();
    final store = BrowseStore(apiCache: cache);
    final initialLoad = store.loadCategories(reset: true);

    cache.requests.single.response.complete(
      const TwitchPage(
        data: [_firstCategory, _secondCategory],
        cursor: "page-2",
      ),
    );
    await initialLoad;

    final pagination = store.loadCategories();
    final preservingRefresh = store.refreshCategoriesFirstPage();
    final fullRefresh = store.loadCategories(reset: true, refresh: true);

    cache.requests[1].response.complete(
      const TwitchPage(data: [_thirdCategory], cursor: null),
    );
    await Future<void>.delayed(Duration.zero);
    cache.requests[2].response.complete(
      const TwitchPage(
        data: [_updatedSecondCategory, _fourthCategory],
        cursor: "fresh-page-2",
      ),
    );
    await Future.wait([pagination, preservingRefresh, fullRefresh]);

    expect(store.categories.map((category) => category.id), ["2", "4"]);
    expect(store.categoriesCursor, "fresh-page-2");
    expect(cache.requests, hasLength(3));
  });

  test("queues one live refresh during pagination and preserves its tail", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = BrowseStore(apiCache: cache);
    final initialLoad = store.loadLiveChannels(reset: true);

    cache.requests.single.response.complete(
      const TwitchPage(
        data: [_firstStream, _secondStream],
        cursor: "page-2",
      ),
    );
    await initialLoad;

    final pagination = store.loadLiveChannels();
    final refresh = store.refreshLiveChannelsFirstPage();
    final duplicateRefresh = store.refreshLiveChannelsFirstPage();

    expect(
      cache.requests.map((request) => (request.cursor, request.refresh)),
      [(null, false), ("page-2", false)],
    );

    cache.requests[1].response.complete(
      const TwitchPage(
        data: [_updatedSecondStream, _thirdStream],
        cursor: null,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      cache.requests.map((request) => (request.cursor, request.refresh)),
      [(null, false), ("page-2", false), (null, true)],
    );
    cache.requests[2].response.complete(
      const TwitchPage(
        data: [_firstStream, _updatedSecondStream],
        cursor: "fresh-page-2",
      ),
    );
    await Future.wait([pagination, refresh, duplicateRefresh]);

    expect(
      store.liveChannels.map((channel) => channel.id),
      ["creator-1", "creator-2", "creator-3"],
    );
    expect(store.liveChannelsCursor, isNull);
    expect(cache.userRefreshes, [false, false, true]);
  });
}

class _PaginatedCategoriesCache extends TwitchApiCache {
  _PaginatedCategoriesCache() : super(clientLoader: () => throw UnimplementedError());

  int refreshRequests = 0;

  @override
  Future<TwitchPage<TwitchCategory>> fetchTopCategoriesPage({
    int first = 12,
    String? cursor,
    bool refresh = false,
  }) async {
    if (refresh) {
      refreshRequests++;
      return const TwitchPage(
        data: [_updatedSecondCategory, _fourthCategory],
        cursor: "fresh-page-2",
      );
    }
    if (cursor == "page-2") {
      return const TwitchPage(
        data: [_updatedSecondCategory, _thirdCategory],
        cursor: null,
      );
    }
    return const TwitchPage(
      data: [_firstCategory, _secondCategory],
      cursor: "page-2",
    );
  }
}

class _OverlappingLiveChannelsCache extends TwitchApiCache {
  _OverlappingLiveChannelsCache() : super(clientLoader: () => throw UnimplementedError());

  int refreshRequests = 0;

  @override
  Future<TwitchPage<TwitchFollowedStream>> fetchLiveStreamsPage({
    int first = 20,
    List<String> gameIds = const <String>[],
    List<String> userLogins = const <String>[],
    String? cursor,
    bool refresh = false,
  }) async {
    if (refresh) {
      refreshRequests++;
    }
    if (cursor == "page-2") {
      return const TwitchPage(
        data: [_updatedSecondStream, _thirdStream],
        cursor: null,
      );
    }

    return const TwitchPage(
      data: [_firstStream, _secondStream],
      cursor: "page-2",
    );
  }

  @override
  Future<Map<String, TwitchUser>> fetchUsersByIds(
    List<String> ids, {
    bool refresh = false,
  }) async => _usersById(ids);
}

class _DelayedCategoriesCache extends TwitchApiCache {
  _DelayedCategoriesCache()
    : super(
        clientLoader: () async => throw StateError("Unexpected API client load."),
      );

  final requests =
      <
        ({
          String? cursor,
          bool refresh,
          Completer<TwitchPage<TwitchCategory>> response,
        })
      >[];

  @override
  Future<TwitchPage<TwitchCategory>> fetchTopCategoriesPage({
    int first = 12,
    String? cursor,
    bool refresh = false,
  }) {
    final response = Completer<TwitchPage<TwitchCategory>>();
    requests.add((cursor: cursor, refresh: refresh, response: response));
    return response.future;
  }
}

class _DelayedLiveChannelsCache extends TwitchApiCache {
  _DelayedLiveChannelsCache()
    : super(
        clientLoader: () async => throw StateError("Unexpected API client load."),
      );

  final requests =
      <
        ({
          String? cursor,
          bool refresh,
          Completer<TwitchPage<TwitchFollowedStream>> response,
        })
      >[];
  final userRefreshes = <bool>[];

  @override
  Future<TwitchPage<TwitchFollowedStream>> fetchLiveStreamsPage({
    int first = 20,
    List<String> gameIds = const <String>[],
    List<String> userLogins = const <String>[],
    String? cursor,
    bool refresh = false,
  }) {
    final response = Completer<TwitchPage<TwitchFollowedStream>>();
    requests.add((cursor: cursor, refresh: refresh, response: response));
    return response.future;
  }

  @override
  Future<Map<String, TwitchUser>> fetchUsersByIds(
    List<String> ids, {
    bool refresh = false,
  }) async {
    userRefreshes.add(refresh);
    return _usersById(ids);
  }
}

Map<String, TwitchUser> _usersById(List<String> ids) => {
  for (final id in ids)
    id: TwitchUser(
      id: id,
      login: "login-$id",
      displayName: "Creator $id",
    ),
};

const _firstCategory = TwitchCategory(
  id: "1",
  name: "First",
  boxArtUrl: null,
  viewerCount: 300,
);
const _secondCategory = TwitchCategory(
  id: "2",
  name: "Second",
  boxArtUrl: null,
  viewerCount: 200,
);
const _updatedSecondCategory = TwitchCategory(
  id: "2",
  name: "Updated second",
  boxArtUrl: null,
  viewerCount: 250,
);
const _thirdCategory = TwitchCategory(
  id: "3",
  name: "Third",
  boxArtUrl: null,
  viewerCount: 100,
);
const _fourthCategory = TwitchCategory(
  id: "4",
  name: "Fourth",
  boxArtUrl: null,
  viewerCount: 150,
);

const _firstStream = TwitchFollowedStream(
  id: "stream-1",
  userId: "creator-1",
  userLogin: "first",
  userName: "First",
  gameName: "Just Chatting",
  title: "First stream",
  viewerCount: 300,
);
const _secondStream = TwitchFollowedStream(
  id: "stream-2",
  userId: "creator-2",
  userLogin: "second",
  userName: "Second",
  gameName: "Just Chatting",
  title: "Second stream",
  viewerCount: 200,
);
const _updatedSecondStream = TwitchFollowedStream(
  id: "stream-2",
  userId: "creator-2",
  userLogin: "second",
  userName: "Second",
  gameName: "Just Chatting",
  title: "Updated second stream",
  viewerCount: 210,
);
const _thirdStream = TwitchFollowedStream(
  id: "stream-3",
  userId: "creator-3",
  userLogin: "third",
  userName: "Third",
  gameName: "Just Chatting",
  title: "Third stream",
  viewerCount: 100,
);
