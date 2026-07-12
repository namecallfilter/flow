import "dart:async";
import "dart:math" as math;

import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/spacing.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/browse/browse_screen.dart";
import "package:flow/features/channel/channel_screen.dart";
import "package:flow/features/player/media3_player_controller.dart";
import "package:flow/features/player/media3_player_view.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

typedef PlaybackUriLoader = Future<Uri> Function(String login);
typedef ViewerCountLoader = Future<int?> Function(String login);
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
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

class StreamPlayerScreen extends StatefulWidget {
  const StreamPlayerScreen({
    required this.apiCache,
    required this.channel,
    super.key,
    this.playbackUriLoader,
    this.viewerCountLoader,
    this.playerSurfaceBuilder,
    this.preferences,
    this.displayModeController = const SystemPlayerDisplayModeController(),
    this.clock = DateTime.now,
  });

  final TwitchApiCache apiCache;
  final StreamChannel channel;
  final PlaybackUriLoader? playbackUriLoader;
  final ViewerCountLoader? viewerCountLoader;
  final PlayerSurfaceBuilder? playerSurfaceBuilder;
  final FlowPreferences? preferences;
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
    properties.add(DiagnosticsProperty<FlowPreferences?>("preferences", preferences));
    properties.add(
      ObjectFlagProperty<ViewerCountLoader?>.has("viewerCountLoader", viewerCountLoader),
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
  Timer? _viewerTimer;
  Uri? _playbackUri;
  List<String> _proxyUrls = const [];
  int? _latencyMs;
  TwitchAdEvent? _activeAd;
  final ValueNotifier<_QualitySettingsState> _qualitySettings = ValueNotifier(
    const _QualitySettingsState(qualities: [], selectedId: "auto"),
  );
  late String _viewerText;
  String? _errorMessage;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _playWhenReady = true;
  bool _controlsVisible = true;
  bool _wasPlayingBeforeBackground = false;
  bool _viewerRefreshInFlight = false;
  bool _appIsResumed = true;
  bool _openingDestination = false;
  bool _playerForcedLandscape = false;
  int _loadGeneration = 0;
  int _playbackSessionGeneration = 0;
  Future<void> _displayModeTail = Future<void>.value();

  bool get _playbackSupported =>
      widget.playerSurfaceBuilder != null || Media3PlayerView.isSupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewerText = widget.channel.viewers;
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.channel.startedAt != null) {
        setState(() {});
      }
    });
    unawaited(_refreshViewerCount());
    _viewerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_appIsResumed) {
        unawaited(_refreshViewerCount());
      }
    });
    if (_playbackSupported) {
      unawaited(_loadPlaybackUri());
    } else {
      _isBuffering = false;
      _playWhenReady = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _appIsResumed = false;
      if (_playWhenReady) {
        _wasPlayingBeforeBackground = true;
      }
      final controller = _playerController;
      if (controller == null) {
        return;
      }
      unawaited(controller.pause());
    } else if (state == AppLifecycleState.resumed) {
      _appIsResumed = true;
      unawaited(_refreshViewerCount());
      final resumePlayback = _wasPlayingBeforeBackground;
      _wasPlayingBeforeBackground = false;
      if (resumePlayback && !_openingDestination && _playerController != null) {
        unawaited(_playerController!.play());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _uptimeTimer?.cancel();
    _viewerTimer?.cancel();
    unawaited(_playerEvents?.cancel());
    _qualitySettings.dispose();
    unawaited(_queueDisplayMode(widget.displayModeController.restore));
    super.dispose();
  }

  Future<void> _loadPlaybackUri({bool refresh = false}) async {
    if (!_playbackSupported) {
      return;
    }
    final generation = ++_loadGeneration;
    if (refresh) {
      _qualitySettings.value = const _QualitySettingsState(
        qualities: [],
        selectedId: "auto",
      );
    }
    setState(() {
      _errorMessage = null;
      _isBuffering = true;
      _activeAd = null;
      if (refresh) {
        _latencyMs = null;
        _controlsVisible = true;
      }
    });

    try {
      final proxyUrls = await _loadProxyUrls();
      final loader = widget.playbackUriLoader ?? widget.apiCache.fetchLivePlaybackUri;
      final uri = await loader(widget.channel.login);
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      final previousEvents = _playerEvents;
      _playerEvents = null;
      _playerController = null;
      unawaited(previousEvents?.cancel());
      setState(() {
        _playbackUri = uri;
        _proxyUrls = proxyUrls;
        _playbackSessionGeneration++;
      });
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

  Future<List<String>> _loadProxyUrls() async {
    final settingsStore = widget.preferences == null ? AppSettingsScope.maybeOf(context) : null;
    if (widget.playbackUriLoader != null && widget.preferences == null && settingsStore == null) {
      return const [];
    }
    try {
      if (settingsStore != null) {
        if (!settingsStore.isLoaded) {
          await settingsStore.load();
        }
        if (!settingsStore.adProxyEnabled) {
          return const [];
        }
        if (widget.playbackUriLoader == null) {
          await _syncSubscriptionWhitelist(
            settingsStore.preferences,
            settingsStore: settingsStore,
          );
        }
        if (settingsStore.adProxyEffectiveWhitelistedChannels.contains(
          widget.channel.login.trim().toLowerCase(),
        )) {
          return const [];
        }
        return settingsStore.adProxyUrls.toList();
      }

      final preferences = widget.preferences ?? SharedPreferencesFlowPreferences();
      if (!await preferences.readAdProxyEnabled()) {
        return const [];
      }
      if (widget.playbackUriLoader == null) {
        await _syncSubscriptionWhitelist(preferences);
      }
      final whitelistedChannels = normalizeChannelLogins([
        ...await preferences.readAdProxyWhitelistedChannels(),
        ...await preferences.readAdProxySubscriptionChannels(),
      ]);
      if (whitelistedChannels.contains(widget.channel.login.trim().toLowerCase())) {
        return const [];
      }
      return preferences.readAdProxyUrls();
    } on Object {
      return const [];
    }
  }

  Future<void> _syncSubscriptionWhitelist(
    FlowPreferences preferences, {
    AppSettingsStore? settingsStore,
  }) async {
    try {
      final login = widget.channel.login.trim().toLowerCase();
      final isSubscribed = await widget.apiCache.fetchChannelSubscriptionStatus(login);
      if (settingsStore == null) {
        await syncSubscriptionWhitelist(
          preferences,
          login: login,
          isSubscribed: isSubscribed,
        );
      } else {
        await settingsStore.syncAdProxySubscriptionChannel(
          login: login,
          isSubscribed: isSubscribed,
        );
      }
    } on Object {
      // Subscription state is optional; playback should still start if it cannot be checked.
    }
  }

  Future<void> _refreshViewerCount() async {
    if (_viewerRefreshInFlight) {
      return;
    }
    _viewerRefreshInFlight = true;
    try {
      final loader = widget.viewerCountLoader;
      final viewerCount = loader == null
          ? await _fetchViewerCount(widget.channel.login)
          : await loader(widget.channel.login);
      if (mounted && viewerCount != null && viewerCount >= 0) {
        setState(() => _viewerText = formatCompactCount(viewerCount));
      }
    } on Object {
      // Viewer count is supplemental; preserve the last known value on failure.
    } finally {
      _viewerRefreshInFlight = false;
    }
  }

  Future<int?> _fetchViewerCount(String login) async {
    final page = await widget.apiCache.fetchLiveStreamsPage(
      first: 1,
      userLogins: [login],
      refresh: true,
    );
    return page.data.isEmpty ? null : page.data.first.viewerCount;
  }

  void _handleControllerCreated(
    TwitchPlayerController controller,
    int playbackSessionGeneration,
  ) {
    if (!mounted || playbackSessionGeneration != _playbackSessionGeneration) {
      return;
    }
    unawaited(_playerEvents?.cancel());
    _playerController = controller;
    _playerEvents = controller.events.listen(
      _handlePlayerEvent,
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isBuffering = false;
            _controlsVisible = true;
            _activeAd = null;
            _errorMessage = _playerErrorMessage(error);
          });
        }
      },
    );
    if (_openingDestination || !_appIsResumed) {
      unawaited(controller.pause());
    }
  }

  void _handlePlayerEvent(TwitchPlayerEvent event) {
    if (!mounted) {
      return;
    }
    switch (event) {
      case TwitchLatencyEvent(:final latencyMs):
        if (_playWhenReady) {
          setState(() => _latencyMs = latencyMs);
        }
      case TwitchAdEvent(:final active):
        setState(() => _activeAd = active ? event : null);
      case TwitchPlaybackStateEvent(
        :final isPlaying,
        :final isBuffering,
        :final playWhenReady,
      ):
        setState(() {
          _isPlaying = isPlaying;
          _isBuffering = isBuffering;
          _playWhenReady = playWhenReady;
          if (!playWhenReady || isBuffering) {
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
          _activeAd = null;
          _errorMessage = message;
        });
      case TwitchQualitiesEvent(:final qualities, :final selectedId):
        _qualitySettings.value = _QualitySettingsState(
          qualities: List.unmodifiable(qualities),
          selectedId: selectedId,
        );
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

  Future<void> _queueDisplayMode(Future<void> Function() operation) {
    final result = _displayModeTail.then((_) => operation());
    _displayModeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _toggleLandscape({required bool isLandscape}) async {
    setState(() => _controlsVisible = true);
    final landscape = _playerForcedLandscape ? false : !isLandscape;
    _playerForcedLandscape = landscape;
    await _queueDisplayMode(
      () => widget.displayModeController.setLandscape(landscape: landscape),
    );
  }

  Future<void> _showQualitySettings() async {
    _controlsTimer?.cancel();
    setState(() => _controlsVisible = true);
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _QualitySettingsSheet(
        settings: _qualitySettings,
        onSelected: (id) => Navigator.of(sheetContext).pop(id),
      ),
    );
    if (!mounted) {
      return;
    }
    if (selectedId != null) {
      try {
        await _playerController?.setQuality(selectedId);
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_playerErrorMessage(error))),
          );
        }
      }
    }
    if (_isPlaying) {
      _scheduleControlsHide();
    }
  }

  Future<void> _openChannel() async {
    final login = widget.channel.login.trim().isEmpty
        ? widget.channel.name.trim()
        : widget.channel.login.trim();
    if (login.isEmpty) {
      return;
    }

    await _openDestination(
      () => Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChannelScreen(
            apiCache: widget.apiCache,
            initialChannel: ChannelPreview(
              login: login,
              displayName: widget.channel.name,
              avatarImageUrl: widget.channel.avatarImageUrl,
              isLive: true,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCategory() async {
    final categoryName = widget.channel.category.trim();
    if (categoryName.isEmpty || categoryName.toLowerCase() == "live") {
      return;
    }

    await _openDestination(() async {
      try {
        final page = await widget.apiCache.searchCategoriesPage(
          categoryName,
          first: 10,
        );
        if (!mounted) {
          return;
        }

        final normalizedName = categoryName.toLowerCase();
        final matches = page.data.where(
          (category) => category.name.trim().toLowerCase() == normalizedName,
        );
        final category = matches.firstOrNull;
        if (category == null) {
          _showDestinationError("That category is no longer available.");
          return;
        }

        final destination = BrowseCategory(
          id: category.id,
          name: category.name,
          viewerCount: 0,
          viewers: "--",
          imageUrl: twitchBoxArtUrl(category.boxArtUrl),
          colors: colorsForText(category.id),
        );
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => CategoryStreamsScreen(
              apiCache: widget.apiCache,
              category: destination,
            ),
          ),
        );
      } on Object catch (error) {
        if (mounted) {
          _showDestinationError(browseErrorMessage(error));
        }
      }
    });
  }

  Future<void> _openDestination(Future<void> Function() open) async {
    if (_openingDestination) {
      return;
    }
    _openingDestination = true;
    _controlsTimer?.cancel();
    final resumeOnReturn = _playWhenReady;
    final restoreLandscapeOnReturn = _playerForcedLandscape;
    try {
      if (resumeOnReturn) {
        await _playerController?.pause();
      }
      if (restoreLandscapeOnReturn) {
        await _queueDisplayMode(widget.displayModeController.restore);
      }
      if (!mounted) {
        return;
      }
      await open();
    } finally {
      _openingDestination = false;
      if (mounted && restoreLandscapeOnReturn) {
        await _queueDisplayMode(
          () => widget.displayModeController.setLandscape(landscape: true),
        );
      }
      if (mounted && resumeOnReturn) {
        if (_appIsResumed) {
          await _playerController?.play();
        } else {
          _wasPlayingBeforeBackground = true;
        }
      }
    }
  }

  void _showDestinationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.size.width > mediaQuery.size.height;
    final playbackSessionGeneration = _playbackSessionGeneration;
    final viewport = _PlayerViewport(
      channel: widget.channel,
      playbackUri: _playbackUri,
      proxyUrls: _proxyUrls,
      playbackSessionGeneration: playbackSessionGeneration,
      playbackSupported: _playbackSupported,
      playerSurfaceBuilder: widget.playerSurfaceBuilder,
      onControllerCreated: (controller) => _handleControllerCreated(
        controller,
        playbackSessionGeneration,
      ),
      isLandscape: isLandscape,
      controlsVisible: _controlsVisible,
      isBuffering: _isBuffering,
      playWhenReady: _playWhenReady,
      latencyMs: _latencyMs,
      activeAd: _activeAd,
      viewerText: _viewerText,
      liveDuration: _liveDuration,
      errorMessage: _errorMessage,
      onSurfaceTap: _toggleControls,
      onBack: Navigator.of(context).maybePop,
      onTogglePlayback: _togglePlayback,
      onJumpToLive: _jumpToLive,
      onRefresh: () => _loadPlaybackUri(refresh: true),
      onToggleLandscape: () => _toggleLandscape(isLandscape: isLandscape),
      onSettings: _showQualitySettings,
      onProfileTap: () => unawaited(_openChannel()),
      onCategoryTap: () => unawaited(_openCategory()),
    );

    return Scaffold(
      key: ValueKey("player_page_${widget.channel.login}"),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: !isLandscape,
        bottom: false,
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = isLandscape
                ? constraints.maxHeight
                : constraints.maxWidth * 9 / 16;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                height: viewportHeight,
                child: viewport,
              ),
            );
          },
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

