import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/following/following_store.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  testWidgets("keeps anonymous channels visible during a saved-session refresh", (
    tester,
  ) async {
    final authController = _DelayedGuestRefreshAuthController();
    final apiCache = TwitchApiCache(
      clientLoader: () async => throw StateError("Unexpected API request."),
    );
    final followingStore = FollowingStore(
      authController: authController,
      apiCache: apiCache,
    );
    await followingStore.loadSavedConnection();
    final browseStore = BrowseStore(apiCache: apiCache)
      ..liveChannels = const [
        StreamChannel(
          id: "top-1",
          login: "topcreator",
          name: "TopCreator",
          initials: "TC",
          title: "Live now",
          category: "Just Chatting",
          viewers: "12.3K",
          avatarColors: [Colors.purple, Colors.pink],
          thumbnailColors: [Colors.blue, Colors.indigo],
        ),
      ]
      ..liveChannelsLoaded = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: FollowingScreen(
          followingStore: followingStore,
          browseStore: browseStore,
          periodicRefreshInterval: null,
        ),
      ),
    );
    await tester.pump();

    final refresh = followingStore.loadSavedConnection(refresh: true);
    await tester.pump();

    expect(authController.loadCount, 2);
    expect(followingStore.sessionStatus, TwitchSessionStatus.loggedOut);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("following_title")),
        matching: find.text("Live Channels"),
      ),
      findsOneWidget,
    );
    expect(find.text("TopCreator"), findsOneWidget);
    expect(find.byKey(const ValueKey("bottom_nav_item_Live Channels")), findsOneWidget);
    expect(find.byKey(const ValueKey("bottom_nav_item_Following")), findsNothing);
    expect(find.byKey(const ValueKey("following_skeleton")), findsNothing);

    authController.refresh.complete(null);
    await refresh;
    await tester.pump();
  });

  testWidgets("loads top live channels after signing out while mounted", (tester) async {
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "",
        accessToken: "",
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              "data": {
                "streams": {
                  "edges": const <Object?>[],
                  "pageInfo": {"hasNextPage": false},
                },
              },
            }),
            200,
            headers: {"content-type": "application/json"},
          ),
        ),
      ),
    );
    final followingStore = FollowingStore(
      authController: _authController(clientId: ""),
      apiCache: apiCache,
    )..applyConnection(_connection());
    final browseStore = BrowseStore(apiCache: apiCache);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: FollowingScreen(
          followingStore: followingStore,
          browseStore: browseStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await followingStore.signOut();
    await tester.runAsync(() async {
      for (var index = 0; index < 20 && !browseStore.liveChannelsLoaded; index++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey("following_title")),
        matching: find.text("Live Channels"),
      ),
      findsOneWidget,
    );
    expect(find.text("No live channels are available right now."), findsOneWidget);
    expect(browseStore.liveChannelsLoaded, isTrue);
    expect(find.byKey(const ValueKey("following_offline_card")), findsNothing);
  });

  testWidgets("opens the player from live media and channels from identities", (
    tester,
  ) async {
    await tester.pumpWidget(
      _followingScreen(
        apiCache: _channelApiCache(),
        openTwitchLogin: (_, _) async => _connection(
          followedStreams: const [
            TwitchFollowedStream(
              id: "stream-1",
              userId: "live-1",
              userLogin: "liveone",
              userName: "LiveOne",
              gameName: "Minecraft",
              title: "Building with chat",
              viewerCount: 321,
            ),
          ],
          followedChannels: const [
            TwitchFollowedChannel(
              broadcasterId: "live-1",
              broadcasterLogin: "liveone",
              broadcasterName: "LiveOne",
            ),
            TwitchFollowedChannel(
              broadcasterId: "offline-1",
              broadcasterLogin: "offlineone",
              broadcasterName: "OfflineOne",
            ),
          ],
        ),
      ),
    );

    await _logInFromMe(tester);

    await tester.tap(find.byKey(const ValueKey("stream_thumbnail_LiveOne")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("player_page_liveone")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_page_liveone")), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const ValueKey("player_page_liveone"))),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("stream_channel_identity_LiveOne")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_liveone")), findsOneWidget);

    Navigator.of(tester.element(find.byKey(const ValueKey("channel_page_liveone")))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("offline_toggle")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("offline_channel_row_OfflineOne")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_offlineone")), findsOneWidget);
  });

  testWidgets("offline categories receive their own tap without opening the channel", (
    tester,
  ) async {
    var channelSelections = 0;
    var categorySelections = 0;
    const channel = OfflineChannel(
      id: "offline-1",
      login: "offlineone",
      name: "OfflineOne",
      initials: "OO",
      lastLive: "Last live today",
      category: "Just Chatting",
      categoryId: "509658",
      avatarColors: [Colors.purple, Colors.pink],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: Scaffold(
          body: OfflineChannelRow(
            channel: channel,
            onTap: () => channelSelections++,
            onCategoryTap: () => categorySelections++,
          ),
        ),
      ),
    );

    final categoryFinder = find.byKey(const ValueKey("offline_channel_category_OfflineOne"));
    await tester.tap(categoryFinder);
    await tester.pump();
    expect(categorySelections, 1);
    expect(channelSelections, 0);
    await tester.tap(find.text("OfflineOne"));
    await tester.pump();
    expect(channelSelections, 1);
    expect(categorySelections, 1);
  });

  testWidgets("limits stream-card channel links to the avatar, name, and badge", (
    tester,
  ) async {
    var channelSelections = 0;
    var streamSelections = 0;
    var categorySelections = 0;
    const channel = StreamChannel(
      login: "liveone",
      name: "LiveOne",
      initials: "LO",
      title: "Building with chat",
      category: "Minecraft",
      categoryId: "27471",
      viewers: "321",
      avatarColors: [Colors.purple, Colors.pink],
      thumbnailColors: [Colors.blue, Colors.indigo],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: StreamCard(
              channel: channel,
              onChannelSelected: (_) {
                channelSelections += 1;
              },
              onStreamSelected: (_) {
                streamSelections += 1;
              },
              onCategorySelected: (_) {
                categorySelections += 1;
              },
            ),
          ),
        ),
      ),
    );

    for (final key in const [
      "stream_channel_avatar_LiveOne",
      "stream_channel_identity_LiveOne",
      "stream_channel_badge_LiveOne",
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }

    expect(channelSelections, 3);
    expect(streamSelections, 0);

    final contentRect = tester.getRect(
      find.byKey(const ValueKey("stream_card_content_row_LiveOne")),
    );
    final badgeRect = tester.getRect(
      find.byKey(const ValueKey("stream_channel_badge_LiveOne")),
    );
    final whitespace = Offset(contentRect.right - 2, badgeRect.center.dy);
    expect(whitespace.dx, greaterThan(badgeRect.right));

    await tester.tapAt(whitespace);
    await tester.pump();

    expect(channelSelections, 3);
    expect(streamSelections, 1);
    await tester.tap(find.byKey(const ValueKey("stream_category_LiveOne")));
    await tester.pump();
    expect(categorySelections, 1);
    expect(streamSelections, 1);

    await tester.longPress(find.byKey(const ValueKey("stream_title_LiveOne")));
    await tester.pumpAndSettle();
    expect(find.text(channel.title), findsNWidgets(2));
    expect(streamSelections, 1);
    await tester.pump(const Duration(seconds: 6));
  });
}

