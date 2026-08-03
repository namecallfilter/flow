import "dart:ui";

import "package:flow/app/spacing.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class ScrollReactiveHeaderProgressNotification extends Notification {
  const ScrollReactiveHeaderProgressNotification(this.hiddenFraction);

  final double hiddenFraction;
}

class ScrollReactiveChrome extends StatefulWidget {
  const ScrollReactiveChrome({
    required this.scrollController,
    required this.header,
    required this.child,
    super.key,
    this.ignoreScrollUpdates,
  });

  static const scrollToTopShowThreshold = 600.0;
  static const scrollToTopHideThreshold = 80.0;

  static EdgeInsets safeAreaInsetsOf(BuildContext context) {
    final view = View.of(context);
    return EdgeInsets.fromViewPadding(
      view.viewPadding,
      view.devicePixelRatio,
    );
  }

  final ScrollController scrollController;
  final Widget header;
  final Widget child;
  final bool Function()? ignoreScrollUpdates;

  @override
  State<ScrollReactiveChrome> createState() => _ScrollReactiveChromeState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ScrollController>("scrollController", scrollController))
      ..add(ObjectFlagProperty<bool Function()?>.has("ignoreScrollUpdates", ignoreScrollUpdates));
  }
}

class _ScrollReactiveChromeState extends State<ScrollReactiveChrome> {
  final _headerKey = GlobalKey();
  final _headerOffset = ValueNotifier(0.0);
  final _showScrollToTop = ValueNotifier(false);
  ScrollPosition? _scrollPosition;
  double? _lastScrollPixels;
  double _headerHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(ScrollReactiveChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
      _scrollPosition = null;
      _lastScrollPixels = null;
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    _headerOffset.dispose();
    _showScrollToTop.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.scrollController.hasClients) {
      _scrollPosition = null;
      _lastScrollPixels = null;
      return;
    }

    final position = widget.scrollController.position;
    final currentPixels = position.pixels.clamp(position.minScrollExtent, position.maxScrollExtent);
    final previousPixels = identical(_scrollPosition, position)
        ? _lastScrollPixels ?? currentPixels
        : currentPixels;
    _scrollPosition = position;
    _lastScrollPixels = currentPixels;
    final ignoreScrollUpdates = widget.ignoreScrollUpdates?.call() ?? false;

    if (currentPixels <= position.minScrollExtent + 0.5) {
      _setHeaderOffset(
        0,
        notify: !ignoreScrollUpdates,
        notifyIfUnchanged: true,
      );
    } else if (!ignoreScrollUpdates && _headerHeight > 0) {
      final scrollDelta = currentPixels - previousPixels;
      if (scrollDelta != 0) {
        _setHeaderOffset(
          _headerOffset.value - scrollDelta,
          notifyIfUnchanged: true,
        );
      }
    }

