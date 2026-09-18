import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_predictions.dart";
import "package:flow/features/player/twitch_prediction_card.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
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
    expect(find.text("1 / 2"), findsOneWidget);
    await tester.tap(find.byTooltip("Next highlight"));
    await tester.pumpAndSettle();
    expect(find.text("Pinned old"), findsOneWidget);
    expect(find.text("Who wins?"), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text("Pinned old"), findsOneWidget);
    await tester.pumpWidget(app(pin: "new", createdAt: DateTime.utc(2026, 9, 19)));
    await tester.pumpAndSettle();
    expect(find.text("Pinned new"), findsOneWidget);
    expect(find.text("1 / 2"), findsOneWidget);
    await tester.tap(find.byTooltip("Previous highlight"));
    await tester.pumpAndSettle();
    expect(find.text("Who wins?"), findsOneWidget);
    expect(find.text("2 / 2"), findsOneWidget);
    await tester.pumpWidget(app(pin: null));
    await tester.pumpAndSettle();
    expect(find.text("Who wins?"), findsOneWidget);
    expect(find.byTooltip("Next highlight"), findsNothing);
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
    expect(find.byTooltip("Retry predictions"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("results update while open without a refresh button or waiting label", (
    tester,
  ) async {
    final client = _Client()..status = "LOCKED";
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
    await tester.tap(find.text("Results"));
    await tester.pumpAndSettle();
    expect(find.text("Refresh"), findsNothing);
    expect(find.textContaining("awaiting result"), findsNothing);
    client.status = "RESOLVED";
    controller.predictionUpdates.notifyListeners();
    await tester.pump();
    await tester.pump();
    expect(find.text("Winner: Lions"), findsWidgets);
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
    expect(find.text("Winner: Lions"), findsOneWidget);
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
    expect(find.text("Who wins?"), findsOneWidget);
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
    await tester.tap(find.byTooltip("Retry predictions"));
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
    expect(find.widgetWithText(ListTile, "Lions"), findsOneWidget);
    client.failRefresh = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text("Could not refresh predictions."), findsNothing);
    expect(client.transactions, isEmpty);
    final submit = find.widgetWithText(FilledButton, "Predict with … points");
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(find.widgetWithText(ListTile, "Lions"));
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
      await tester.tap(find.widgetWithText(ListTile, "Lions"));
      await tester.enterText(find.byType(TextField), "100");
      await tester.pump();
      await tester.ensureVisible(predict);
      await tester.tap(predict);
      await tester.pumpAndSettle();
      expect(client.transactions.last, retry ? original : isNot(original));
      expect(find.text("Prediction submitted."), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Predict with 100 points"), findsNothing);
    }
    expect(client.submittedPoints, [100, 200, 100, 100, 100]);
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
  bool regional = false;
  bool failRefresh = false;
  String status = "ACTIVE";
  int fetches = 0;
  Completer<TwitchChannelPredictions>? pendingRefresh;

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
          winningOutcomeId: status == "RESOLVED" ? "blue" : null,
          createdAt: DateTime.utc(2026, 9, 18),
          closesAt: DateTime.now().add(const Duration(minutes: 5)),
          viewerStateAvailable: true,
          restriction: regional ? "REGION_LOCKED" : null,
          outcomes: const [
            TwitchPredictionOutcome(
              id: "blue",
              title: "Lions",
              points: 3911760,
              users: 42,
              color: "BLUE",
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
  }
}
