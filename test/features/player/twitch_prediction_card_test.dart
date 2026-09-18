import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_predictions.dart";
import "package:flow/features/player/twitch_prediction_card.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
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
    await tester.tap(predict);
    await tester.pumpAndSettle();
    expect(client.transactions, hasLength(2));
    expect(client.transactions.toSet(), hasLength(1));
    expect(find.text("Prediction submitted."), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "Predict with 100 points"), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Client extends TwitchApiClient {
  _Client() : super(clientId: "client", accessToken: "", gqlAccessToken: "token");
  final transactions = <String>[];
  int balance = 1000;
  bool regional = false;
  bool failRefresh = false;

  @override
  Future<TwitchChannelPredictions> fetchPredictions(String login) async {
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
          status: "ACTIVE",
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
    expect(points, 100);
    transactions.add(transactionId);
    if (transactions.length == 1) {
      throw TwitchApiException("Connection lost");
    }
  }
}
