import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/player_controller.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

import "../../helpers/fake_flow_video_controller.dart";

void main() {
  setUp(() {
    debugSetFlowVideoControllerFactory(FakeFlowVideoController.new);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    debugResetFlowVideoControllerFactory();
  });

  testWidgets("loads playback and renders the video surface", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: _playbackApiCache(),
          channel: _channel(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_page_jason")), findsOneWidget);
    expect(
      find.byKey(const ValueKey("fake_video_/api/v2/channel/hls/jason.m3u8")),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey("player_stream_elapsed")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_latency")), findsOneWidget);
    expect(find.text("2.88s"), findsOneWidget);
    expect(find.byKey(const ValueKey("player_chat_reserved_area")), findsOneWidget);
    expect(find.text("Live with chat"), findsOneWidget);
    expect(find.text("Just Chatting"), findsOneWidget);
    expect(find.byKey(const ValueKey("player_stream_category_icon")), findsOneWidget);
    expect(find.text("Just Chatting with 26.3K viewers"), findsNothing);
    expect(find.byKey(const ValueKey("player_chat_settings_icon")), findsOneWidget);

    final elapsed = tester.widget<Text>(
      find.byKey(const ValueKey("player_stream_elapsed")),
    );
    expect(elapsed.data, matches(RegExp(r"^\d+:\d\d:\d\d$")));
  });

  testWidgets("shows playback load errors with retry", (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              gqlAccessToken: "gql-token-123",
              httpClient: MockClient((_) async {
                requests++;
                if (requests == 1) {
                  return _forbiddenPlaybackResponse();
                }
                return _livePlaybackResponse();
              }),
            ),
          ),
          channel: _channel(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_error_message")), findsOneWidget);
    expect(find.textContaining("SUB_ONLY"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_retry_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_error_message")), findsNothing);
    expect(
      find.byKey(const ValueKey("fake_video_/api/v2/channel/hls/jason.m3u8")),
      findsOneWidget,
    );
  });

  testWidgets("uses fullscreen player layout without chat reservation", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: _playbackApiCache(),
          channel: _channel(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_chat_reserved_area")), findsOneWidget);
    expect(find.byIcon(Icons.screen_rotation_rounded), findsOneWidget);
    expect(find.byTooltip("Enter landscape"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_fullscreen_button")));
    await _pumpFullscreenTransition(tester);

    expect(find.byKey(const ValueKey("player_chat_reserved_area")), findsNothing);
    expect(find.byIcon(Icons.screen_rotation_rounded), findsOneWidget);
    expect(find.byTooltip("Exit landscape"), findsOneWidget);
    final rotateIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey("player_fullscreen_button")),
        matching: find.byIcon(Icons.screen_rotation_rounded),
      ),
    );
    expect(rotateIcon.size, 26);

    await tester.tap(find.byKey(const ValueKey("player_fullscreen_button")));
    await _pumpFullscreenTransition(tester);

    expect(find.byKey(const ValueKey("player_chat_reserved_area")), findsOneWidget);
  });

  testWidgets("jump to live seeks without refreshing playback", (tester) async {
    var requests = 0;
    late FakeFlowVideoController controller;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              gqlAccessToken: "gql-token-123",
              httpClient: MockClient((_) async {
                requests++;
                return _livePlaybackResponse();
              }),
            ),
          ),
          channel: _channel(),
          videoControllerFactory: (playlistUri) {
            controller = FakeFlowVideoController(playlistUri);
            return controller;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.byKey(const ValueKey("player_jump_live_button")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_jump_live_button")));
    await tester.pumpAndSettle();

    expect(controller.seekToLiveCallCount, 1);
    expect(requests, 1);
  });

  testWidgets("refresh button reloads the player", (tester) async {
    var requests = 0;
    final controllers = <FakeFlowVideoController>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client-123",
              accessToken: "token-123",
              gqlAccessToken: "gql-token-123",
              httpClient: MockClient((_) async {
                requests++;
                return _livePlaybackResponse();
              }),
            ),
          ),
          channel: _channel(),
          videoControllerFactory: (playlistUri) {
            final controller = FakeFlowVideoController(playlistUri);
            controllers.add(controller);
            return controller;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(controllers, hasLength(1));
    expect(find.byKey(const ValueKey("player_refresh_button")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_refresh_button")));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(controllers, hasLength(2));
    expect(controllers.first.seekToLiveCallCount, 0);
  });

  testWidgets("shows controls again after tapping the hidden video surface", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: _playbackApiCache(),
          channel: _channel(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(find.byKey(const ValueKey("player_video_tap_target")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_play_pause_button")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_video_tap_target")));
    await tester.pump();

    expect(find.byKey(const ValueKey("player_video_tap_target")), findsNothing);
    expect(find.byKey(const ValueKey("player_quality_button")), findsOneWidget);
  });

  testWidgets("shows loading instead of playback button while buffering", (tester) async {
    late FakeFlowVideoController controller;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: _playbackApiCache(),
          channel: _channel(),
          videoControllerFactory: (playlistUri) {
            controller = FakeFlowVideoController(playlistUri);
            return controller;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_play_pause_button")), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    controller.setBuffering(isBuffering: true);
    await tester.pump();

    expect(find.byKey(const ValueKey("player_play_pause_button")), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("opens quality settings and selects a quality", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: _playbackApiCache(),
          channel: _channel(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("player_quality_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_quality_auto")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_1080p60")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_720p60")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_quality_720p60")));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("player_quality_button")));
    await tester.pumpAndSettle();

    final selectedTile = find.byKey(const ValueKey("player_quality_720p60"));
    expect(
      find.descendant(
        of: selectedTile,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets("updates quality settings while the sheet is open", (tester) async {
    late FakeFlowVideoController controller;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: _playbackApiCache(),
          channel: _channel(),
          videoControllerFactory: (playlistUri) {
            controller = FakeFlowVideoController(
              playlistUri,
              qualities: const [FlowVideoQuality.auto],
            );
            return controller;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("player_quality_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_quality_auto")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_1080p60")), findsNothing);

    controller.setQualities(const [
      FlowVideoQuality.auto,
      FlowVideoQuality(id: "1080p60", label: "1080p60"),
      FlowVideoQuality(id: "720p60", label: "720p60"),
    ]);
    await tester.pump();

    expect(find.byKey(const ValueKey("player_quality_1080p60")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_720p60")), findsOneWidget);
  });

  testWidgets("resumes auto hiding controls after dismissing quality settings", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: PlayerScreen(
          apiCache: _playbackApiCache(),
          channel: _channel(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("player_quality_button")));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byKey(const ValueKey("player_quality_auto")))).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(find.byKey(const ValueKey("player_video_tap_target")), findsOneWidget);
  });
}

Future<void> _pumpFullscreenTransition(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

TwitchApiCache _playbackApiCache() => TwitchApiCache(
  clientLoader: () async => TwitchApiClient(
    clientId: "client-123",
    accessToken: "token-123",
    gqlAccessToken: "gql-token-123",
    httpClient: MockClient((_) async => _livePlaybackResponse()),
  ),
);

StreamChannel _channel() => StreamChannel(
  id: "creator-1",
  login: "jason",
  name: "Jason",
  initials: "J",
  title: "Live with chat",
  category: "Just Chatting",
  viewers: "26.3K",
  avatarColors: const [Color(0xFF111111), Color(0xFF222222)],
  thumbnailColors: const [Color(0xFF111111), Color(0xFF222222)],
  startedAt: DateTime.now().subtract(
    const Duration(hours: 3, minutes: 28, seconds: 52),
  ),
);

http.Response _livePlaybackResponse() => _jsonResponse({
  "data": {
    "streamPlaybackAccessToken": {
      "value": "token-value",
      "signature": "sig-value",
      "authorization": {"isForbidden": false},
    },
  },
});

http.Response _forbiddenPlaybackResponse() => _jsonResponse({
  "data": {
    "streamPlaybackAccessToken": {
      "value": "token-value",
      "signature": "sig-value",
      "authorization": {
        "isForbidden": true,
        "forbiddenReasonCode": "SUB_ONLY",
      },
    },
  },
});

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);
