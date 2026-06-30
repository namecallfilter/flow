import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class FlowPullToRefresh extends StatefulWidget {
  const FlowPullToRefresh({
    required this.scrollController,
    required this.onRefresh,
    required this.child,
    required this.indicatorStartTop,
    required this.indicatorMaxTravel,
    super.key,
    this.triggerDistance = 96,
  });

  final ScrollController scrollController;
  final RefreshCallback onRefresh;
  final Widget child;
  final double indicatorStartTop;
  final double indicatorMaxTravel;
  final double triggerDistance;

  @override
  State<FlowPullToRefresh> createState() => _FlowPullToRefreshState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ScrollController>("scrollController", scrollController))
      ..add(ObjectFlagProperty<RefreshCallback>.has("onRefresh", onRefresh))
      ..add(DoubleProperty("indicatorStartTop", indicatorStartTop))
      ..add(DoubleProperty("indicatorMaxTravel", indicatorMaxTravel))
      ..add(DoubleProperty("triggerDistance", triggerDistance));
  }
}

class _FlowPullToRefreshState extends State<FlowPullToRefresh> {
  static const _pullResistance = 0.55;
  static const _reverseResistance = 0.9;

  double _pullExtent = 0;
  bool _isPulling = false;
  bool _hasReversed = false;
  bool _isRefreshing = false;
  bool _isSettling = false;

  bool get _isAtTop {
    if (!widget.scrollController.hasClients) {
      return false;
    }

    final position = widget.scrollController.position;
    return position.pixels <= position.minScrollExtent + 0.5;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isRefreshing) {
      return;
    }

    _isPulling = false;
    _hasReversed = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isRefreshing) {
      return;
    }

    final isPullGesture = _isPulling || (_isAtTop && event.delta.dy > 0);
    if (!isPullGesture) {
      return;
    }

    if (event.delta.dy < 0) {
      _hasReversed = true;
    }

    final dragDelta = event.delta.dy > 0
        ? event.delta.dy * _pullResistance
        : event.delta.dy * _reverseResistance;
    final nextExtent = (_pullExtent + dragDelta).clamp(0.0, widget.triggerDistance);

    _snapScrollableToTop();
    setState(() {
      _isPulling = nextExtent > 0;
      _isSettling = false;
      _pullExtent = nextExtent;
    });
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_isRefreshing) {
      return;
    }

    final shouldRefresh = _isPulling && !_hasReversed && _pullExtent >= widget.triggerDistance;
    _isPulling = false;
    _hasReversed = false;

    if (shouldRefresh) {
      unawaited(_runRefresh());
    } else {
      _collapseIndicator();
    }
  }

  Future<void> _runRefresh() async {
    setState(() {
      _isRefreshing = true;
      _isSettling = false;
      _pullExtent = widget.triggerDistance;
    });

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isSettling = true;
          _pullExtent = 0;
        });
      }
    }
  }

  void _collapseIndicator() {
    if (_pullExtent == 0) {
      setState(() {
        _isSettling = false;
      });
      return;
    }

    setState(() {
      _isSettling = true;
      _pullExtent = 0;
    });
  }

  void _snapScrollableToTop() {
    if (!widget.scrollController.hasClients) {
      return;
    }

    final position = widget.scrollController.position;
    if (position.pixels > position.minScrollExtent) {
      widget.scrollController.jumpTo(position.minScrollExtent);
    }
  }

  void _handleIndicatorSettled() {
    if (_isPulling || _isRefreshing || _pullExtent > 0 || !_isSettling) {
      return;
    }

    setState(() {
      _isSettling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_pullExtent / widget.triggerDistance).clamp(0.0, 1.0);
    final shouldShowIndicator = progress > 0 || _isRefreshing || _isSettling;
    final indicatorTop = widget.indicatorStartTop + (widget.indicatorMaxTravel * progress);
    final animationDuration = _isPulling ? Duration.zero : const Duration(milliseconds: 150);

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: Stack(
        children: [
          widget.child,
          if (shouldShowIndicator)
            AnimatedPositioned(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              top: indicatorTop,
              left: 0,
              right: 0,
              onEnd: _handleIndicatorSettled,
              child: Center(
                child: AnimatedOpacity(
                  duration: animationDuration,
                  opacity: progress > 0 || _isRefreshing ? 1 : 0,
                  child: _PullRefreshSpinner(
                    progress: progress,
                    refreshing: _isRefreshing,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PullRefreshSpinner extends StatelessWidget {
  const _PullRefreshSpinner({
    required this.progress,
    required this.refreshing,
  });

  final double progress;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshProgressIndicator(
      key: const ValueKey("pull_refresh_indicator"),
      value: refreshing ? null : progress,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty("progress", progress))
      ..add(FlagProperty("refreshing", value: refreshing, ifTrue: "refreshing"));
  }
}
