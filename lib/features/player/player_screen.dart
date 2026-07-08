import "dart:async";
import "dart:math" as math;

import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/spacing.dart";
import "package:flow/features/player/player_controller.dart";
import "package:flow/features/player/player_store.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_mobx/flutter_mobx.dart";

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.apiCache,
    required this.channel,
    super.key,
    this.playerStore,
    this.videoControllerFactory,
  });

  final TwitchApiCache apiCache;
  final StreamChannel channel;
  final PlayerStore? playerStore;
  final FlowVideoControllerFactory? videoControllerFactory;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchApiCache>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(DiagnosticsProperty<PlayerStore?>("playerStore", playerStore));
    properties.add(
      ObjectFlagProperty<FlowVideoControllerFactory?>.has(
        "videoControllerFactory",
        videoControllerFactory,
      ),
    );
  }
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _controlsAutoHideDelay = Duration(seconds: 4);

  late final PlayerStore _store;
  FlowVideoController? _videoController;
  Timer? _controlsHideTimer;
  bool _isInitializingVideo = false;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _suppressChromeForFullscreenTransition = false;
  String? _videoErrorMessage;
  int _loadGeneration = 0;
  int _chromeRevision = 0;

  String get _login {
    final login = widget.channel.login.trim();
    return login.isEmpty ? widget.channel.name.trim() : login;
  }

  bool get _canAutoHideControls {
    final controller = _videoController;
    return controller != null &&
        controller.isInitialized &&
        controller.isPlaying &&
        !controller.isBuffering &&
        !_store.isLoading &&
        !_isInitializingVideo &&
        _videoErrorMessage == null &&
        controller.errorDescription == null;
  }

  @override
  void initState() {
    super.initState();
    _store =
        widget.playerStore ??
        PlayerStore(
          apiCache: widget.apiCache,
          login: _login,
        );
    unawaited(_loadPlayback());
  }

  @override
  void dispose() {
    _loadGeneration++;
    _cancelControlsHideTimer();
    _videoController?.removeListener(_handleVideoChanged);
    _videoController?.dispose();
    if (_isFullscreen) {
      unawaited(_restoreSystemChrome());
    }
    super.dispose();
  }

  Future<void> _loadPlayback({bool refresh = false}) async {
    final generation = ++_loadGeneration;
    _cancelControlsHideTimer();
    setState(() {
      _videoErrorMessage = null;
      _controlsVisible = true;
    });

    final playback = await _store.load(refresh: refresh);
    if (!mounted || generation != _loadGeneration || playback == null) {
      if (mounted && generation == _loadGeneration && playback == null) {
        _disposeCurrentVideoController();
        _cancelControlsHideTimer();
        setState(() {
          _videoController = null;
          _isInitializingVideo = false;
          _controlsVisible = true;
        });
      }
      return;
    }

    await _initializeVideo(playback.playlistUri, generation);
  }

  Future<void> _initializeVideo(Uri playlistUri, int generation) async {
    final previousController = _videoController;
    previousController?.removeListener(_handleVideoChanged);

    final factory = widget.videoControllerFactory ?? createFlowVideoController;
    final nextController = factory(playlistUri)..addListener(_handleVideoChanged);

    setState(() {
      _videoController = nextController;
      _isInitializingVideo = true;
      _videoErrorMessage = null;
      _controlsVisible = true;
    });
    previousController?.dispose();

    try {
      await nextController.initialize();
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(_videoController, nextController)) {
        nextController.dispose();
        return;
      }

      await nextController.play();
      if (mounted && identical(_videoController, nextController)) {
        setState(() {
          _isInitializingVideo = false;
          _controlsVisible = true;
        });
        _scheduleControlsHide();
      }
    } on Object catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(_videoController, nextController)) {
        return;
      }
      nextController.removeListener(_handleVideoChanged);
      nextController.dispose();
      _cancelControlsHideTimer();
      setState(() {
        _videoController = null;
        _isInitializingVideo = false;
        _videoErrorMessage = error.toString();
        _controlsVisible = true;
      });
    }
  }

  void _handleVideoChanged() {
    if (!mounted) {
      return;
    }
    if (_canAutoHideControls) {
      if (_controlsVisible && _controlsHideTimer == null) {
        _scheduleControlsHide();
      }
    } else {
      _cancelControlsHideTimer();
    }
    setState(() {});
  }

  void _toggleControls() {
    if (_controlsVisible && _canAutoHideControls) {
      _cancelControlsHideTimer();
      setState(() {
        _controlsVisible = false;
      });
      return;
    }
    _showControls();
  }

  void _showControls({bool autoHide = true}) {
    _cancelControlsHideTimer();
    if (mounted && !_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
    if (autoHide) {
      _scheduleControlsHide();
    }
  }

  void _scheduleControlsHide() {
    _cancelControlsHideTimer();
    if (!_canAutoHideControls) {
      return;
    }
    _controlsHideTimer = Timer(_controlsAutoHideDelay, () {
      if (!mounted) {
        return;
      }
      _controlsHideTimer = null;
      if (!_canAutoHideControls) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }

  void _cancelControlsHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  void _disposeCurrentVideoController() {
    _videoController?.removeListener(_handleVideoChanged);
    _videoController?.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.isInitialized) {
      return;
    }

    if (controller.isPlaying) {
      await controller.pause();
      _showControls(autoHide: false);
    } else {
      await controller.play();
      _showControls();
    }
  }

  Future<void> _seekToLiveEdge() async {
    final controller = _videoController;
    if (controller == null || !controller.isInitialized) {
      await _loadPlayback(refresh: true);
      return;
    }

    await controller.seekToLive();
    _showControls();
  }

  Future<void> _showQualitySheet() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    _showControls(autoHide: false);
    final selectedQualityId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => ListView(
            shrinkWrap: true,
            children: [
              for (final quality in controller.qualities)
                ListTile(
                  key: ValueKey("player_quality_${quality.id}"),
                  title: Text(quality.label),
                  trailing: controller.selectedQualityId == quality.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(quality.id),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (selectedQualityId != null) {
      await controller.setQuality(selectedQualityId);
    }
    if (mounted) {
      _showControls();
    }
  }

  Future<void> _toggleFullscreen() async {
    final nextFullscreen = !_isFullscreen;

    _cancelControlsHideTimer();
    setState(() {
      _suppressChromeForFullscreenTransition = true;
      _controlsVisible = false;
    });

    await _waitForTransitionFrame();
    if (!mounted) {
      return;
    }

    setState(() {
      _isFullscreen = nextFullscreen;
    });

    await _waitForSystemChromeTransition(
      nextFullscreen ? _enterFullscreenSystemChrome() : _restoreSystemChrome(),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _chromeRevision++;
      _suppressChromeForFullscreenTransition = false;
      _controlsVisible = true;
    });

    _scheduleControlsHide();
  }

  Future<void> _waitForSystemChromeTransition(Future<void> transition) async {
    try {
      await transition;
    } on Object {
      // Keep fullscreen state transitions best-effort. A failed platform
      // chrome call should not strand the player overlay mid-transition.
    }
  }

  Future<void> _waitForTransitionFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  static Future<void> _enterFullscreenSystemChrome() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  static Future<void> _restoreSystemChrome() async {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final controller = _videoController;
      final errorMessage =
          _videoErrorMessage ?? controller?.errorDescription ?? _store.errorMessage;
      final isBusy = _store.isLoading || _isInitializingVideo || (controller?.isBuffering ?? false);
      final stage = _PlayerStage(
        channel: widget.channel,
        controller: controller,
        controlsVisible: _controlsVisible,
        chromeRevision: _chromeRevision,
        suppressChrome: _suppressChromeForFullscreenTransition,
        errorMessage: errorMessage,
        isBusy: isBusy,
        isFullscreen: _isFullscreen,
        onBack: Navigator.of(context).maybePop,
        onJumpToLiveEdge: () {
          _showControls(autoHide: false);
          unawaited(_seekToLiveEdge());
        },
        onRefresh: () {
          _showControls(autoHide: false);
          unawaited(_loadPlayback(refresh: true));
        },
        onRetry: () {
          _showControls(autoHide: false);
          unawaited(_loadPlayback(refresh: true));
        },
        onShowQuality: () => unawaited(_showQualitySheet()),
        onToggleControls: _toggleControls,
        onToggleFullscreen: () => unawaited(_toggleFullscreen()),
        onTogglePlayback: () => unawaited(_togglePlayback()),
      );

      return Scaffold(
        key: ValueKey("player_page_${_login.toLowerCase()}"),
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final topInset = _isFullscreen ? 0.0 : MediaQuery.paddingOf(context).top;
            final stageHeight = _isFullscreen ? constraints.maxHeight : _playerStageHeight(context);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: topInset + stageHeight,
                  right: 0,
                  bottom: 0,
                  left: 0,
                  child: Visibility(
                    visible: !_isFullscreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        const Expanded(child: _ChatReservedArea()),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: topInset,
                  right: 0,
                  bottom: _isFullscreen ? 0 : null,
                  left: 0,
                  height: _isFullscreen ? null : stageHeight,
                  child: stage,
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

double _playerStageHeight(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final desiredHeight = size.width * 9 / 16;
  final maxHeight = size.height * 0.44;
  final minHeight = math.min(maxHeight, 220.0);
  return desiredHeight.clamp(minHeight, maxHeight);
}

class _PlayerStage extends StatelessWidget {
  const _PlayerStage({
    required this.channel,
    required this.controller,
    required this.controlsVisible,
    required this.chromeRevision,
    required this.suppressChrome,
    required this.errorMessage,
    required this.isBusy,
    required this.isFullscreen,
    required this.onBack,
    required this.onJumpToLiveEdge,
    required this.onRefresh,
    required this.onRetry,
    required this.onShowQuality,
    required this.onToggleControls,
    required this.onToggleFullscreen,
    required this.onTogglePlayback,
  });

  final StreamChannel channel;
  final FlowVideoController? controller;
  final bool controlsVisible;
  final int chromeRevision;
  final bool suppressChrome;
  final String? errorMessage;
  final bool isBusy;
  final bool isFullscreen;
  final VoidCallback onBack;
  final VoidCallback onJumpToLiveEdge;
  final VoidCallback onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onShowQuality;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final currentError = errorMessage;
    final showChrome = !suppressChrome && (controlsVisible || isBusy || currentError != null);
    final child = GestureDetector(
      key: const ValueKey("player_stage"),
      behavior: HitTestBehavior.opaque,
      onTap: onToggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: _PlayerVideoSurface(
              channel: channel,
              controller: controller,
            ),
          ),
          if (!showChrome)
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey("player_video_tap_target"),
                behavior: HitTestBehavior.opaque,
                onTap: onToggleControls,
                child: const SizedBox.expand(),
              ),
            ),
          if (!suppressChrome)
            AnimatedOpacity(
              key: ValueKey("player_chrome_opacity_$chromeRevision"),
              opacity: showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !showChrome,
                child: KeyedSubtree(
                  key: ValueKey(
                    "player_chrome_${isFullscreen ? "fullscreen" : "inline"}_$chromeRevision",
                  ),
                  child: _PlayerChrome(
                    channel: channel,
                    controller: controller,
                    isBusy: isBusy,
                    isFullscreen: isFullscreen,
                    onBack: onBack,
                    onJumpToLiveEdge: onJumpToLiveEdge,
                    onRefresh: onRefresh,
                    onShowQuality: onShowQuality,
                    onToggleControls: onToggleControls,
                    onToggleFullscreen: onToggleFullscreen,
                    onTogglePlayback: onTogglePlayback,
                    showPlaybackButton: currentError == null && !isBusy,
                  ),
                ),
              ),
            ),
          if (isBusy && currentError == null)
            const Center(
              child: SizedBox.square(
                dimension: 34,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          if (currentError != null)
            _PlayerErrorState(
              message: currentError,
              onRetry: onRetry,
            ),
        ],
      ),
    );

    if (isFullscreen) {
      return SizedBox.expand(child: child);
    }

    return SizedBox(
      height: _playerStageHeight(context),
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(DiagnosticsProperty<FlowVideoController?>("controller", controller));
    properties.add(DiagnosticsProperty<bool>("controlsVisible", controlsVisible));
    properties.add(IntProperty("chromeRevision", chromeRevision));
    properties.add(DiagnosticsProperty<bool>("suppressChrome", suppressChrome));
    properties.add(StringProperty("errorMessage", errorMessage));
    properties.add(DiagnosticsProperty<bool>("isBusy", isBusy));
    properties.add(DiagnosticsProperty<bool>("isFullscreen", isFullscreen));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onBack", onBack));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onJumpToLiveEdge", onJumpToLiveEdge));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onRefresh", onRefresh));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onRetry", onRetry));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onShowQuality", onShowQuality));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onToggleControls", onToggleControls));
    properties.add(
      ObjectFlagProperty<VoidCallback>.has(
        "onToggleFullscreen",
        onToggleFullscreen,
      ),
    );
    properties.add(
      ObjectFlagProperty<VoidCallback>.has(
        "onTogglePlayback",
        onTogglePlayback,
      ),
    );
  }
}

