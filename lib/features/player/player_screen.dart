import "dart:async";
import "dart:math" as math;

import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/spacing.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/media3_player_controller.dart";
import "package:flow/features/player/media3_player_view.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

typedef PlaybackUriLoader = Future<Uri> Function(String login);
typedef PlayerSurfaceBuilder =
    Widget Function(
      BuildContext context,
      Uri uri,
      ValueChanged<TwitchPlayerController> onControllerCreated,
    );

abstract interface class PlayerDisplayModeController {
  Future<void> setLandscape({required bool landscape});

  Future<void> restore();
}

class SystemPlayerDisplayModeController implements PlayerDisplayModeController {
  const SystemPlayerDisplayModeController();

  @override
  Future<void> setLandscape({required bool landscape}) async {
    if (landscape) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return;
    }

    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Future<void> restore() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

class StreamPlayerScreen extends StatefulWidget {
  const StreamPlayerScreen({
    required this.apiCache,
    required this.channel,
    super.key,
    this.playbackUriLoader,
    this.playerSurfaceBuilder,
    this.displayModeController = const SystemPlayerDisplayModeController(),
    this.clock = DateTime.now,
  });

  final TwitchApiCache apiCache;
  final StreamChannel channel;
  final PlaybackUriLoader? playbackUriLoader;
  final PlayerSurfaceBuilder? playerSurfaceBuilder;
  final PlayerDisplayModeController displayModeController;
  final DateTime Function() clock;

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchApiCache>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(
      ObjectFlagProperty<PlaybackUriLoader?>.has("playbackUriLoader", playbackUriLoader),
    );
    properties.add(
      ObjectFlagProperty<PlayerSurfaceBuilder?>.has(
        "playerSurfaceBuilder",
        playerSurfaceBuilder,
      ),
    );
    properties.add(
      DiagnosticsProperty<PlayerDisplayModeController>(
        "displayModeController",
        displayModeController,
      ),
    );
    properties.add(ObjectFlagProperty<DateTime Function()>.has("clock", clock));
  }
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen> with WidgetsBindingObserver {
  TwitchPlayerController? _playerController;
  StreamSubscription<TwitchPlayerEvent>? _playerEvents;
  Timer? _controlsTimer;
  Timer? _uptimeTimer;
  Uri? _playbackUri;
  int? _latencyMs;
  String? _errorMessage;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _controlsVisible = true;
  bool _wasPlayingBeforeBackground = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.channel.startedAt != null) {
        setState(() {});
      }
    });
    unawaited(_loadPlaybackUri());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _playerController;
    if (controller == null) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_isPlaying) {
        _wasPlayingBeforeBackground = true;
      }
      unawaited(controller.pause());
    } else if (state == AppLifecycleState.resumed && _wasPlayingBeforeBackground) {
      _wasPlayingBeforeBackground = false;
      unawaited(controller.play());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _uptimeTimer?.cancel();
    unawaited(_playerEvents?.cancel());
    unawaited(widget.displayModeController.restore());
    super.dispose();
  }

  Future<void> _loadPlaybackUri({bool refresh = false}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _errorMessage = null;
      _isBuffering = true;
      if (refresh) {
        _latencyMs = null;
        _controlsVisible = true;
      }
    });

    try {
      final loader = widget.playbackUriLoader ?? widget.apiCache.fetchLivePlaybackUri;
      final uri = await loader(widget.channel.login);
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      if (refresh && _playerController != null) {
        await _playerController!.load(uri);
      }
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => _playbackUri = uri);
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _isBuffering = false;
        _controlsVisible = true;
        _errorMessage = _playerErrorMessage(error);
      });
    }
  }

  void _handleControllerCreated(TwitchPlayerController controller) {
    unawaited(_playerEvents?.cancel());
    _playerController = controller;
    _playerEvents = controller.events.listen(
      _handlePlayerEvent,
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isBuffering = false;
            _controlsVisible = true;
            _errorMessage = _playerErrorMessage(error);
          });
        }
      },
    );
  }

  void _handlePlayerEvent(TwitchPlayerEvent event) {
    if (!mounted) {
      return;
    }
    switch (event) {
      case TwitchLatencyEvent(:final latencyMs):
        setState(() => _latencyMs = latencyMs);
      case TwitchPlaybackStateEvent(:final isPlaying, :final isBuffering):
        setState(() {
          _isPlaying = isPlaying;
          _isBuffering = isBuffering;
          if (!isPlaying || isBuffering) {
            _controlsVisible = true;
          }
        });
        if (isPlaying && !isBuffering) {
          _scheduleControlsHide();
        } else {
          _controlsTimer?.cancel();
        }
      case TwitchPlayerErrorEvent(:final message):
        setState(() {
          _isBuffering = false;
          _controlsVisible = true;
          _errorMessage = message;
        });
    }
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isBuffering && _errorMessage == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible && _isPlaying) {
      _scheduleControlsHide();
    } else {
      _controlsTimer?.cancel();
    }
  }

  Future<void> _togglePlayback() async {
    setState(() => _controlsVisible = true);
    await _playerController?.togglePlayback();
  }

  Future<void> _jumpToLive() async {
    setState(() => _controlsVisible = true);
    await _playerController?.jumpToLive();
    _scheduleControlsHide();
  }

  Future<void> _toggleLandscape({required bool isLandscape}) async {
    setState(() => _controlsVisible = true);
    await widget.displayModeController.setLandscape(landscape: !isLandscape);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.size.width > mediaQuery.size.height;
    final viewport = _PlayerViewport(
      channel: widget.channel,
      playbackUri: _playbackUri,
      playerSurfaceBuilder: widget.playerSurfaceBuilder,
      onControllerCreated: _handleControllerCreated,
      isLandscape: isLandscape,
      controlsVisible: _controlsVisible,
      isPlaying: _isPlaying,
      isBuffering: _isBuffering,
      latencyMs: _latencyMs,
      liveDuration: _liveDuration,
      errorMessage: _errorMessage,
      onSurfaceTap: _toggleControls,
      onBack: Navigator.of(context).maybePop,
      onTogglePlayback: _togglePlayback,
      onJumpToLive: _jumpToLive,
      onRefresh: () => _loadPlaybackUri(refresh: true),
      onToggleLandscape: () => _toggleLandscape(isLandscape: isLandscape),
    );

    return Scaffold(
      key: ValueKey("player_page_${widget.channel.login}"),
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        top: !isLandscape,
        bottom: false,
        left: false,
        right: false,
        child: isLandscape
            ? SizedBox.expand(child: viewport)
            : Align(
                alignment: Alignment.topCenter,
                child: AspectRatio(aspectRatio: 16 / 9, child: viewport),
              ),
      ),
    );
  }

  Duration? get _liveDuration {
    final startedAt = widget.channel.startedAt;
    if (startedAt == null) {
      return null;
    }
    final elapsed = widget.clock().difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }
}

