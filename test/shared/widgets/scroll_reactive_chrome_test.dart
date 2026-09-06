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

  testWidgets("shows and hides the scroll-to-top badge at its thresholds and returns to the top", (
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

    expect(
      tester.getSize(find.byKey(const ValueKey("scroll_to_top_badge"))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const ValueKey("scroll_to_top_badge")));
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(0, 0.1));
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);
  });

  testWidgets("removes the Top badge when collapsing content corrects the scroll offset", (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    _configureView(tester);
    late StateSetter updateContent;
    var expanded = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollReactiveChrome(
            scrollController: scrollController,
            header: const SizedBox(key: ValueKey("test_header"), height: 100),
            child: SingleChildScrollView(
              controller: scrollController,
              child: StatefulBuilder(
                builder: (context, setState) {
                  updateContent = setState;
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: SizedBox(height: expanded ? 5000 : 300),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scrollController.jumpTo(700);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsOneWidget);

    updateContent(() => expanded = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();

    expect(scrollController.offset, 0);
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey("test_header"))).dy, 44);
    expect(tester.takeException(), isNull);
  });

  testWidgets("hidden content metrics stay quiet and chrome syncs when reactivated", (
    tester,
  ) async {
    final scrollController = ScrollController();
    final active = ValueNotifier(true);
    addTearDown(scrollController.dispose);
    addTearDown(active.dispose);
    _configureView(tester);
    final headerProgress = <double>[];
    late StateSetter updateContent;
    var expanded = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ScrollReactiveHeaderProgressNotification>(
            onNotification: (notification) {
              headerProgress.add(notification.hiddenFraction);
              return false;
            },
            child: ValueListenableBuilder(
              valueListenable: active,
              builder: (context, enabled, child) => TickerMode(enabled: enabled, child: child!),
              child: ScrollReactiveChrome(
                scrollController: scrollController,
                header: const SizedBox(key: ValueKey("test_header"), height: 100),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      updateContent = setState;
                      return SizedBox(height: expanded ? 5000 : 300);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scrollController.jumpTo(700);
    await tester.pump();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsOneWidget);

    active.value = false;
    await tester.pumpAndSettle();
    headerProgress.clear();
    updateContent(() => expanded = false);
    await tester.pumpAndSettle();
    expect(scrollController.offset, 0);
    expect(headerProgress, isEmpty);

    active.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("scroll_to_top_badge")), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey("test_header"))).dy, 44);
    expect(headerProgress.last, 0);
    expect(tester.takeException(), isNull);
  });
}

void _configureView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44);
  tester.view.viewPadding = const FakeViewPadding(
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
