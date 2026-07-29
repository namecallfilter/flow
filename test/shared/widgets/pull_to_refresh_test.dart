import "dart:async";

import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
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
}

class _RefreshApp extends StatelessWidget {
  const _RefreshApp({
    required this.scrollController,
    required this.onRefresh,
  });

  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: FlowPullToRefresh(
        key: const ValueKey("periodic_refresh_surface"),
        scrollController: scrollController,
        onRefresh: onRefresh,
        indicatorStartTop: 0,
        indicatorMaxTravel: 52,
        child: ListView(
          controller: scrollController,
          children: const [SizedBox(height: 1200)],
        ),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ScrollController>("scrollController", scrollController))
      ..add(ObjectFlagProperty<Future<void> Function()>.has("onRefresh", onRefresh));
  }
}