class _PlayerChrome extends StatelessWidget {
  const _PlayerChrome({
    required this.channel,
    required this.controller,
    required this.isBusy,
    required this.isFullscreen,
    required this.onBack,
    required this.onJumpToLiveEdge,
    required this.onRefresh,
    required this.onShowQuality,
    required this.onToggleControls,
    required this.onToggleFullscreen,
    required this.onTogglePlayback,
    required this.showPlaybackButton,
  });

  final StreamChannel channel;
  final FlowVideoController? controller;
  final bool isBusy;
  final bool isFullscreen;
  final VoidCallback onBack;
  final VoidCallback onJumpToLiveEdge;
  final VoidCallback onRefresh;
  final VoidCallback onShowQuality;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTogglePlayback;
  final bool showPlaybackButton;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final fullscreenHorizontalInset = math.max(
      math.max(viewPadding.left, viewPadding.right) + AppSpacing.md,
      _fullscreenChromeMinHorizontalInset,
    );
    final leftInset = isFullscreen ? fullscreenHorizontalInset : AppSpacing.md;
    final rightInset = isFullscreen ? fullscreenHorizontalInset : AppSpacing.md;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey("player_chrome_tap_target"),
            behavior: HitTestBehavior.opaque,
            onTap: onToggleControls,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: isFullscreen ? 112 : 80,
          child: const _ChromeGradient(fromTop: true),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: isFullscreen ? 88 : 60,
          child: const _ChromeGradient(fromTop: false),
        ),
        Positioned(
          top: AppSpacing.xs,
          left: isFullscreen ? leftInset : AppSpacing.xs,
          right: isFullscreen ? rightInset : AppSpacing.sm,
          child: _PlayerTopBar(
            channel: channel,
            isFullscreen: isFullscreen,
            onBack: onBack,
            onShowQuality: onShowQuality,
          ),
        ),
        if (showPlaybackButton)
          Center(
            child: _PrimaryPlaybackButton(
              controller: controller,
              isBusy: isBusy,
              isFullscreen: isFullscreen,
              onPressed: onTogglePlayback,
            ),
          ),
        Positioned(
          left: leftInset,
          right: rightInset,
          bottom: isFullscreen ? -4 : -6,
          child: _PlayerBottomBar(
            channel: channel,
            controller: controller,
            isBusy: isBusy,
            isFullscreen: isFullscreen,
            onJumpToLiveEdge: onJumpToLiveEdge,
            onRefresh: onRefresh,
            onToggleFullscreen: onToggleFullscreen,
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(DiagnosticsProperty<FlowVideoController?>("controller", controller));
    properties.add(DiagnosticsProperty<bool>("isBusy", isBusy));
    properties.add(DiagnosticsProperty<bool>("isFullscreen", isFullscreen));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onBack", onBack));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onJumpToLiveEdge", onJumpToLiveEdge));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onRefresh", onRefresh));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onShowQuality", onShowQuality));
    properties.add(
      ObjectFlagProperty<VoidCallback>.has(
        "onToggleControls",
        onToggleControls,
      ),
    );
    properties.add(
      ObjectFlagProperty<VoidCallback>.has(
        "onToggleFullscreen",
        onToggleFullscreen,
      ),
    );
    properties.add(
      ObjectFlagProperty<VoidCallback>.has(
        "onTogglePlayback",
        onTogglePlayback,
      ),
    );
    properties.add(DiagnosticsProperty<bool>("showPlaybackButton", showPlaybackButton));
  }
}

