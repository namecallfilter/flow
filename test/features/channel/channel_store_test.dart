import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/channel/channel_store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("does not ask the cache for a past broadcast cursor already requested", () async {
    final apiCache = _CountingChannelCache();
    final store = ChannelStore(apiCache: apiCache, login: "jason");

    await store.load();
    await store.loadMorePastBroadcasts();
    await store.loadMorePastBroadcasts();

    expect(apiCache.nextPageLoads, 1);
    expect(
      store.channel?.pastBroadcasts.map((broadcast) => broadcast.id),
      ["vod-1", "vod-2"],
    );
  });
}

class _CountingChannelCache extends TwitchApiCache {
  _CountingChannelCache() : super(clientLoader: () => throw UnimplementedError());

  int nextPageLoads = 0;

  @override
  Future<TwitchChannelDetails> fetchChannelDetails(
    String login, {
    int videosFirst = 30,
    String? videosCursor,
    bool refresh = false,
  }) async {
    if (videosCursor == "vod-cursor-1") {
      nextPageLoads++;
      return _details(
        broadcastId: "vod-2",
        broadcastTitle: "Second Stream",
        cursor: "vod-cursor-1",
      );
    }

    return _details(cursor: "vod-cursor-1");
  }
}

TwitchChannelDetails _details({
  String broadcastId = "vod-1",
  String broadcastTitle = "2025 Japan Trip",
  String? cursor,
}) => TwitchChannelDetails(
  id: "creator-1",
  login: "jason",
  displayName: "Jason",
  description: "Hi Im Jason",
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