Future<void> _subscriptionWhitelistUpdateTail = Future<void>.value();

Future<void> syncSubscriptionWhitelist(
  FlowPreferences preferences, {
  required String login,
  required bool isSubscribed,
}) {
  final result = _subscriptionWhitelistUpdateTail.then((_) async {
    final normalized = normalizeChannelLogins([login]);
    if (normalized.isEmpty) {
      return;
    }
    final normalizedLogin = normalized.single;
    final channels = await preferences.readAdProxySubscriptionChannels();
    if (isSubscribed && !channels.contains(normalizedLogin)) {
      await preferences.saveAdProxySubscriptionChannels([...channels, normalizedLogin]);
    } else if (!isSubscribed && channels.contains(normalizedLogin)) {
      await preferences.saveAdProxySubscriptionChannels(channels.toList()..remove(normalizedLogin));
    }
  });
  _subscriptionWhitelistUpdateTail = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return result;
}

class _PlayerViewport extends StatelessWidget {
  const _PlayerViewport({
    required this.channel,
    required this.playbackUri,
    required this.proxyUrls,
    required this.playbackSessionGeneration,
    required this.playbackSupported,
    required this.playerSurfaceBuilder,
    required this.onControllerCreated,
    required this.isLandscape,
    required this.controlsVisible,
    required this.isBuffering,
    required this.playWhenReady,
    required this.latencyMs,
    required this.activeAd,
    required this.viewerText,
    required this.liveDuration,
    required this.errorMessage,
    required this.onSurfaceTap,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onJumpToLive,
    required this.onRefresh,
    required this.onToggleLandscape,
    required this.onSettings,
    required this.onProfileTap,
    required this.onCategoryTap,
  });