class _ChromeGradient extends StatelessWidget {
  const _ChromeGradient({required this.fromTop});

  final bool fromTop;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
        end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
        colors: const [
          Color.fromRGBO(0, 0, 0, 0.56),
          Color.fromRGBO(0, 0, 0, 0.32),
          Color.fromRGBO(0, 0, 0, 0.12),
          Colors.transparent,
        ],
        stops: const [0, 0.34, 0.7, 1],
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>("fromTop", fromTop));
  }
}

const _chromeTextShadows = [
  Shadow(
    color: Color(0x99000000),
    blurRadius: 4,
  ),
];
const _primaryPlaybackShadows = [
  Shadow(
    color: Color(0x99000000),
    blurRadius: 6,
  ),
];

const _fullscreenChromeMinHorizontalInset = 48.0;
const _overlayIconButtonDimension = 44.0;
const _overlayIconSize = 30.0;
const _rotateOverlayIconSize = 26.0;
const _overlayActionButtonGap = AppSpacing.md;

List<Shadow> _chromeShadows(bool _) => _chromeTextShadows;

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.channel,
    required this.isFullscreen,
    required this.onBack,
    required this.onShowQuality,
  });

  final StreamChannel channel;
  final bool isFullscreen;
  final VoidCallback onBack;
  final VoidCallback onShowQuality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = channel.title.trim();
    final category = channel.category.trim().isEmpty ? "Live" : channel.category;
    final shadows = _chromeShadows(isFullscreen);

    return Row(
      children: [
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            key: const ValueKey("player_back_button"),
            tooltip: "Back",
            onPressed: onBack,
            icon: Icon(
              Icons.adaptive.arrow_back,
              color: Colors.white,
              shadows: shadows,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        AvatarRing(
          initials: channel.initials,
          size: 32,
          avatarColors: channel.avatarColors,
          imageUrl: channel.avatarImageUrl,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    flex: 0,
                    child: Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        shadows: shadows,
                      ),
                    ),
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        key: const ValueKey("player_stream_title"),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontWeight: FontWeight.w700,
                          shadows: shadows,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                key: const ValueKey("player_stream_metadata"),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_rounded,
                    key: const ValueKey("player_stream_category_icon"),
                    color: Colors.white,
                    size: 16,
                    shadows: shadows,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: shadows,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _OverlayIconButton(
          key: const ValueKey("player_quality_button"),
          tooltip: "Quality",
          icon: Icons.settings_rounded,
          shadows: shadows,
          onPressed: onShowQuality,
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(DiagnosticsProperty<bool>("isFullscreen", isFullscreen));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onBack", onBack));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onShowQuality", onShowQuality));
  }
}

