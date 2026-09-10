import "dart:async";
import "dart:math" as math;

import "package:flow/features/player/player_screen.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

int _openStreamPlayerGeneration = 0;

Future<void> openStreamPlayer(BuildContext context, {required WidgetBuilder builder}) async {
  final generation = ++_openStreamPlayerGeneration;
  if (Tooltip.dismissAllToolTips()) {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted || generation != _openStreamPlayerGeneration) {
      return;
    }
  }
  final screen = builder(context);
  final host = PlaybackHost.maybeOf(context);
  if (host != null && screen is StreamPlayerScreen) {
    return host.open(context, screen);
  }
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}

enum PlaybackMode { expanded, mini, pip }

/// Keeps a single platform view mounted above the app's navigation stack.
class PlaybackHost extends NavigatorObserver {
  OverlayEntry? _entry;
  StreamPlayerScreen? _screen;
  PageRoute<void>? _playerRoute;
  Route<dynamic>? _backPreviewRoute;
  PageRoute<void>? _playerBackRoute;
  double _backProgress = 0;
  SwipeEdge _backSwipeEdge = SwipeEdge.left;
  LocalHistoryEntry? _inlineHistory;
  MaterialPageRoute<void>? _overlayPageRoute;
  PlaybackMode _mode = PlaybackMode.expanded;
  PlaybackMode _modeBeforePip = PlaybackMode.expanded;
  String? _identity;
  final _overlayRoutes = <Route<dynamic>>[];
  bool miniPlayerEnabled = true;
  bool _chatOnly = false;
  bool _browsingFromPlayer = false;
  double _dragOffset = 0;
  bool _dragging = false;
  bool _dismissing = false;
  bool _settling = false;
  bool _pipTransition = false;
  bool _skipAnimation = false;
  Size? _windowSize;

  static PlaybackHost? maybeOf(BuildContext context) => Navigator.of(
    context,
    rootNavigator: true,
  ).widget.observers.whereType<PlaybackHost>().firstOrNull;

  PlaybackMode get mode => _mode;
  bool get _canMinimize => miniPlayerEnabled && !_chatOnly;

  bool startBackGesture(PredictiveBackEvent event) {
    final route = _playerRoute;
    if (event.isButtonEvent ||
        _mode != PlaybackMode.expanded ||
        route == null ||
        !route.isCurrent ||
        !route.popGestureEnabled) {
      return false;
    }
    _playerBackRoute = route;
    _backSwipeEdge = event.swipeEdge;
    _backProgress = event.progress;
    route.handleStartBackGesture(progress: 1 - event.progress);
    _changed();
    return true;
  }

  void updateBackGestureProgress(PredictiveBackEvent event) {
    _backProgress = event.progress;
    _playerBackRoute?.handleUpdateBackGestureProgress(progress: 1 - event.progress);
    _changed();
  }

  void finishBackGesture({required bool commit}) {
    final route = _playerBackRoute;
    _playerBackRoute = null;
    _backProgress = 0;
    _changed();
    if (commit) {
      route?.handleCommitBackGesture();
    } else {
      route?.handleCancelBackGesture();
    }
  }

  void setInlineBackHandler(VoidCallback? onClose) {
    final previous = _inlineHistory;
    _inlineHistory = null;
    previous?.remove();
    if (onClose == null || _playerRoute == null) {
      return;
    }
    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(
      onRemove: () {
        if (_inlineHistory == entry) {
          _inlineHistory = null;
          onClose();
        }
      },
    );
    _inlineHistory = entry;
    _playerRoute!.addLocalHistoryEntry(entry);
  }

  void setChatOnly({required bool enabled}) {
    _chatOnly = enabled;
    _skipAnimation = true;
    _changed();
  }

  void setMiniPlayerEnabled({required bool enabled}) {
    miniPlayerEnabled = enabled;
    if (!enabled && _mode == PlaybackMode.mini) {
      if (_browsingFromPlayer) {
        _mode = PlaybackMode.expanded;
        _changed();
      } else {
        dismiss();
      }
    } else {
      _changed();
    }
  }

  void beginSwipe() {
    _dragging = true;
    _settling = false;
    _changed();
  }