class _PlayerViewport extends StatelessWidget {
  const _PlayerViewport({
    required this.channel,
    required this.playbackUri,
    required this.playerSurfaceBuilder,
    required this.onControllerCreated,
    required this.isLandscape,
    required this.controlsVisible,
    required this.isPlaying,
    required this.isBuffering,
    required this.latencyMs,
    required this.liveDuration,
    required this.errorMessage,
    required this.onSurfaceTap,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onJumpToLive,
    required this.onRefresh,
    required this.onToggleLandscape,
  });

  final StreamChannel channel;
  final Uri? playbackUri;
  final PlayerSurfaceBuilder? playerSurfaceBuilder;
  final ValueChanged<TwitchPlayerController> onControllerCreated;
  final bool isLandscape;
  final bool controlsVisible;
  final bool isPlaying;
  final bool isBuffering;
  final int? latencyMs;
  final Duration? liveDuration;
  final String? errorMessage;
  final VoidCallback onSurfaceTap;
  final VoidCallback onBack;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function() onJumpToLive;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onToggleLandscape;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final horizontalPadding = isLandscape
        ? math.max(AppSpacing.md, math.max(viewPadding.left, viewPadding.right))
        : AppSpacing.md;
    final verticalPadding = isLandscape
        ? math.max(AppSpacing.md, math.max(viewPadding.top, viewPadding.bottom))
        : AppSpacing.md;

