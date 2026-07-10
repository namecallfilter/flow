import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/media3_player_controller.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
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
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: true,
        playWhenReady: false,
      ),
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
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
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
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
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

  testWidgets("rotating preserves the platform player and playback session", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    var surfaceCreations = 0;
    var playbackLoads = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        onSurfaceCreated: () => surfaceCreations++,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live.m3u8");
        },
      ),
    );
    await tester.pump();
    expect(surfaceCreations, 1);
    expect(playbackLoads, 1);

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();

    expect(surfaceCreations, 1);
    expect(playbackLoads, 1);
    expect(player._loadedUris, isEmpty);
    expect(find.byKey(const ValueKey("player_chrome_landscape")), findsOneWidget);
  });

  testWidgets("uses compact aligned chrome and exposes quality selection", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
    );
    player.emit(
      const TwitchQualitiesEvent(
        selectedId: "auto",
        qualities: [
          TwitchQualityOption(
            id: "video:720",
            label: "720p60",
            width: 1280,
            height: 720,
            frameRate: 60,
            bitrate: 4500000,
          ),
        ],
      ),
    );
    await tester.pump();

    final viewport = tester.getRect(find.byKey(const ValueKey("player_viewport")));
    final topRow = tester.getRect(find.byKey(const ValueKey("player_top_row")));
    final bottomRow = tester.getRect(find.byKey(const ValueKey("player_bottom_row")));
    final back = tester.getRect(find.byKey(const ValueKey("player_back_button")));
    final liveDot = tester.getRect(find.byKey(const ValueKey("player_live_dot")));
    final settings = tester.getRect(find.byKey(const ValueKey("player_settings_button")));
    final orientation = tester.getRect(
      find.byKey(const ValueKey("player_orientation_button")),
    );

    expect(topRow.top - viewport.top, 4);
    expect(viewport.bottom - bottomRow.bottom, 4);
    expect(topRow.left, 4);
    expect(topRow.right, 396);
    expect(back.center.dx, liveDot.center.dx);
    expect(settings.center.dx, orientation.center.dx);
    expect(tester.widget<AvatarRing>(find.byKey(const ValueKey("player_avatar"))).isLive, false);
    final nameAndTitle = tester.widget<Text>(
      find.byKey(const ValueKey("player_name_and_title")),
    );
    expect(nameAndTitle.textSpan?.toPlainText(), "Creator  A precise stream title");
    expect(find.byIcon(Icons.category_rounded), findsOneWidget);
    final playButton = tester.widget<IconButton>(
      find.byKey(const ValueKey("player_play_pause_button")),
    );
    expect(playButton.style?.backgroundColor?.resolve({}), Colors.transparent);

    await tester.tap(find.byKey(const ValueKey("player_settings_button")));
    await tester.pumpAndSettle();
    expect(find.text("Quality"), findsOneWidget);
    expect(find.text("Video quality"), findsNothing);
    expect(find.text("Choose the stream resolution."), findsNothing);
    expect(find.byKey(const ValueKey("player_quality_auto")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_video:720")), findsOneWidget);
    final qualityTile = tester.widget<ListTile>(
      find.byKey(const ValueKey("player_quality_video:720")),
    );
    expect(qualityTile.subtitle, isNull);
    expect(qualityTile.shape, isNull);
    expect(qualityTile.selectedTileColor, isNull);
    expect(qualityTile.trailing, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_quality_auto")),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey("player_quality_video:720")));
    await tester.pumpAndSettle();
    expect(player._selectedQualityIds, ["video:720"]);
  });

  testWidgets("an open quality sheet populates when player tracks arrive", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    final playbackUri = Completer<Uri>();
    var surfaceCreations = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        playbackUriLoader: (_) => playbackUri.future,
        onSurfaceCreated: () => surfaceCreations++,
      ),
    );
    await tester.pump();
    expect(surfaceCreations, 0);

    await tester.tap(find.byKey(const ValueKey("player_settings_button")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey("player_quality_sheet")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_auto")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_loading")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_video:1080")), findsNothing);

    playbackUri.complete(Uri.parse("https://example.com/live.m3u8"));
    await tester.pump();
    expect(surfaceCreations, 1);

    player.emit(
      const TwitchQualitiesEvent(
        selectedId: "video:1080",
        qualities: [
          TwitchQualityOption(
            id: "video:1080",
            label: "1080p60",
            width: 1920,
            height: 1080,
            frameRate: 60,
            bitrate: 6000000,
          ),
          TwitchQualityOption(
            id: "video:720",
            label: "720p60",
            width: 1280,
            height: 720,
            frameRate: 60,
            bitrate: 4500000,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey("player_quality_loading")), findsNothing);
    expect(find.byKey(const ValueKey("player_quality_video:1080")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_video:720")), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_quality_video:1080")),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_quality_auto")),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey("player_quality_video:720")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(player._selectedQualityIds, ["video:720"]);
  });

  testWidgets("updates viewers separately and freezes latency while paused", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    var playbackLoads = 0;
    var viewerLoads = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live.m3u8");
        },
        viewerCountLoader: (_) async {
          viewerLoads++;
          return viewerLoads == 1 ? 15000 : 20000;
        },
      ),
    );
    await tester.pump();
    expect(find.text("15K"), findsOneWidget);

    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
      ),
    );
    player.emit(const TwitchLatencyEvent(2000));
    await tester.pump();
    expect(find.text("2.00s"), findsOneWidget);

    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
    );
    player.emit(const TwitchLatencyEvent(9000));
    await tester.pump();
    expect(find.text("2.00s"), findsOneWidget);
    expect(find.text("9.00s"), findsNothing);
    expect(find.byTooltip("Play"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: true,
        playWhenReady: true,
      ),
    );
    await tester.pump();
    player.emit(const TwitchLatencyEvent(1500));
    await tester.pump();
    expect(find.text("1.50s"), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text("20K"), findsOneWidget);
    expect(viewerLoads, 2);
    expect(playbackLoads, 1);
    expect(player._loadedUris, isEmpty);
  });

  testWidgets("keeps stitched-ad progress visible through updates and rotation", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();

    player.emit(const TwitchLatencyEvent(2100));
    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 1,
        total: 3,
        durationMs: 30000,
        remainingMs: 24000,
        rollType: "preroll",
      ),
    );
    await tester.pump();

    expect(find.text("2.10s"), findsOneWidget);
    expect(find.text("Ad 1 of 3 · 0:24"), findsOneWidget);
    expect(find.byKey(const ValueKey("player_ad_progress")), findsOneWidget);
    final visibleAdTop = tester
        .getTopLeft(
          find.byKey(const ValueKey("player_ad_progress")),
        )
        .dy;
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey("player_ad_progress")),
        matching: find.byType(AnimatedOpacity),
      ),
      findsNothing,
    );

    final portraitViewport = tester.getRect(
      find.byKey(const ValueKey("player_viewport")),
    );
    await tester.tapAt(
      Offset(portraitViewport.left + 100, portraitViewport.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text("Ad 1 of 3 · 0:24"), findsOneWidget);
    final hiddenAdTop = tester
        .getTopLeft(
          find.byKey(const ValueKey("player_ad_progress")),
        )
        .dy;
    expect(hiddenAdTop, lessThan(visibleAdTop));
    expect(visibleAdTop - hiddenAdTop, closeTo(40, 0.01));
    final controlsOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey("player_top_row")),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(controlsOpacity.opacity, 0);

    await tester.tapAt(
      Offset(portraitViewport.left + 100, portraitViewport.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("player_ad_progress"))).dy,
      closeTo(visibleAdTop, 0.01),
    );

    await tester.tapAt(
      Offset(portraitViewport.left + 100, portraitViewport.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 2,
        total: 3,
        durationMs: 30000,
        remainingMs: 12000,
        rollType: "midroll",
      ),
    );
    await tester.pump();
    expect(find.text("Ad 2 of 3 · 0:12"), findsOneWidget);

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    final landscapeViewport = tester.getRect(
      find.byKey(const ValueKey("player_viewport")),
    );
    final adPill = tester.getRect(find.byKey(const ValueKey("player_ad_progress")));
    expect(find.text("Ad 2 of 3 · 0:12"), findsOneWidget);
    expect(landscapeViewport.contains(adPill.topLeft), isTrue);
    expect(landscapeViewport.contains(adPill.bottomRight), isTrue);

    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 0,
        total: 0,
        durationMs: 6000,
        remainingMs: 6000,
      ),
    );
    await tester.pump();
    expect(find.text("Ad · 0:06"), findsOneWidget);

    player.emit(const TwitchPlayerErrorEvent("Playback failed"));
    await tester.pump();
    expect(find.byKey(const ValueKey("player_ad_progress")), findsNothing);

    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 3,
        total: 3,
        durationMs: 6000,
        remainingMs: 4000,
      ),
    );
    await tester.pump();

    player.emit(
      const TwitchAdEvent(
        active: false,
        current: 0,
        total: 0,
        durationMs: 0,
        remainingMs: 0,
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey("player_ad_progress")), findsNothing);
  });
}

