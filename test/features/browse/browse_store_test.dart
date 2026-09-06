import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flow/features/browse/category_streams_store.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("periodic refresh keeps recommendation cursors until an explicit refresh", () async {
    final streamsCache = _DelayedLiveChannelsCache();
    final streams = BrowseStore(apiCache: streamsCache)..streamSort = StreamSort.recommendedForYou;
    final initialStreams = streams.loadLiveChannels(reset: true);
    streamsCache.requests.single.response.complete(
      const TwitchPage(data: [_firstStream], cursor: "personal-streams-next"),
    );
    await initialStreams;
    await streams.refreshLiveChannelsFirstPage();
    expect(streamsCache.requests, hasLength(1));
    expect(streams.liveChannelsCursor, "personal-streams-next");
    final refreshStreams = streams.loadLiveChannels(reset: true, refresh: true);
    expect(streamsCache.requests.last.cursor, isNull);
    streamsCache.requests.last.response.complete(
      const TwitchPage(data: [_secondStream], cursor: "fresh-streams-next"),
    );
    await refreshStreams;
    expect(streams.liveChannels.single.id, "creator-2");
    expect(streams.liveChannelsCursor, "fresh-streams-next");

    final categoriesCache = _DelayedCategoriesCache();
    final categories = BrowseStore(apiCache: categoriesCache)
      ..categorySort = CategorySort.recommendedForYou;
    final initialCategories = categories.loadCategories(reset: true);
    categoriesCache.requests.single.response.complete(
      const TwitchPage(data: [_firstCategory], cursor: "personal-categories-next"),
    );
    await initialCategories;
    await categories.refreshCategoriesFirstPage();
    expect(categoriesCache.requests, hasLength(1));
    expect(categories.categoriesCursor, "personal-categories-next");
    final refreshCategories = categories.loadCategories(reset: true, refresh: true);
    expect(categoriesCache.requests.last.cursor, isNull);
    categoriesCache.requests.last.response.complete(
      const TwitchPage(data: [_thirdCategory], cursor: "fresh-categories-next"),
    );
    await refreshCategories;
    expect(categories.categories.single.id, "3");
    expect(categories.categoriesCursor, "fresh-categories-next");
  });

  test("changing category mode discards the previous mode's in-flight page", () async {
    final cache = _DelayedCategoriesCache();
    final store = BrowseStore(apiCache: cache);
    final oldLoad = store.loadCategories(reset: true);
    final recommendedLoad = store.selectCategorySort(CategorySort.recommendedForYou);
    expect(cache.requests.last.cursor, isNull);
    cache.requests.last.response.complete(
      const TwitchPage(data: [_thirdCategory], cursor: "recommended-page-2"),
    );
    await recommendedLoad;
    cache.requests.first.response.complete(
      const TwitchPage(data: [_firstCategory], cursor: "viewers-page-2"),
    );
    await oldLoad;
    expect(store.categories.single.id, "3");
    expect(store.categoriesCursor, "recommended-page-2");
    expect(store.categorySort, CategorySort.recommendedForYou);
  });

  for (final sort in StreamSort.values) {
    final expectedIds = switch (sort) {
      StreamSort.viewersHighToLow => ["creator-1", "creator-2", "creator-3"],
      StreamSort.viewersLowToHigh => ["creator-3", "creator-2", "creator-1"],
      StreamSort.recommendedForYou => ["creator-3", "creator-1", "creator-2"],
      StreamSort.recentlyStarted => ["creator-1", "creator-2", "creator-3"],
    };
    test("Browse normalizes live counts across pages for ${sort.name}", () async {
      final cache = _DelayedLiveChannelsCache();
      final store = BrowseStore(apiCache: cache)..streamSort = sort;
      final initial = store.loadLiveChannels(reset: true);
      cache.requests.single.response.complete(
        const TwitchPage(data: [_thirdStream, _firstStream], cursor: "server-page-2"),
      );
      await initial;
      final pagination = store.loadLiveChannels();
      expect(cache.requests.last.cursor, "server-page-2");
      expect(cache.requests.last.sort, sort);
      cache.requests.last.response.complete(
        const TwitchPage(data: [_secondStream], cursor: null),
      );
      await pagination;
      expect(store.liveChannels.map((channel) => channel.id), expectedIds);
    });

    test("category normalizes live counts across pages for ${sort.name}", () async {
      final cache = _DelayedLiveChannelsCache();
      final store = CategoryStreamsStore(
        apiCache: cache,
        category: browseCategoryFromApi(_firstCategory),
      )..streamSort = sort;
      final initial = store.loadStreams(reset: true);
      cache.requests.single.response.complete(
        const TwitchPage(data: [_thirdStream, _firstStream], cursor: "server-page-2"),
      );
      await initial;
      final pagination = store.loadStreams();
      expect(cache.requests.last.cursor, "server-page-2");
      expect(cache.requests.last.sort, sort);
      cache.requests.last.response.complete(
        const TwitchPage(data: [_secondStream], cursor: null),
      );
      await pagination;
      expect(store.channels.map((channel) => channel.id), expectedIds);
    });
  }

  test("periodic live refresh preserves paginated channels moved by viewer sorting", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = BrowseStore(apiCache: cache);
    final initial = store.loadLiveChannels(reset: true);
    cache.requests.single.response.complete(
      const TwitchPage(data: [_thirdStream, _secondStream], cursor: "page-2"),
    );
    await initial;
    final pagination = store.loadLiveChannels();
    cache.requests.last.response.complete(
      const TwitchPage(data: [_firstStream], cursor: null),
    );
    await pagination;
    final refresh = store.refreshLiveChannelsFirstPage();
    cache.requests.last.response.complete(
      const TwitchPage(data: [_thirdStream], cursor: "fresh-page-2"),
    );
    await refresh;
    expect(store.liveChannels.map((channel) => channel.id), ["creator-1", "creator-3"]);
    expect(store.liveChannelsCursor, isNull);
  });

  test("changing browse order ignores old pages and starts with a fresh cursor", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = BrowseStore(apiCache: cache);
    final oldLoad = store.loadLiveChannels(reset: true);
    final newLoad = store.selectStreamSort(StreamSort.viewersLowToHigh);
    expect(cache.requests.last.sort, StreamSort.viewersLowToHigh);
    expect(cache.requests.last.cursor, isNull);
    cache.requests.last.response.complete(
      const TwitchPage(data: [_thirdStream], cursor: "ascending-page-2"),
    );
    await newLoad;
    cache.requests.first.response.complete(
      const TwitchPage(data: [_firstStream], cursor: "descending-page-2"),
    );
    await oldLoad;
    expect(store.liveChannels.single.id, "creator-3");
    expect(store.liveChannelsCursor, "ascending-page-2");
    expect(store.isLoadingLiveChannels, isFalse);
  });

  test("category order changes discard the previous in-flight request", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = CategoryStreamsStore(
      apiCache: cache,
      category: browseCategoryFromApi(_firstCategory),
    );
    final oldLoad = store.loadStreams(reset: true);
    final newLoad = store.selectStreamSort(StreamSort.recommendedForYou);
    expect(cache.requests.last.sort, StreamSort.recommendedForYou);
    cache.requests.first.response.completeError(TwitchApiException("Old request failed"));
    await oldLoad;
    expect(store.isLoading, isTrue);
    expect(store.errorMessage, isNull);
    cache.requests.last.response.complete(
      const TwitchPage(data: [_thirdStream], cursor: null),
    );
    await newLoad;
    expect(store.channels.single.id, "creator-3");
  });

  test("category refresh supersedes pending pagination without losing existing content", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = CategoryStreamsStore(
      apiCache: cache,
      category: browseCategoryFromApi(_firstCategory),
    );
    final initial = store.loadStreams(reset: true);
    cache.requests.single.response.complete(
      const TwitchPage(data: [_firstStream], cursor: "old-page-2"),
    );
    await initial;
    final pagination = store.loadStreams();
    final refresh = store.loadStreams(reset: true, refresh: true);
    expect(cache.requests.last.cursor, isNull);
    expect(store.channels.single.id, "creator-1");
    cache.requests.last.response.complete(
      const TwitchPage(data: [_thirdStream], cursor: "fresh-page-2"),
    );
    await refresh;
    cache.requests[1].response.complete(
      const TwitchPage(data: [_secondStream], cursor: null),
    );
    await pagination;
    expect(store.channels.single.id, "creator-3");
    expect(store.cursor, "fresh-page-2");
  });

  test("live prefetch restores the saved order before its first request", () async {
    final preferences = MemoryFlowPreferences();
    await preferences.saveStreamSort("browse", StreamSort.recommendedForYou);
    final cache = _DelayedLiveChannelsCache();
    final store = BrowseStore(apiCache: cache, preferences: preferences);
    final prefetch = store.loadLiveChannels(reset: true);
    final duplicate = store.loadLiveChannels(reset: true);
    await Future<void>.delayed(Duration.zero);
    expect(cache.requests.single.sort, StreamSort.recommendedForYou);
    cache.requests.single.response.complete(const TwitchPage(data: [], cursor: null));
    await Future.wait([prefetch, duplicate]);
    expect(store.liveChannelsLoaded, isTrue);
  });

  test("failed category refresh preserves results and the next page", () async {
    final cache = _DelayedCategoriesCache();
    final store = BrowseStore(apiCache: cache);
    final initialLoad = store.loadCategories(reset: true);
    cache.requests.single.response.complete(
      const TwitchPage(data: [_firstCategory], cursor: "page-2"),
    );
    await initialLoad;

    final refresh = store.loadCategories(reset: true, refresh: true);
    cache.requests[1].response.completeError(TwitchApiException("Offline"));
    await refresh;
    expect(store.categories.single.id, "1");
    expect(store.categoriesCursor, "page-2");

    final nextPage = store.loadCategories();
    expect(cache.requests.last.cursor, "page-2");
    cache.requests.last.response.complete(
      const TwitchPage(data: [_secondCategory], cursor: null),
    );
    await nextPage;
    expect(store.categories.map((category) => category.id), ["1", "2"]);
  });

  test("failed live refresh preserves its pagination cursor", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = BrowseStore(apiCache: cache);
    final initialLoad = store.loadLiveChannels(reset: true);
    cache.requests.single.response.complete(
      const TwitchPage(data: [_firstStream], cursor: "page-2"),
    );
    await initialLoad;

    final refresh = store.loadLiveChannels(reset: true, refresh: true);
    cache.requests[1].response.completeError(TwitchApiException("Offline"));
    await refresh;

    expect(store.liveChannels.single.id, "creator-1");
    expect(store.liveChannelsCursor, "page-2");
  });

  test("category streams retain pagination after failed refresh and merge overlaps", () async {
    final cache = _DelayedLiveChannelsCache();
    final store = CategoryStreamsStore(
      apiCache: cache,
      category: browseCategoryFromApi(_firstCategory),
    );
    final initialLoad = store.loadStreams(reset: true);
    cache.requests.single.response.complete(
      const TwitchPage(data: [_firstStream, _secondStream], cursor: "page-2"),
    );
    await initialLoad;

    final refresh = store.loadStreams(reset: true, refresh: true);
    cache.requests[1].response.completeError(TwitchApiException("Offline"));
    await refresh;
    expect(store.cursor, "page-2");

    final nextPage = store.loadStreams();
    expect(cache.requests.last.cursor, "page-2");
    cache.requests.last.response.complete(
      const TwitchPage(data: [_updatedSecondStream, _thirdStream], cursor: null),
    );
    await nextPage;

    expect(store.channels.map((channel) => channel.id), ["creator-1", "creator-2", "creator-3"]);
    expect(store.channels[1].title, "Updated second stream");
  });

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
      ["creator-1", "creator-3"],
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
    CategorySort sort = CategorySort.viewersHighToLow,
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
    StreamSort sort = StreamSort.viewersHighToLow,
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
    CategorySort sort = CategorySort.viewersHighToLow,
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
          StreamSort sort,
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
    StreamSort sort = StreamSort.viewersHighToLow,
  }) {
    final response = Completer<TwitchPage<TwitchFollowedStream>>();
    requests.add((cursor: cursor, refresh: refresh, response: response, sort: sort));
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