  final StreamChannel channel;
  final Uri? playbackUri;
  final List<String> proxyUrls;
  final int playbackSessionGeneration;
  final bool playbackSupported;
  final PlayerSurfaceBuilder? playerSurfaceBuilder;
  final ValueChanged<TwitchPlayerController> onControllerCreated;
  final bool isLandscape;
  final bool controlsVisible;
  final bool isBuffering;
  final bool playWhenReady;
  final int? latencyMs;
  final TwitchAdEvent? activeAd;
  final String viewerText;
  final Duration? liveDuration;
  final String? errorMessage;
  final VoidCallback onSurfaceTap;
  final VoidCallback onBack;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function() onJumpToLive;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onToggleLandscape;
  final Future<void> Function() onSettings;
  final VoidCallback onProfileTap;
  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final horizontalPadding = isLandscape
        ? math.max(AppSpacing.sm, math.max(viewPadding.left, viewPadding.right))
        : AppSpacing.sm;
    final verticalPadding = isLandscape
        ? math.max(AppSpacing.sm, math.max(viewPadding.top, viewPadding.bottom))
        : AppSpacing.sm;

    return ColoredBox(
      key: const ValueKey("player_viewport"),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!playbackSupported)
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Text(
                  Media3PlayerView.unsupportedMessage,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else if (playbackUri case final uri?)
            KeyedSubtree(
              key: ValueKey("player_media_surface_$playbackSessionGeneration"),
              child: playerSurfaceBuilder == null
                  ? Media3PlayerView(
                      uri: uri,
                      proxyUrls: proxyUrls,
                      onControllerCreated: onControllerCreated,
                    )
                  : playerSurfaceBuilder!(context, uri, onControllerCreated),
            ),
          KeyedSubtree(
            key: ValueKey("player_chrome_${isLandscape ? "landscape" : "portrait"}"),
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    key: const ValueKey("player_scrim"),
                    opacity: controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const IgnorePointer(child: _PlayerScrim()),
                  ),
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
                            _PlayerHeader(
                              channel: channel,
                              onBack: onBack,
                              onSettings: onSettings,
                              onProfileTap: onProfileTap,
                              onCategoryTap: onCategoryTap,
                            ),
                            _PlayerFooter(
                              viewers: viewerText,
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
                  if (playbackSupported)
                    if (errorMessage case final message?)
                      Center(
                        child: _PlayerError(message: message, onRetry: onRefresh),
                      )
                    else
                      Center(
                        key: const ValueKey("player_center_control"),
                        child: _CenterPlaybackControl(
                          playWhenReady: playWhenReady,
                          isBuffering: isBuffering,
                          visible: controlsVisible,
                          onPressed: onTogglePlayback,
                        ),
                      ),
                ],
              ),
            ),
          ),
          if (activeAd case final ad?)
            AnimatedPositioned(
              key: const ValueKey("player_ad_position"),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              top: verticalPadding + (controlsVisible ? 44 : 4),
              left: horizontalPadding + 48,
              right: horizontalPadding + 48,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _AdProgressPill(ad: ad),
                ),
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
    properties.add(IterableProperty<String>("proxyUrls", proxyUrls));
    properties.add(IntProperty("playbackSessionGeneration", playbackSessionGeneration));
    properties.add(
      FlagProperty(
        "playbackSupported",
        value: playbackSupported,
        ifTrue: "playback supported",
      ),
    );
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
    properties.add(FlagProperty("isBuffering", value: isBuffering, ifTrue: "buffering"));
    properties.add(
      FlagProperty("playWhenReady", value: playWhenReady, ifTrue: "play requested"),
    );
    properties.add(IntProperty("latencyMs", latencyMs));
    properties.add(DiagnosticsProperty<TwitchAdEvent?>("activeAd", activeAd));
    properties.add(StringProperty("viewerText", viewerText));
    properties.add(DiagnosticsProperty<Duration?>("liveDuration", liveDuration));
    properties.add(StringProperty("errorMessage", errorMessage));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onProfileTap", onProfileTap));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onCategoryTap", onCategoryTap));
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
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has("onSettings", onSettings),
    );
  }
}

