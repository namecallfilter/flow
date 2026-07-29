import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("rejects OAuth callbacks with mismatched state", () {
    expect(
      () => TwitchAuthCallback.parse(
        Uri.parse("https://twitch.tv/login#access_token=token-123&state=wrong-state"),
        expectedState: "state-123",
      ),
      throwsA(isA<TwitchAuthException>()),
    );
  });

  test("completes Twitch auth and loads following data", () async {
    final store = _MemoryTwitchStore();
    final gqlAuthorizationHeaders = <String, String?>{};
    final controller = _authController(
      secureStore: store,
      cookieExtractor: const _StaticCookieExtractor("cookie-token-123"),
      gqlAuthorizationHeaders: gqlAuthorizationHeaders,
    );

    await controller.createAuthorizationUri();
    final connection = await controller.completeAuth(
      Uri.parse(
        "https://twitch.tv/login"
        "#access_token=token-123&scope=user%3Aread%3Afollows&state=state-123",
      ),
    );

    expect(store.accessToken, "token-123");
    expect(store.webSessionToken, "cookie-token-123");
    expect(store.pendingState, isNull);
    expect(connection.user.displayName, "Flow Tester");
    expect(connection.followedStreams.single.userName, "AussieAntics");
    expect(connection.followedChannels.single.broadcasterName, "NovaSkye");
    expect(gqlAuthorizationHeaders["FlowCurrentUser"], "OAuth cookie-token-123");
    expect(gqlAuthorizationHeaders["FlowFollowedLiveUsers"], "OAuth cookie-token-123");
    expect(gqlAuthorizationHeaders["FlowFollowedUsers"], "OAuth cookie-token-123");
    expect(gqlAuthorizationHeaders["FlowUsers"], isNull);
  });

  test("clears an invalid saved session", () async {
    final store = _MemoryTwitchStore()
      ..accessToken = "expired-token"
      ..webSessionToken = "expired-cookie";
    final controller = _authController(
      secureStore: store,
      validateToken: false,
    );

    expect(await controller.loadSavedConnection(), isNull);
    expect(store.accessToken, isNull);
    expect(store.webSessionToken, isNull);
  });

  test("does not replace a saved session when login is incomplete", () async {
    final store = _MemoryTwitchStore()
      ..accessToken = "saved-token"
      ..webSessionToken = "saved-cookie";
    final controller = _authController(secureStore: store);

    await controller.createAuthorizationUri();

    await expectLater(
      controller.completeAuth(
        Uri.parse(
          "https://twitch.tv/login"
          "#access_token=new-token&scope=user%3Aread%3Afollows&state=state-123",
        ),
      ),
      throwsA(isA<TwitchAuthException>()),
    );
    expect(store.accessToken, "saved-token");
    expect(store.webSessionToken, "saved-cookie");
  });

  test("restores a saved session when replacement persistence fails", () async {
    final store = _FailingNewSessionStore()
      ..accessToken = "saved-token"
      ..webSessionToken = "saved-cookie";
    final controller = _authController(
      secureStore: store,
      cookieExtractor: const _StaticCookieExtractor("cookie-token-123"),
    );

    await controller.createAuthorizationUri();

    await expectLater(
      controller.completeAuth(
        Uri.parse(
          "https://twitch.tv/login"
          "#access_token=new-token&scope=user%3Aread%3Afollows&state=state-123",
        ),
      ),
      throwsStateError,
    );
    expect(store.accessToken, "saved-token");
    expect(store.webSessionToken, "saved-cookie");
  });

  test("signs out by clearing saved credentials", () async {
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "cookie-token-123";
    final controller = _authController(secureStore: store);

    await controller.signOut();

    expect(store.accessToken, isNull);
    expect(store.webSessionToken, isNull);
  });

  test("a stale restore does not clear a newer OAuth state", () async {
    final store = _MemoryTwitchStore()
      ..accessToken = "expired-token"
      ..webSessionToken = "expired-cookie";
    final validationStarted = Completer<void>();
    final validationResponse = Completer<http.Response>();
    final controller = _authController(
      secureStore: store,
      validationStarted: validationStarted,
      validationResponse: validationResponse.future,
    );

    final restore = controller.loadSavedConnection();
    await validationStarted.future;
    await controller.createAuthorizationUri();
    validationResponse.complete(http.Response("invalid", 401));

    expect(await restore, isNull);
    expect(store.pendingState, "state-123");
    expect(store.accessToken, "expired-token");
    expect(store.webSessionToken, "expired-cookie");
  });

  test("a restore started during OAuth does not clear its pending state", () async {
    final store = _MemoryTwitchStore();
    final controller = _authController(secureStore: store);

    await controller.createAuthorizationUri();

    expect(await controller.loadSavedConnection(), isNull);
    expect(store.pendingState, "state-123");
  });

  test("canceling an in-flight login prevents credential writes", () async {
    final store = _MemoryTwitchStore();
    final validationStarted = Completer<void>();
    final validationResponse = Completer<http.Response>();
    final controller = _authController(
      secureStore: store,
      cookieExtractor: const _StaticCookieExtractor("cookie-token-123"),
      validationStarted: validationStarted,
      validationResponse: validationResponse.future,
    );

    await controller.createAuthorizationUri();
    final completion = controller.completeAuth(
      Uri.parse(
        "https://twitch.tv/login"
        "#access_token=token-123&scope=user%3Aread%3Afollows&state=state-123",
      ),
    );
    final completionExpectation = expectLater(
      completion,
      throwsA(isA<TwitchAuthException>()),
    );
    await validationStarted.future;
    await controller.cancelPendingAuth("state-123");
    validationResponse.complete(
      _jsonResponse({"client_id": "client-123", "user_id": "user-123"}),
    );

    await completionExpectation;
    expect(store.pendingState, isNull);
    expect(store.accessToken, isNull);
    expect(store.webSessionToken, isNull);
  });

  test("sign-out wins over an in-flight login", () async {
    final store = _MemoryTwitchStore();
    final validationStarted = Completer<void>();
    final validationResponse = Completer<http.Response>();
    final controller = _authController(
      secureStore: store,
      cookieExtractor: const _StaticCookieExtractor("cookie-token-123"),
      validationStarted: validationStarted,
      validationResponse: validationResponse.future,
    );

    await controller.createAuthorizationUri();
    final completion = controller.completeAuth(
      Uri.parse(
        "https://twitch.tv/login"
        "#access_token=token-123&scope=user%3Aread%3Afollows&state=state-123",
      ),
    );
    final completionExpectation = expectLater(
      completion,
      throwsA(isA<TwitchAuthException>()),
    );
    await validationStarted.future;
    await controller.signOut();
    validationResponse.complete(
      _jsonResponse({"client_id": "client-123", "user_id": "user-123"}),
    );

    await completionExpectation;
    expect(store.pendingState, isNull);
    expect(store.accessToken, isNull);
    expect(store.webSessionToken, isNull);
  });
}

