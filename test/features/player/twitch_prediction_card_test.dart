import "dart:async";
import "dart:ui" show Tristate;

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_polls.dart";
import "package:flow/api/twitch_predictions.dart";
import "package:flow/features/player/twitch_prediction_card.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("prediction headers stay aligned in sidechat and collapse survives refresh", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _Client()..status = "RESOLVED";
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    Widget app(double width) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TwitchPredictionCard(
              controller: controller,
              isVisible: true,
              showSheet: (_) async {},
            ),
          ),
        ),
      ),
    );
    for (final width in [390.0, 240.0]) {
      await tester.pumpWidget(app(width));
      await tester.pumpAndSettle();
      final close = tester.getRect(find.byTooltip("Close prediction"));
      final minimize = tester.getRect(find.byTooltip("Minimize prediction"));
      final action = tester.getRect(find.widgetWithText(FilledButton, "See Details"));
      final title = tester.getRect(find.text("Lions"));
      final card = tester.getRect(find.byKey(const ValueKey("prediction-event")));
      final progress = tester.getRect(find.byType(LinearProgressIndicator));
      expect(action.height, 32);
      expect((width > 340 ? action.top : close.top) - card.top, 8);
      expect(card.bottom - progress.bottom, 8);
      expect(close.center.dy, minimize.center.dy);
      final closeIcon = tester.getRect(
        find.descendant(
          of: find.byTooltip("Close prediction"),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      expect(tester.getRect(find.text("3,911,760")).right, closeIcon.right - 4);
      expect(
        tester.getRect(find.text("1. Lions")).left,
        tester.getRect(find.byIcon(Icons.emoji_events_outlined)).left + 1.5,
      );
      expect(title.center.dy, close.center.dy);
      expect(tester.getRect(find.byIcon(Icons.emoji_events_outlined)).center.dy, close.center.dy);
      expect(find.textContaining("points awarded"), findsNothing);
      expect(find.textContaining("go to"), findsNothing);
      expect(find.text("Who wins?"), findsNothing);
      if (width > 340) {
        expect(action.center.dy, close.center.dy);
      } else {
        expect(action.top, greaterThanOrEqualTo(title.bottom));
      }
      await tester.tap(find.byTooltip("Minimize prediction"));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byTooltip("Close prediction")), close);
      expect(tester.getRect(find.widgetWithText(FilledButton, "See Details")), action);
      expect(tester.getRect(find.text("Lions")), title);
      expect(
        tester.getRect(find.byKey(const ValueKey("prediction-event"))).bottom -
            tester.getRect(find.byType(LinearProgressIndicator)).bottom,
        8,
      );
      await tester.tap(find.byTooltip("Expand prediction"));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip("Minimize prediction"));
    await tester.pumpAndSettle();
    controller.predictionUpdates.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byTooltip("Expand prediction"), findsOneWidget);
    expect(find.text("3,911,760"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("all ten prediction outcomes remain selectable on a narrow phone", (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _Client()
      ..outcomes = List.generate(
        10,
        (index) => TwitchPredictionOutcome(
          id: "outcome-$index",
          title: "Outcome ${index + 1}",
          points: (index + 1) * 100,
          users: index + 1,
          color: "BLUE",
        ),
      );
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TwitchPredictionCard(
              controller: controller,
              isVisible: true,
              showSheet: (builder) => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: builder,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Who wins?"), findsOneWidget);
    expect(find.text("Predict with Channel Points"), findsNothing);
    expect(
      tester.getCenter(find.text("Who wins?")).dy,
      tester.getCenter(find.byTooltip("Minimize prediction")).dy,
    );
    expect(find.byTooltip("Minimize prediction"), findsOneWidget);
    for (var index = 1; index <= 10; index++) {
      expect(find.text("$index. Outcome $index"), findsOneWidget);
    }
    await tester.tap(find.text("Predict"));
    await tester.pumpAndSettle();
    for (var index = 0; index < 10; index++) {
      final outcome = find.byKey(ValueKey("prediction-outcome-outcome-$index"));
      await tester.ensureVisible(outcome);
      await tester.tap(outcome);
      await tester.pump();
      expect(tester.getSemantics(outcome).flagsCollection.isSelected, Tristate.isTrue);
    }
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), "100");
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, "Predict with 100 points"))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    expect(client.transactions, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("compact titles rotate every four seconds and expired predictions stay hidden", (
    tester,
  ) async {
    final client = _Client()..closesAt = DateTime.now().add(const Duration(seconds: 10));
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            child: TwitchPredictionCard(
              controller: controller,
              isVisible: true,
              showSheet: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text("Who wins?"), findsOneWidget);
    await tester.tap(find.byTooltip("Minimize prediction"));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text("Who wins?"), findsNothing);
    expect(find.text("3.9M vs 7.9M"), findsOneWidget);
    final totals = tester.getRect(find.text("3.9M vs 7.9M"));
    final action = tester.getRect(find.widgetWithText(FilledButton, "Predict"));
    await tester.tap(find.byTooltip("Expand prediction"));
    await tester.pump();
    expect(tester.getRect(find.text("3.9M vs 7.9M")), totals);
    expect(tester.getRect(find.widgetWithText(FilledButton, "Predict")), action);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text("Who wins?"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    controller.predictionUpdates.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("locked predictions are not hydrated into highlights", (tester) async {
    final client = _Client()..status = "LOCKED";
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TwitchPredictionCard(
          controller: controller,
          isVisible: true,
          showSheet: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("dismissed predictions can show their result once and expire after 120 seconds", (
    tester,
  ) async {
    final client = _Client();
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchPredictionCard(
            controller: controller,
            isVisible: true,
            showSheet: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byTooltip("Minimize prediction"), findsOneWidget);
    expect(find.text("3,911,760"), findsOneWidget);
    await tester.tap(find.byTooltip("Minimize prediction"));
    await tester.pumpAndSettle();
    expect(find.text("3,911,760"), findsNothing);
    await tester.tap(find.byTooltip("Close prediction"));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    client.status = "RESOLVE_PENDING";
    controller.predictionUpdates.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text("Lions"), findsOneWidget);
    expect(find.text("See Details"), findsOneWidget);
    expect(find.byTooltip("Minimize prediction"), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    client.status = "RESOLVED";
    controller.predictionUpdates.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text("See Details"), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    controller.predictionUpdates.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("cancellation removes a prediction immediately", (tester) async {
    final client = _Client();
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TwitchPredictionCard(
          controller: controller,
          isVisible: true,
          showSheet: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsOneWidget);
    for (final status in ["CANCEL_PENDING", "CANCELED"]) {
      client.status = status;
      controller.predictionUpdates.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("prediction-event")), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("highlights show the newest first and preserve manual selection on updates", (
    tester,
  ) async {
    final client = _Client();
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    Widget app({String? pin = "old", DateTime? createdAt}) => MaterialApp(
      home: Scaffold(
        body: TwitchPredictionCard(
          controller: controller,
          isVisible: true,
          showSheet: (_) async {},
          pinnedChat: pin == null
              ? null
              : (
                  id: pin,
                  createdAt: createdAt ?? DateTime.utc(2026, 9, 17),
                  child: Text("Pinned $pin"),
                ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text("Who wins?"), findsOneWidget);
    expect(find.text("Pinned old"), findsNothing);
    expect(find.text("View All (2)"), findsNothing);
    final peek = tester.getRect(find.byKey(const ValueKey("highlight-stack-peek")));
    await tester.tapAt(Offset(peek.center.dx, peek.top + 4));
    await tester.pumpAndSettle();
    expect(find.text("Who wins?"), findsOneWidget);
    expect(find.text("Pinned old"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("highlight-select-pin-old")));
    await tester.pumpAndSettle();
    expect(find.text("Pinned old"), findsOneWidget);
    expect(find.text("Who wins?"), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text("Pinned old"), findsOneWidget);
    await tester.pumpWidget(app(pin: "new", createdAt: DateTime.utc(2026, 9, 19)));
    await tester.pumpAndSettle();
    expect(find.text("Pinned new"), findsOneWidget);
    expect(find.text("View All (2)"), findsNothing);
    final nextPeek = tester.getRect(find.byKey(const ValueKey("highlight-stack-peek")));
    await tester.tapAt(Offset(nextPeek.center.dx, nextPeek.top + 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("highlight-select-prediction-event")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsOneWidget);
    await tester.pumpWidget(app(pin: null));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsOneWidget);
    expect(find.text("View All (2)"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("a pin remains visible while predictions are loading or unavailable", (tester) async {
    final client = _Client()..pendingRefresh = Completer<TwitchChannelPredictions>();
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TwitchPredictionCard(
          controller: controller,
          isVisible: true,
          showSheet: (_) async {},
          pinnedChat: (id: "pin", createdAt: null, child: const Text("Pinned message")),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Pinned message"), findsOneWidget);
    client.pendingRefresh!.completeError(TwitchApiException("Unavailable"));
    await tester.pumpAndSettle();
    expect(find.text("Pinned message"), findsOneWidget);
    expect(find.byTooltip("Retry"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("poll failures remain visible beside a prediction or pin and retry clears them", (
    tester,
  ) async {
    for (final showPin in [false, true]) {
      final client = _Client()
        ..failPollRefresh = true
        ..status = showPin ? "LOCKED" : "ACTIVE";
      final controller = TwitchChatController(
        clientLoader: () async => client,
        channel: "channel",
        autoConnect: false,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchPredictionCard(
              controller: controller,
              isVisible: true,
              showSheet: (_) async {},
              pinnedChat: showPin
                  ? (id: "pin", createdAt: null, child: const Text("Pinned message"))
                  : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final highlight = showPin
          ? find.text("Pinned message")
          : find.byKey(const ValueKey("prediction-event"));
      expect(highlight, findsOneWidget);
      expect(find.text("Could not refresh poll."), findsOneWidget);
      client.failPollRefresh = false;
      final fetches = client.fetches;
      await tester.tap(find.byTooltip("Retry"));
      await tester.pumpAndSettle();
      expect(client.fetches, fetches + 1);
      expect(find.text("Could not refresh poll."), findsNothing);
      expect(find.byTooltip("Retry"), findsNothing);
      expect(highlight, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets("results update while open without a refresh button or waiting label", (
    tester,
  ) async {
    final client = _Client();
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TwitchPredictionCard(
              controller: controller,
              isVisible: true,
              showSheet: (builder) =>
                  showModalBottomSheet<void>(context: context, builder: builder),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("awaiting result"), findsNothing);
    await tester.tap(find.text("Predict"));
    await tester.pumpAndSettle();
    expect(find.text("1:3.02"), findsOneWidget);
    expect(find.byTooltip("Channel Points"), findsNWidgets(2));
    expect(find.byTooltip("Return ratio"), findsNWidgets(2));
    expect(find.byTooltip("Voters"), findsNWidgets(2));
    expect(find.byTooltip("Top vote"), findsOneWidget);
    client.status = "LOCKED";
    controller.predictionUpdates.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text("Refresh"), findsNothing);
    expect(find.textContaining("awaiting result"), findsNothing);
    expect(find.text("See Details"), findsOneWidget);
    client.status = "RESOLVED";
    controller.predictionUpdates.notifyListeners();
    await tester.pump();
    await tester.pump();
    expect(find.text("Winner: Lions"), findsWidgets);
    expect(
      find.descendant(
        of: find.ancestor(of: find.text("Winner"), matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.emoji_events_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text("Winner"), findsOneWidget);
    expect(client.transactions, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("an update received during a fetch is reconciled as soon as that fetch finishes", (
    tester,
  ) async {
    final client = _Client()..pendingRefresh = Completer<TwitchChannelPredictions>();
    final pending = client.pendingRefresh!;
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TwitchPredictionCard(
          controller: controller,
          isVisible: true,
          showSheet: (_) async {},
        ),
      ),
    );
    await tester.pump();
    expect(client.fetches, 1);
    controller.predictionUpdates.notifyListeners();
    controller.predictionUpdates.notifyListeners();
    expect(client.fetches, 1);
    client.pendingRefresh = null;
    client.status = "RESOLVED";
    pending.complete(await _Client().fetchPredictions("channel"));
    await tester.pumpAndSettle();
    expect(client.fetches, 2);
    expect(find.text("Lions"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("a new controller refreshes while an old prediction request remains pending", (
    tester,
  ) async {
    final oldClient = _Client()..pendingRefresh = Completer<TwitchChannelPredictions>();
    final newClient = _Client()..pendingRefresh = Completer<TwitchChannelPredictions>();
    final oldController = TwitchChatController(
      clientLoader: () async => oldClient,
      channel: "old",
      autoConnect: false,
    );
    final newController = TwitchChatController(
      clientLoader: () async => newClient,
      channel: "new",
      autoConnect: false,
    );
    addTearDown(oldController.dispose);
    addTearDown(newController.dispose);
    Widget app(TwitchChatController controller) => MaterialApp(
      home: TwitchPredictionCard(controller: controller, isVisible: true, showSheet: (_) async {}),
    );
    await tester.pumpWidget(app(oldController));
    await tester.pumpAndSettle();
    expect(oldClient.fetches, 1);
    await tester.pumpWidget(app(newController));
    await tester.pumpAndSettle();
    expect(newClient.fetches, 1);
    final snapshot = await _Client().fetchPredictions("channel");
    oldClient.pendingRefresh!.complete(snapshot);
    await tester.pumpAndSettle();
    expect(find.text("Who wins?"), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(newClient.fetches, 1);
    newClient.pendingRefresh!.complete(snapshot);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("prediction-event")), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("an initial prediction failure offers retry and clears after recovery", (
    tester,
  ) async {
    final client = _Client()..failRefresh = true;
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchPredictionCard(
            controller: controller,
            isVisible: true,
            showSheet: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Could not refresh predictions."), findsOneWidget);
    expect(find.text("Who wins?"), findsNothing);
    client.failRefresh = false;
    await tester.tap(find.byTooltip("Retry"));
    await tester.pumpAndSettle();
    expect(find.text("Could not refresh predictions."), findsNothing);
    expect(find.text("Who wins?"), findsOneWidget);
    expect(client.transactions, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("empty balances and regional picks show accurate participation text", (tester) async {
    final client = _Client()..balance = 0;
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    for (final regional in [false, true]) {
      client.regional = regional;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TwitchPredictionCard(
                controller: controller,
                isVisible: true,
                showSheet: (builder) => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: builder,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Predict"));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining("Your points will be spent"), findsNothing);
      if (regional) {
        expect(find.text("Predict with 0 points"), findsOneWidget);
      } else {
        expect(
          find.text("You do not have any Channel Points available for this prediction."),
          findsOneWidget,
        );
      }
      expect(client.transactions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets("prediction card opens an explicit outcome and amount form and preserves retry IDs", (
    tester,
  ) async {
    final client = _Client()..failSubmissions = 3;
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TwitchPredictionCard(
              controller: controller,
              isVisible: true,
              showSheet: (builder) => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: builder,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Who wins?"), findsOneWidget);
    expect(find.text("3,911,760"), findsOneWidget);
    await tester.tap(find.text("Predict"));
    await tester.pumpAndSettle();
    expect(client.transactions, isEmpty);
    client.failRefresh = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text("Could not refresh predictions."), findsOneWidget);
    expect(find.byKey(const ValueKey("prediction-outcome-blue")), findsOneWidget);
    client.failRefresh = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text("Could not refresh predictions."), findsNothing);
    expect(client.transactions, isEmpty);
    final submit = find.widgetWithText(FilledButton, "Predict with … points");
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey("prediction-outcome-blue")));
    await tester.enterText(find.byType(TextField), "1001");
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, "Predict with 1,001 points"))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), "100");
    await tester.pump();
    final predict = find.widgetWithText(FilledButton, "Predict with 100 points");
    await tester.ensureVisible(predict);
    await tester.tap(predict);
    await tester.pumpAndSettle();
    expect(find.text("Connection lost"), findsOneWidget);
    for (final amount in ["200", "100"]) {
      await tester.enterText(find.byType(TextField), amount);
      await tester.pump();
      final button = find.widgetWithText(FilledButton, "Predict with $amount points");
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text("Connection lost"), findsOneWidget);
    }
    final original = client.transactions.first;
    expect(client.transactions[1], isNot(original));
    expect(client.transactions[2], original);
    for (final retry in [true, false]) {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Predict"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("prediction-outcome-blue")));
      await tester.enterText(find.byType(TextField), "100");
      await tester.pump();
      final submit = find.widgetWithText(
        FilledButton,
        retry ? "Predict with 100 points" : "Add 100 points",
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(client.transactions.last, retry ? original : isNot(original));
      expect(find.text("Add … points"), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.widgetWithText(FilledButton, "Predict with 100 points"), findsNothing);
    }
    expect(client.submittedPoints, [100, 200, 100, 100, 100]);
    expect(find.text("Your prediction: 200 points"), findsOneWidget);
    expect(find.textContaining("cannot change"), findsNothing);
    expect(find.textContaining("Your points will be spent"), findsNothing);
    expect(find.textContaining(" return"), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.helperText, isNull);
    await tester.enterText(find.byType(TextField), "200");
    await tester.pump();
    final add = find.text("Add 200 points");
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(client.pointsSpent, 400);
    expect(client.balance, 600);
    expect(client.transactions.last, isNot(client.transactions[client.transactions.length - 2]));
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey("prediction-outcome-pink"))).onTap,
      isNull,
    );
    client.status = "LOCKED";
    controller.predictionUpdates.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Client extends TwitchApiClient {
  _Client() : super(clientId: "client", accessToken: "", gqlAccessToken: "token");
  final transactions = <String>[];
  final submittedPoints = <int>[];
  int failSubmissions = 1;
  int balance = 1000;
  int pointsSpent = 0;
  String? selectedOutcome;
  List<TwitchPredictionOutcome>? outcomes;
  bool regional = false;
  bool failRefresh = false;
  bool failPollRefresh = false;
  String status = "ACTIVE";
  int fetches = 0;
  DateTime closesAt = DateTime.now().add(const Duration(minutes: 5));
  Completer<TwitchChannelPredictions>? pendingRefresh;

  @override
  Future<TwitchChannelPoll> fetchPoll(String login) async {
    if (failPollRefresh) {
      throw TwitchApiException("Poll unavailable");
    }
    return const TwitchChannelPoll(channelId: "1");
  }

  @override
  Future<TwitchChannelPredictions> fetchPredictions(String login) async {
    fetches++;
    if (pendingRefresh != null) {
      return pendingRefresh!.future;
    }
    if (failRefresh) {
      throw TwitchApiException("ServerException: internal transport details");
    }
    return TwitchChannelPredictions(
      channelId: "1",
      viewerId: "2",
      balance: balance,
      hasAcceptedTerms: true,
      events: [
        TwitchPrediction(
          id: "event",
          title: "Who wins?",
          status: status,
          winningOutcomeId: status == "RESOLVED" || status == "RESOLVE_PENDING" ? "blue" : null,
          endedAt: status == "RESOLVED" || status == "RESOLVE_PENDING" ? DateTime.now() : null,
          createdAt: DateTime.utc(2026, 9, 18),
          closesAt: closesAt,
          viewerStateAvailable: true,
          selectedOutcomeId: selectedOutcome,
          pointsSpent: pointsSpent,
          restriction: regional ? "REGION_LOCKED" : null,
          outcomes:
              outcomes ??
              const [
                TwitchPredictionOutcome(
                  id: "blue",
                  title: "Lions",
                  points: 3911760,
                  users: 42,
                  color: "BLUE",
                  topPoints: 30000,
                ),
                TwitchPredictionOutcome(
                  id: "pink",
                  title: "Bills",
                  points: 7887357,
                  users: 55,
                  color: "PINK",
                ),
              ],
        ),
      ],
    );
  }

  @override
  Future<void> makePrediction({
    required String channelLogin,
    required String eventId,
    required String outcomeId,
    required int points,
    required String transactionId,
    required String viewerId,
    bool acceptTerms = false,
  }) async {
    expect(outcomeId, "blue");
    transactions.add(transactionId);
    submittedPoints.add(points);
    if (transactions.length <= failSubmissions) {
      throw TwitchApiException("Connection lost");
    }
    selectedOutcome = outcomeId;
    pointsSpent += points;
    balance -= points;
  }
}