class _PrimaryPlaybackButton extends StatelessWidget {
  const _PrimaryPlaybackButton({
    required this.controller,
    required this.isBusy,
    required this.isFullscreen,
    required this.onPressed,
  });

  final FlowVideoController? controller;
  final bool isBusy;
  final bool isFullscreen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller?.isPlaying ?? false;
    final canPlay = controller?.isInitialized ?? false;

    return SizedBox.square(
      dimension: 68,
      child: IconButton(
        key: const ValueKey("player_play_pause_button"),
        tooltip: isPlaying ? "Pause" : "Play",
        onPressed: canPlay && !isBusy ? onPressed : null,
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: canPlay && !isBusy ? Colors.white : Colors.white38,
          size: 56,
          shadows: _primaryPlaybackShadows,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FlowVideoController?>("controller", controller));
    properties.add(DiagnosticsProperty<bool>("isBusy", isBusy));
    properties.add(DiagnosticsProperty<bool>("isFullscreen", isFullscreen));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onPressed", onPressed));
  }
}

class _PlayerBottomBar extends StatelessWidget {
  const _PlayerBottomBar({
    required this.channel,
    required this.controller,
    required this.isBusy,
    required this.isFullscreen,
    required this.onJumpToLiveEdge,
    required this.onRefresh,
    required this.onToggleFullscreen,
  });

