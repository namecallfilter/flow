import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/tabs_screen.dart";
import "package:flow/app/tabs_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  testWidgets("keeps Browse section and scroll state when switching tabs", (
    tester,
  ) async {
    var topCategoriesRequests = 0;
    var topLiveStreamsRequests = 0;
    var followedLiveRequests = 0;
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: store,
            onRequest: (request) {
              if (_isGraphQlOperation(request, "FlowTopGames") &&
                  _graphQlVariables(request)["after"] == null) {
                topCategoriesRequests++;
              }
              if (_isGraphQlOperation(request, "FlowTopStreams") &&
                  _graphQlVariables(request)["after"] == null) {
                topLiveStreamsRequests++;
              }
              if (_isGraphQlOperation(request, "FlowFollowedLiveUsers")) {
                followedLiveRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(followedLiveRequests, 1);
    expect(topCategoriesRequests, 1);
    expect(topLiveStreamsRequests, 1);
    expect(
      find.byKey(const ValueKey("browse_title"), skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    expect(topCategoriesRequests, 1);

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();
    expect(topLiveStreamsRequests, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_live_channels")), findsOneWidget);
    expect(find.text("NextStreamer"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_live_channels")), findsOneWidget);
    expect(find.text("NextStreamer"), findsOneWidget);
    expect(topCategoriesRequests, 1);
    expect(topLiveStreamsRequests, 1);
    expect(followedLiveRequests, 1);
  });

  testWidgets("refreshes Following and Browse roots while hidden and on resume", (
    tester,
  ) async {
    var topCategoriesRequests = 0;
    var topLiveStreamsRequests = 0;
    var followedLiveRequests = 0;
    var categoryStreamsRequests = 0;
    var channelDetailsRequests = 0;
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: store,
            onRequest: (request) {
              if (_isGraphQlOperation(request, "FlowTopGames") &&
                  _graphQlVariables(request)["after"] == null) {
                topCategoriesRequests++;
              }
              if (_isGraphQlOperation(request, "FlowTopStreams") &&
                  _graphQlVariables(request)["after"] == null) {
                topLiveStreamsRequests++;
              }
              if (_isGraphQlOperation(request, "FlowFollowedLiveUsers")) {
                followedLiveRequests++;
              }
              if (_isGraphQlOperation(request, "FlowGameStreams")) {
                categoryStreamsRequests++;
              }
              if (_isGraphQlOperation(request, "FlowChannelDetails")) {
                channelDetailsRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(topCategoriesRequests, 1);
    expect(topLiveStreamsRequests, 1);
    expect(followedLiveRequests, 1);
    expect(categoryStreamsRequests, 0);
    expect(channelDetailsRequests, 0);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(topCategoriesRequests, 2);
    expect(topLiveStreamsRequests, 2);
    expect(followedLiveRequests, 2);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(topCategoriesRequests, 3);
    expect(topLiveStreamsRequests, 3);
    expect(followedLiveRequests, 3);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(topCategoriesRequests, 3);
    expect(topLiveStreamsRequests, 3);
    expect(followedLiveRequests, 3);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(topCategoriesRequests, 4);
    expect(topLiveStreamsRequests, 4);
    expect(followedLiveRequests, 4);
    expect(categoryStreamsRequests, 0);
    expect(channelDetailsRequests, 0);
  });

  testWidgets("keeps Browse category route when switching tabs", (tester) async {
    var categoryStreamsRequests = 0;
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: store,
            onRequest: (request) {
              if (_isGraphQlOperation(request, "FlowGameStreams")) {
                categoryStreamsRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_category_card_Just Chatting")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    final categoryStreamsRequestsAfterOpen = categoryStreamsRequests;
    expect(categoryStreamsRequestsAfterOpen, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsNothing);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    expect(categoryStreamsRequests, categoryStreamsRequestsAfterOpen);
  });

  testWidgets(
    "predictive back previews Following and leaves Following to Android",
    (
      tester,
    ) async {
      final store = _MemoryTwitchStore()
        ..accessToken = "token-123"
        ..webSessionToken = "gql-token-123";
      final tabsStore = TabsStore();
      final backPlatform = _BackPlatformSpy();
      await backPlatform.install(tester);
      addTearDown(backPlatform.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.light),
          home: FlowTabsScreen(
            authController: _authController(secureStore: store),
            tabsStore: tabsStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(backPlatform.frameworkHandlesBack, isFalse);

      for (final entry in {
        "Browse": const ValueKey("browse_title"),
        "Settings": const ValueKey("settings_title"),
      }.entries) {
        final tab = entry.key;
        await tester.tap(find.byKey(ValueKey("bottom_nav_item_$tab")));
        await tester.pumpAndSettle();

        final title = find.byKey(entry.value);
        final initialTitleX = tester.getTopLeft(title).dx;
        expect(backPlatform.frameworkHandlesBack, isTrue);
        expect(await _startBackGesture(tester), isTrue);
        await tester.pump();
        expect(find.byKey(const ValueKey("predictive_tab_back_transition")), findsOneWidget);

        await _updateBackGesture(tester, progress: 0.45);
        await tester.pump();
        expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
        expect(title, findsOneWidget);
        expect(tester.getTopLeft(title).dx, greaterThan(initialTitleX));

        await _sendBackGestureMessage(tester, const MethodCall("cancelBackGesture"));
        await tester.pump();
        expect(find.byKey(const ValueKey("predictive_tab_back_transition")), findsNothing);
        expect(title, findsOneWidget);
        expect(tester.getTopLeft(title).dx, closeTo(initialTitleX, 0.01));
        expect(backPlatform.frameworkHandlesBack, isTrue);

        expect(await _startBackGesture(tester), isTrue);
        await tester.pump();
        await _updateBackGesture(tester, progress: 0.08);
        await tester.pump();
        await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
        expect(tabsStore.currentRoute, FlowRoutes.following);
        await tester.pump();
        expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
        await tester.pumpAndSettle();
        expect(backPlatform.frameworkHandlesBack, isFalse);
      }

      expect(await _startBackGesture(tester), isFalse);
      backPlatform.systemPops = 0;
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pump();
      expect(backPlatform.systemPops, 1);
      expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    "predictive back only changes the active retained tab stack",
    (tester) async {
      final store = _MemoryTwitchStore()
        ..accessToken = "token-123"
        ..webSessionToken = "gql-token-123";
      final backPlatform = _BackPlatformSpy();
      await backPlatform.install(tester);
      addTearDown(backPlatform.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.light),
          home: FlowTabsScreen(
            authController: _authController(secureStore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey("stream_channel_identity_AussieAntics")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("browse_category_card_Just Chatting")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
      await tester.pumpAndSettle();
      expect(backPlatform.frameworkHandlesBack, isTrue);

      final hiddenFollowingChannel = find.byKey(
        const ValueKey("channel_page_aussieantics"),
        skipOffstage: false,
      );
      final hiddenBrowseCategory = find.byKey(
        const ValueKey("category_streams_page_Just Chatting"),
        skipOffstage: false,
      );
      final followingNavigator = Navigator.of(tester.element(hiddenFollowingChannel));
      final browseNavigator = Navigator.of(tester.element(hiddenBrowseCategory));

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      expect(followingNavigator.userGestureInProgress, isFalse);
      expect(browseNavigator.userGestureInProgress, isFalse);
      await _updateBackGesture(tester, progress: 0.4);
      await tester.pump();
      await _sendBackGestureMessage(tester, const MethodCall("cancelBackGesture"));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
      expect(hiddenFollowingChannel, findsOneWidget);
      expect(hiddenBrowseCategory, findsOneWidget);

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      await _updateBackGesture(tester, progress: 0.4);
      await tester.pump();
      await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsOneWidget);
      expect(hiddenBrowseCategory, findsOneWidget);
      expect(backPlatform.frameworkHandlesBack, isTrue);

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      expect(followingNavigator.userGestureInProgress, isTrue);
      expect(browseNavigator.userGestureInProgress, isFalse);
      await _updateBackGesture(tester, progress: 0.4);
      await tester.pump();
      await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
      expect(hiddenFollowingChannel, findsNothing);
      expect(hiddenBrowseCategory, findsOneWidget);
      expect(backPlatform.frameworkHandlesBack, isFalse);

      await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      expect(browseNavigator.userGestureInProgress, isTrue);
      await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("browse_title")), findsOneWidget);
      expect(backPlatform.frameworkHandlesBack, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets("does not reload settings preferences when navigating to Settings", (
    tester,
  ) async {
    final preferencesStore = _CountingPreferencesStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: _MemoryTwitchStore()),
          settingsStore: AppSettingsStore(
            preferences: SharedPreferencesFlowPreferences(store: preferencesStore),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialReadCount = preferencesStore.readCount;
    expect(initialReadCount, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
    await tester.pumpAndSettle();

    expect(preferencesStore.readCount, initialReadCount);
  });
}

Future<Object?> _startBackGesture(WidgetTester tester) => _sendBackGestureMessage(
  tester,
  const MethodCall("startBackGesture", <String, dynamic>{
    "touchOffset": <double>[5, 300],
    "progress": 0.0,
    "swipeEdge": 0,
  }),
);

Future<Object?> _updateBackGesture(
  WidgetTester tester, {
  required double progress,
}) => _sendBackGestureMessage(
  tester,
  MethodCall("updateBackGestureProgress", <String, dynamic>{
    "touchOffset": const <double>[120, 300],
    "progress": progress,
    "swipeEdge": 0,
  }),
);

Future<Object?> _sendBackGestureMessage(
  WidgetTester tester,
  MethodCall methodCall,
) async {
  ByteData? response;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    "flutter/backgesture",
    const StandardMethodCodec().encodeMethodCall(methodCall),
    (data) => response = data,
  );
  return response == null ? null : const StandardMethodCodec().decodeEnvelope(response!);
}

class _BackPlatformSpy {
  final _frameworkHandlesBackValues = <bool>[];
  late final TestDefaultBinaryMessenger _messenger;
  int systemPops = 0;

  bool get frameworkHandlesBack => _frameworkHandlesBackValues.last;

  Future<void> install(WidgetTester tester) async {
    _messenger = tester.binding.defaultBinaryMessenger;
    _messenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) {
      switch (methodCall.method) {
        case "SystemNavigator.setFrameworkHandlesBack":
          _frameworkHandlesBackValues.add(methodCall.arguments! as bool);
          break;
        case "SystemNavigator.pop":
          systemPops++;
          break;
      }
      return Future<void>.value();
    });
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      "flutter/lifecycle",
      const StringCodec().encodeMessage("AppLifecycleState.resumed"),
      (_) {},
    );
  }

  void dispose() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  }
}

TwitchAuthController _authController({
  required _MemoryTwitchStore secureStore,
  _RequestObserver? onRequest,
}) => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: secureStore,
  apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    gqlAccessToken: gqlAccessToken,
    httpClient: _flowHttpClient(onRequest: onRequest),
  ),
  cookieExtractor: const _StaticCookieExtractor(),
);

MockClient _flowHttpClient({_RequestObserver? onRequest}) => MockClient((request) async {
  onRequest?.call(request);

  if (request.url.host == "id.twitch.tv" && request.url.path == "/oauth2/validate") {
    return _jsonResponse({"client_id": "client-123", "user_id": "user-123"});
  }

  if (request.url.host == "gql.twitch.tv") {
    final query = _graphQlQuery(request);
    final variables = _graphQlVariables(request);

    if (query.contains("FlowCurrentUser")) {
      return _jsonResponse({
        "data": {"currentUser": _userJson("user-123")},
      });
    }

    if (query.contains("FlowFollowedLiveUsers")) {
      return _jsonResponse({
        "data": {
          "currentUser": {
            "followedLiveUsers": {
              "edges": [
                {
                  "cursor": null,
                  "node": _userJson("creator-1")
                    ..["stream"] = _streamJson(
                      id: "followed-stream",
                      userId: "creator-1",
                      userLogin: "aussieantics",
                      userName: "AussieAntics",
                      gameName: "Fortnite",
                      viewerCount: 10706,
                    ),
                },
              ],
              "pageInfo": {"hasNextPage": false},
            },
          },
        },
      });
    }

    if (query.contains("FlowFollowedUsers")) {
      return _jsonResponse({
        "data": {
          "currentUser": {
            "follows": {
              "edges": const <Object?>[],
              "pageInfo": {"hasNextPage": false},
            },
          },
        },
      });
    }

    if (query.contains("FlowUsers")) {
      final ids = (variables["ids"] as List<Object?>?)?.cast<String>() ?? const <String>[];
      return _jsonResponse({
        "data": {
          "users": [
            for (final id in ids) _userJson(id),
          ],
        },
      });
    }

    if (query.contains("FlowTopGames")) {
      return _jsonResponse({
        "data": {
          "games": {
            "edges": [
              {
                "cursor": null,
                "node": {
                  "id": "509658",
                  "displayName": "Just Chatting",
                  "boxArtURL":
                      "https://static-cdn.jtvnw.net/ttv-boxart/509658-{width}x{height}.jpg",
                },
              },
            ],
            "pageInfo": {"hasNextPage": false},
          },
        },
      });
    }

    if (query.contains("FlowGameStreams")) {
      return _gameStreamsResponse(const <Map<String, Object?>>[]);
    }

    if (query.contains("FlowTopStreams")) {
      if (variables["after"] == "stream-page-2") {
        return _streamConnectionResponse([
          _streamJson(
            id: "stream-124",
            userId: "creator-5",
            userLogin: "nextstreamer",
            userName: "NextStreamer",
            gameName: "VALORANT",
            viewerCount: 1900,
          ),
        ]);
      }
      return _streamConnectionResponse(
        [
          for (var index = 0; index < 20; index++)
            _streamJson(
              id: "stream-$index",
              userId: "creator-$index",
              userLogin: "streamer$index",
              userName: "Streamer$index",
              gameName: "Just Chatting",
              viewerCount: 9000 - index,
            ),
        ],
        cursor: "stream-page-2",
      );
    }
  }

  return http.Response("not found", 404);
});

bool _isGraphQlOperation(http.Request request, String operationName) =>
    request.url.host == "gql.twitch.tv" && request.body.contains(operationName);

String _graphQlQuery(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return body["query"]! as String;
}

Map<String, Object?> _graphQlVariables(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
}

Map<String, Object?> _userJson(String id) {
  final login = switch (id) {
    "user-123" => "flowtester",
    "creator-5" => "nextstreamer",
    _ => "aussieantics",
  };
  final displayName = switch (id) {
    "user-123" => "Flow Tester",
    "creator-5" => "NextStreamer",
    _ => "AussieAntics",
  };
  return {
    "id": id,
    "login": login,
    "displayName": displayName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$id.png",
    "broadcastSettings": null,
    "stream": null,
  };
}

Map<String, Object?> _streamJson({
  required String id,
  required String userId,
  required String userLogin,
  required String userName,
  required String gameName,
  required int viewerCount,
}) => {
  "id": id,
  "broadcaster": {
    "id": userId,
    "login": userLogin,
    "displayName": userName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$userId.png",
    "broadcastSettings": {"title": "Live from GraphQL"},
  },
  "createdAt": "2026-07-01T00:00:00Z",
  "freeformTags": const <Object?>[],
  "game": {"id": "game-$gameName", "displayName": gameName},
  "previewImageURL":
      "https://static-cdn.jtvnw.net/previews-ttv/live_user_$userLogin-{width}x{height}.jpg",
  "viewersCount": viewerCount,
};

http.Response _streamConnectionResponse(
  List<Map<String, Object?>> streams, {
  String? cursor,
}) => _jsonResponse({
  "data": {
    "streams": {
      "edges": [
        for (final stream in streams) {"cursor": cursor, "node": stream},
      ],
      "pageInfo": {"hasNextPage": cursor != null},
    },
  },
});

http.Response _gameStreamsResponse(
  List<Map<String, Object?>> streams,
) => _jsonResponse({
  "data": {
    "game": {
      "streams": {
        "edges": [
          for (final stream in streams) {"cursor": null, "node": stream},
        ],
        "pageInfo": {"hasNextPage": false},
      },
    },
  },
});

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

class _MemoryTwitchStore implements TwitchSecureStore {
  String? accessToken;
  String? pendingState;
  String? webSessionToken;

  @override
  Future<void> clearPendingState() async {
    pendingState = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readPendingState() async => pendingState;

  @override
  Future<String?> readWebSessionToken() async => webSessionToken;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> savePendingState(String state) async {
    pendingState = state;
  }

  @override
  Future<void> saveWebSessionToken(String token) async {
    webSessionToken = token;
  }
}

class _CountingPreferencesStore implements FlowPreferencesStore {
  int readCount = 0;

  @override
  Future<String?> getString(String key) async {
    readCount++;
    return null;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    readCount++;
    return null;
  }

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> setString(String key, String value) async {}

  @override
  Future<void> setStringList(String key, List<String> value) async {}
}

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}
