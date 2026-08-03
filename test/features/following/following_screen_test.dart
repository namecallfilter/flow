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
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  testWidgets("uses skeleton only for the initial Following load", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final initialStore = FollowingStore(authController: _authController(clientId: ""))
      ..isLoadingFollowing = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: FollowingScreen(followingStore: initialStore),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey("following_skeleton")), findsOneWidget);
    expect(find.byType(StreamCardSkeleton), findsNWidgets(9));
    final firstStreamSkeleton = find.byKey(const ValueKey("following_stream_skeleton_0"));
    final thumbnail = find.descendant(
      of: firstStreamSkeleton,
      matching: find.byKey(const ValueKey("stream_skeleton_thumbnail")),
    );
    final viewers = find.descendant(
      of: firstStreamSkeleton,
      matching: find.byKey(const ValueKey("stream_skeleton_viewers")),
    );
    final avatar = find.descendant(
      of: firstStreamSkeleton,
      matching: find.byKey(const ValueKey("stream_skeleton_avatar")),
    );
    final verified = find.descendant(
      of: firstStreamSkeleton,
      matching: find.byKey(const ValueKey("stream_skeleton_verified")),
    );
    final title = find.descendant(
      of: firstStreamSkeleton,
      matching: find.byKey(const ValueKey("stream_skeleton_title")),
    );
    final metadata = find.descendant(
      of: firstStreamSkeleton,
      matching: find.byKey(const ValueKey("stream_skeleton_metadata")),
    );
    final offlineSkeleton = find.byKey(const ValueKey("following_offline_skeleton"));
    final offlineSkeletonRect = tester.getRect(offlineSkeleton);
    final scrollPosition = Scrollable.of(tester.element(offlineSkeleton)).position;

    expect(tester.getSize(firstStreamSkeleton).height, 93);
    expect(tester.getSize(thumbnail), const Size(116, 65.25));
    expect(tester.getSize(viewers), const Size(49, 17));
    expect(tester.getTopLeft(viewers).dx - tester.getTopLeft(thumbnail).dx, 6);
    expect(tester.getBottomRight(thumbnail).dy - tester.getBottomRight(viewers).dy, 3);
    expect(tester.getSize(avatar), const Size(28, 28));
    expect(tester.getSize(verified), const Size(14, 14));
    expect(tester.getSize(title).height, 17);
    expect(tester.getSize(metadata), const Size(104, 15));
    expect(tester.getTopLeft(title).dy - tester.getBottomLeft(avatar).dy, 6);
    expect(tester.getTopLeft(metadata).dy - tester.getBottomLeft(title).dy, 5);
    expect(offlineSkeletonRect.height, 72);
    expect(scrollPosition.maxScrollExtent, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text("No followed channels are live now."), findsNothing);
    expect(find.byKey(const ValueKey("offline_toggle")), findsNothing);

    final refreshStore = FollowingStore(authController: _authController(clientId: ""))
      ..connection = _connection(
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
        ],
      )
      ..isLoadingFollowing = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: FollowingScreen(
          key: const ValueKey("refresh_following_screen"),
          followingStore: refreshStore,
        ),
      ),
    );
    await tester.pump();

    final loadedOfflineCard = find.byKey(const ValueKey("following_offline_card"));
    final loadedOfflineRect = tester.getRect(loadedOfflineCard);
    expect(find.byKey(const ValueKey("following_skeleton")), findsNothing);
    expect(find.text("LiveOne"), findsOneWidget);
    expect(find.byType(StreamCard), findsOneWidget);
    expect(loadedOfflineRect.height, offlineSkeletonRect.height);
    expect(loadedOfflineRect.width, offlineSkeletonRect.width);
    expect(loadedOfflineRect.left, offlineSkeletonRect.left);
  });

  testWidgets("shows top live channels without offline content when logged out", (
    tester,
  ) async {
    final apiCache = TwitchApiCache(
      clientLoader: () async => throw StateError("Unexpected API request."),
    );
    final followingStore = FollowingStore(
      authController: _authController(clientId: ""),
      apiCache: apiCache,
    )..sessionStatus = TwitchSessionStatus.loggedOut;
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
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey("following_title")),
        matching: find.text("Live Channels"),
      ),
      findsOneWidget,
    );
    expect(find.text("TopCreator"), findsOneWidget);
    expect(find.byKey(const ValueKey("following_offline_card")), findsNothing);
    expect(find.byKey(const ValueKey("offline_toggle")), findsNothing);
    expect(find.byKey(const ValueKey("following_skeleton")), findsNothing);
    expect(find.byKey(const ValueKey("bottom_nav_item_Live Channels")), findsOneWidget);
    expect(find.byIcon(Icons.live_tv), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

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

  testWidgets("renders live streams and expands offline channels from auth data", (
    tester,
  ) async {
    await tester.pumpWidget(
      _followingScreen(
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
              thumbnailUrl:
                  "https://static-cdn.jtvnw.net/previews-ttv/live_user_liveone-{width}x{height}.jpg",
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
          channelInfoByBroadcasterId: const {
            "offline-1": TwitchChannelInfo(
              broadcasterId: "offline-1",
              broadcasterName: "OfflineOne",
              gameName: "Just Chatting",
              title: "Back later",
            ),
          },
        ),
      ),
    );

    await _logInFromMe(tester);

    expect(find.text("LiveOne"), findsOneWidget);
    expect(find.text("Building with chat"), findsOneWidget);
    expect(find.text("OfflineOne"), findsNothing);

    await tester.tap(find.byKey(const ValueKey("offline_toggle")));
    await tester.pumpAndSettle();

    expect(find.text("OfflineOne"), findsOneWidget);
    expect(find.text("Just Chatting"), findsOneWidget);
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

  testWidgets("limits stream-card channel links to the avatar, name, and badge", (
    tester,
  ) async {
    var channelSelections = 0;
    var streamSelections = 0;
    const channel = StreamChannel(
      login: "liveone",
      name: "LiveOne",
      initials: "LO",
      title: "Building with chat",
      category: "Minecraft",
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
  });

  testWidgets("uses category metadata space for a second title line", (tester) async {
    const longTitle =
        "A long stream title that wraps onto another line without moving the card content";
    const standardChannel = StreamChannel(
      login: "standard",
      name: "Standard",
      initials: "ST",
      title: longTitle,
      category: "Minecraft",
      viewers: "321",
      avatarColors: [Colors.purple, Colors.pink],
      thumbnailColors: [Colors.blue, Colors.indigo],
    );
    const categoryChannel = StreamChannel(
      login: "category",
      name: "Category",
      initials: "CA",
      title: longTitle,
      category: "Minecraft",
      viewers: "321",
      avatarColors: [Colors.purple, Colors.pink],
      thumbnailColors: [Colors.blue, Colors.indigo],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: const Scaffold(
          body: SizedBox(
            width: 390,
            child: Column(
              children: [
                StreamCard(
                  key: ValueKey("standard_stream_card"),
                  channel: standardChannel,
                ),
                StreamCard(
                  key: ValueKey("category_stream_card"),
                  channel: categoryChannel,
                  showCategory: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    double topOffset(String key, String channelName) =>
        tester.getTopLeft(find.byKey(ValueKey(key))).dy -
        tester
            .getTopLeft(
              find.byKey(ValueKey("stream_card_content_padding_$channelName")),
            )
            .dy;

    final standardTitleFinder = find.byKey(const ValueKey("stream_title_Standard"));
    final categoryTitleFinder = find.byKey(const ValueKey("stream_title_Category"));
    final standardTitle = tester.widget<Text>(standardTitleFinder);
    final categoryTitle = tester.widget<Text>(categoryTitleFinder);

    expect(tester.getSize(find.byKey(const ValueKey("standard_stream_card"))).height, 93);
    expect(tester.getSize(find.byKey(const ValueKey("category_stream_card"))).height, 93);
    expect(standardTitle.maxLines, 1);
    expect(categoryTitle.maxLines, 2);
    expect(
      tester.getSize(categoryTitleFinder).height,
      greaterThan(tester.getSize(standardTitleFinder).height),
    );
    expect(find.byKey(const ValueKey("stream_category_Standard")), findsOneWidget);
    expect(find.byKey(const ValueKey("stream_category_Category")), findsNothing);

    for (final keyPrefix in const [
      "stream_thumbnail_",
      "stream_channel_avatar_",
      "stream_channel_identity_",
      "stream_channel_badge_",
      "stream_title_",
    ]) {
      expect(
        topOffset("${keyPrefix}Category", "Category"),
        closeTo(topOffset("${keyPrefix}Standard", "Standard"), 0.1),
      );
    }
  });

  testWidgets("keeps the Following header content gap as the app standard", (
    tester,
  ) async {
    await tester.pumpWidget(
      _followingScreen(
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
          ],
        ),
      ),
    );

    await _logInFromMe(tester);

    final headerBottom = tester.getBottomLeft(find.byKey(const ValueKey("frosted_top_bar"))).dy;
    final firstCardTop = tester
        .getTopLeft(find.byKey(const ValueKey("stream_card_content_padding_LiveOne")))
        .dy;

    expect(firstCardTop - headerBottom, closeTo(PageHeaderLayout.headerContentGap, 0.1));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("frosted_top_bar")),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey("top_header_material")), findsOneWidget);
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
  Map<String, TwitchChannelInfo> channelInfoByBroadcasterId = const {},
}) => TwitchAuthConnection(
  user: const TwitchUser(
    id: "user-123",
    login: "flowtester",
    displayName: "Flow Tester",
  ),
  followedStreams: followedStreams,
  followedChannels: followedChannels,
  channelInfoByBroadcasterId: channelInfoByBroadcasterId,
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

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}