  final StreamChannel channel;
  final FlowVideoController? controller;
  final bool isBusy;
  final bool isFullscreen;
  final VoidCallback onJumpToLiveEdge;
  final VoidCallback onRefresh;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final shadows = _chromeShadows(isFullscreen);
    Widget buildStats() => Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LiveDot(),
            const SizedBox(width: AppSpacing.xs),
            _StreamElapsedTime(
              startedAt: channel.startedAt,
              isFullscreen: isFullscreen,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 18,
              shadows: shadows,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              channel.viewers.isEmpty ? "--" : channel.viewers,
              key: const ValueKey("player_viewer_count"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                shadows: shadows,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 18,
              shadows: shadows,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _latencyText(controller?.latencySeconds),
              key: const ValueKey("player_latency"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: shadows,
              ),
            ),
          ],
        ),
      ],
    );

    Widget buildActions() => Row(
      key: const ValueKey("player_action_buttons"),
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverlayIconButton(
          key: const ValueKey("player_jump_live_button"),
          tooltip: "Jump to live edge",
          icon: Icons.fast_forward_rounded,
          shadows: shadows,
          onPressed: isBusy ? null : onJumpToLiveEdge,
        ),
        const SizedBox(width: _overlayActionButtonGap),
        _OverlayIconButton(
          key: const ValueKey("player_refresh_button"),
          tooltip: "Refresh player",
          icon: Icons.refresh_rounded,
          shadows: shadows,
          onPressed: isBusy ? null : onRefresh,
        ),
        const SizedBox(width: _overlayActionButtonGap),
        _OverlayIconButton(
          key: const ValueKey("player_fullscreen_button"),
          tooltip: isFullscreen ? "Exit landscape" : "Enter landscape",
          icon: Icons.screen_rotation_rounded,
          iconSize: _rotateOverlayIconSize,
          shadows: shadows,
          onPressed: onToggleFullscreen,
        ),
      ],
    );

    return SizedBox(
      height: 44,
      child: isFullscreen
          ? Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: buildStats(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: buildActions(),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: buildStats(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                buildActions(),
              ],
            ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(DiagnosticsProperty<FlowVideoController?>("controller", controller));
    properties.add(DiagnosticsProperty<bool>("isBusy", isBusy));
    properties.add(DiagnosticsProperty<bool>("isFullscreen", isFullscreen));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onJumpToLiveEdge", onJumpToLiveEdge));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onRefresh", onRefresh));
    properties.add(
      ObjectFlagProperty<VoidCallback>.has(
        "onToggleFullscreen",
        onToggleFullscreen,
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconSize = _overlayIconSize,
    this.shadows,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double iconSize;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _overlayIconButtonDimension,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        color: onPressed == null ? Colors.white38 : Colors.white,
        size: iconSize,
        shadows: shadows,
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("tooltip", tooltip));
    properties.add(DiagnosticsProperty<IconData>("icon", icon));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onPressed", onPressed));
    properties.add(DoubleProperty("iconSize", iconSize));
    properties.add(IterableProperty<Shadow>("shadows", shadows));
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFF453A),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF453A).withValues(alpha: 0.3),
          blurRadius: 8,
        ),
      ],
    ),
    child: const SizedBox.square(dimension: 10),
  );
}

