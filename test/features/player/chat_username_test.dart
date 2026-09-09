import "dart:ui" as ui;

import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/features/player/chat_username.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";

const _style = TextStyle(
  fontSize: 24,
  height: 1.4,
  color: Colors.black,
  fontWeight: FontWeight.w700,
);
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
const _green = Color(0xFF00FF00);
const _stops = [(at: 0.0, color: _red), (at: 1.0, color: _blue)];

Widget _app(ChatAssetPaint paint, {bool animated = true, bool reducedMotion = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Align(
          alignment: Alignment.topLeft,
          child: ChatUsername(name: "Painted", style: _style, paint: paint, animated: animated),
        ),
      ),
    );

void main() {
  testWidgets("paint gradients use CSS angles, repeat periods, and radial shapes", (tester) async {
    Future<List<Color>> pixels(ChatPaintLayer layer, List<Offset> positions) async {
      await tester.pumpWidget(_app(ChatAssetPaint(id: "paint", name: "Paint", layers: [layer])));
      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      return (await tester.runAsync(
        () => _sample(mask.shaderCallback(const Rect.fromLTWH(0, 0, 100, 40)), positions),
      ))!;
    }

    final horizontal = await pixels(
      const ChatPaintLayer(
        id: "linear",
        type: ChatPaintLayerType.linearGradient,
        angle: 90,
        stops: _stops,
      ),
      [const Offset(1, 20), const Offset(98, 20)],
    );
    expect(horizontal.first.r, greaterThan(0.95));
    expect(horizontal.last.b, greaterThan(0.95));
    final vertical = await pixels(
      const ChatPaintLayer(id: "up", type: ChatPaintLayerType.linearGradient, stops: _stops),
      [const Offset(50, 1), const Offset(50, 38)],
    );
    expect(vertical.first.b, greaterThan(0.95));
    expect(vertical.last.r, greaterThan(0.95));
    final repeating = await pixels(
      const ChatPaintLayer(
        id: "repeat",
        type: ChatPaintLayerType.linearGradient,
        angle: 90,
        repeating: true,
        stops: [(at: 0.2, color: _red), (at: 0.6, color: _blue)],
      ),
      [const Offset(2, 20), const Offset(42, 20), const Offset(22, 20)],
    );
    expect(repeating[0].r, closeTo(repeating[1].r, 0.01));
    expect(repeating[2].r, greaterThan(0.9));
    final extended = await pixels(
      const ChatPaintLayer(
        id: "outside",
        type: ChatPaintLayerType.linearGradient,
        angle: 90,
        stops: [(at: -0.5, color: _red), (at: 0.5, color: _blue)],
      ),
      [const Offset(0, 20)],
    );
    expect(extended.single.r, closeTo(0.5, 0.02));
    expect(extended.single.b, closeTo(0.5, 0.02));
    final circle = await pixels(
      const ChatPaintLayer(
        id: "circle",
        type: ChatPaintLayerType.radialGradient,
        shape: ChatPaintRadialShape.circle,
        stops: _stops,
      ),
      [const Offset(50, 0)],
    );
    final ellipse = await pixels(
      const ChatPaintLayer(id: "ellipse", type: ChatPaintLayerType.radialGradient, stops: _stops),
      [const Offset(50, 0)],
    );
    expect(ellipse.single.b, greaterThan(circle.single.b + 0.3));
  });

  testWidgets("translucent gradient pixels retain the current name color beneath the paint", (
    tester,
  ) async {
    const boundaryKey = ValueKey("paint pixels");
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ChatUsername(
              name: "Painter",
              style: TextStyle(fontSize: 24, color: _green, decoration: TextDecoration.none),
              paint: ChatAssetPaint(
                id: "translucent",
                name: "Translucent",
                layers: [
                  ChatPaintLayer(
                    id: "gradient",
                    type: ChatPaintLayerType.linearGradient,
                    stops: [(at: 0, color: Colors.transparent), (at: 1, color: Colors.transparent)],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData())!.buffer.asUint8List();
      image.dispose();
      return bytes;
    });
    final opaque = [
      for (var offset = 0; offset < pixels!.length; offset += 4)
        if (pixels[offset + 3] == 255)
          Color.fromARGB(255, pixels[offset], pixels[offset + 1], pixels[offset + 2]),
    ];
    expect(opaque, isNotEmpty);
    expect(opaque, everyElement(_green));
  });

  testWidgets("paint layers keep order and opacity with shadows on the first layer only", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ChatAssetPaint(
          id: "layered",
          name: "Layered",
          layers: [
            ChatPaintLayer(id: "base", type: ChatPaintLayerType.color, color: _red),
            ChatPaintLayer(
              id: "top",
              type: ChatPaintLayerType.color,
              color: _blue,
              opacity: 0.5,
            ),
          ],
          shadows: [Shadow(color: _green, blurRadius: 2, offset: Offset(2, 1))],
        ),
      ),
    );
    final layers = find.descendant(of: find.byType(ChatUsername), matching: find.byType(Opacity));
    expect(layers, findsNWidgets(2));
    expect(tester.widget<Opacity>(layers.first).opacity, 1);
    expect(tester.widget<Opacity>(layers.last).opacity, 0.5);
    expect(find.descendant(of: layers.first, matching: find.byType(ColorFiltered)), findsOneWidget);
    expect(find.descendant(of: layers.last, matching: find.byType(ColorFiltered)), findsNothing);
    final colors = <Color>[];
    for (final layer in [layers.first, layers.last]) {
      final mask = tester.widget<ShaderMask>(
        find.descendant(of: layer, matching: find.byType(ShaderMask)).last,
      );
      colors.add(
        (await tester.runAsync(
          () => _sample(mask.shaderCallback(const Rect.fromLTWH(0, 0, 100, 40)), [
            const Offset(50, 20),
          ]),
        ))!.single,
      );
    }
    expect(colors, [_red, _blue]);
  });

  testWidgets("painted text preserves natural size, baseline, scaling, and one semantic name", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const paint = ChatAssetPaint(
      id: "paint",
      name: "Paint",
      layers: [
        ChatPaintLayer(id: "linear", type: ChatPaintLayerType.linearGradient, stops: _stops),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text("Painter", key: ValueKey("plain"), style: _style),
                  ChatUsername(
                    key: ValueKey("painted"),
                    name: "Painter",
                    style: _style,
                    paint: paint,
                  ),
                ],
              ),
              SizedBox(
                width: 50,
                child: ChatUsername(
                  key: ValueKey("narrow"),
                  name: "A very long painted name",
                  style: _style,
                  paint: paint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final plain = tester.renderObject<RenderBox>(find.byKey(const ValueKey("plain")));
    final painted = tester.renderObject<RenderBox>(find.byKey(const ValueKey("painted")));
    expect(painted.size, plain.size);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("painted"))).dy,
      tester.getTopLeft(find.byKey(const ValueKey("plain"))).dy,
    );
    expect(find.bySemanticsLabel("Painter"), findsNWidgets(2));
    expect(tester.getSize(find.byKey(const ValueKey("narrow"))).width, 50);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets("unavailable image paints retain the readable text fallback", (tester) async {
    const url = "https://example.com/unavailable.webp";
    final frames = _Frames();
    PaintingBinding.instance.imageCache.putIfAbsent(const NetworkImage(url), () => frames);
    addTearDown(PaintingBinding.instance.imageCache.clear);
    await tester.pumpWidget(
      _app(
        const ChatAssetPaint(
          id: "image",
          name: "Image",
          layers: [
            ChatPaintLayer(
              id: "image",
              type: ChatPaintLayerType.image,
              images: [
                ChatPaintImage(url: url, mime: "image/webp"),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.widget<Text>(find.text("Painted")).style!.color, Colors.black);
    frames.reportError(exception: Exception("Image unavailable"), silent: true);
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.widget<Text>(find.text("Painted")).style!.color, Colors.black);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("image paints follow native frames and choose still images when motion is disabled", (
    tester,
  ) async {
    const stillUrl = "https://example.com/still.webp";
    const animatedUrl = "https://example.com/animated.webp";
    final still = _Frames();
    final animation = _Frames();
    await tester.runAsync(() async {
      still.emit(await _solid(_green));
      animation.emit(await _solid(_red));
      PaintingBinding.instance.imageCache.putIfAbsent(const NetworkImage(stillUrl), () => still);
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(animatedUrl),
        () => animation,
      );
    });
    addTearDown(PaintingBinding.instance.imageCache.clear);
    const paint = ChatAssetPaint(
      id: "image",
      name: "Image",
      layers: [
        ChatPaintLayer(
          id: "image",
          type: ChatPaintLayerType.image,
          images: [
            ChatPaintImage(url: stillUrl, mime: "image/webp"),
            ChatPaintImage(url: animatedUrl, mime: "image/webp", frameCount: 2),
          ],
        ),
      ],
    );
    Future<Color> displayed() async {
      await tester.pump();
      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      return (await tester.runAsync(
        () => _sample(mask.shaderCallback(const Rect.fromLTWH(0, 0, 100, 40)), [
          const Offset(50, 20),
        ]),
      ))!.single;
    }

    await tester.pumpWidget(_app(paint));
    expect(await displayed(), _red);
    await tester.runAsync(() async => animation.emit(await _solid(_blue)));
    expect(await displayed(), _blue);
    await tester.pumpWidget(_app(paint, animated: false));
    expect(await displayed(), _green);
    await tester.pumpWidget(_app(paint, reducedMotion: true));
    expect(await displayed(), _green);
    const onlyAnimated = ChatAssetPaint(
      id: "image",
      name: "Image",
      layers: [
        ChatPaintLayer(
          id: "image",
          type: ChatPaintLayerType.image,
          images: [
            ChatPaintImage(url: animatedUrl, mime: "image/webp", frameCount: 2),
          ],
        ),
      ],
    );
    await tester.pumpWidget(_app(onlyAnimated, animated: false));
    expect(await displayed(), _blue);
    await tester.runAsync(() async => animation.emit(await _solid(_red)));
    expect(await displayed(), _blue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

Future<ui.Image> _solid(Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(color, ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();
  return image;
}

Future<List<Color>> _sample(ui.Shader shader, List<Offset> positions) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 100, 40), Paint()..shader = shader);
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 40);
  final bytes = (await image.toByteData())!;
  final colors = [
    for (final position in positions)
      Color.fromARGB(
        bytes.getUint8((position.dy.toInt() * 100 + position.dx.toInt()) * 4 + 3),
        bytes.getUint8((position.dy.toInt() * 100 + position.dx.toInt()) * 4),
        bytes.getUint8((position.dy.toInt() * 100 + position.dx.toInt()) * 4 + 1),
        bytes.getUint8((position.dy.toInt() * 100 + position.dx.toInt()) * 4 + 2),
      ),
  ];
  image.dispose();
  picture.dispose();
  shader.dispose();
  return colors;
}

class _Frames extends ImageStreamCompleter {
  void emit(ui.Image image) => setImage(ImageInfo(image: image));
}