    return ColoredBox(
      key: const ValueKey("player_viewport"),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (playbackUri case final uri?)
            if (playerSurfaceBuilder case final builder?)
              builder(context, uri, onControllerCreated)
            else
              Media3PlayerView(uri: uri, onControllerCreated: onControllerCreated),
          const IgnorePointer(child: _PlayerScrim()),
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey("player_surface_tap_target"),
              behavior: HitTestBehavior.opaque,
              onTap: onSurfaceTap,
            ),
          ),
          AnimatedOpacity(
            opacity: controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: IgnorePointer(
              ignoring: !controlsVisible,
              child: Padding(
                key: const ValueKey("player_overlay_padding"),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PlayerHeader(channel: channel, onBack: onBack),
                    _PlayerFooter(
                      viewers: channel.viewers,
                      liveDuration: liveDuration,
                      latencyMs: latencyMs,
                      isLandscape: isLandscape,
                      onJumpToLive: onJumpToLive,
                      onRefresh: onRefresh,
                      onToggleLandscape: onToggleLandscape,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (errorMessage case final message?)
            Center(
              child: _PlayerError(message: message, onRetry: onRefresh),
            )
          else
            Center(
              key: const ValueKey("player_center_control"),
              child: _CenterPlaybackControl(
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                visible: controlsVisible,
                onPressed: onTogglePlayback,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(DiagnosticsProperty<Uri?>("playbackUri", playbackUri));
    properties.add(
      ObjectFlagProperty<PlayerSurfaceBuilder?>.has(
        "playerSurfaceBuilder",
        playerSurfaceBuilder,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchPlayerController>>.has(
        "onControllerCreated",
        onControllerCreated,
      ),
    );
    properties.add(FlagProperty("isLandscape", value: isLandscape, ifTrue: "landscape"));
    properties.add(
      FlagProperty("controlsVisible", value: controlsVisible, ifTrue: "controls visible"),
    );
    properties.add(FlagProperty("isPlaying", value: isPlaying, ifTrue: "playing"));
    properties.add(FlagProperty("isBuffering", value: isBuffering, ifTrue: "buffering"));
    properties.add(IntProperty("latencyMs", latencyMs));
    properties.add(DiagnosticsProperty<Duration?>("liveDuration", liveDuration));
    properties.add(StringProperty("errorMessage", errorMessage));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onSurfaceTap", onSurfaceTap));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onBack", onBack));
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has(
        "onTogglePlayback",
        onTogglePlayback,
      ),
    );
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has("onJumpToLive", onJumpToLive),
    );
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has("onRefresh", onRefresh),
    );
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has(
        "onToggleLandscape",
        onToggleLandscape,
      ),
    );
  }
}

class _PlayerScrim extends StatelessWidget {
  const _PlayerScrim();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xB3000000),
          Color(0x00000000),
          Color(0x00000000),
          Color(0xBF000000),
        ],
        stops: [0, 0.30, 0.62, 1],
      ),
    ),
  );
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.channel, required this.onBack});

  final StreamChannel channel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey("player_top_row"),
    children: [
      _OverlayIconButton(
        key: const ValueKey("player_back_button"),
        tooltip: "Back",
        icon: Icons.adaptive.arrow_back,
        onPressed: onBack,
      ),
      const SizedBox(width: AppSpacing.xs),
      AvatarRing(
        initials: channel.initials,
        size: 38,
        avatarColors: channel.avatarColors,
        imageUrl: channel.avatarImageUrl,
        isLive: true,
        ringWidth: 2,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channel.title.isEmpty ? channel.name : channel.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                shadows: _textShadows,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "${channel.name} · ${channel.category}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: _textShadows,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onBack", onBack));
  }
}

class _PlayerFooter extends StatelessWidget {
  const _PlayerFooter({
    required this.viewers,
    required this.liveDuration,
    required this.latencyMs,
    required this.isLandscape,
    required this.onJumpToLive,
    required this.onRefresh,
    required this.onToggleLandscape,
  });

