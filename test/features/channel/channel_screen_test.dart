import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/channel/channel_screen.dart";
import "package:flow/features/channel/channel_store.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/following/following_store.dart";
import "package:flow/features/player/player_navigation.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  for (final isLive in [true, false]) {
    testWidgets("initial channel skeleton includes action buttons for live=$isLive", (
      tester,
    ) async {
      final details = Completer<http.Response>();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.dark),
          home: ChannelScreen(
            apiCache: TwitchApiCache(
              clientLoader: () async => TwitchApiClient(
                clientId: "client",
                accessToken: "",
                httpClient: MockClient((_) => details.future),
              ),
            ),
            initialChannel: ChannelPreview(login: "jason", displayName: "Jason", isLive: isLive),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey("channel_header_skeleton")), findsOneWidget);
      expect(find.byKey(const ValueKey("channel_follow_button_skeleton")), findsOneWidget);
      expect(
        find.byKey(const ValueKey("channel_chat_button_skeleton")),
        isLive ? findsNothing : findsOneWidget,
      );
      expect(find.byKey(const ValueKey("channel_follow_button")), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      details.complete(_channelDetailsResponse(isLive: isLive));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("channel_follow_button_skeleton")), findsNothing);
      expect(find.byKey(const ValueKey("channel_chat_button_skeleton")), findsNothing);
      expect(find.byKey(const ValueKey("channel_follow_button")), findsOneWidget);
      expect(
        find.byKey(const ValueKey("channel_chat_button")),
        isLive ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("follow skeleton remains while the initial status loads after the profile", (
    tester,
  ) async {
    final client = _FollowClient(isLive: false)
      ..following = true
      ..statusGate = Completer<void>();
    await tester.pumpWidget(_followApp(() async => client));
    await tester.pump();
    expect(find.byKey(const ValueKey("channel_header_card")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_follow_button_skeleton")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_chat_button")), findsOneWidget);
    expect(find.text("Follow"), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    client.statusGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_follow_button_skeleton")), findsNothing);
    expect(find.text("Following"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("channel follow waits for confirmation and ignores repeated taps", (tester) async {
    final client = _FollowClient();
    await tester.pumpWidget(_followApp(() async => client));
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey("channel_follow_button"));
    expect(find.text("Follow"), findsOneWidget);
    client.changeGate = Completer<void>();
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(client.changes, [true]);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text("Following"), findsNothing);
    expect(find.text("Follow"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.widget<FlowPullToRefresh>(find.byType(FlowPullToRefresh)).onRefresh();
    await tester.pump();
    expect(client.statusChecks, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    client.changeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text("Following"), findsOneWidget);
    client.changeGate = Completer<void>();
    await tester.tap(button);
    await tester.pump();
    expect(find.text("Following"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    client.changeGate!.complete();
    await tester.pumpAndSettle();
    expect(client.changes, [true, false]);
    expect(find.text("Follow"), findsOneWidget);
  });

  testWidgets("offline follow loads existing status and retries failures without a mutation", (
    tester,
  ) async {
    final client = _FollowClient(isLive: false)
      ..following = true
      ..failStatus = true;
    await tester.pumpWidget(_followApp(() async => client));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey("channel_follow_button"));
    expect(find.text("Retry follow status"), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_chat_button")), findsOneWidget);

    client.failStatus = false;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text("Following"), findsOneWidget);
    expect(client.changes, isEmpty);

    client.failChange = true;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(client.following, isTrue);
    expect(find.text("Could not update follow status. Try again."), findsOneWidget);
    expect(find.text("Retry follow status"), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text("Following"), findsOneWidget);
    expect(client.changes, [false]);
  });

  testWidgets("guest follow uses the existing sign-in guidance", (tester) async {
    final client = _FollowClient(token: null);
    await tester.pumpWidget(_followApp(() async => client));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("channel_follow_button")));
    await tester.pumpAndSettle();
    expect(find.text("Sign in from Following to follow"), findsOneWidget);
    expect(client.statusChecks, 0);
    expect(client.changes, isEmpty);
  });

  testWidgets("follow refreshes retained accounts and rejects stale account actions and results", (
    tester,
  ) async {
    final first = _FollowClient();
    final second = _FollowClient(token: "second")..following = true;
    var current = first;
    Future<TwitchApiClient> loadClient() async => current;
    await tester.pumpWidget(_followApp(loadClient));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey("channel_follow_button"));

    current = second;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(first.changes, isEmpty);
    expect(second.changes, isEmpty);
    expect(find.text("Following"), findsOneWidget);

    second.changeGate = Completer<void>();
    await tester.tap(button);
    await tester.pump();
    expect(second.changes, [false]);
    current = first;
    second.changeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text("Follow"), findsOneWidget);
    expect(first.statusChecks, 2);

    await tester.pumpWidget(_followApp(loadClient, visible: false));
    await tester.pump();
    second.following = true;
    current = second;
    await tester.pumpWidget(_followApp(loadClient));
    await tester.pumpAndSettle();
    expect(find.text("Following"), findsOneWidget);
    expect(second.changes, [false]);
  });

  testWidgets("opens a VOD player page and reuses playback when it is selected again", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final navigatorKey = GlobalKey<NavigatorState>();
    final host = PlaybackHost();
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [host],
        builder: (_, child) => AppSettingsScope(settingsStore: settings, child: child!),
        theme: buildFlowTheme(Brightness.dark),
        home: ChannelScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              httpClient: MockClient((_) async => _channelDetailsResponse(isLive: false)),
            ),
          ),
          initialChannel: const ChannelPreview(login: "jason", displayName: "Jason"),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey("past_broadcast_title_preview_vod-1")));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text("2025 Japan Trip"), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey("past_broadcast_title_preview_vod-1")));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();

    final playerFinder = find.byType(StreamPlayerScreen);
    final player = tester.widget<StreamPlayerScreen>(playerFinder);
    final playerState = tester.state(playerFinder);
    expect(player.videoId, "vod-1");
    expect(player.channel.login, "jason");
    expect(player.channel.title, "2025 Japan Trip");
    expect(
      find.byKey(const ValueKey("past_broadcast_thumbnail_vod-1")).hitTestable(),
      findsNothing,
    );
    expect(host.mode, PlaybackMode.expanded);
    expect(navigatorKey.currentState!.canPop(), isTrue);

    host.minimize();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_jason")), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(tester.state(playerFinder), same(playerState));

    await tester.tap(find.byKey(const ValueKey("past_broadcast_thumbnail_vod-1")));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(navigatorKey.currentState!.canPop(), isTrue);
    expect(tester.state(playerFinder), same(playerState));

    host.minimize();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("past_broadcast_category_button_vod-1")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    expect(tester.state(playerFinder), same(playerState));
    expect(host.mode, PlaybackMode.mini);

    host.dismiss();
    await tester.pumpAndSettle();
    expect(playerFinder, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final isPartner in [true, false]) {
    testWidgets("channel header uses Twitch partner status ($isPartner)", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChannelScreen(
            apiCache: TwitchApiCache(
              clientLoader: () async => TwitchApiClient(
                clientId: "client-123",
                accessToken: "token-123",
                httpClient: MockClient((_) async => _channelDetailsResponse(isPartner: isPartner)),
              ),
            ),
            initialChannel: const ChannelPreview(
              login: "jason",
              displayName: "Jason",
              isPartner: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.verified), isPartner ? findsOneWidget : findsNothing);
    });
  }

  testWidgets("opens channel after player return and live Following reorder", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final tabNavigatorKey = GlobalKey<NavigatorState>();
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
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
        builder: (_, child) => AppSettingsScope(settingsStore: settings, child: child!),
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
    await tester.longPress(find.byKey(const ValueKey("channel_back_button")));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text("Back"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("channel_back_button")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_jason")), findsNothing);
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
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => AppSettingsScope(settingsStore: settings, child: child!),
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

  testWidgets("offline profile opens chat from its Chat button and Back closes it", (
    tester,
  ) async {
    final host = PlaybackHost();
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [host],
        builder: (_, child) => AppSettingsScope(settingsStore: settings, child: child!),
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
    await tester.tap(find.byKey(const ValueKey("channel_chat_button")));
    await tester.pumpAndSettle();
    expect(
      tester.widget<StreamPlayerScreen>(find.byType(StreamPlayerScreen)).initiallyOffline,
      isTrue,
    );
    expect(find.byKey(const ValueKey("player_chat_header")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_viewport")), findsNothing);
    await tester.tap(find.byTooltip("Back").hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(StreamPlayerScreen), findsNothing);
    expect(find.byKey(const ValueKey("channel_chat_button")), findsOneWidget);
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

Widget _followApp(TwitchApiClientLoader loadClient, {bool visible = true}) => MaterialApp(
  theme: buildFlowTheme(Brightness.dark),
  home: TickerMode(
    enabled: visible,
    child: ChannelScreen(
      apiCache: TwitchApiCache(clientLoader: loadClient),
      initialChannel: const ChannelPreview(login: "jason", displayName: "Jason"),
    ),
  ),
);

class _FollowClient extends TwitchApiClient {
  _FollowClient({String? token = "first", bool isLive = true})
    : super(
        clientId: "client",
        accessToken: token ?? "",
        gqlAccessToken: token,
        httpClient: MockClient((_) async => _channelDetailsResponse(isLive: isLive)),
      );

  bool following = false;
  bool failStatus = false;
  bool failChange = false;
  int statusChecks = 0;
  final changes = <bool>[];
  Completer<void>? changeGate;
  Completer<void>? statusGate;

  @override
  Future<TwitchChatAccess> fetchChatAccess(String login) async {
    expect(login, "jason");
    statusChecks++;
    await statusGate?.future;
    if (failStatus) {
      throw TwitchApiException("Status unavailable");
    }
    return TwitchChatAccess(
      channelId: "123",
      channelDisplayName: "Jason",
      rules: const [],
      isFollowing: following,
    );
  }

  Future<void> _change(String channelId, bool follow) async {
    expect(channelId, "123");
    changes.add(follow);
    await changeGate?.future;
    if (failChange) {
      throw TwitchApiException("Change rejected");
    }
    following = follow;
  }

  @override
  Future<DateTime> followChannel(String channelId) async {
    await _change(channelId, true);
    return DateTime(2026);
  }

  @override
  Future<void> unfollowChannel(String channelId) => _change(channelId, false);
}

http.Response _channelDetailsResponse({
  String videoId = "vod-1",
  String videoTitle = "2025 Japan Trip",
  List<String>? videoTitles,
  String videoCategoryId = "509658",
  String videoCategory = "Just Chatting",
  String? nextCursor,
  bool isLive = true,
  bool isPartner = false,
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
          "isPartner": isPartner,
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