TwitchAuthController _authController({
  required _MemoryTwitchStore secureStore,
  TwitchCookieExtractor cookieExtractor = const _StaticCookieExtractor(),
  Map<String, String?>? gqlAuthorizationHeaders,
  bool validateToken = true,
  Completer<void>? validationStarted,
  Future<http.Response>? validationResponse,
}) => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: secureStore,
  stateGenerator: () => "state-123",
  apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    gqlAccessToken: gqlAccessToken,
    httpClient: _authHttpClient(
      gqlAuthorizationHeaders: gqlAuthorizationHeaders,
      validateToken: validateToken,
      validationStarted: validationStarted,
      validationResponse: validationResponse,
    ),
  ),
  cookieExtractor: cookieExtractor,
);

MockClient _authHttpClient({
  Map<String, String?>? gqlAuthorizationHeaders,
  bool validateToken = true,
  Completer<void>? validationStarted,
  Future<http.Response>? validationResponse,
}) => MockClient((request) async {
  if (request.url.host == "id.twitch.tv" && request.url.path == "/oauth2/validate") {
    if (validationStarted != null && !validationStarted.isCompleted) {
      validationStarted.complete();
    }
    if (validationResponse != null) {
      return validationResponse;
    }
    return validateToken
        ? _jsonResponse({"client_id": "client-123", "user_id": "user-123"})
        : http.Response("invalid", 401);
  }

  if (request.url.host == "gql.twitch.tv") {
    final query = _graphQlQuery(request);
    final variables = _graphQlVariables(request);

    if (query.contains("FlowCurrentUser")) {
      gqlAuthorizationHeaders?["FlowCurrentUser"] = request.headers["Authorization"];
      return _jsonResponse({
        "data": {
          "currentUser": {
            "id": "user-123",
            "login": "flowtester",
            "displayName": "Flow Tester",
            "profileImageURL": "https://static-cdn.jtvnw.net/user-123.png",
          },
        },
      });
    }

    if (query.contains("FlowFollowedLiveUsers")) {
      gqlAuthorizationHeaders?["FlowFollowedLiveUsers"] = request.headers["Authorization"];
      return _jsonResponse({
        "data": {
          "currentUser": {
            "followedLiveUsers": {
              "edges": [
                {
                  "cursor": null,
                  "node": _userJson("creator-1")
                    ..["stream"] = _streamJson(
                      id: "stream-123",
                      userId: "creator-1",
                      userLogin: "aussieantics",
                      userName: "AussieAntics",
                      gameName: "Fortnite",
                      title: "DROPS ON",
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
      gqlAuthorizationHeaders?["FlowFollowedUsers"] = request.headers["Authorization"];
      return _jsonResponse({
        "data": {
          "currentUser": {
            "follows": {
              "edges": [
                {
                  "cursor": null,
                  "followedAt": "2026-07-01T00:00:00Z",
                  "node": _userJson("creator-2"),
                },
              ],
              "pageInfo": {"hasNextPage": false},
            },
          },
        },
      });
    }

    if (query.contains("FlowUsers")) {
      gqlAuthorizationHeaders?["FlowUsers"] = request.headers["Authorization"];
      final ids = (variables["ids"] as List<Object?>?)?.cast<String>() ?? const <String>[];
      return _jsonResponse({
        "data": {
          "users": [
            for (final id in ids) _userJson(id),
          ],
        },
      });
    }
  }

  return http.Response("not found", 404);
});

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
    "creator-1" => "aussieantics",
    "creator-2" => "novaskye",
    _ => id,
  };
  final displayName = switch (id) {
    "user-123" => "Flow Tester",
    "creator-1" => "AussieAntics",
    "creator-2" => "NovaSkye",
    _ => id,
  };
  return {
    "id": id,
    "login": login,
    "displayName": displayName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$id.png",
    "broadcastSettings": id == "creator-2"
        ? {
            "title": "Ranked grind",
            "game": {"id": "516575", "displayName": "VALORANT"},
          }
        : null,
    "stream": null,
  };
}

Map<String, Object?> _streamJson({
  required String id,
  required String userId,
  required String userLogin,
  required String userName,
  required String gameName,
  required String title,
  required int viewerCount,
}) => {
  "id": id,
  "createdAt": "2026-07-01T00:00:00Z",
  "freeformTags": const <Object?>[],
  "game": {"id": "33214", "displayName": gameName},
  "previewImageURL":
      "https://static-cdn.jtvnw.net/previews-ttv/live_user_$userLogin-{width}x{height}.jpg",
  "viewersCount": viewerCount,
  "broadcaster": {
    "id": userId,
    "login": userLogin,
    "displayName": userName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$userId.png",
    "broadcastSettings": {"title": title},
  },
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
  Future<void> clearSession() async {
    accessToken = null;
    pendingState = null;
    webSessionToken = null;
  }

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

class _FailingNewSessionStore extends _MemoryTwitchStore {
  var _hasFailed = false;

  @override
  Future<void> saveWebSessionToken(String token) async {
    if (!_hasFailed && token == "cookie-token-123") {
      _hasFailed = true;
      throw StateError("Secure storage is unavailable.");
    }
    await super.saveWebSessionToken(token);
  }
}

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor([this.token]);

  final String? token;

  @override
  Future<String?> extractTwitchAuthToken() async => token;
}
