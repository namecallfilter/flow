import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/app.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "../../helpers/twitch_fakes.dart";

void main() {
  testWidgets("renders an empty following feed before Twitch auth", (tester) async {
    await tester.pumpWidget(const FlowApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    expect(find.text("No followed channels are live now."), findsOneWidget);
    expect(find.text("No offline followed channels."), findsOneWidget);
    expect(find.byType(StreamCard), findsNothing);
  });

  testWidgets("shows a setup message when Twitch auth is not configured", (
    tester,
  ) async {
    var openedLogin = false;

    await tester.pumpWidget(
      _followingScreen(
        authController: _authController(
          config: const TwitchAuthConfig(clientId: ""),
        ),
        openTwitchLogin: (_, _) async {
          openedLogin = true;
          return null;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pump();

    expect(openedLogin, isFalse);
    expect(find.textContaining("TWITCH_CLIENT_ID"), findsOneWidget);
  });

  testWidgets("profile avatar opens Twitch login and confirms the connected user", (
    tester,
  ) async {
    var openedLogin = false;

    await tester.pumpWidget(
      _followingScreen(
        openTwitchLogin: (context, controller) async {
          openedLogin = true;
          return _connection();
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pump();

    expect(openedLogin, isTrue);
    expect(find.textContaining("Connected as Flow Tester"), findsOneWidget);
  });

  testWidgets("pull to refresh reloads saved following data", (tester) async {
    var followedStreamsRequests = 0;
    final store = FakeTwitchSecureStore()..accessToken = "token-123";

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

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(followedStreamsRequests, 1);

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(followedStreamsRequests, 2);
  });

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
              tags: ["English"],
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
    expect(find.text("321"), findsOneWidget);
    expect(find.text("Minecraft"), findsOneWidget);
    expect(find.byTooltip("Expand Offline"), findsOneWidget);
    expect(find.text("OfflineOne"), findsNothing);

    await tester.tap(find.byKey(const ValueKey("offline_toggle")));
    await tester.pumpAndSettle();

    expect(find.text("OfflineOne"), findsOneWidget);
    expect(find.text("Just Chatting"), findsOneWidget);
  });

  testWidgets("starts offline expanded when no followed channels are live", (
    tester,
  ) async {
    await tester.pumpWidget(
      _followingScreen(
        openTwitchLogin: (_, _) async => _connection(
          followedChannels: const [
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

    expect(find.text("No followed channels are live now."), findsNothing);
    expect(find.byTooltip("Collapse Offline"), findsOneWidget);
    expect(find.text("OfflineOne"), findsOneWidget);
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
  TwitchAuthConfig config = const TwitchAuthConfig(clientId: "client-123"),
  FakeTwitchSecureStore? secureStore,
  RequestObserver? onRequest,
}) => TwitchAuthController(
  config: config,
  secureStore: secureStore ?? FakeTwitchSecureStore(),
  apiClientFactory: (accessToken) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    httpClient: fakeTwitchApiClient(onRequest: onRequest),
  ),
  cookieExtractor: const FakeCookieExtractor(),
);

TwitchAuthConnection _connection({
  List<TwitchFollowedStream> followedStreams = const [],
  List<TwitchFollowedChannel> followedChannels = const [],
  Map<String, TwitchUser> usersById = const {},
  Map<String, TwitchChannelInfo> channelInfoByBroadcasterId = const {},
}) => TwitchAuthConnection(
  user: const TwitchUser(
    id: "user-123",
    login: "flowtester",
    displayName: "Flow Tester",
  ),
  followedStreams: followedStreams,
  followedChannels: followedChannels,
  usersById: usersById,
  channelInfoByBroadcasterId: channelInfoByBroadcasterId,
);
