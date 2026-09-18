import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/channel/channel_store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("does not ask the cache for a past broadcast cursor already requested", () async {
    final apiCache = _CountingChannelCache();
    final store = ChannelStore(apiCache: apiCache, login: "jason");

    await store.load(refresh: true, liveStatusOnly: true);
    expect(apiCache.lastVideosFirst, 30);
    apiCache.gate = Completer<void>();
    final initialLoad = store.load();
    await store.load(refresh: true, liveStatusOnly: true);
    expect(apiCache.lastVideosFirst, 30);
    apiCache.gate!.complete();
    await initialLoad;
    await store.loadMorePastBroadcasts();
    await store.loadMorePastBroadcasts();
    final broadcasts = store.channel!.pastBroadcasts;
    final cursor = store.channel!.pastBroadcastsCursor;
    apiCache.title = "Updated broadcast title";
    await store.load(refresh: true, liveStatusOnly: true);

    expect(apiCache.nextPageLoads, 1);
    expect(apiCache.lastVideosFirst, 1);
    expect(store.channel!.pastBroadcasts, same(broadcasts));
    expect(store.channel!.pastBroadcastsCursor, cursor);
    expect(store.channel!.title, "Updated broadcast title");
    expect(
      store.channel?.pastBroadcasts.map((broadcast) => broadcast.id),
      ["vod-1", "vod-2"],
    );
  });

  test("periodic refresh retries a failed initial load with a full broadcast page", () async {
    final apiCache = _CountingChannelCache()..fail = true;
    final store = ChannelStore(apiCache: apiCache, login: "jason");
    await store.load();
    expect(store.channel, isNull);
    expect(store.errorMessage, isNotNull);

    apiCache.fail = false;
    await store.load(refresh: true, liveStatusOnly: true);
    expect(apiCache.lastVideosFirst, 30);
    expect(store.channel!.pastBroadcasts.single.id, "vod-1");
    expect(store.errorMessage, isNull);

    final channel = store.channel;
    apiCache.fail = true;
    await store.load(refresh: true, liveStatusOnly: true);
    expect(store.channel, same(channel));
    expect(store.errorMessage, isNull);
  });
}

class _CountingChannelCache extends TwitchApiCache {
  _CountingChannelCache() : super(clientLoader: () => throw UnimplementedError());

  int nextPageLoads = 0;
  int? lastVideosFirst;
  String title = "";
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<TwitchChannelDetails> fetchChannelDetails(
    String login, {
    int videosFirst = 30,
    String? videosCursor,
    bool refresh = false,
  }) async {
    lastVideosFirst = videosFirst;
    await gate?.future;
    if (fail) {
      throw TwitchApiException("Network unavailable");
    }
    if (videosCursor == "vod-cursor-1") {
      nextPageLoads++;
      return _details(
        broadcastId: "vod-2",
        broadcastTitle: "Second Stream",
        cursor: "vod-cursor-1",
      );
    }

    return _details(cursor: "vod-cursor-1", title: title);
  }
}

TwitchChannelDetails _details({
  String broadcastId = "vod-1",
  String broadcastTitle = "2025 Japan Trip",
  String? cursor,
  String title = "",
}) => TwitchChannelDetails(
  id: "creator-1",
  login: "jason",
  displayName: "Jason",
  description: "Hi Im Jason",
  title: title,
  followers: 2300000,
  pastBroadcasts: [
    TwitchPastBroadcast(
      id: broadcastId,
      title: broadcastTitle,
      categoryId: "509658",
      category: "Just Chatting",
      duration: const Duration(seconds: 17999),
      viewCount: 91234,
    ),
  ],
  pastBroadcastsCursor: cursor,
);
