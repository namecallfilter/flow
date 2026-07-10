import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/media3_player_controller.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("shows measured latency and keeps playback controls independent", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    final displayMode = _FakeDisplayModeController();
    var playbackLoads = 0;

    await tester.pumpWidget(
      _playerApp(
        player: player,
        displayMode: displayMode,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live-$playbackLoads.m3u8");
        },
      ),
    );
    await tester.pump();

    expect(find.text("--"), findsOneWidget);
    player.emit(const TwitchLatencyEvent(2050));
    player.emit(
      const TwitchPlaybackStateEvent(isPlaying: false, isBuffering: false),
    );
    await tester.pump();
    expect(find.text("2.05s"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_play_pause_button")));
    await tester.tap(find.byKey(const ValueKey("player_jump_live_button")));
    await tester.tap(find.byKey(const ValueKey("player_orientation_button")));
    await tester.pump();

    expect(player._toggleCount, 1);
    expect(player._jumpToLiveCount, 1);
    expect(displayMode._landscapeRequests, [true]);

    await tester.tap(find.byKey(const ValueKey("player_refresh_button")));
    await tester.pump();
    expect(find.text("--"), findsOneWidget);
    expect(playbackLoads, 2);
    expect(player._loadedUris.single.path, "/live-2.m3u8");

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(displayMode._restoreCount, 1);
  });

  testWidgets("uses a 16:9 portrait viewport with aligned symmetric overlays", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(isPlaying: false, isBuffering: false),
    );
    await tester.pump();

    final viewport = tester.getRect(find.byKey(const ValueKey("player_viewport")));
    final topRow = tester.getRect(find.byKey(const ValueKey("player_top_row")));
    final bottomRow = tester.getRect(find.byKey(const ValueKey("player_bottom_row")));
    final centerControl = tester.getRect(
      find.byKey(const ValueKey("player_center_control")),
    );

    expect(viewport.width / viewport.height, closeTo(16 / 9, 0.001));
    expect(topRow.top - viewport.top, closeTo(viewport.bottom - bottomRow.bottom, 0.01));
    expect(topRow.left, closeTo(bottomRow.left, 0.01));
    expect(topRow.right, closeTo(bottomRow.right, 0.01));
    expect(centerControl.center, viewport.center);
    expect(tester.takeException(), isNull);
  });

  testWidgets("fills landscape and mirrors the largest cutout inset", (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(
      left: 44,
      right: 8,
      top: 3,
      bottom: 20,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(isPlaying: false, isBuffering: false),
    );
    await tester.pump();

    final viewport = tester.getRect(find.byKey(const ValueKey("player_viewport")));
    final topRow = tester.getRect(find.byKey(const ValueKey("player_top_row")));
    final bottomRow = tester.getRect(find.byKey(const ValueKey("player_bottom_row")));

    expect(viewport, const Rect.fromLTWH(0, 0, 800, 400));
    expect(topRow.left, 44);
    expect(topRow.right, 756);
    expect(bottomRow.left, 44);
    expect(bottomRow.right, 756);
    expect(topRow.top, 20);
    expect(bottomRow.bottom, 380);
  });
}

Widget _playerApp({
  required _FakePlayerController player,
  PlayerDisplayModeController? displayMode,
  PlaybackUriLoader? playbackUriLoader,
}) => MaterialApp(
  theme: buildFlowTheme(Brightness.dark),
  home: StreamPlayerScreen(
    apiCache: TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client",
        accessToken: "token",
      ),
    ),
    channel: StreamChannel(
      id: "creator-1",
      login: "creator",
      name: "Creator",
      initials: "CR",
      title: "A precise stream title",
      category: "Just Chatting",
      viewers: "12.3K",
      viewerCount: 12345,
      startedAt: DateTime(2026, 7, 9, 19),
      avatarColors: const [Colors.purple, Colors.pink],
      thumbnailColors: const [Colors.black, Colors.grey],
    ),
    playbackUriLoader: playbackUriLoader ?? (_) async => Uri.parse("https://example.com/live.m3u8"),
    displayModeController: displayMode ?? _FakeDisplayModeController(),
    clock: () => DateTime(2026, 7, 9, 20, 2, 3),
    playerSurfaceBuilder: (context, uri, onControllerCreated) =>
        _FakePlayerSurface(player: player, onControllerCreated: onControllerCreated),
  ),
);

class _FakePlayerSurface extends StatefulWidget {
  const _FakePlayerSurface({
    required this._player,
    required this._onControllerCreated,
  });

  final TwitchPlayerController _player;
  final ValueChanged<TwitchPlayerController> _onControllerCreated;

  @override
  State<_FakePlayerSurface> createState() => _FakePlayerSurfaceState();
}

class _FakePlayerSurfaceState extends State<_FakePlayerSurface> {
  @override
  void initState() {
    super.initState();
    widget._onControllerCreated(widget._player);
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

class _FakePlayerController implements TwitchPlayerController {
  final _events = StreamController<TwitchPlayerEvent>.broadcast();
  final _loadedUris = <Uri>[];
  int _jumpToLiveCount = 0;
  int _toggleCount = 0;

  @override
  Stream<TwitchPlayerEvent> get events => _events.stream;

  void emit(TwitchPlayerEvent event) => _events.add(event);

  @override
  Future<void> jumpToLive() async {
    _jumpToLiveCount++;
  }

  @override
  Future<void> load(Uri uri) async {
    _loadedUris.add(uri);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> togglePlayback() async {
    _toggleCount++;
  }
}

class _FakeDisplayModeController implements PlayerDisplayModeController {
  final _landscapeRequests = <bool>[];
  int _restoreCount = 0;

  @override
  Future<void> restore() async {
    _restoreCount++;
  }

  @override
  Future<void> setLandscape({required bool landscape}) async {
    _landscapeRequests.add(landscape);
  }
}