class _AdProgressPill extends StatelessWidget {
  const _AdProgressPill({required this.ad});

  final TwitchAdEvent ad;

  @override
  Widget build(BuildContext context) {
    final text = _formatAdProgress(ad);
    return Semantics(
      key: const ValueKey("player_ad_progress"),
      container: true,
      label: _adSemanticsLabel(ad),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            key: const ValueKey("player_ad_progress_text"),
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAdEvent>("ad", ad));
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
  const _PlayerHeader({
    required this.channel,
    required this.onBack,
    required this.onSettings,
    required this.onProfileTap,
    required this.onCategoryTap,
  });

  final StreamChannel channel;
  final VoidCallback onBack;
  final Future<void> Function() onSettings;
  final VoidCallback onProfileTap;
  final VoidCallback onCategoryTap;

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
      Semantics(
        button: true,
        label: "Open ${channel.name} channel",
        child: GestureDetector(
          key: const ValueKey("player_profile_button"),
          behavior: HitTestBehavior.opaque,
          onTap: onProfileTap,
          child: AvatarRing(
            key: const ValueKey("player_avatar"),
            initials: channel.initials,
            size: 36,
            avatarColors: channel.avatarColors,
            imageUrl: channel.avatarImageUrl,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: channel.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (channel.title.isNotEmpty)
                    TextSpan(
                      text: "  ${channel.title}",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              key: const ValueKey("player_name_and_title"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Semantics(
              button: true,
              label: "Open ${channel.category} category",
              child: GestureDetector(
                key: const ValueKey("player_category_button"),
                behavior: HitTestBehavior.opaque,
                onTap: onCategoryTap,
                child: Row(
                  key: const ValueKey("player_category_row"),
                  children: [
                    Icon(
                      Icons.category_rounded,
                      color: Colors.white.withValues(alpha: 0.78),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        channel.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      _OverlayIconButton(
        key: const ValueKey("player_settings_button"),
        tooltip: "Video quality",
        icon: Icons.settings_rounded,
        onPressed: onSettings,
      ),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onBack", onBack));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onProfileTap", onProfileTap));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onCategoryTap", onCategoryTap));
    properties.add(
      ObjectFlagProperty<Future<void> Function()>.has("onSettings", onSettings),
    );
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
      const SizedBox(
        width: 32,
        height: 40,
        child: Padding(
          padding: EdgeInsets.only(left: 12, right: 4),
          child: Center(
            child: _LiveDot(key: ValueKey("player_live_dot")),
          ),
        ),
      ),
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _OverlayMetric(
                  key: const ValueKey("player_live_duration"),
                  text: _formatLiveDuration(liveDuration),
                ),
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
      const SizedBox(width: AppSpacing.sm),
      _OverlayIconButton(
        key: const ValueKey("player_refresh_button"),
        tooltip: "Refresh player",
        icon: Icons.refresh_rounded,
        onPressed: onRefresh,
      ),
      const SizedBox(width: AppSpacing.sm),
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
    required this.playWhenReady,
    required this.isBuffering,
    required this.visible,
    required this.onPressed,
  });

  final bool playWhenReady;
  final bool isBuffering;
  final bool visible;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final showBufferingIndicator = isBuffering && playWhenReady;
    return IgnorePointer(
      ignoring: !visible || showBufferingIndicator,
      child: AnimatedOpacity(
        opacity: visible || showBufferingIndicator ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: showBufferingIndicator
            ? const SizedBox.square(
                dimension: 42,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : IconButton(
                key: const ValueKey("player_play_pause_button"),
                tooltip: playWhenReady ? "Pause" : "Play",
                onPressed: onPressed,
                iconSize: 54,
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  minimumSize: const Size.square(68),
                ),
                icon: Icon(
                  playWhenReady ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      FlagProperty("playWhenReady", value: playWhenReady, ifTrue: "play requested"),
    );
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

class _QualitySettingsState {
  const _QualitySettingsState({
    required this.qualities,
    required this.selectedId,
  });

  final List<TwitchQualityOption> qualities;
  final String selectedId;
}

class _QualitySettingsSheet extends StatelessWidget {
  const _QualitySettingsSheet({
    required this.settings,
    required this.onSelected,
  });

  final ValueListenable<_QualitySettingsState> settings;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: ValueListenableBuilder<_QualitySettingsState>(
        valueListenable: settings,
        builder: (context, state, _) => Column(
          key: const ValueKey("player_quality_sheet"),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  "Quality",
                  key: const ValueKey("player_quality_heading"),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Divider(
              key: ValueKey("player_quality_heading_divider"),
              height: 1,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
            ),
            Flexible(
              child: ListView(
                key: const ValueKey("player_quality_list"),
                shrinkWrap: true,
                primary: false,
                padding: EdgeInsets.zero,
                children: [
                  _QualityOptionTile(
                    id: "auto",
                    label: "Auto",
                    selected: state.selectedId == "auto",
                    onSelected: onSelected,
                  ),
                  for (final quality in state.qualities)
                    _QualityOptionTile(
                      id: quality.id,
                      label: quality.label,
                      selected: state.selectedId == quality.id,
                      onSelected: onSelected,
                    ),
                  if (state.qualities.isEmpty)
                    const SizedBox(
                      key: ValueKey("player_quality_loading"),
                      height: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<ValueListenable<_QualitySettingsState>>(
        "settings",
        settings,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<String>>.has("onSelected", onSelected),
    );
  }
}

class _QualityOptionTile extends StatelessWidget {
  const _QualityOptionTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String id;
  final String label;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: ListTile(
      key: ValueKey("player_quality_$id"),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: () => onSelected(id),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("id", id));
    properties.add(StringProperty("label", label));
    properties.add(FlagProperty("selected", value: selected, ifTrue: "selected"));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>>.has("onSelected", onSelected),
    );
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
    style: IconButton.styleFrom(
      minimumSize: const Size.square(40),
      maximumSize: const Size.square(40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    color: Colors.white,
    iconSize: 27,
    icon: Icon(icon),
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
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("text", text));
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: Center(
      child: SizedBox.square(
        dimension: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.liveRed,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

String _formatLatency(int? latencyMs) =>
    latencyMs == null ? "--" : "${(latencyMs / 1000).toStringAsFixed(2)}s";

String _formatAdProgress(TwitchAdEvent ad) {
  final hasCount = ad.current > 0 && ad.total > 0 && ad.current <= ad.total;
  final prefix = hasCount ? "Ad ${ad.current} of ${ad.total}" : "Ad";
  return "$prefix · ${_formatAdCountdown(ad.remainingMs)}";
}

String _formatAdCountdown(int remainingMs) {
  final totalSeconds = math.max(0, (remainingMs + 999) ~/ 1000);
  final hours = totalSeconds ~/ Duration.secondsPerHour;
  final minutes = (totalSeconds ~/ Duration.secondsPerMinute).remainder(60);
  final seconds = totalSeconds.remainder(60).toString().padLeft(2, "0");
  if (hours > 0) {
    return "$hours:${minutes.toString().padLeft(2, "0")}:$seconds";
  }
  return "$minutes:$seconds";
}

String _adSemanticsLabel(TwitchAdEvent ad) {
  final hasCount = ad.current > 0 && ad.total > 0 && ad.current <= ad.total;
  final count = hasCount ? " ${ad.current} of ${ad.total}" : "";
  final remainingSeconds = math.max(0, (ad.remainingMs + 999) ~/ 1000);
  return "Advertisement$count, $remainingSeconds seconds remaining";
}

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
