import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/player/player_controller.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

import "../../helpers/fake_flow_video_controller.dart";

void main() {
  setUp(() {
    debugSetFlowVideoControllerFactory(FakeFlowVideoController.new);
  });

  tearDown(debugResetFlowVideoControllerFactory);

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

  testWidgets("opens channel pages from live identity and offline rows", (
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

    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("stream_thumbnail_LiveOne")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("player_page_liveone")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_page_liveone")), findsNothing);

    Navigator.of(tester.element(find.byKey(const ValueKey("player_page_liveone")))).pop();
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

    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    final headerBottom = tester.getBottomLeft(find.byKey(const ValueKey("frosted_top_bar"))).dy;
    final firstCardTop = tester
        .getTopLeft(find.byKey(const ValueKey("stream_card_content_padding_LiveOne")))
        .dy;

    expect(firstCardTop - headerBottom, closeTo(PageHeaderLayout.headerContentGap, 0.1));
  });
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

TwitchAuthController _authController() => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: _MemoryTwitchStore(),
  apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
    clientId: "client-123",
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
      final query = body["query"]?.toString() ?? "";
      if (query.contains("FlowPlaybackAccessToken")) {
        return _livePlaybackResponse();
      }

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

http.Response _livePlaybackResponse() => http.Response(
  jsonEncode({
    "data": {
      "streamPlaybackAccessToken": {
        "value": "token-value",
        "signature": "sig-value",
        "authorization": {"isForbidden": false},
      },
    },
  }),
  200,
  headers: {"content-type": "application/json"},
);

class _MemoryTwitchStore implements TwitchSecureStore {
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

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}
