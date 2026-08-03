import "package:flow/app/spacing.dart";
import "package:flow/shared/widgets/scroll_reactive_chrome.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("links header travel to scroll delta and preserves partial progress", (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    _configureView(tester);

    await tester.pumpWidget(_testApp(scrollController));
    await tester.pump();

    final material = find.byKey(const ValueKey("top_header_material"));
    expect(tester.getRect(material), const Rect.fromLTWH(0, 0, 800, 144));

    final header = find.byKey(const ValueKey("test_header"));
    final headerClip = find.byKey(const ValueKey("scroll_reactive_header_clip"));
    final initialTop = tester.getTopLeft(header).dy;
    final headerHeight = tester.getSize(header).height;
    expect(tester.getRect(material).bottom, tester.getRect(header).bottom);

    scrollController.jumpTo(headerHeight * 0.4);
    await tester.pump();
    expect(
      tester.getTopLeft(header).dy - initialTop,
      closeTo(-headerHeight * 0.4, 0.1),
    );
    expect(tester.getRect(material).height, closeTo(44 + 60, 0.1));
    expect(tester.getRect(material).bottom, tester.getRect(header).bottom);

    scrollController.jumpTo(headerHeight * 0.3);
    await tester.pump();
    expect(
      tester.getTopLeft(header).dy - initialTop,
      closeTo(-headerHeight * 0.3, 0.1),
    );

    scrollController.jumpTo(headerHeight * 0.6);
    await tester.pump();

    expect(
      tester.getTopLeft(header).dy - initialTop,
      closeTo(-headerHeight * 0.6, 0.1),
    );

    scrollController.jumpTo(headerHeight * 2.4);
    await tester.pump();
    expect(
      tester.getTopLeft(header).dy - initialTop,
      closeTo(-headerHeight, 0.1),
    );
    expect(tester.getRect(header).intersect(tester.getRect(headerClip)).isEmpty, isTrue);
    expect(tester.getRect(material).height, closeTo(44 + 6, 0.1));

    scrollController.jumpTo(headerHeight * 2.15);
    await tester.pump();
    expect(
      tester.getTopLeft(header).dy - initialTop,
      closeTo(-headerHeight * 0.75, 0.1),
    );

    scrollController.jumpTo(headerHeight);
    await tester.pump();
    expect(tester.getTopLeft(header).dy, closeTo(initialTop, 0.1));

    scrollController.jumpTo(0);
    await tester.pump();
    expect(tester.getTopLeft(header).dy, closeTo(initialTop, 0.1));
  });

  testWidgets("keeps the safe-area tint and thresholds the scroll-to-top badge", (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    _configureView(tester);

    await tester.pumpWidget(_testApp(scrollController));
    await tester.pump();

    scrollController.jumpTo(599);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);

    scrollController.jumpTo(600);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsOneWidget);

    scrollController.jumpTo(500);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsOneWidget);

    scrollController.jumpTo(80);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);

    scrollController.jumpTo(500);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);

    scrollController.jumpTo(700);
    await tester.pump();

    final header = find.byKey(const ValueKey("test_header"));
    final headerClip = find.byKey(const ValueKey("scroll_reactive_header_clip"));
    expect(tester.getRect(header).intersect(tester.getRect(headerClip)).isEmpty, isTrue);
    final material = find.byKey(const ValueKey("top_header_material"));
    expect(material, findsOneWidget);
    expect(find.byKey(const ValueKey("top_safe_area_tint")), findsNothing);
    expect(tester.getRect(material), const Rect.fromLTWH(0, 0, 800, 50));
    expect(
      find.descendant(of: material, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    final gradient =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey("top_header_material_gradient")),
                )
                .decoration
            as BoxDecoration;
    final linearGradient = gradient.gradient! as LinearGradient;
    expect(linearGradient.begin, Alignment.topCenter);
    expect(linearGradient.end, Alignment.bottomCenter);
    expect(linearGradient.stops![0], 0);
    expect(linearGradient.stops![1], closeTo(28 / 50, 0.001));
    expect(linearGradient.stops![2], 1);
    expect((1 - linearGradient.stops![1]) * tester.getRect(material).height, closeTo(22, 0.1));
    expect(linearGradient.colors.map((color) => color.a), orderedEquals([0.50, 0.46, 0]));
    expect(linearGradient.colors.last.a, 0);
    expect(gradient.color, isNull);
    final listView = find.byType(ListView);
    expect(tester.getRect(listView).top, 0);
    expect(
      tester
          .getRect(find.byKey(const ValueKey("test_item_14")))
          .intersect(tester.getRect(material))
          .isEmpty,
      isFalse,
    );
    final badge = find.byKey(const ValueKey("scroll_to_top_badge"));
    expect(badge, findsOneWidget);
    expect(tester.getRect(badge).top, closeTo(44 + AppSpacing.md, 0.1));
    expect(tester.getRect(badge).center.dx, closeTo(400, 0.1));
    expect(tester.getSize(badge).height, greaterThanOrEqualTo(48));

    scrollController.jumpTo(650);
    await tester.pump();
    expect(tester.getRect(badge).top, closeTo(44 + 50 + AppSpacing.md, 0.1));
    expect(tester.getRect(material).height, closeTo(44 + 50, 0.1));

    scrollController.jumpTo(600);
    await tester.pump();
    expect(tester.getRect(badge).top, closeTo(44 + 100 + AppSpacing.md, 0.1));
    expect(tester.getRect(material).height, closeTo(44 + 100, 0.1));

    scrollController.jumpTo(70);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);

    scrollController.jumpTo(700);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("scroll_to_top_badge")));
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(0, 0.1));
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);
  });

  testWidgets("centers a restored deep-scroll chip below the measured header", (
    tester,
  ) async {
    final scrollController = ScrollController(initialScrollOffset: 700);
    addTearDown(scrollController.dispose);
    _configureView(tester, leftViewPadding: 40);

    await tester.pumpWidget(_testApp(scrollController));
    await tester.pump();

    final badge = find.byKey(const ValueKey("scroll_to_top_badge"));
    expect(badge, findsOneWidget);
    expect(tester.getRect(badge).top, closeTo(44 + 100 + AppSpacing.md, 0.1));
    expect(tester.getRect(badge).center.dx, closeTo(400, 0.1));
  });
}

void _configureView(
  WidgetTester tester, {
  double leftViewPadding = 0,
}) {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44);
  tester.view.viewPadding = FakeViewPadding(
    left: leftViewPadding,
    top: 44,
    bottom: 34,
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}

Widget _testApp(ScrollController scrollController) => MaterialApp(
  home: Scaffold(
    body: ScrollReactiveChrome(
      scrollController: scrollController,
      header: const SizedBox(
        key: ValueKey("test_header"),
        height: 100,
        child: Center(child: Text("Header")),
      ),
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemExtent: 50,
        itemCount: 100,
        itemBuilder: (context, index) => SizedBox(
          key: ValueKey("test_item_$index"),
          child: Text("Item $index"),
        ),
      ),
    ),
  ),
);
