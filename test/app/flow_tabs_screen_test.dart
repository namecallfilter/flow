import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/flow_tabs_screen.dart";
import "package:flow/app/theme.dart";
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
    final store = _MemoryTwitchStore()..accessToken = "token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: store,
            onRequest: (request) {
              if (request.url.path == "/helix/games/top" &&
                  !request.url.queryParameters.containsKey("after")) {
                topCategoriesRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    expect(topCategoriesRequests, 1);

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();
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
  });

  testWidgets("switching to Following closes Browse search and Browse", (
    tester,
  ) async {
    final store = _MemoryTwitchStore()..accessToken = "token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(authController: _authController(secureStore: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_title")), findsNothing);
    expect(find.byKey(const ValueKey("browse_search_page")), findsNothing);
  });

  testWidgets("switching to Settings from Browse search removes Browse underneath", (
    tester,
  ) async {
    final store = _MemoryTwitchStore()..accessToken = "token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(authController: _authController(secureStore: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_title")), findsNothing);
    expect(find.byKey(const ValueKey("browse_search_page")), findsNothing);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_title")), findsNothing);
    expect(find.byKey(const ValueKey("settings_title")), findsNothing);
  });
}

TwitchAuthController _authController({
  required _MemoryTwitchStore secureStore,
  _RequestObserver? onRequest,
}) => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: secureStore,
  apiClientFactory: (accessToken) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    httpClient: _flowHttpClient(onRequest: onRequest),
  ),
  cookieExtractor: const _StaticCookieExtractor(),
);

MockClient _flowHttpClient({_RequestObserver? onRequest}) => MockClient((request) async {
  onRequest?.call(request);

  if (request.url.host == "id.twitch.tv" && request.url.path == "/oauth2/validate") {
    return _jsonResponse({"client_id": "client-123", "user_id": "user-123"});
  }

  if (request.url.path == "/helix/users") {
    final ids = request.url.queryParametersAll["id"];
    if (ids != null) {
      return _jsonResponse({
        "data": [
          for (final id in ids)
            {
              "id": id,
              "login": id == "creator-5" ? "nextstreamer" : "aussieantics",
              "display_name": id == "creator-5" ? "NextStreamer" : "AussieAntics",
              "profile_image_url": "https://static-cdn.jtvnw.net/$id.png",
            },
        ],
      });
    }
    return _jsonResponse({
      "data": [
        {"id": "user-123", "login": "flowtester", "display_name": "Flow Tester"},
      ],
    });
  }

  if (request.url.path == "/helix/streams/followed") {
    return _jsonResponse({
      "data": [
        _streamJson(
          id: "followed-stream",
          userId: "creator-1",
          userLogin: "aussieantics",
          userName: "AussieAntics",
          gameName: "Fortnite",
          viewerCount: 10706,
        ),
      ],
    });
  }

  if (request.url.path == "/helix/channels/followed") {
    return _jsonResponse({"data": <Object?>[]});
  }

  if (request.url.path == "/helix/games/top") {
    return _jsonResponse({
      "data": [
        {
          "id": "509658",
          "name": "Just Chatting",
          "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/509658-{width}x{height}.jpg",
        },
      ],
    });
  }

  if (request.url.path == "/helix/streams") {
    if ((request.url.queryParametersAll["game_id"] ?? const <String>[]).isNotEmpty) {
      return _jsonResponse({"data": <Object?>[]});
    }
    if (request.url.queryParameters["after"] == "stream-page-2") {
      return _jsonResponse({
        "data": [
          _streamJson(
            id: "stream-124",
            userId: "creator-5",
            userLogin: "nextstreamer",
            userName: "NextStreamer",
            gameName: "VALORANT",
            viewerCount: 1900,
          ),
        ],
      });
    }
    return _jsonResponse({
      "data": [
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
      "pagination": {"cursor": "stream-page-2"},
    });
  }

  return http.Response("not found", 404);
});

Map<String, Object?> _streamJson({
  required String id,
  required String userId,
  required String userLogin,
  required String userName,
  required String gameName,
  required int viewerCount,
}) => {
  "id": id,
  "user_id": userId,
  "user_login": userLogin,
  "user_name": userName,
  "game_name": gameName,
  "title": "Live from Helix",
  "viewer_count": viewerCount,
  "thumbnail_url":
      "https://static-cdn.jtvnw.net/previews-ttv/live_user_$userLogin-{width}x{height}.jpg",
};

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

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}
