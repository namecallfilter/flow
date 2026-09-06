import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/channel/channel_screen.dart";
import "package:flow/features/channel/channel_store.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/following/following_store.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  testWidgets("opens channel after player return and live Following reorder", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final tabNavigatorKey = GlobalKey<NavigatorState>();
    final response = Completer<http.Response>();
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          if (body["query"].toString().contains("FlowChannelDetails")) {
            return response.future;
          }
          return http.Response('{"data":{}}', 200);
        }),
      ),
    );
    TwitchAuthConnection connection(int viewers) => TwitchAuthConnection(
      user: const TwitchUser(id: "viewer", login: "viewer", displayName: "Viewer"),
      followedStreams: [
        TwitchFollowedStream(
          id: "live-1",
          userId: "creator-1",
          userLogin: "jason",
          userName: "Jason",
          title: "Live with chat",
          gameName: "Just Chatting",
          viewerCount: viewers,
        ),
        const TwitchFollowedStream(
          id: "live-2",
          userId: "creator-2",
          userLogin: "other",
          userName: "Other",
          title: "Another live stream",
          gameName: "Minecraft",
          viewerCount: 100,
        ),
      ],
      followedChannels: const [],
    );
    final followingStore = FollowingStore(
      authController: TwitchAuthController(
        config: const TwitchAuthConfig(clientId: "client-123"),
        secureStore: const SecureTwitchStore(),
        cookieExtractor: const MethodChannelTwitchCookieExtractor(),
        apiClientFactory: (token, {gqlAccessToken}) => TwitchApiClient(
          clientId: "client-123",
          accessToken: token,
        ),
      ),
      apiCache: apiCache,
    )..connection = connection(200);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: buildFlowTheme(Brightness.dark),
        home: Scaffold(
          body: Navigator(
            key: tabNavigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => FollowingScreen(
                followingStore: followingStore,
                apiCache: apiCache,
              ),
            ),
          ),
          bottomNavigationBar: const AppBottomNav(currentRoute: FlowRoutes.following),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey("stream_title_Jason")));
    await tester.pumpAndSettle();
    expect(find.text("Live with chat"), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey("stream_thumbnail_Jason")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("player_page_jason")), findsOneWidget);

    followingStore.connection = connection(50);
    await tester.pump();
    rootNavigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await tester.tap(find.byKey(const ValueKey("stream_channel_identity_Jason")));
    await tester.pump();
    response.complete(
      _channelDetailsResponse(videoTitles: List.generate(20, (index) => "Broadcast $index")),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_jason")), findsOneWidget);
    expect(find.byKey(const ValueKey("past_broadcast_vod-1")), findsOneWidget);
    expect(rootNavigatorKey.currentState!.canPop(), isFalse);
    expect(tabNavigatorKey.currentState!.canPop(), isTrue);
    expect(tester.takeException(), isNull);

    await tester.longPress(find.byKey(const ValueKey("past_broadcast_title_preview_vod-1")));
    await tester.pumpAndSettle();
    tabNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("stream_channel_identity_Jason")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("past_broadcast_vod-1")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("renders past broadcasts at larger system text sizes", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient(
                (_) async => _channelDetailsResponse(
                  videoTitle: "A long past broadcast title that needs both available lines",
                ),
              ),
            ),
          ),
          initialChannel: const ChannelPreview(login: "jason", displayName: "Jason"),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("past_broadcast_vod-1")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("updates the active broadcast duration locally every second", (
    tester,
  ) async {
    final streamStartedAt = tester.binding.clock.now().subtract(const Duration(hours: 5));
    var apiRequests = 0;
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((_) async {
          apiRequests++;
          return _channelDetailsResponse(
            videoTitles: const ["Live archive", "Earlier stream"],
            streamStartedAt: streamStartedAt,
            firstVideoCreatedAt: streamStartedAt,
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: apiCache,
          channelStore: ChannelStore(
            apiCache: apiCache,
            login: "jason",
            now: tester.binding.clock.now,
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

    expect(find.text("5:00:00"), findsOneWidget);
    expect(find.text("4:59:59"), findsOneWidget);
    expect(apiRequests, 1);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text("5:00:01"), findsOneWidget);
    expect(find.text("4:59:59"), findsOneWidget);
    expect(apiRequests, 1);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text("5:00:03"), findsOneWidget);
    expect(find.text("4:59:59"), findsOneWidget);
    expect(apiRequests, 1);
  });

  testWidgets("refetches the channel and keeps live duration current when reopened", (
    tester,
  ) async {
    final streamStartedAt = tester.binding.clock.now();
    final reopenedResponse = Completer<http.Response>();
    var apiRequests = 0;
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((_) {
          apiRequests++;
          if (apiRequests == 1) {
            return Future.value(
              _channelDetailsResponse(
                videoLengthSeconds: 49,
                streamStartedAt: streamStartedAt,
                firstVideoCreatedAt: streamStartedAt,
              ),
            );
          }
          return reopenedResponse.future;
        }),
      ),
    );

    final reopenedChannelResponse = _channelDetailsResponse(
      videoLengthSeconds: 55,
      streamStartedAt: streamStartedAt,
      firstVideoCreatedAt: streamStartedAt,
    );

    Widget buildChannel() => MaterialApp(
      theme: buildFlowTheme(Brightness.dark),
      home: ChannelScreen(
        apiCache: apiCache,
        channelStore: ChannelStore(
          apiCache: apiCache,
          login: "jason",
          now: tester.binding.clock.now,
        ),
        initialChannel: const ChannelPreview(
          login: "jason",
          displayName: "Jason",
          isLive: true,
        ),
      ),
    );

    await tester.pumpWidget(buildChannel());
    await tester.pumpAndSettle();

    expect(find.text("0:49"), findsOneWidget);
    expect(apiRequests, 1);

    await tester.pump(const Duration(seconds: 6));

    expect(find.text("0:55"), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildChannel());
    await tester.pump();

    expect(apiRequests, 2);
    expect(find.text("0:49"), findsNothing);

    reopenedResponse.complete(reopenedChannelResponse);
    await tester.pumpAndSettle();

    expect(find.text("0:55"), findsOneWidget);
    expect(apiRequests, 2);
  });

  testWidgets("keeps category navigation in the active tab stack", (tester) async {
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
                (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
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
          return _channelDetailsResponse(
            videoCategoryId: "33214",
            videoCategory: "Fortnite",
          );
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

    final liveCategoryPage = find.byKey(
      const ValueKey("category_streams_page_Just Chatting"),
    );
    expect(liveCategoryPage, findsOneWidget);
    expect(find.byKey(const ValueKey("app_bottom_nav_bar")), findsOneWidget);
    expect(
      Navigator.of(tester.element(liveCategoryPage)),
      same(tabNavigatorKey.currentState),
    );
    expect(rootNavigatorKey.currentState?.canPop(), isFalse);
    expect(tabNavigatorKey.currentState?.canPop(), isTrue);
    expect(requestedGameIds, ["509658"]);

    tabNavigatorKey.currentState?.pop();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey("past_broadcast_category_button_vod-1")),
    );
    await tester.pumpAndSettle();

    final pastCategoryPage = find.byKey(
      const ValueKey("category_streams_page_Fortnite"),
    );
    expect(pastCategoryPage, findsOneWidget);
    expect(find.byKey(const ValueKey("app_bottom_nav_bar")), findsOneWidget);
    expect(
      Navigator.of(tester.element(pastCategoryPage)),
      same(tabNavigatorKey.currentState),
    );
    expect(rootNavigatorKey.currentState?.canPop(), isFalse);
    expect(tabNavigatorKey.currentState?.canPop(), isTrue);
    expect(requestedGameIds, ["509658", "33214"]);
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

http.Response _channelDetailsResponse({
  String videoId = "vod-1",
  String videoTitle = "2025 Japan Trip",
  List<String>? videoTitles,
  String videoCategoryId = "509658",
  String videoCategory = "Just Chatting",
  String? nextCursor,
  bool isLive = true,
  DateTime? streamStartedAt,
  DateTime? firstVideoCreatedAt,
  int videoLengthSeconds = 17999,
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
                  "createdAt": (streamStartedAt ?? DateTime.parse("2026-07-04T01:00:00Z"))
                      .toUtc()
                      .toIso8601String(),
                  "game": {"id": "509658", "displayName": "Just Chatting"},
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
                    "game": {
                      "id": videoCategoryId,
                      "displayName": videoCategory,
                    },
                    "lengthSeconds": videoLengthSeconds,
                    "previewThumbnailURL":
                        "https://static-cdn.jtvnw.net/${index == 0 ? videoId : "$videoId-$index"}.jpg",
                    "publishedAt": DateTime.now()
                        .subtract(Duration(days: 2 + index, hours: 1))
                        .toUtc()
                        .toIso8601String(),
                    "createdAt":
                        (index == 0 && firstVideoCreatedAt != null
                                ? firstVideoCreatedAt
                                : DateTime.now().subtract(
                                    Duration(days: 2 + index, hours: 2),
                                  ))
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
