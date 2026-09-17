import "dart:math" as math;
import "dart:ui" as ui;

import "package:flow/api/twitch_chat_assets.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";

class ChatUsername extends StatelessWidget {
  const ChatUsername({
    required this.name,
    required this.style,
    required this.paint,
    this.animated = true,
    super.key,
  });

  final String name;
  final TextStyle style;
  final ChatAssetPaint paint;
  final bool animated;

  Widget _text() => Text(
    name,
    style: style.copyWith(fontFamily: "FlowChatInter", color: Colors.white),
    textHeightBehavior: const TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    ),
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.clip,
  );

  @override
  Widget build(BuildContext context) {
    final animate =
        animated &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    final baseColor =
        paint.layers
            .where((layer) => layer.type == ChatPaintLayerType.color && layer.color != null)
            .firstOrNull
            ?.color ??
        style.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    final layers = <Widget>[
      Positioned.fill(child: ColoredBox(color: baseColor)),
    ];
    for (final layer in paint.layers.reversed) {
      Widget content;
      if (layer.type == ChatPaintLayerType.image) {
        final supported = layer.images.where(
          (image) =>
              const ["image/webp", "image/gif", "image/png", "image/jpeg"].contains(image.mime),
        );
        final candidates = supported.isEmpty ? layer.images : supported;
        final useAnimation = animate && candidates.any((image) => image.frameCount > 1);
        final images = candidates.where((image) => (image.frameCount > 1) == useAnimation).toList();
        if (images.isEmpty) {
          images.addAll(candidates);
        }
        if (images.isEmpty) {
          continue;
        }
        images.sort((left, right) => left.scale.compareTo(right.scale));
        final density = MediaQuery.devicePixelRatioOf(context);
        final image = images.where((image) => image.scale >= density).firstOrNull ?? images.last;
        content = _PaintImage(
          image.url,
          const ColoredBox(color: Colors.white),
          animated: animate,
        );
      } else {
        content = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => _shader(layer, bounds),
          child: const ColoredBox(color: Colors.white),
        );
      }
      layers.add(Positioned.fill(child: content));
    }
    layers.add(_TextPaintMask(child: _text()));
    return Semantics(
      label: name,
      child: ExcludeSemantics(
        child: _withShadows(
          ClipRect(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: Stack(clipBehavior: Clip.none, children: layers),
          ),
          paint.shadows,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("name", name));
    properties.add(DiagnosticsProperty<TextStyle>("style", style));
    properties.add(DiagnosticsProperty<ChatAssetPaint>("paint", paint));
    properties.add(FlagProperty("animated", value: animated, ifTrue: "animated"));
  }
}

class _TextPaintMask extends SingleChildRenderObjectWidget {
  const _TextPaintMask({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTextPaintMask();
}

class _RenderTextPaintMask extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(offset & size, Paint()..blendMode = BlendMode.dstIn);
    super.paint(context, offset);
    context.canvas.restore();
  }
}

// Android image paints lose shadow tint through ColorFiltered. The shader mask
// preserves it and includes earlier shadows outside the text's layout bounds.
class _ShadowMask extends ShaderMask {
  const _ShadowMask({
    required this._overflow,
    required super.shaderCallback,
    required super.child,
  }) : super(blendMode: BlendMode.srcIn);

  final double _overflow;

  @override
  RenderShaderMask createRenderObject(BuildContext context) => _RenderShadowMask(
    overflow: _overflow,
    shaderCallback: shaderCallback,
  );

  @override
  void updateRenderObject(BuildContext context, covariant _RenderShadowMask renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject._overflow = _overflow;
    renderObject.markNeedsPaint();
  }
}

class _RenderShadowMask extends RenderShaderMask {
  _RenderShadowMask({required this._overflow, required super.shaderCallback})
    : super(blendMode: BlendMode.srcIn);

  double _overflow;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    layer?.maskRect = (offset & size).inflate(_overflow);
  }
}

Widget _withShadows(Widget child, List<Shadow> shadows) {
  var result = child;
  var overflow = 0.0;
  // ponytail: two shadows render four copies; use retained textures for deeper paint chains.
  for (final shadow in shadows) {
    result = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: shadow.offset,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: shadow.blurRadius,
                sigmaY: shadow.blurRadius,
                tileMode: TileMode.decal,
              ),
              child: _ShadowMask(
                overflow: overflow,
                shaderCallback: (_) => ui.Gradient.linear(
                  Offset.zero,
                  const Offset(1, 0),
                  [shadow.color, shadow.color],
                ),
                child: result,
              ),
            ),
          ),
        ),
        result,
      ],
    );
    overflow += math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs()) + 3 * shadow.blurRadius;
  }
  return result;
}

