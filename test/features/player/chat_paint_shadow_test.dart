import "dart:ui" as ui;

import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/features/player/chat_username.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  for (final imagePaint in [false, true]) {
    testWidgets(
      "${imagePaint ? 'image' : 'solid'} paint shadows chain without including the chat background",
      (
        tester,
      ) async {
        const boundaryKey = ValueKey("shadow pixels");
        const imageUrl = "https://example.com/shadow-paint.webp";
        if (imagePaint) {
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            ui.Canvas(recorder).drawColor(Colors.white, BlendMode.src);
            final picture = recorder.endRecording();
            final image = await picture.toImage(2, 2);
            picture.dispose();
            PaintingBinding.instance.imageCache.putIfAbsent(
              const NetworkImage(imageUrl),
              () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
            );
          });
          addTearDown(PaintingBinding.instance.imageCache.clear);
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: Colors.green,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 40,
                          top: 40,
                          child: ChatUsername(
                            name: "M",
                            style: const TextStyle(fontSize: 20, height: 1, color: Colors.white),
                            paint: ChatAssetPaint(
                              id: "shadows",
                              name: "Shadows",
                              layers: [
                                if (imagePaint)
                                  const ChatPaintLayer(
                                    id: "image",
                                    type: ChatPaintLayerType.image,
                                    images: [ChatPaintImage(url: imageUrl, mime: "image/webp")],
                                  )
                                else
                                  const ChatPaintLayer(
                                    id: "white",
                                    type: ChatPaintLayerType.color,
                                    color: Colors.white,
                                  ),
                              ],
                              shadows: const [
                                Shadow(color: Colors.red, offset: Offset(30, 0), blurRadius: 0.1),
                                Shadow(color: Colors.blue, offset: Offset(0, 30), blurRadius: 0.1),
                              ],
                            ),
                          ),
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
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
        final bytes = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          image.dispose();
          return bytes;
        }))!;
        Color pixel(int x, int y) {
          final offset = (y * 140 + x) * 4;
          return Color.fromARGB(
            bytes[offset + 3],
            bytes[offset],
            bytes[offset + 1],
            bytes[offset + 2],
          );
        }

        final white = [
          for (var y = 40; y < 65; y++)
            for (var x = 40; x < 65; x++)
              if (pixel(x, y) == Colors.white) (x: x, y: y),
        ];
        expect(white, isNotEmpty);
        final point = white[white.length ~/ 2];
        expect(pixel(point.x + 30, point.y).toARGB32(), Colors.red.toARGB32());
        expect(pixel(point.x, point.y + 30).toARGB32(), Colors.blue.toARGB32());
        expect(pixel(point.x + 30, point.y + 30).toARGB32(), Colors.blue.toARGB32());
        expect(pixel(65, 65).toARGB32(), Colors.green.toARGB32());
        expect(pixel(5, 5).toARGB32(), Colors.green.toARGB32());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
