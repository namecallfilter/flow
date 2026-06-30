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
    final controller = _authController(
      secureStore: store,
      cookieExtractor: const _StaticCookieExtractor("cookie-token-123"),
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
  });
}

TwitchAuthController _authController({
  required _MemoryTwitchStore secureStore,
  TwitchCookieExtractor cookieExtractor = const _StaticCookieExtractor(),
}) => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: secureStore,
  stateGenerator: () => "state-123",
  apiClientFactory: (accessToken) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    httpClient: _authHttpClient(),
  ),
  cookieExtractor: cookieExtractor,
);

MockClient _authHttpClient() => MockClient((request) async {
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
    return _jsonResponse({
      "data": [
        {
          "broadcaster_id": "creator-2",
          "broadcaster_login": "novaskye",
          "broadcaster_name": "NovaSkye",
        },
      ],
    });
  }

  if (request.url.path == "/helix/channels") {
    return _jsonResponse({
      "data": [
        {
          "broadcaster_id": "creator-2",
          "broadcaster_name": "NovaSkye",
          "game_name": "VALORANT",
          "title": "Ranked grind",
        },
      ],
    });
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
  const _StaticCookieExtractor([this.token]);

  final String? token;

  @override
  Future<String?> extractTwitchAuthToken() async => token;
}
