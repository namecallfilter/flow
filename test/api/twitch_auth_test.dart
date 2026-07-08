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

  test("refreshes stale GraphQL web-session token while loading saved auth", () async {
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "stale-cookie-token";
    final currentUserAuthorizationHeaders = <String?>[];
    final controller = _authController(
      secureStore: store,
      cookieExtractor: const _StaticCookieExtractor("fresh-cookie-token"),
      currentUserAuthorizationHeaders: currentUserAuthorizationHeaders,
      invalidGqlAuthorization: "OAuth stale-cookie-token",
    );

    final connection = await controller.loadSavedConnection();

    expect(connection, isNotNull);
    expect(connection!.user.displayName, "Flow Tester");
    expect(store.webSessionToken, "fresh-cookie-token");
    expect(currentUserAuthorizationHeaders, [
      "OAuth stale-cookie-token",
      "OAuth fresh-cookie-token",
    ]);
  });
}

TwitchAuthController _authController({
  required _MemoryTwitchStore secureStore,
  TwitchCookieExtractor cookieExtractor = const _StaticCookieExtractor(),
  Map<String, String?>? gqlAuthorizationHeaders,
  List<String?>? currentUserAuthorizationHeaders,
  String? invalidGqlAuthorization,
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
      currentUserAuthorizationHeaders: currentUserAuthorizationHeaders,
      invalidGqlAuthorization: invalidGqlAuthorization,
    ),
  ),
  cookieExtractor: cookieExtractor,
);

MockClient _authHttpClient({
  Map<String, String?>? gqlAuthorizationHeaders,
  List<String?>? currentUserAuthorizationHeaders,
  String? invalidGqlAuthorization,
}) => MockClient((request) async {
  if (request.url.host == "id.twitch.tv" && request.url.path == "/oauth2/validate") {
    return _jsonResponse({"client_id": "client-123", "user_id": "user-123"});
  }

  if (request.url.host == "gql.twitch.tv") {
    final query = _graphQlQuery(request);
    final variables = _graphQlVariables(request);

    if (query.contains("FlowCurrentUser")) {
      final authorization = request.headers["Authorization"];
      gqlAuthorizationHeaders?["FlowCurrentUser"] = authorization;
      currentUserAuthorizationHeaders?.add(authorization);
      if (authorization == invalidGqlAuthorization) {
        return _jsonResponse({
          "errors": [
            {"message": "Unauthorized"},
          ],
        });
      }
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
  const _StaticCookieExtractor([this.token]);

  final String? token;

  @override
  Future<String?> extractTwitchAuthToken() async => token;
}