class _PlayerVideoSurface extends StatelessWidget {
  const _PlayerVideoSurface({
    required this.channel,
    required this.controller,
  });

  final StreamChannel channel;
  final FlowVideoController? controller;

  @override
  Widget build(BuildContext context) {
    final currentController = controller;
    if (currentController != null && currentController.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: currentController.aspectRatio,
          child: currentController.buildView(),
        ),
      );
    }

    final imageUrl = channel.thumbnailUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(DiagnosticsProperty<FlowVideoController?>("controller", controller));
  }
}

class _StreamElapsedTime extends StatefulWidget {
  const _StreamElapsedTime({
    required this.startedAt,
    required this.isFullscreen,
  });

  final DateTime? startedAt;
  final bool isFullscreen;

  @override
  State<_StreamElapsedTime> createState() => _StreamElapsedTimeState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DateTime?>("startedAt", startedAt));
    properties.add(DiagnosticsProperty<bool>("isFullscreen", isFullscreen));
  }
}

class _StreamElapsedTimeState extends State<_StreamElapsedTime> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _StreamElapsedTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (widget.startedAt == null) {
      _timer = null;
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) => Text(
    _elapsedText(widget.startedAt, DateTime.now()),
    key: const ValueKey("player_stream_elapsed"),
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: _chromeShadows(widget.isFullscreen),
    ),
  );
}

String _elapsedText(DateTime? startedAt, DateTime now) {
  if (startedAt == null) {
    return "--:--:--";
  }

  final elapsed = now.difference(startedAt);
  final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = safeElapsed.inHours;
  final minutes = safeElapsed.inMinutes.remainder(60).toString().padLeft(2, "0");
  final seconds = safeElapsed.inSeconds.remainder(60).toString().padLeft(2, "0");
  return "$hours:$minutes:$seconds";
}

String _latencyText(double? seconds) {
  if (seconds == null || seconds.isNaN || seconds.isInfinite) {
    return "--";
  }
  return "${seconds.clamp(0, double.infinity).toStringAsFixed(2)}s";
}

class _PlayerErrorState extends StatelessWidget {
  const _PlayerErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white.withValues(alpha: 0.82),
              size: 42,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              key: const ValueKey("player_error_message"),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey("player_retry_button"),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("message", message));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onRetry", onRetry));
  }
}

class _ChatReservedArea extends StatelessWidget {
  const _ChatReservedArea();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + AppSpacing.lg;

    return Stack(
      key: const ValueKey("player_chat_reserved_area"),
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Colors.black),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: bottomPadding,
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Chat",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.76),
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.more_vert_rounded,
                key: const ValueKey("player_chat_settings_icon"),
                color: Colors.white.withValues(alpha: 0.8),
                size: 32,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
