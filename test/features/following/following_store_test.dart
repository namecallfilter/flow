import "dart:convert";

import "package:flow/api/twitch_api.dart";
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
          if (request.url.path == "/helix/streams/followed") {
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
}

TwitchAuthController _authController({_RequestObserver? onRequest}) {
  final secureStore = _MemoryTwitchStore()..accessToken = "token-123";
  return TwitchAuthController(
    config: const TwitchAuthConfig(clientId: "client-123"),
    secureStore: secureStore,
    apiClientFactory: (accessToken) => TwitchApiClient(
      clientId: "client-123",
      accessToken: accessToken,
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

  if (request.url.path == "/helix/users") {
    final ids = request.url.queryParametersAll["id"];
    if (ids != null) {
      return _jsonResponse({
        "data": [
          for (final id in ids)
            {
              "id": id,
              "login": "aussieantics",
              "display_name": "AussieAntics",
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
        {
          "id": "stream-123",
          "user_id": "creator-1",
          "user_login": "aussieantics",
          "user_name": "AussieAntics",
          "game_name": "Fortnite",
          "title": "DROPS ON",
          "viewer_count": 10706,
          "thumbnail_url":
              "https://static-cdn.jtvnw.net/previews-ttv/live_user_aussieantics-{width}x{height}.jpg",
        },
      ],
    });
  }

  if (request.url.path == "/helix/channels/followed") {
    return _jsonResponse({"data": <Object?>[]});
  }

  return http.Response("not found", 404);
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

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}
