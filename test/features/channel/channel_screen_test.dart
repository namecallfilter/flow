import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/channel/channel_screen.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flow/shared/widgets/skeleton.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  testWidgets("renders channel identity and past broadcasts", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient((_) async => _channelDetailsResponse()),
            ),
          ),
          initialChannel: const ChannelPreview(
            login: "jason",
            displayName: "Jason",
            avatarImageUrl: "https://static-cdn.jtvnw.net/creator-1.png",
            isLive: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("channel_page_jason")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_back_button")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_title_Jason")), findsNothing);
    _expectVisibleHeaderGap(
      tester,
      header: find.ancestor(
        of: find.byKey(const ValueKey("channel_back_button")),
        matching: find.byType(ClipRect),
      ),
      content: find.byKey(const ValueKey("channel_header_card")),
    );
    expect(find.byType(AvatarRing), findsNothing);
    expect(find.byKey(const ValueKey("channel_live_badge")), findsOneWidget);
    expect(find.text("LIVE"), findsOneWidget);
    final avatarRect = tester.getRect(find.byKey(const ValueKey("channel_profile_avatar")));
    final liveBadgeRect = tester.getRect(find.byKey(const ValueKey("channel_live_badge")));
    expect(liveBadgeRect.center.dx, closeTo(avatarRect.center.dx, 1));
    expect(liveBadgeRect.top, greaterThan(avatarRect.center.dy));
    expect(find.text("Just Chatting with 26.3K viewers"), findsOneWidget);
    expect(find.text("2.3M followers"), findsOneWidget);
    expect(find.text("Hi Im Jason"), findsOneWidget);
    expect(find.text("Past broadcasts"), findsOneWidget);
    expect(find.byKey(const ValueKey("past_broadcast_vod-1")), findsOneWidget);
    expect(find.byKey(const ValueKey("past_broadcast_thumbnail_vod-1")), findsOneWidget);
    expect(find.byKey(const ValueKey("past_broadcast_age_vod-1")), findsNothing);
    expect(find.text("2025 Japan Trip"), findsOneWidget);
    expect(find.text("4:59:59"), findsOneWidget);
    expect(find.text("91.2K views"), findsOneWidget);
    expect(find.text("2 days ago | Just Chatting"), findsOneWidget);
    final thumbnailRect = tester.getRect(
      find.byKey(const ValueKey("past_broadcast_thumbnail_vod-1")),
    );
    final durationBadgeFinder = find.byKey(const ValueKey("past_broadcast_duration_vod-1"));
    expect(durationBadgeFinder, findsOneWidget);
    final durationBadgeRect = tester.getRect(durationBadgeFinder);
    expect(durationBadgeRect.left, closeTo(thumbnailRect.left + 6, 1));
    expect(durationBadgeRect.bottom, closeTo(thumbnailRect.bottom - 5, 1));
  });

  testWidgets("wraps long live metadata without ellipsizing", (tester) async {
    const longCategory = "Really Long Category Name That Needs More Than One Line To Render Fully";

    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient(
                (_) async => _channelDetailsResponse(category: longCategory),
              ),
            ),
          ),
          initialChannel: const ChannelPreview(
            login: "jason",
            displayName: "Jason",
            isLive: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final metadata = tester.widget<Text>(find.byKey(const ValueKey("channel_live_metadata")));

    expect(metadata.data, "$longCategory with 26.3K viewers");
    expect(metadata.maxLines, isNull);
    expect(metadata.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets("opens the live player when the channel avatar is tapped", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient((_) async => _channelDetailsResponse()),
            ),
          ),
          initialChannel: const ChannelPreview(
            login: "jason",
            displayName: "Jason",
            isLive: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("channel_profile_avatar")));
    await tester.pumpAndSettle();

    final player = tester.widget<StreamPlayerScreen>(
      find.byType(StreamPlayerScreen),
    );
    expect(player.channel.id, "creator-1");
    expect(player.channel.login, "jason");
    expect(player.channel.name, "Jason");
    expect(player.channel.title, "Live with chat");
    expect(player.channel.category, "Just Chatting");
    expect(player.channel.viewers, "26.3K");
    expect(
      player.channel.startedAt?.toUtc(),
      DateTime.parse("2026-07-04T01:00:00Z"),
    );
  });

  testWidgets("shows a skeleton until channel details load", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final response = Completer<http.Response>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient((_) => response.future),
            ),
          ),
          initialChannel: const ChannelPreview(
            login: "jason",
            displayName: "Jason",
            isLive: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final broadcastSkeletons = find.byWidgetPredicate(
      (widget) => widget is SkeletonBox && widget.width == 132 && widget.height == 74.25,
    );
    expect(find.byKey(const ValueKey("channel_skeleton")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_header_skeleton")), findsOneWidget);
    expect(broadcastSkeletons, findsNWidgets(11));
    expect(
      tester.getBottomLeft(broadcastSkeletons.at(10)).dy,
      greaterThanOrEqualTo(1200),
    );
    expect(find.byKey(const ValueKey("channel_header_card")), findsNothing);
    expect(find.byKey(const ValueKey("channel_profile_avatar")), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(StreamPlayerScreen), findsNothing);

    response.complete(_channelDetailsResponse(isLive: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("channel_skeleton")), findsNothing);
    expect(find.byKey(const ValueKey("channel_header_card")), findsOneWidget);
  });

  testWidgets("does not open the player from an offline channel avatar", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient(
                (_) async => _channelDetailsResponse(isLive: false),
              ),
            ),
          ),
          initialChannel: const ChannelPreview(
            login: "jason",
            displayName: "Jason",
            isLive: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("channel_live_badge")), findsNothing);
    await tester.tap(find.byKey(const ValueKey("channel_profile_avatar")));
    await tester.pumpAndSettle();

    expect(find.byType(StreamPlayerScreen), findsNothing);
  });

  testWidgets("loads more past broadcasts when scrolling near the bottom", (tester) async {
    final requestedRequests = <http.Request>[];
    await tester.binding.setSurfaceSize(const Size(390, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient((request) async {
                requestedRequests.add(request);
                final body = jsonDecode(request.body) as Map<String, Object?>;
                final variables =
                    (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
                return variables["videosAfter"] == "vod-cursor-1"
                    ? _channelDetailsResponse(
                        videoId: "vod-2",
                        videoTitle: "Second Stream",
                      )
                    : _channelDetailsResponse(nextCursor: "vod-cursor-1");
              }),
            ),
          ),
          initialChannel: const ChannelPreview(
            login: "jason",
            displayName: "Jason",
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("past_broadcast_vod-1")), findsOneWidget);
    expect(find.byKey(const ValueKey("past_broadcast_vod-2")), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(
      requestedRequests.any((request) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final variables = (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
        return variables["videosAfter"] == "vod-cursor-1";
      }),
      isTrue,
    );
    expect(find.byKey(const ValueKey("past_broadcast_vod-2")), findsOneWidget);
    expect(find.text("Second Stream"), findsOneWidget);
  });
}