    final scrollDistance = currentPixels - position.minScrollExtent;
    _showScrollToTop.value = _showScrollToTop.value
        ? scrollDistance > ScrollReactiveChrome.scrollToTopHideThreshold
        : scrollDistance >= ScrollReactiveChrome.scrollToTopShowThreshold;
  }

  void _syncAfterLayout() {
    if (!mounted) {
      return;
    }

    final measuredHeight = _headerKey.currentContext?.size?.height;
    if (measuredHeight != null && measuredHeight > 0 && measuredHeight != _headerHeight) {
      final hiddenFraction = _headerHeight == 0
          ? 0.0
          : (-_headerOffset.value / _headerHeight).clamp(0.0, 1.0);
      setState(() {
        _headerHeight = measuredHeight;
      });
      _setHeaderOffset(-_headerHeight * hiddenFraction);
    }

    if (!widget.scrollController.hasClients) {
      _scrollPosition = null;
      _lastScrollPixels = null;
      _setHeaderOffset(0);
      _showScrollToTop.value = false;
      return;
    }
    final position = widget.scrollController.position;
    final currentPixels = position.pixels.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (!identical(_scrollPosition, position)) {
      _scrollPosition = position;
      _lastScrollPixels = currentPixels;
    } else {
      _lastScrollPixels ??= currentPixels;
    }
    if (currentPixels <= position.minScrollExtent + 0.5) {
      _setHeaderOffset(0);
    }
    final scrollDistance = currentPixels - position.minScrollExtent;
    _showScrollToTop.value = _showScrollToTop.value
        ? scrollDistance > ScrollReactiveChrome.scrollToTopHideThreshold
        : scrollDistance >= ScrollReactiveChrome.scrollToTopShowThreshold;
  }

  void _setHeaderOffset(
    double offset, {
    bool notify = true,
    bool notifyIfUnchanged = false,
  }) {
    final nextOffset = _headerHeight > 0 ? offset.clamp(-_headerHeight, 0.0) : 0.0;
    final changed = _headerOffset.value != nextOffset;
    if (!changed && !notifyIfUnchanged) {
      return;
    }
    if (changed) {
      _headerOffset.value = nextOffset;
    }
    if (notify && _headerHeight > 0) {
      ScrollReactiveHeaderProgressNotification(
        (-nextOffset / _headerHeight).clamp(0.0, 1.0),
      ).dispatch(context);
    }
  }

  Future<void> _scrollToTop() async {
    if (!widget.scrollController.hasClients) {
      return;
    }

    final position = widget.scrollController.position;
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(position.minScrollExtent);
      return;
    }
    await position.animateTo(
      position.minScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAfterLayout());
    final viewPadding = ScrollReactiveChrome.safeAreaInsetsOf(context);
    final topInset = viewPadding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: SafeArea(
            top: false,
            bottom: false,
            child: widget.child,
          ),
        ),
        AnimatedBuilder(
          animation: _headerOffset,
          builder: (context, _) {
            final visibleHeaderHeight = (_headerHeight + _headerOffset.value).clamp(
              0.0,
              _headerHeight,
            );
            final preferredHeight = topInset + visibleHeaderHeight;
            final minimumHeight = topInset + 6;
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: preferredHeight > minimumHeight ? preferredHeight : minimumHeight,
              child: const _TopHeaderMaterial(),
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: ClipRect(
              key: const ValueKey("scroll_reactive_header_clip"),
              child: AnimatedBuilder(
                animation: _headerOffset,
                child: KeyedSubtree(
                  key: _headerKey,
                  child: widget.header,
                ),
                builder: (context, child) => Transform.translate(
                  key: const ValueKey("scroll_reactive_header"),
                  offset: Offset(0, _headerOffset.value),
                  child: child,
                ),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _headerOffset,
          child: ValueListenableBuilder(
            valueListenable: _showScrollToTop,
            child: _ScrollToTopBadge(onPressed: _scrollToTop),
            builder: (context, isVisible, child) => isVisible ? child! : const SizedBox.shrink(),
          ),
          builder: (context, child) {
            final visibleHeaderHeight = (_headerHeight + _headerOffset.value).clamp(
              0.0,
              _headerHeight,
            );
            return Positioned(
              top: topInset + visibleHeaderHeight + AppSpacing.md,
              left: 0,
              right: 0,
              child: Center(child: child),
            );
          },
        ),
      ],
    );
  }
}

class _TopHeaderMaterial extends StatelessWidget {
  const _TopHeaderMaterial();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.brightness == Brightness.dark
        ? const Color(0xFF08080A)
        : theme.scaffoldBackgroundColor;

    return IgnorePointer(
      child: ClipRect(
        key: const ValueKey("top_header_material"),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fadeStart = ((constraints.maxHeight - 22) / constraints.maxHeight).clamp(
              0.0,
              1.0,
            );
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: DecoratedBox(
                key: const ValueKey("top_header_material_gradient"),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tint.withValues(alpha: 0.50),
                      tint.withValues(alpha: 0.46),
                      tint.withValues(alpha: 0),
                    ],
                    stops: [0, fadeStart, 1],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScrollToTopBadge extends StatelessWidget {
  const _ScrollToTopBadge({required this.onPressed});

  final AsyncCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: "Scroll to top",
      child: Tooltip(
        message: "Scroll to top",
        child: Material(
          key: const ValueKey("scroll_to_top_badge"),
          elevation: 3,
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          shadowColor: Colors.black.withValues(alpha: 0.24),
          shape: StadiumBorder(
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_upward, size: 20),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      "Top",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<AsyncCallback>.has("onPressed", onPressed));
  }
}