  final String viewers;
  final Duration? liveDuration;
  final int? latencyMs;
  final bool isLandscape;
  final Future<void> Function() onJumpToLive;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onToggleLandscape;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey("player_bottom_row"),
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const _LiveDot(),
                const SizedBox(width: 5),
                _OverlayMetric(text: _formatLiveDuration(liveDuration)),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.visibility_rounded, color: Colors.white, size: 19),
                const SizedBox(width: 5),
                _OverlayMetric(text: viewers),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.speed_rounded, color: Colors.white, size: 19),
                const SizedBox(width: 5),
                _OverlayMetric(
                  key: const ValueKey("player_latency"),
                  text: _formatLatency(latencyMs),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      _OverlayIconButton(
        key: const ValueKey("player_jump_live_button"),
        tooltip: "Jump to live edge",
        icon: Icons.fast_forward_rounded,
        onPressed: onJumpToLive,
      ),
      _OverlayIconButton(
        key: const ValueKey("player_refresh_button"),
        tooltip: "Refresh player",
        icon: Icons.refresh_rounded,
        onPressed: onRefresh,
      ),
      _OverlayIconButton(
        key: const ValueKey("player_orientation_button"),
        tooltip: isLandscape ? "Exit landscape" : "Enter landscape",
        icon: Icons.screen_rotation_rounded,
        onPressed: onToggleLandscape,
      ),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("viewers", viewers));
    properties.add(DiagnosticsProperty<Duration?>("liveDuration", liveDuration));
    properties.add(IntProperty("latencyMs", latencyMs));
    properties.add(FlagProperty("isLandscape", value: isLandscape, ifTrue: "landscape"));
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has("onJumpToLive", onJumpToLive),
    );
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has("onRefresh", onRefresh),
    );
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has(
        "onToggleLandscape",
        onToggleLandscape,
      ),
    );
  }
}

class _CenterPlaybackControl extends StatelessWidget {
  const _CenterPlaybackControl({
    required this.isPlaying,
    required this.isBuffering,
    required this.visible,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool visible;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible || isBuffering ? 1 : 0,
    duration: const Duration(milliseconds: 160),
    child: isBuffering
        ? const SizedBox.square(
            dimension: 42,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          )
        : IconButton(
            key: const ValueKey("player_play_pause_button"),
            tooltip: isPlaying ? "Pause" : "Play",
            onPressed: onPressed,
            iconSize: 54,
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.24),
              minimumSize: const Size.square(68),
            ),
            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty("isPlaying", value: isPlaying, ifTrue: "playing"));
    properties.add(FlagProperty("isBuffering", value: isBuffering, ifTrue: "buffering"));
    properties.add(FlagProperty("visible", value: visible, ifTrue: "visible"));
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has("onPressed", onPressed),
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 320),
    margin: const EdgeInsets.symmetric(horizontal: 52),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          key: const ValueKey("player_error_retry_button"),
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text("Try again"),
        ),
      ],
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("message", message));
    properties.add(ObjectFlagProperty<Future<void> Function()>.has("onRetry", onRetry));
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    color: Colors.white,
    iconSize: 27,
    icon: Icon(
      icon,
      shadows: const [
        Shadow(color: Color(0x99000000), blurRadius: 5, offset: Offset(0, 1)),
      ],
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("tooltip", tooltip));
    properties.add(DiagnosticsProperty<IconData>("icon", icon));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onPressed", onPressed));
  }
}

class _OverlayMetric extends StatelessWidget {
  const _OverlayMetric({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
      shadows: _textShadows,
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("text", text));
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 10,
    child: DecoratedBox(
      decoration: BoxDecoration(color: AppColors.liveRed, shape: BoxShape.circle),
    ),
  );
}

const _textShadows = [
  Shadow(color: Color(0xB3000000), blurRadius: 4, offset: Offset(0, 1)),
];

String _formatLatency(int? latencyMs) =>
    latencyMs == null ? "--" : "${(latencyMs / 1000).toStringAsFixed(2)}s";

String _formatLiveDuration(Duration? duration) {
  if (duration == null) {
    return "LIVE";
  }
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
  return hours > 0 ? "$hours:$minutes:$seconds" : "${duration.inMinutes}:$seconds";
}

String _playerErrorMessage(Object error) {
  final message = error.toString().trim();
  if (message.isEmpty) {
    return "The stream could not be loaded.";
  }
  return message.replaceFirst(RegExp(r"^[A-Za-z]+Exception:\s*"), "");
}
