import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/tabs_screen.dart";
import "package:flow/app/theme.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
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

  testWidgets("allows predictive back from Browse and Settings to Following", (
    tester,
  ) async {
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ["Browse", "Settings"]) {
      await tester.tap(find.byKey(ValueKey("bottom_nav_item_$tab")));
      await tester.pumpAndSettle();

      expect(tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey("bottom_nav_item_Following")),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    }
  });

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
