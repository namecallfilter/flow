import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("initials preserve emoji and combined Unicode characters", () {
    expect(initialsForName("👩🏽‍💻 creator"), "👩🏽‍💻C");
    expect(initialsForName("e\u0301clair"), "E\u0301");
    expect(initialsForName("  "), "CH");
  });

  group("offlineChannelsFromConnection", () {
    test("labels the last broadcast instead of the follow date and retains category identity", () {
      final now = DateTime.now();
      final channels = offlineChannelsFromConnection(
        TwitchAuthConnection(
          user: const TwitchUser(id: "viewer", login: "viewer", displayName: "Viewer"),
          followedStreams: const [],
          followedChannels: [
            for (final id in ["today", "older", "unknown", "missing-name"])
              TwitchFollowedChannel(
                broadcasterId: id,
                broadcasterLogin: id,
                broadcasterName: id,
                followedAt: DateTime(2020),
              ),
          ],
          channelInfoByBroadcasterId: {
            "missing-name": const TwitchChannelInfo(
              broadcasterId: "missing-name",
              broadcasterName: "missing-name",
              gameName: "",
              gameId: "509658",
              title: "Back later",
            ),
            for (final id in ["today", "older"])
              id: TwitchChannelInfo(
                broadcasterId: id,
                broadcasterName: id,
                gameName: "Just Chatting",
                gameId: "509658",
                title: "Back later",
                lastBroadcastStartedAt: id == "today" ? now : now.subtract(const Duration(days: 3)),
              ),
          },
        ),
      );
      final byId = {for (final channel in channels) channel.id: channel};

      expect(byId["today"]?.lastLive, "Last live today");
      expect(byId["older"]?.lastLive, "Last live 3 days ago");
      expect(byId["unknown"]?.lastLive, "Offline");
      expect(byId["today"]?.categoryId, "509658");
      expect(byId["today"]?.category, "Just Chatting");
      expect(byId["unknown"]?.categoryId, isEmpty);
      expect(byId["missing-name"]?.category, "Back later");
      expect(byId["missing-name"]?.categoryId, isEmpty);
    });

    test("sorts offline channels by most recent broadcast with unknown times last", () {
      final channels = offlineChannelsFromConnection(
        TwitchAuthConnection(
          user: const TwitchUser(
            id: "viewer",
            login: "viewer",
            displayName: "Viewer",
          ),
          followedStreams: const [
            TwitchFollowedStream(
              id: "stream-1",
              userId: "live",
              userLogin: "live",
              userName: "Live",
              gameName: "Just Chatting",
              title: "Live",
              viewerCount: 1,
            ),
          ],
          followedChannels: [
            TwitchFollowedChannel(
              broadcasterId: "oldest",
              broadcasterLogin: "oldest",
              broadcasterName: "Oldest",
              followedAt: DateTime(2023),
            ),
            TwitchFollowedChannel(
              broadcasterId: "live",
              broadcasterLogin: "live",
              broadcasterName: "Live",
              followedAt: DateTime(2026),
            ),
            TwitchFollowedChannel(
              broadcasterId: "newest",
              broadcasterLogin: "newest",
              broadcasterName: "Newest",
              followedAt: DateTime(2025),
            ),
            TwitchFollowedChannel(
              broadcasterId: "unknown",
              broadcasterLogin: "unknown",
              broadcasterName: "Unknown",
              followedAt: DateTime(2026),
            ),
          ],
          channelInfoByBroadcasterId: {
            "oldest": TwitchChannelInfo(
              broadcasterId: "oldest",
              broadcasterName: "Oldest",
              gameName: "Just Chatting",
              title: "Back later",
              lastBroadcastStartedAt: DateTime(2026, 9, 6),
            ),
            "newest": TwitchChannelInfo(
              broadcasterId: "newest",
              broadcasterName: "Newest",
              gameName: "Just Chatting",
              title: "Back later",
              lastBroadcastStartedAt: DateTime(2026, 9, 4),
            ),
          },
        ),
      );

      expect(
        channels.map((channel) => channel.name),
        ["Oldest", "Newest", "Unknown"],
      );
    });
  });

  group("relativeTime", () {
    test("formats elapsed years instead of long month counts", () {
      expect(
        relativeTime(DateTime.now().subtract(const Duration(days: 365 * 3 + 30))),
        "3 years ago",
      );
      expect(
        relativeTime(DateTime.now().subtract(const Duration(days: 365))),
        "1 year ago",
      );
    });
  });

  test("preserves stream start time for player metadata", () {
    final startedAt = DateTime(2026, 7, 9, 20, 30);

    final channel = streamChannelFromStream(
      TwitchFollowedStream(
        id: "stream-1",
        userId: "creator-1",
        userLogin: "creator",
        userName: "Creator",
        gameName: "Just Chatting",
        title: "Live now",
        viewerCount: 1234,
        startedAt: startedAt,
      ),
    );

    expect(channel.startedAt, startedAt);
  });

  test("requests appropriately sized category artwork", () {
    expect(
      twitchBoxArtUrl("https://example.com/box-{width}x{height}.jpg"),
      "https://example.com/box-300x400.jpg",
    );
    expect(
      twitchBoxArtUrl("https://example.com/box-52x72.jpg"),
      "https://example.com/box-300x400.jpg",
    );
  });

  test("maps category viewer counts without fetching streams", () {
    final category = browseCategoryFromApi(
      const TwitchCategory(
        id: "27471",
        name: "Minecraft",
        boxArtUrl: "https://example.com/box-{width}x{height}.jpg",
        viewerCount: 4200,
      ),
    );

    expect(category.viewerCount, 4200);
    expect(category.viewers, "4.2K");
  });
}