  void updateSwipe(double delta) {
    _dragOffset = _mode == PlaybackMode.mini
        ? _dragOffset + delta
        : math.max(0, _dragOffset + delta);
    _changed();
  }

  void endSwipe(double velocity) {
    _dragging = false;
    _settling = true;
    if (_mode == PlaybackMode.mini) {
      if (_dragOffset.abs() > 80 || velocity.abs() > 700) {
        _dismissing = true;
        if (_dragOffset == 0) {
          _dragOffset = velocity.sign;
        }
      } else {
        _dragOffset = 0;
      }
      _changed();
    } else if (_dragOffset > 80 || velocity > 700) {
      if (_canMinimize) {
        minimize();
      } else {
        _dismissing = true;
        _changed();
      }
    } else {
      restore();
    }
  }

  void cancelSwipe() {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    _settling = _dragOffset != 0;
    _dragOffset = 0;
    _changed();
  }

  Future<void> open(
    BuildContext context,
    StreamPlayerScreen screen,
  ) async {
    final identity = screen.videoId == null
        ? "live:${screen.channel.login.toLowerCase()}"
        : "vod:${screen.videoId}";
    if (_identity != identity ||
        screen.initiallyOffline ||
        screen.initiallyOffline != _screen?.initiallyOffline) {
      _chatOnly = screen.initiallyOffline;
      _screen = screen;
      _identity = identity;
    }
    if (_entry == null) {
      _entry = OverlayEntry(
        builder: (context) => Offstage(
          offstage:
              _browsingFromPlayer && _mode == PlaybackMode.expanded && _backPreviewRoute == null,
          child: Transform.scale(
            scale: 1 - 0.1 * _backProgress,
            child: Transform.translate(
              offset: Offset(
                math.max(0, MediaQuery.sizeOf(context).width / 20 - 8) *
                    _backProgress *
                    (_backSwipeEdge == SwipeEdge.right ? -1 : 1),
                0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32 * _backProgress),
                child: _buildPlayer(context),
              ),
            ),
          ),
        ),
        maintainState: true,
      );
      navigator!.overlay!.insert(_entry!);
    }
    _dismissing = false;
    restore();
  }

  void minimize({bool forNavigation = false}) {
    if (_entry == null || _mode == PlaybackMode.pip || _mode == PlaybackMode.mini) {
      return;
    }
    if (!_canMinimize && !forNavigation) {
      dismiss();
      return;
    }
    _dragOffset = 0;
    _settling = true;
    _browsingFromPlayer = forNavigation && _playerRoute != null;
    _mode = _canMinimize ? PlaybackMode.mini : PlaybackMode.expanded;
    if (!forNavigation) {
      _removePlayerRoute();
    }
    _changed();
  }

  void restore() {
    if (_entry == null || _dismissing) {
      return;
    }
    _settling = _backPreviewRoute == null && (_mode != PlaybackMode.expanded || _dragOffset > 0);
    _backPreviewRoute = null;
    _mode = PlaybackMode.expanded;
    _dragOffset = 0;
    _dragging = false;
    _dismissing = false;
    _browsingFromPlayer = false;
    if (_playerRoute != null && !_playerRoute!.isCurrent) {
      _removePlayerRoute();
    }
    if (_playerRoute == null) {
      final route = PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const SizedBox.expand(),
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
      _playerRoute = route;
      unawaited(navigator!.push<void>(route));
    }
    _changed();
    _bringToFront();
  }

  Future<void> openOverlayPage({required WidgetBuilder builder}) async {
    final route = MaterialPageRoute<void>(builder: builder);
    _overlayPageRoute = route;
    await navigator!.push<void>(route);
    await route.completed;
    if (_overlayPageRoute == route) {
      _overlayPageRoute = null;
      _bringToFront();
    }
  }

  void setPictureInPicture({required bool active}) {
    if (_entry == null) {
      return;
    }
    _pipTransition = false;
    _skipAnimation = true;
    _settling = false;
    if (active && _mode != PlaybackMode.pip) {
      _modeBeforePip = _mode;
      _mode = PlaybackMode.pip;
    } else if (!active && _mode == PlaybackMode.pip) {
      _mode = _modeBeforePip;
      if (_mode == PlaybackMode.mini && !_canMinimize) {
        dismiss();
        return;
      }
    }
    _changed();
    _bringToFront();
  }

  void setPictureInPictureTransition({required bool active}) {
    _pipTransition = active;
    _changed();
    _bringToFront();
  }

  void dismiss() {
    _inlineHistory?.remove();
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    _screen = null;
    _chatOnly = false;
    _browsingFromPlayer = false;
    _identity = null;
    _backPreviewRoute = null;
    _playerBackRoute = null;
    _backProgress = 0;
    _mode = PlaybackMode.expanded;
    _modeBeforePip = PlaybackMode.expanded;
    _dragOffset = 0;
    _dragging = false;
    _dismissing = false;
    _settling = false;
    _pipTransition = false;
    _skipAnimation = false;
    _windowSize = null;
    _removePlayerRoute();
  }

  void _removePlayerRoute() {
    _inlineHistory?.remove();
    final route = _playerRoute;
    _playerRoute = null;
    if (route?.isActive == true) {
      navigator!.removeRoute(route!);
    }
  }

  void _changed() {
    _entry?.markNeedsBuild();
  }

  void _bringToFront() {
    scheduleMicrotask(() {
      if (_entry != null && navigator?.mounted == true) {
        navigator!.overlay!.rearrange(
          [
            _entry!,
            if (_backPreviewRoute?.isCurrent == true) ..._backPreviewRoute!.overlayEntries,
            if (_mode != PlaybackMode.pip && !_pipTransition)
              for (final route in _overlayRoutes) ...route.overlayEntries,
          ],
          below: _entry,
        );
      }
    });
  }

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == _playerRoute && _browsingFromPlayer) {
      _backPreviewRoute = route;
      _skipAnimation = true;
      _changed();
      _bringToFront();
    }
  }

  @override
  void didStopUserGesture() {
    if (_backPreviewRoute?.isCurrent == true) {
      _backPreviewRoute = null;
      _skipAnimation = true;
      _changed();
      _bringToFront();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute || route == _overlayPageRoute) {
      _overlayRoutes.add(route);
    }
    if (route is TransitionRoute) {
      void updateOrder(AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          _overlayRoutes.remove(route);
        }
        if (status == AnimationStatus.dismissed && route == _overlayPageRoute) {
          _overlayPageRoute = null;
        }
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          _bringToFront();
        }
      }

      route.animation?.addStatusListener(updateOrder);
      unawaited(
        route.completed.then((_) {
          route.animation?.removeStatusListener(updateOrder);
          if (_overlayRoutes.remove(route)) {
            _bringToFront();
          }
        }),
      );
    }
    if (route is! PopupRoute &&
        route != _playerRoute &&
        route != _overlayPageRoute &&
        _entry != null) {
      // Navigator is locked during observer callbacks.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isCurrent) {
          minimize(forNavigation: true);
        }
      });
    }
    _bringToFront();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == _playerRoute) {
      _playerRoute = null;
      minimize();
    }
    _bringToFront();
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (topRoute == _playerRoute && _browsingFromPlayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_playerRoute?.isCurrent == true && _browsingFromPlayer) {
          restore();
        }
      });
    }
    _bringToFront();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _overlayRoutes.remove(route);
    if (route == _overlayPageRoute) {
      _overlayPageRoute = null;
    }
    _bringToFront();
  }

  Widget _buildPlayer(BuildContext context) {
    final media = MediaQuery.of(context);
    final mode = _backPreviewRoute == null ? _mode : PlaybackMode.expanded;
    final mini =
        mode == PlaybackMode.mini ||
        (mode == PlaybackMode.pip &&
            _modeBeforePip == PlaybackMode.mini &&
            media.size.width < media.size.height);
    final pip = mode == PlaybackMode.pip;
    final resized = _windowSize != null && _windowSize != media.size;
    _windowSize = media.size;
    final animate = !_dragging && !pip && !_pipTransition && !_skipAnimation && !resized;
    _skipAnimation = false;
    final miniWidth = math.min(200.0, media.size.width - 24);
    final miniHeight = miniWidth * 9 / 16;
    final miniRect = Rect.fromLTWH(
      media.size.width - miniWidth - 12,
      math.max(media.padding.top, media.size.height - miniHeight - media.padding.bottom - 84),
      miniWidth,
      miniHeight,
    );
    final landscape = media.size.width > media.size.height;
    final expandedRect = Rect.fromLTWH(
      0,
      landscape || _chatOnly ? 0 : media.padding.top,
      media.size.width,
      landscape ? media.size.height : media.size.width * 9 / 16,
    );
    final progress = mini
        ? 1.0
        : (_dragOffset / math.max(1, miniRect.top - expandedRect.top)).clamp(0.0, 1.0);
    var rect = mini ? miniRect : expandedRect;
    if (mini) {
      rect = rect.shift(
        Offset(
          _dismissing ? _dragOffset.sign * media.size.width : _dragOffset,
          0,
        ),
      );
    } else if (_dismissing) {
      rect = rect.shift(Offset(0, media.size.height));
    } else if (_dragOffset > 0) {
      rect = _canMinimize
          ? Rect.lerp(expandedRect, miniRect, progress)!
          : rect.shift(Offset(0, _dragOffset));
    }
    final pageRect = _canMinimize
        ? Rect.fromLTRB(
            rect.left,
            rect.top,
            rect.right,
            media.size.height + (miniRect.bottom - media.size.height) * progress,
          )
        : Rect.fromLTWH(
            rect.left,
            rect.top,
            rect.width,
            media.size.height - expandedRect.top,
          );
    final moving = _backPreviewRoute == null && (_dragging || _settling || _dismissing);
    final borderRadius = BorderRadius.circular(mini || _dragOffset > 0 ? 10 : 0);
    return Stack(
      children: [
        AnimatedPositioned.fromRect(
          rect: !mini && !moving
              ? Rect.fromLTRB(pageRect.left, 0, pageRect.right, pageRect.bottom)
              : pageRect,
          duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: mini || pip || moving || _pipTransition,
            child: Visibility(
              visible: !pip,
              maintainState: true,
              child: AnimatedOpacity(
                opacity: _dismissing ? 0 : 1,
                duration: _dragging || !animate ? Duration.zero : const Duration(milliseconds: 220),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: ColoredBox(
                    key: const ValueKey("player_page_background"),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned.fromRect(
          rect: pip ? rect : pageRect,
          duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
          curve: Curves.easeOutCubic,
          onEnd: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_dismissing) {
              dismiss();
            } else if (_settling) {
              _settling = false;
              _changed();
            }
          }),
          child: AnimatedOpacity(
            opacity: _dismissing ? 0 : 1,
            duration: _dragging || !animate ? Duration.zero : const Duration(milliseconds: 220),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: mini ? (_) => beginSwipe() : null,
                onHorizontalDragUpdate: mini ? (details) => updateSwipe(details.delta.dx) : null,
                onHorizontalDragEnd: mini
                    ? (details) => endSwipe(details.primaryVelocity ?? 0)
                    : null,
                onHorizontalDragCancel: mini ? cancelSwipe : null,
                child: PlaybackPresentation(
                  host: this,
                  mode: mode,
                  hideChrome: moving || _pipTransition,
                  miniPlayerEnabled: miniPlayerEnabled,
                  child: KeyedSubtree(key: ValueKey(_identity), child: _screen!),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PlaybackPresentation extends InheritedWidget {
  const PlaybackPresentation({
    required this.host,
    required this.mode,
    this.miniPlayerEnabled = true,
    this.hideChrome = false,
    required super.child,
    super.key,
  });

  final PlaybackHost host;
  final PlaybackMode mode;
  final bool miniPlayerEnabled;
  final bool hideChrome;

  static PlaybackPresentation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlaybackPresentation>();

  @override
  bool updateShouldNotify(PlaybackPresentation oldWidget) =>
      mode != oldWidget.mode ||
      miniPlayerEnabled != oldWidget.miniPlayerEnabled ||
      hideChrome != oldWidget.hideChrome;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<PlaybackHost>("host", host));
    properties.add(EnumProperty<PlaybackMode>("mode", mode));
    properties.add(DiagnosticsProperty<bool>("hideChrome", hideChrome));
    properties.add(DiagnosticsProperty<bool>("miniPlayerEnabled", miniPlayerEnabled));
  }
}
