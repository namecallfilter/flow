import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/channel/channel_screen.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
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
    expect(find.byKey(const ValueKey("channel_category_button")), findsOneWidget);
    expect(find.text("Just Chatting"), findsOneWidget);
    expect(find.text("with 26.3K viewers"), findsOneWidget);
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

  testWidgets("wraps a long live category without ellipsizing", (tester) async {
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

    final category = tester.widget<Text>(
      find.byKey(const ValueKey("channel_category_label")),
    );
    final viewers = tester.widget<Text>(
      find.byKey(const ValueKey("channel_live_viewers")),
    );

    expect(find.byKey(const ValueKey("channel_live_metadata")), findsOneWidget);
    expect(category.data, longCategory);
    expect(category.softWrap, isTrue);
    expect(category.maxLines, isNull);
    expect(category.overflow, isNot(TextOverflow.ellipsis));
    expect(viewers.data, "with 26.3K viewers");
    expect(viewers.softWrap, isTrue);
    expect(viewers.maxLines, isNull);
    expect(viewers.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets("keeps live category navigation in the active tab stack", (tester) async {
    final requestedGameIds = <String>[];
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final tabNavigatorKey = GlobalKey<NavigatorState>();
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final query = body["query"]?.toString() ?? "";
          if (query.contains("FlowGameStreams")) {
            final variables =
                (body["variables"] as Map<String, Object?>?) ??
                const <String, Object?>{};
            requestedGameIds.add(variables["id"]?.toString() ?? "");
            return http.Response(
              jsonEncode({
                "data": {
                  "game": {
                    "streams": {
                      "edges": <Object?>[],
                      "pageInfo": {"hasNextPage": false},
                    },
                  },
                },
              }),
              200,
              headers: {"content-type": "application/json"},
            );
          }
          return _channelDetailsResponse();
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: buildFlowTheme(Brightness.dark),
        home: Scaffold(
          body: Navigator(
            key: tabNavigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => ChannelScreen(
                apiCache: apiCache,
                initialChannel: const ChannelPreview(
                  login: "jason",
                  displayName: "Jason",
                  isLive: true,
                ),
              ),
            ),
          ),
          bottomNavigationBar: const AppBottomNav(
            currentRoute: FlowRoutes.following,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("app_bottom_nav_bar")), findsOneWidget);
    expect(rootNavigatorKey.currentState?.canPop(), isFalse);
    expect(tabNavigatorKey.currentState?.canPop(), isFalse);

    await tester.tap(find.byKey(const ValueKey("channel_category_button")));
    await tester.pumpAndSettle();

    final categoryPage = find.byKey(
      const ValueKey("category_streams_page_Just Chatting"),
    );
    expect(categoryPage, findsOneWidget);
    expect(find.byKey(const ValueKey("app_bottom_nav_bar")), findsOneWidget);
    expect(
      Navigator.of(tester.element(categoryPage)),
      same(tabNavigatorKey.currentState),
    );
    expect(rootNavigatorKey.currentState?.canPop(), isFalse);
    expect(tabNavigatorKey.currentState?.canPop(), isTrue);
    expect(requestedGameIds, ["509658"]);
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

    final headerSkeleton = find.byKey(const ValueKey("channel_header_skeleton"));
    final firstSkeletonRow = find.byKey(const ValueKey("channel_broadcast_skeleton_0"));
    final secondSkeletonRow = find.byKey(const ValueKey("channel_broadcast_skeleton_1"));
    final firstSkeletonThumbnail = find.byKey(
      const ValueKey("channel_broadcast_skeleton_thumbnail_0"),
    );
    final firstSkeletonDuration = find.byKey(
      const ValueKey("channel_broadcast_skeleton_duration_0"),
    );
    final firstSkeletonText = find.byKey(
      const ValueKey("channel_broadcast_skeleton_text_0"),
    );
    final headerSkeletonRect = tester.getRect(headerSkeleton);
    final skeletonThumbnailSize = tester.getSize(firstSkeletonThumbnail);
    final skeletonRowStride =
        tester.getTopLeft(secondSkeletonRow).dy - tester.getTopLeft(firstSkeletonRow).dy;

    expect(find.byKey(const ValueKey("channel_skeleton")), findsOneWidget);
    expect(headerSkeleton, findsOneWidget);
    expect(find.byKey(const ValueKey("channel_broadcast_skeleton_9")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_broadcast_skeleton_10")), findsNothing);
    expect(headerSkeletonRect.height, 174);
    expect(tester.getSize(firstSkeletonThumbnail), const Size(132, 74.25));
    expect(tester.getSize(firstSkeletonDuration), const Size(49, 17));
    expect(
      tester.getTopLeft(firstSkeletonDuration).dx - tester.getTopLeft(firstSkeletonThumbnail).dx,
      6,
    );
    expect(
      tester.getBottomRight(firstSkeletonThumbnail).dy -
          tester.getBottomRight(firstSkeletonDuration).dy,
      5,
    );
    expect(tester.getSize(firstSkeletonText).height, 82);
    expect(
      tester.getTopLeft(firstSkeletonText).dx - tester.getTopRight(firstSkeletonThumbnail).dx,
      AppSpacing.md,
    );
    expect(skeletonRowStride, 94);
    for (final key in const [
      "channel_broadcast_skeleton_title_1_0",
      "channel_broadcast_skeleton_title_2_0",
      "channel_broadcast_skeleton_metadata_0",
      "channel_broadcast_skeleton_views_0",
    ]) {
      expect(tester.getSize(find.byKey(ValueKey(key))).width, greaterThan(0));
    }
    expect(find.byKey(const ValueKey("channel_header_card")), findsNothing);
    expect(find.byKey(const ValueKey("channel_profile_avatar")), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(StreamPlayerScreen), findsNothing);

    response.complete(
      _channelDetailsResponse(
        isLive: false,
        videoTitles: const [
          "A very long broadcast title that wraps onto a second line",
          "Another long broadcast title that also needs a second line",
        ],
      ),
    );
    await tester.pumpAndSettle();

    final loadedHeader = find.byKey(const ValueKey("channel_header_card"));
    final firstLoadedRow = find.byKey(const ValueKey("past_broadcast_vod-1"));
    final secondLoadedRow = find.byKey(const ValueKey("past_broadcast_vod-1-1"));
    final firstLoadedThumbnail = find.byKey(
      const ValueKey("past_broadcast_thumbnail_vod-1"),
    );
    final firstLoadedText = find.byKey(const ValueKey("past_broadcast_text_vod-1"));
    final loadedRowStride =
        tester.getTopLeft(secondLoadedRow).dy - tester.getTopLeft(firstLoadedRow).dy;

    expect(find.byKey(const ValueKey("channel_skeleton")), findsNothing);
    expect(loadedHeader, findsOneWidget);
    expect(tester.getRect(loadedHeader).height, closeTo(headerSkeletonRect.height, 4));
    expect(tester.getSize(firstLoadedThumbnail), skeletonThumbnailSize);
    expect(
      tester.getTopLeft(firstLoadedText).dx - tester.getTopRight(firstLoadedThumbnail).dx,
      AppSpacing.md,
    );
    expect(loadedRowStride, closeTo(skeletonRowStride, 4));
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
  List<String>? videoTitles,
  String category = "Just Chatting",
  String? nextCursor,
  bool isLive = true,
}) {
  final titles = videoTitles ?? [videoTitle];

  return http.Response(
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
              for (var index = 0; index < titles.length; index++)
                {
                  "cursor": index == titles.length - 1 ? nextCursor : null,
                  "node": {
                    "id": index == 0 ? videoId : "$videoId-$index",
                    "title": titles[index],
                    "game": {"id": "509658", "displayName": "Just Chatting"},
                    "lengthSeconds": 17999,
                    "previewThumbnailURL":
                        "https://static-cdn.jtvnw.net/${index == 0 ? videoId : "$videoId-$index"}.jpg",
                    "publishedAt": DateTime.now()
                        .subtract(Duration(days: 2 + index, hours: 1))
                        .toUtc()
                        .toIso8601String(),
                    "createdAt": DateTime.now()
                        .subtract(Duration(days: 2 + index, hours: 2))
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
}
