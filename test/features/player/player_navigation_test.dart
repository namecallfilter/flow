import "dart:async";

import "package:flow/features/player/player_navigation.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets(
    "new streams retain only the latest root destination and preserve the nested tab stack",
    (
      tester,
    ) async {
      final rootNavigator = GlobalKey<NavigatorState>();
      final tabNavigator = GlobalKey<NavigatorState>();
      Widget page(String name) => Scaffold(key: ValueKey(name), body: Text(name));

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigator,
          home: Scaffold(
            body: Navigator(
              key: tabNavigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => page("tab root")),
            ),
          ),
        ),
      );
      unawaited(
        tabNavigator.currentState!.push<void>(
          MaterialPageRoute<void>(builder: (_) => page("tab category")),
        ),
      );
      await tester.pumpAndSettle();
      final originalCategory = tester.element(find.byKey(const ValueKey("tab category")));

      unawaited(openStreamPlayer(originalCategory, builder: (_) => page("stream A")));
      await tester.pumpAndSettle();
      expect(rootNavigator.currentState!.canPop(), isTrue);
      expect(tabNavigator.currentState!.canPop(), isTrue);

      Element? retainedDestination;
      for (final (destination, nextStream) in [
        ("player category", "stream B"),
        ("player channel", "stream C"),
      ]) {
        if (destination == "player category") {
          unawaited(
            rootNavigator.currentState!.push<void>(
              MaterialPageRoute<void>(builder: (_) => page("intermediate profile")),
            ),
          );
          await tester.pumpAndSettle();
        }
        unawaited(
          rootNavigator.currentState!.push<void>(
            MaterialPageRoute<void>(builder: (_) => page(destination)),
          ),
        );
        await tester.pumpAndSettle();
        retainedDestination = tester.element(find.byKey(ValueKey(destination)));
        unawaited(
          openStreamPlayer(
            retainedDestination,
            builder: (_) => page(nextStream),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(destination), skipOffstage: false), findsOneWidget);
        expect(find.byKey(const ValueKey("stream A"), skipOffstage: false), findsNothing);
        expect(
          find.byKey(const ValueKey("intermediate profile"), skipOffstage: false),
          findsNothing,
        );
      }

      expect(find.byKey(const ValueKey("stream B"), skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey("player category"), skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey("stream C")), findsOneWidget);
      rootNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey("player channel"))),
        same(retainedDestination),
      );
      expect(rootNavigator.currentState!.canPop(), isTrue);

      // Reopening from the retained page must not remove that same page.
      unawaited(openStreamPlayer(retainedDestination!, builder: (_) => page("stream D")));
      await tester.pumpAndSettle();
      rootNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey("player channel"))),
        same(retainedDestination),
      );
      rootNavigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(rootNavigator.currentState!.canPop(), isFalse);
      expect(tabNavigator.currentState!.canPop(), isTrue);
      expect(tester.element(find.byKey(const ValueKey("tab category"))), same(originalCategory));

      // Previously popped anchors cannot affect a fresh stream or a direct switch.
      unawaited(openStreamPlayer(originalCategory, builder: (_) => page("stream E")));
      await tester.pumpAndSettle();
      unawaited(
        openStreamPlayer(
          tester.element(find.byKey(const ValueKey("stream E"))),
          builder: (_) => page("stream F"),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("stream E"), skipOffstage: false), findsNothing);
      rootNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(rootNavigator.currentState!.canPop(), isFalse);
      expect(tester.element(find.byKey(const ValueKey("tab category"))), same(originalCategory));
      tabNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("tab root")), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
