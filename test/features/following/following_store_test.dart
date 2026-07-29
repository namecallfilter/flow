import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/features/following/following_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  test("keeps saved following data in memory until refresh", () async {
    var followedRequests = 0;
    final store = FollowingStore(
      authController: _authController(
        onRequest: (request) {
          if (_isGraphQlOperation(request, "FlowFollowedLiveUsers")) {
            followedRequests++;
          }
        },
      ),
    );

    await store.loadSavedConnection();
    await store.loadSavedConnection();

    expect(store.connection?.user.displayName, "Flow Tester");
    expect(store.liveChannels.single.name, "AussieAntics");
    expect(followedRequests, 1);

    await store.loadSavedConnection(refresh: true);

    expect(followedRequests, 2);
  });

  test("does not clear the shared API cache during a Following refresh", () async {
    final apiCache = _TrackingApiCache();
    final store = FollowingStore(
      authController: _authController(),
      apiCache: apiCache,
    );

    await store.loadSavedConnection();
    await store.loadSavedConnection(refresh: true);

    expect(apiCache.clearCount, 0);
  });
}

TwitchAuthController _authController({_RequestObserver? onRequest}) {
  final secureStore = _MemoryTwitchStore()
    ..accessToken = "token-123"
    ..webSessionToken = "gql-token-123";
  return TwitchAuthController(
    config: const TwitchAuthConfig(clientId: "client-123"),
    secureStore: secureStore,
    apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
      clientId: "client-123",
      accessToken: accessToken,
      gqlAccessToken: gqlAccessToken,
      httpClient: _followingHttpClient(onRequest: onRequest),
    ),
    cookieExtractor: const _StaticCookieExtractor(),
  );
}

MockClient _followingHttpClient({_RequestObserver? onRequest}) => MockClient((request) async {
  onRequest?.call(request);

  if (request.url.host == "id.twitch.tv" && request.url.path == "/oauth2/validate") {
    return _jsonResponse({"client_id": "client-123", "user_id": "user-123"});
  }

  if (request.url.host == "gql.twitch.tv") {
    final query = _graphQlQuery(request);
    final variables = _graphQlVariables(request);

    if (query.contains("FlowCurrentUser")) {
      return _jsonResponse({
        "data": {
          "currentUser": _userJson("user-123"),
        },
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
    "creator-1" => "aussieantics",
    _ => id,
  };
  final displayName = switch (id) {
    "user-123" => "Flow Tester",
    "creator-1" => "AussieAntics",
    _ => id,
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
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}

class _TrackingApiCache extends TwitchApiCache {
  _TrackingApiCache()
    : super(
        clientLoader: () async => throw StateError("API cache should not load"),
      );

  int clearCount = 0;

  @override
  void clear() {
    clearCount++;
  }
}
