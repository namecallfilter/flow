import "dart:ui" as ui;

import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/features/player/chat_username.dart";
import "package:flow/shared/chat_name_color.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

const _style = TextStyle(
  fontSize: 24,
  height: 1.4,
  color: Colors.black,
  fontWeight: FontWeight.w700,
  decoration: TextDecoration.none,
);
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
const _green = Color(0xFF00FF00);
const _stops = [(at: 0.0, color: _red), (at: 1.0, color: _blue)];

Widget _app(
  ChatAssetPaint paint, {
  bool animated = true,
  bool reducedMotion = false,
  double devicePixelRatio = 1,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reducedMotion,
      devicePixelRatio: devicePixelRatio,
    ),
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: const ValueKey("paint pixels"),
        child: ChatUsername(name: "Painted", style: _style, paint: paint, animated: animated),
      ),
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

  testWidgets("translucent paint follows the username color when the theme changes", (
    tester,
  ) async {
    const boundaryKey = ValueKey("paint pixels");
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) => Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ChatUsername(
                  name: "Painter",
                  style: TextStyle(
                    fontSize: 24,
                    color: readableChatNameColor(Colors.white, Theme.of(context).brightness),
                    decoration: TextDecoration.none,
                  ),
                  paint: const ChatAssetPaint(
                    id: "translucent",
                    name: "Translucent",
                    layers: [
                      ChatPaintLayer(
                        id: "gradient",
                        type: ChatPaintLayerType.linearGradient,
                        stops: [
                          (at: 0, color: Colors.transparent),
                          (at: 1, color: Colors.transparent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pixels = await _pixels(tester);
      final opaque = [
        for (var offset = 0; offset < pixels.length; offset += 4)
          if (pixels[offset + 3] == 255)
            Color.fromARGB(255, pixels[offset], pixels[offset + 1], pixels[offset + 2]),
      ];
      expect(opaque, isNotEmpty);
      expect(
        opaque,
        everyElement(brightness == Brightness.light ? const Color(0xFF717171) : Colors.white),
      );
    }
  });

  testWidgets(
    "paint backgrounds put the first layer on top over one base and ignore layer opacity",
    (
      tester,
    ) async {
      const cases = [
        (
          paint: ChatAssetPaint(
            id: "ordered",
            name: "Ordered",
            layers: [
              ChatPaintLayer(
                id: "top",
                type: ChatPaintLayerType.linearGradient,
                stops: [(at: 0, color: Color(0x80FF0000)), (at: 1, color: Color(0x80FF0000))],
              ),
              ChatPaintLayer(id: "base", type: ChatPaintLayerType.color, color: _blue, opacity: 0),
            ],
          ),
          expected: Color(0xFF80007F),
        ),
        (
          paint: ChatAssetPaint(
            id: "translucent",
            name: "Translucent",
            layers: [
              ChatPaintLayer(
                id: "top",
                type: ChatPaintLayerType.linearGradient,
                stops: [(at: 0, color: Colors.transparent), (at: 1, color: Colors.transparent)],
              ),
              ChatPaintLayer(
                id: "base",
                type: ChatPaintLayerType.color,
                color: Color(0x800000FF),
              ),
            ],
          ),
          expected: Color(0xC00000FF),
        ),
      ];
      for (final testCase in cases) {
        await tester.pumpWidget(_app(testCase.paint));
        final bytes = await _pixels(tester);
        var offset = 0;
        for (var index = 4; index < bytes.length; index += 4) {
          if (bytes[index + 3] > bytes[offset + 3]) {
            offset = index;
          }
        }
        expect(bytes[offset], closeTo(testCase.expected.r * 255, 1));
        expect(bytes[offset + 1], closeTo(testCase.expected.g * 255, 1));
        expect(bytes[offset + 2], closeTo(testCase.expected.b * 255, 1));
        expect(bytes[offset + 3], closeTo(testCase.expected.a * 255, 1));
      }
    },
  );

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
                  Text(
                    "Painter",
                    key: ValueKey("plain"),
                    style: TextStyle(
                      fontFamily: "FlowChatInter",
                      fontSize: 24,
                      height: 1.4,
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                    textHeightBehavior: TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                  ),
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
    final before = await _pixels(tester);
    expect(
      before.indexed.where((entry) => entry.$1 % 4 == 3).map((entry) => entry.$2),
      contains(255),
    );
    expect(
      before.indexed.where((entry) => entry.$1 % 4 != 3).map((entry) => entry.$2),
      everyElement(0),
    );
    frames.reportError(exception: Exception("Image unavailable"), silent: true);
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
    expect(await _pixels(tester), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("image paints follow native frames and choose still images when motion is disabled", (
    tester,
  ) async {
    const stillUrl = "https://example.com/still.webp";
    const animatedUrl = "https://example.com/animated.webp";
    const highDensityUrl = "https://example.com/animated-3x.webp";
    final still = _Frames();
    final animation = _Frames();
    final highDensity = _Frames();
    await tester.runAsync(() async {
      still.emit(await _solid(_green));
      animation.emit(await _solid(_red));
      highDensity.emit(await _solid(Colors.orange));
      PaintingBinding.instance.imageCache.putIfAbsent(const NetworkImage(stillUrl), () => still);
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(animatedUrl),
        () => animation,
      );
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(highDensityUrl),
        () => highDensity,
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
            ChatPaintImage(
              url: "https://example.com/animated-3x.avif",
              mime: "image/avif",
              scale: 3,
              frameCount: 2,
            ),
            ChatPaintImage(url: stillUrl, mime: "image/webp"),
            ChatPaintImage(url: animatedUrl, mime: "image/webp", frameCount: 2),
            ChatPaintImage(url: highDensityUrl, mime: "image/webp", scale: 3, frameCount: 2),
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
    await tester.pumpWidget(_app(paint, devicePixelRatio: 2.5));
    expect((await displayed()).toARGB32(), Colors.orange.toARGB32());
    await tester.pumpWidget(_app(paint, devicePixelRatio: 5));
    expect((await displayed()).toARGB32(), Colors.orange.toARGB32());
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

  testWidgets("backgrounds share one antialiased glyph mask including transparent paint", (
    tester,
  ) async {
    final font = FontLoader("FlowChatInter")
      ..addFont(rootBundle.load("assets/fonts/FlowChatInter-Bold.ttf"));
    await font.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const ValueKey("paint pixels"),
            child: Text(
              "Painted",
              style: _style.copyWith(fontFamily: "FlowChatInter", color: Colors.white),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          ),
        ),
      ),
    );
    final mask = await _pixels(tester);
    expect(
      mask.indexed.any((entry) => entry.$1 % 4 == 3 && entry.$2 > 10 && entry.$2 < 245),
      isTrue,
    );
    for (final base in [_blue, const Color(0x800000FF)]) {
      await tester.pumpWidget(
        _app(
          ChatAssetPaint(
            id: "antialiased",
            name: "Antialiased",
            layers: [
              const ChatPaintLayer(
                id: "top",
                type: ChatPaintLayerType.linearGradient,
                stops: [(at: 0, color: Color(0x80FF0000)), (at: 1, color: Color(0x80FF0000))],
              ),
              ChatPaintLayer(id: "base", type: ChatPaintLayerType.color, color: base),
            ],
          ),
        ),
      );
      final pixels = await _pixels(tester);
      expect(pixels.length, mask.length);
      final alpha = base.a == 1 ? 255 : 224;
      for (var offset = 3; offset < pixels.length; offset += 4) {
        expect(pixels[offset], closeTo(mask[offset] * alpha / 255, 1));
      }
    }
  });
}

Future<List<int>> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey("paint pixels")),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    image.dispose();
    return bytes;
  }))!;
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