ui.Shader _shader(ChatPaintLayer layer, Rect bounds) {
  if (layer.type == ChatPaintLayerType.color || layer.stops.length < 2) {
    final color = layer.color ?? layer.stops.firstOrNull?.color ?? Colors.transparent;
    return ui.Gradient.linear(Offset.zero, const Offset(1, 0), [color, color]);
  }
  final stops = <({double at, Color color})>[];
  for (final stop in layer.stops) {
    stops.add((at: math.max(stops.lastOrNull?.at ?? stop.at, stop.at), color: stop.color));
  }
  final period = stops.last.at - stops.first.at;
  final repeating = layer.repeating && period > 0;
  final extent = repeating ? period : 1.0;
  final cycle = repeating ? (stops.first.at / period).floor() * period : 0.0;
  final expanded = repeating
      ? [
          for (final offset in [-period - cycle, -cycle])
            for (final stop in stops) (at: stop.at + offset, color: stop.color),
        ]
      : stops;
  Color colorAt(double position) {
    for (var index = 1; index < expanded.length; index++) {
      final left = expanded[index - 1];
      final right = expanded[index];
      if (position < right.at) {
        return Color.lerp(
          left.color,
          right.color,
          ((position - left.at) / (right.at - left.at)).clamp(0, 1),
        )!;
      }
    }
    return expanded.last.color;
  }

  final clipped = [
    (at: 0.0, color: colorAt(0)),
    for (final stop in expanded)
      if (stop.at >= 0 && stop.at <= extent) (at: stop.at / extent, color: stop.color),
    (at: 1.0, color: colorAt(extent)),
  ];
  final colors = clipped.map((stop) => stop.color).toList();
  final positions = clipped.map((stop) => stop.at).toList();
  final tileMode = repeating ? TileMode.repeated : TileMode.clamp;
  if (layer.type == ChatPaintLayerType.linearGradient) {
    final radians = layer.angle * math.pi / 180;
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final length = bounds.width * direction.dx.abs() + bounds.height * direction.dy.abs();
    final start = bounds.center - direction * (length / 2);
    return ui.Gradient.linear(
      start,
      start + direction * (length * extent),
      colors,
      positions,
      tileMode,
    );
  }
  final radiusX = layer.shape == ChatPaintRadialShape.circle
      ? math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height) / 2
      : bounds.width / math.sqrt2;
  final radiusY = layer.shape == ChatPaintRadialShape.circle ? radiusX : bounds.height / math.sqrt2;
  final matrix = Matrix4.identity()
    ..translateByDouble(bounds.center.dx, bounds.center.dy, 0, 1)
    ..scaleByDouble(radiusX, radiusY, 1, 1);
  return ui.Gradient.radial(Offset.zero, extent, colors, positions, tileMode, matrix.storage);
}

class _PaintImage extends StatefulWidget {
  const _PaintImage(this._url, this._child, {required this._animated});

  final String _url;
  final bool _animated;
  final Widget _child;

  @override
  State<_PaintImage> createState() => _PaintImageState();
}

class _PaintImageState extends State<_PaintImage> {
  ImageStream? _stream;
  ImageInfo? _frame;
  late final _listener = ImageStreamListener(_onFrame, onError: (Object _, StackTrace? _) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_PaintImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._url != widget._url || oldWidget._animated != widget._animated) {
      _resolve();
    }
  }

  void _resolve() {
    _stream?.removeListener(_listener);
    _replaceFrame(null);
    _stream = NetworkImage(widget._url).resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  void _onFrame(ImageInfo frame, bool synchronous) {
    setState(() => _replaceFrame(frame));
    if (!widget._animated) {
      _stream?.removeListener(_listener);
    }
  }

  void _replaceFrame(ImageInfo? frame) {
    final previous = _frame;
    _frame = frame;
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _replaceFrame(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _frame?.image;
    return image == null
        ? const SizedBox.shrink()
        : ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => ui.ImageShader(
              image,
              TileMode.clamp,
              TileMode.clamp,
              (Matrix4.identity()
                    ..translateByDouble(bounds.left, bounds.top, 0, 1)
                    ..scaleByDouble(bounds.width / image.width, bounds.height / image.height, 1, 1))
                  .storage,
              filterQuality: FilterQuality.low,
            ),
            child: widget._child,
          );
  }
}
