import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
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

    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pump();

    expect(find.text("LiveOne"), findsOneWidget);
    expect(find.text("Building with chat"), findsOneWidget);
    expect(find.text("OfflineOne"), findsNothing);

    await tester.tap(find.byKey(const ValueKey("offline_toggle")));
    await tester.pumpAndSettle();

    expect(find.text("OfflineOne"), findsOneWidget);
    expect(find.text("Just Chatting"), findsOneWidget);
  });

  testWidgets("pull to refresh reloads saved following data", (tester) async {
    var followedStreamsRequests = 0;
    final store = _MemoryTwitchStore()..accessToken = "token-123";

    await tester.pumpWidget(
      _followingScreen(
        authController: _authController(
          secureStore: store,
          onRequest: (request) {
            if (request.url.path == "/helix/streams/followed") {
              followedStreamsRequests++;
            }
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(followedStreamsRequests, 1);

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(followedStreamsRequests, 2);
  });
}

Widget _followingScreen({
  TwitchAuthController? authController,
  TwitchLoginOpener? openTwitchLogin,
}) => MaterialApp(
  home: FollowingScreen(
    authController: authController ?? _authController(),
    openTwitchLogin: openTwitchLogin,
  ),
);

TwitchAuthController _authController({
  _MemoryTwitchStore? secureStore,
  _RequestObserver? onRequest,
}) => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: secureStore ?? _MemoryTwitchStore(),
  apiClientFactory: (accessToken) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    httpClient: _followingHttpClient(onRequest: onRequest),
  ),
  cookieExtractor: const _StaticCookieExtractor(),
);

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
