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
}

class _PaginatedCategoriesCache extends TwitchApiCache {
  _PaginatedCategoriesCache() : super(clientLoader: () => throw UnimplementedError());

  int refreshRequests = 0;

  @override
  Future<TwitchPage<TwitchCategory>> fetchTopCategoriesPage({
    int first = 20,
    String? cursor,
    bool refresh = false,
  }) async {
    if (refresh) {
      refreshRequests++;
      return const TwitchPage(
        data: [
          TwitchCategory(id: "2", name: "Updated second", boxArtUrl: null, viewerCount: 250),
          TwitchCategory(id: "4", name: "Fourth", boxArtUrl: null, viewerCount: 150),
        ],
        cursor: "fresh-page-2",
      );
    }
    if (cursor == "page-2") {
      return const TwitchPage(
        data: [
          TwitchCategory(id: "2", name: "Second page update", boxArtUrl: null, viewerCount: 225),
          TwitchCategory(id: "3", name: "Third", boxArtUrl: null, viewerCount: 100),
        ],
        cursor: null,
      );
    }
    return const TwitchPage(
      data: [
        TwitchCategory(id: "1", name: "First", boxArtUrl: null, viewerCount: 300),
        TwitchCategory(id: "2", name: "Second", boxArtUrl: null, viewerCount: 200),
      ],
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
        data: [
          _updatedSecondStream,
          _thirdStream,
        ],
        cursor: null,
      );
    }

    return const TwitchPage(
      data: [
        _firstStream,
        _secondStream,
      ],
      cursor: "page-2",
    );
  }

  @override
  Future<Map<String, TwitchUser>> fetchUsersByIds(
    List<String> ids, {
    bool refresh = false,
  }) async => {
    for (final id in ids)
      id: TwitchUser(
        id: id,
        login: "login-$id",
        displayName: "Creator $id",
      ),
  };
}

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
