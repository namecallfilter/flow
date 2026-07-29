import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("queues and coalesces live channel refreshes during a load", () async {
    final apiCache = _DelayedLiveChannelsCache();
    final store = BrowseStore(apiCache: apiCache);
    final initialLoad = store.loadLiveChannels();
    final refresh = store.loadLiveChannels(reset: true, refresh: true);
    final duplicateRefresh = store.loadLiveChannels(reset: true, refresh: true);

    expect(apiCache.pageRefreshes, [false]);

    apiCache.pageLoads.single.complete(_liveChannelsPage("stale"));
    await Future<void>.delayed(Duration.zero);

    expect(apiCache.pageRefreshes, [false, true]);
    apiCache.pageLoads[1].complete(_liveChannelsPage("fresh"));
    await Future.wait([initialLoad, refresh, duplicateRefresh]);

    expect(apiCache.pageRefreshes, [false, true]);
    expect(apiCache.userRefreshes, [false, true]);
    expect(store.liveChannels.single.id, "fresh-user");
  });
}

TwitchPage<TwitchFollowedStream> _liveChannelsPage(String id) => TwitchPage<TwitchFollowedStream>(
  data: [
    TwitchFollowedStream(
      id: "$id-stream",
      userId: "$id-user",
      userLogin: "$id-login",
      userName: "$id-name",
      gameName: "Just Chatting",
      title: "$id-title",
      viewerCount: 100,
    ),
  ],
  cursor: null,
);

class _DelayedLiveChannelsCache extends TwitchApiCache {
  _DelayedLiveChannelsCache()
    : super(
        clientLoader: () async => throw StateError("Unexpected API client load."),
      );

  final pageLoads = <Completer<TwitchPage<TwitchFollowedStream>>>[];
  final pageRefreshes = <bool>[];
  final userRefreshes = <bool>[];

  @override
  Future<TwitchPage<TwitchFollowedStream>> fetchLiveStreamsPage({
    int first = 20,
    List<String> gameIds = const <String>[],
    List<String> userLogins = const <String>[],
    String? cursor,
    bool refresh = false,
  }) {
    final load = Completer<TwitchPage<TwitchFollowedStream>>();
    pageLoads.add(load);
    pageRefreshes.add(refresh);
    return load.future;
  }

  @override
  Future<Map<String, TwitchUser>> fetchUsersByIds(
    List<String> ids, {
    bool refresh = false,
  }) {
    userRefreshes.add(refresh);
    return Future.value({
      for (final id in ids)
        id: TwitchUser(
          id: id,
          login: id,
          displayName: id,
        ),
    });
  }
}
