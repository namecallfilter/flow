import "dart:async";

import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("holding a title with finger movement does not show the refresh indicator", (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var refreshes = 0;
    await tester.pumpWidget(
      _RefreshApp(
        scrollController: scrollController,
        periodicRefreshInterval: null,
        onRefresh: () async => refreshes++,
        title: const Tooltip(
          message: "Full stream title",
          child: SizedBox(height: 200, child: Center(child: Text("Stream title"))),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text("Stream title")));
    await gesture.moveBy(const Offset(2, 3));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text("Full stream title"), findsOneWidget);
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);

    await gesture.moveBy(const Offset(8, 9));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
  });

  testWidgets("horizontal gestures with vertical movement do not show the refresh indicator", (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var refreshes = 0;
    var horizontalUpdates = 0;
    await tester.pumpWidget(
      _RefreshApp(
        scrollController: scrollController,
        periodicRefreshInterval: null,
        onRefresh: () async => refreshes++,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (_) => horizontalUpdates++,
          child: const SizedBox(height: 200),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(20, 100));
    await gesture.moveBy(const Offset(100, 3));
    await tester.pump();
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);

    await gesture.moveBy(const Offset(100, 12));
    await tester.pump();
    expect(horizontalUpdates, greaterThan(0));
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
  });

  testWidgets("an accepted vertical pull refreshes once on release", (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final refreshCompleter = Completer<void>();
    var refreshes = 0;
    await tester.pumpWidget(
      _RefreshApp(
        scrollController: scrollController,
        periodicRefreshInterval: null,
        onRefresh: () {
          refreshes++;
          return refreshCompleter.future;
        },
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 100));
    await gesture.moveBy(const Offset(0, 8));
    await tester.pump();
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);

    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsOneWidget);
    expect(refreshes, 0);

    await gesture.up();
    await tester.pump();
    expect(refreshes, 1);
    expect(
      tester.widget<RefreshProgressIndicator>(find.byType(RefreshProgressIndicator)).value,
      null,
    );

    refreshCompleter.complete();
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);
  });

  testWidgets("reversing a vertical pull cancels refresh", (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var refreshes = 0;
    await tester.pumpWidget(
      _RefreshApp(
        scrollController: scrollController,
        periodicRefreshInterval: null,
        onRefresh: () async => refreshes++,
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 100));
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsOneWidget);
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(refreshes, 0);
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);
  });

  testWidgets("cancelling a pull never starts a refresh", (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var refreshes = 0;
    await tester.pumpWidget(
      _RefreshApp(
        scrollController: scrollController,
        periodicRefreshInterval: null,
        onRefresh: () async => refreshes++,
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 100));
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsOneWidget);
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(refreshes, 0);
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);
  });

  testWidgets("periodically refreshes without showing the pull indicator", (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var refreshes = 0;

    await tester.pumpWidget(
      _RefreshApp(
        scrollController: scrollController,
        onRefresh: () async {
          refreshes++;
        },
      ),
    );

    await tester.pump(const Duration(seconds: 29));
    expect(refreshes, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(refreshes, 1);
    expect(find.byKey(const ValueKey("pull_refresh_indicator")), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 2);
  });

  testWidgets("does not poll hidden or covered pages", (tester) async {
    final hiddenController = ScrollController();
    addTearDown(hiddenController.dispose);
    var hiddenRefreshes = 0;

    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: _RefreshApp(
          scrollController: hiddenController,
          onRefresh: () async {
            hiddenRefreshes++;
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    expect(hiddenRefreshes, 0);

    final coveredController = ScrollController();
    addTearDown(coveredController.dispose);
    var coveredRefreshes = 0;
    await tester.pumpWidget(
      _RefreshApp(
        scrollController: coveredController,
        onRefresh: () async {
          coveredRefreshes++;
        },
      ),
    );
    await tester.pump();

    final context = tester.element(find.byKey(const ValueKey("periodic_refresh_surface")));
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));

    expect(coveredRefreshes, 0);
  });

  testWidgets("pauses polling in the background and deduplicates refreshes", (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final refreshCompleter = Completer<void>();
    var refreshes = 0;

    await tester.pumpWidget(
      _RefreshApp(
        scrollController: scrollController,
        onRefresh: () {
          refreshes++;
          return refreshCompleter.future;
        },
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(refreshes, 1);

    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 1);

    refreshCompleter.complete();
    await tester.pump();
  });

  for (final interval in const <Duration?>[
    null,
    Duration.zero,
    Duration(seconds: -1),
  ]) {
    testWidgets("does not refresh on resume when periodic interval is $interval", (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      var refreshes = 0;

      await tester.pumpWidget(
        _RefreshApp(
          scrollController: scrollController,
          periodicRefreshInterval: interval,
          onRefresh: () async {
            refreshes++;
          },
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));

      expect(refreshes, 0);
    });
  }
}

class _RefreshApp extends StatelessWidget {
  const _RefreshApp({
    required this.scrollController,
    required this.onRefresh,
    this.periodicRefreshInterval = const Duration(seconds: 30),
    this.title,
  });

  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Duration? periodicRefreshInterval;
  final Widget? title;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: FlowPullToRefresh(
        key: const ValueKey("periodic_refresh_surface"),
        scrollController: scrollController,
        onRefresh: onRefresh,
        indicatorStartTop: 0,
        indicatorMaxTravel: 52,
        periodicRefreshInterval: periodicRefreshInterval,
        child: ListView(
          controller: scrollController,
          children: [
            ?title,
            const SizedBox(height: 1200),
          ],
        ),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ScrollController>("scrollController", scrollController))
      ..add(ObjectFlagProperty<Future<void> Function()>.has("onRefresh", onRefresh))
      ..add(
        DiagnosticsProperty<Duration?>(
          "periodicRefreshInterval",
          periodicRefreshInterval,
        ),
      );
  }
}
