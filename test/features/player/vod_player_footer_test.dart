import "package:flow/api/twitch_api.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/vod_player_footer.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";

const _storyboard = TwitchVodStoryboard(
  imageUrls: ["https://example.com/sprites-0.jpg", "https://example.com/sprites-1.jpg"],
  width: 160,
  height: 90,
  columns: 2,
  rows: 2,
  count: 8,
  interval: Duration(seconds: 10),
);

void main() {
  testWidgets("unknown duration keeps the initial seek thumb at the start", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VodPlayerFooter(
            position: const Duration(milliseconds: 1),
            duration: Duration.zero,
            onChanged: (_) {},
            onChangeEnd: (_) {},
            onToggleFullscreen: () {},
          ),
        ),
      ),
    );
    final slider = tester.widget<Slider>(find.byKey(const ValueKey("player_vod_seek")));
    expect(slider.value, 0);
    expect(slider.onChanged, isNull);
    expect(find.text("0:00"), findsNWidgets(2));
  });

  testWidgets("dragging shows the matching storyboard crop until seeking ends", (tester) async {
    var position = const Duration(seconds: 50);
    var seeking = false;
    Duration? sought;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: StatefulBuilder(
                builder: (context, setState) => VodPlayerFooter(
                  position: position,
                  duration: const Duration(seconds: 80),
                  metadata: const TwitchVodSeekMetadata(storyboard: _storyboard),
                  seeking: seeking,
                  onChangeStart: (_) => setState(() => seeking = true),
                  onChanged: (value) => setState(() => position = value),
                  onChangeEnd: (value) => setState(() {
                    sought = value;
                    seeking = false;
                  }),
                  onToggleFullscreen: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final preview = find.byKey(const ValueKey("player_vod_seek_preview"));
    final slider = find.byKey(const ValueKey("player_vod_seek"));
    expect(preview, findsNothing);
    final bounds = tester.getRect(slider);
    final gesture = await tester.startGesture(
      Offset(bounds.left + 12 + (bounds.width - 24) * 0.7, bounds.center.dy),
    );
    await tester.pump();
    expect(preview, findsOneWidget);
    expect(find.descendant(of: preview, matching: find.byType(Text)), findsNothing);
    expect(tester.getSize(preview), const Size(160, 90));
    final frame = _storyboard.frameAt(position)!;
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, frame.imageUrl);
    final crop = tester.widget<Positioned>(
      find.ancestor(of: find.byType(Image), matching: find.byType(Positioned)).first,
    );
    expect(crop.left, -frame.column * 160);
    expect(crop.top, -frame.row * 90);
    expect(crop.width, 320);
    expect(crop.height, 180);
    expect(tester.getRect(preview).left, greaterThanOrEqualTo(bounds.left));
    expect(tester.getRect(preview).right, lessThanOrEqualTo(bounds.right));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(sought, position);
    expect(preview, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("muted spans follow the timeline and clamp at the video boundaries", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VodPlayerFooter(
            position: const Duration(seconds: 50),
            duration: const Duration(seconds: 100),
            metadata: const TwitchVodSeekMetadata(
              mutedSegments: [
                TwitchMutedSegment(offset: Duration(seconds: 25), duration: Duration(seconds: 25)),
                TwitchMutedSegment(offset: Duration(seconds: 75), duration: Duration(seconds: 50)),
              ],
            ),
            onChanged: (_) {},
            onChangeEnd: (_) {},
            onToggleFullscreen: () {},
          ),
        ),
      ),
    );
    final shape = tester.widget<SliderTheme>(find.byType(SliderTheme)).data.trackShape!;
    final box = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 200,
        height: 40,
      ),
    )..layout(const BoxConstraints());
    addTearDown(box.dispose);
    const theme = SliderThemeData(
      padding: EdgeInsets.zero,
      trackHeight: 4,
      thumbShape: RoundSliderThumbShape(),
      overlayShape: RoundSliderOverlayShape(),
      activeTrackColor: Colors.purple,
      inactiveTrackColor: Colors.grey,
      disabledActiveTrackColor: Colors.grey,
      disabledInactiveTrackColor: Colors.grey,
    );
    for (final direction in TextDirection.values) {
      expect(
        (PaintingContext context, Offset offset) => shape.paint(
          context,
          offset,
          parentBox: box,
          sliderTheme: theme,
          enableAnimation: const AlwaysStoppedAnimation(1),
          textDirection: direction,
          thumbCenter: const Offset(100, 20),
          isEnabled: true,
        ),
        paints
          ..rect(
            color: AppColors.liveRed,
            rect: direction == TextDirection.ltr
                ? const Rect.fromLTRB(50, 18, 100, 22)
                : const Rect.fromLTRB(100, 18, 150, 22),
          )
          ..rect(
            color: AppColors.liveRed,
            rect: direction == TextDirection.ltr
                ? const Rect.fromLTRB(150, 18, 200, 22)
                : const Rect.fromLTRB(0, 18, 50, 22),
          ),
      );
    }
    expect(find.byKey(const ValueKey("player_vod_seek_preview")), findsNothing);
  });
}