void _expectVisibleHeaderGap(
  WidgetTester tester, {
  required Finder header,
  required Finder content,
}) {
  final headerBottom = tester.getBottomLeft(header).dy;
  final contentTop = tester.getTopLeft(content).dy;

  expect(contentTop - headerBottom, closeTo(PageHeaderLayout.headerContentGap, 0.1));
}

http.Response _channelDetailsResponse({
  String videoId = "vod-1",
  String videoTitle = "2025 Japan Trip",
  String category = "Just Chatting",
  String? nextCursor,
  bool isLive = true,
}) => http.Response(
  jsonEncode({
    "data": {
      "user": {
        "id": "creator-1",
        "login": "jason",
        "displayName": "Jason",
        "description": "Hi Im Jason",
        "profileImageURL": "https://static-cdn.jtvnw.net/creator-1.png",
        "followers": {"totalCount": 2300000},
        "stream": isLive
            ? {
                "id": "live-1",
                "createdAt": "2026-07-04T01:00:00Z",
                "game": {"id": "509658", "displayName": category},
                "previewImageURL":
                    "https://static-cdn.jtvnw.net/previews-ttv/live_user_jason-320x180.jpg",
                "viewersCount": 26300,
                "broadcaster": {
                  "broadcastSettings": {"title": "Live with chat"},
                },
              }
            : null,
        "videos": {
          "edges": [
            {
              "cursor": nextCursor,
              "node": {
                "id": videoId,
                "title": videoTitle,
                "game": {"id": "509658", "displayName": "Just Chatting"},
                "lengthSeconds": 17999,
                "previewThumbnailURL": "https://static-cdn.jtvnw.net/$videoId.jpg",
                "publishedAt": DateTime.now()
                    .subtract(const Duration(days: 2, hours: 1))
                    .toUtc()
                    .toIso8601String(),
                "createdAt": DateTime.now()
                    .subtract(const Duration(days: 2, hours: 2))
                    .toUtc()
                    .toIso8601String(),
                "viewCount": 91234,
              },
            },
          ],
          "pageInfo": {"hasNextPage": nextCursor != null},
        },
      },
    },
  }),
  200,
  headers: {"content-type": "application/json"},
);
