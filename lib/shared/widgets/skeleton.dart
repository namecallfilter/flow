import "dart:async";

import "package:flow/app/radius.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Widget>("child", child));
  }
}

class _SkeletonShimmerState extends State<SkeletonShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SkeletonAnimation(
    animation: _controller,
    child: widget.child,
  );
}

class _SkeletonAnimation extends InheritedNotifier<Animation<double>> {
  const _SkeletonAnimation({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonAnimation>()?.notifier;
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.height,
    super.key,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.sm)),
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final highlightColor = colorScheme.onSurface.withValues(alpha: 0.10);
    final animation = _SkeletonAnimation.maybeOf(context);
    final position = ((animation?.value ?? 0.5) * 3) - 1.5;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment(position - 1, -0.2),
            end: Alignment(position + 1, 0.2),
            colors: [baseColor, highlightColor, baseColor],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty("height", height));
    properties.add(DoubleProperty("width", width));
    properties.add(DiagnosticsProperty<BorderRadius>("borderRadius", borderRadius));
  }
}