Widget _playerApp({
  required _FakePlayerController player,
  PlayerDisplayModeController? displayMode,
  PlaybackUriLoader? playbackUriLoader,
  ViewerCountLoader? viewerCountLoader,
  VoidCallback? onSurfaceCreated,
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
    viewerCountLoader: viewerCountLoader ?? (_) async => null,
    displayModeController: displayMode ?? _FakeDisplayModeController(),
    clock: () => DateTime(2026, 7, 9, 20, 2, 3),
    playerSurfaceBuilder: (context, uri, onControllerCreated) => _FakePlayerSurface(
      player: player,
      onControllerCreated: onControllerCreated,
      onSurfaceCreated: onSurfaceCreated,
    ),
  ),
);

class _FakePlayerSurface extends StatefulWidget {
  const _FakePlayerSurface({
    required this._player,
    required this._onControllerCreated,
    this._onSurfaceCreated,
  });

  final TwitchPlayerController _player;
  final ValueChanged<TwitchPlayerController> _onControllerCreated;
  final VoidCallback? _onSurfaceCreated;

  @override
  State<_FakePlayerSurface> createState() => _FakePlayerSurfaceState();
}

class _FakePlayerSurfaceState extends State<_FakePlayerSurface> {
  @override
  void initState() {
    super.initState();
    widget._onSurfaceCreated?.call();
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
  Future<void> setQuality(String id) async {
    _selectedQualityIds.add(id);
  }

  @override
  Future<void> togglePlayback() async {
    _toggleCount++;
  }

  final _selectedQualityIds = <String>[];
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
