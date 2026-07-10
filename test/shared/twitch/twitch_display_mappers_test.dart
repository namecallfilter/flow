import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("offlineChannelsFromConnection", () {
    test("sorts offline channels by most recent follow first", () {
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
            const TwitchFollowedChannel(
              broadcasterId: "unknown",
              broadcasterLogin: "unknown",
              broadcasterName: "Unknown",
            ),
          ],
        ),
      );

      expect(
        channels.map((channel) => channel.name),
        ["Newest", "Oldest", "Unknown"],
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

  test("preserves numeric viewers and start time for player metadata", () {
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

    expect(channel.viewerCount, 1234);
    expect(channel.startedAt, startedAt);
  });
}