Future<void> _logInFromMe(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey("login_offer_screen")), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey("login_offer_button")));
  await tester.pumpAndSettle();
}

Widget _followingScreen({
  TwitchApiCache? apiCache,
  TwitchLoginOpener? openTwitchLogin,
}) => MaterialApp(
  theme: buildFlowTheme(Brightness.dark),
  home: FollowingScreen(
    authController: _authController(),
    apiCache: apiCache,
    openTwitchLogin: openTwitchLogin,
  ),
);

TwitchAuthController _authController({String clientId = "client-123"}) => TwitchAuthController(
  config: TwitchAuthConfig(clientId: clientId),
  secureStore: _MemoryTwitchStore(),
  apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
    clientId: clientId,
    accessToken: accessToken,
    gqlAccessToken: gqlAccessToken,
  ),
  cookieExtractor: const _StaticCookieExtractor(),
);

TwitchAuthConnection _connection({
  List<TwitchFollowedStream> followedStreams = const [],
  List<TwitchFollowedChannel> followedChannels = const [],
}) => TwitchAuthConnection(
  user: const TwitchUser(
    id: "user-123",
    login: "flowtester",
    displayName: "Flow Tester",
  ),
  followedStreams: followedStreams,
  followedChannels: followedChannels,
);

TwitchApiCache _channelApiCache() => TwitchApiCache(
  clientLoader: () async => TwitchApiClient(
    clientId: "client-123",
    accessToken: "token-123",
    httpClient: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final variables = (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
      final login = variables["login"]?.toString() ?? "channel";
      return http.Response(
        jsonEncode({
          "data": {
            "user": {
              "id": login,
              "login": login,
              "displayName": login == "liveone" ? "LiveOne" : "OfflineOne",
              "description": "",
              "profileImageURL": "https://static-cdn.jtvnw.net/$login.png",
              "followers": {"totalCount": 0},
              "stream": null,
              "videos": {
                "edges": const <Object?>[],
                "pageInfo": {"hasNextPage": false},
              },
            },
          },
        }),
        200,
        headers: {"content-type": "application/json"},
      );
    }),
  ),
);

class _MemoryTwitchStore implements TwitchSecureStore {
  @override
  Future<void> clearSession() async {}

  @override
  Future<void> clearPendingState() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readPendingState() async => null;

  @override
  Future<String?> readWebSessionToken() async => null;

  @override
  Future<void> saveAccessToken(String token) async {}

  @override
  Future<void> savePendingState(String state) async {}

  @override
  Future<void> saveWebSessionToken(String token) async {}
}

class _DelayedGuestRefreshAuthController extends TwitchAuthController {
  _DelayedGuestRefreshAuthController()
    : super(
        config: const TwitchAuthConfig(clientId: "client-123"),
        secureStore: _MemoryTwitchStore(),
        apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
          clientId: "client-123",
          accessToken: accessToken,
        ),
        cookieExtractor: const _StaticCookieExtractor(),
      );

  final refresh = Completer<TwitchAuthConnection?>();
  int loadCount = 0;

  @override
  Future<TwitchAuthConnection?> loadSavedConnection() {
    loadCount++;
    return loadCount == 1 ? Future<TwitchAuthConnection?>.value() : refresh.future;
  }
}

class _StaticCookieExtractor extends TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}
