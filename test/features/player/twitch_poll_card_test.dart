import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_polls.dart";
import "package:flow/features/player/twitch_poll_card.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("poll header expands, minimizes, and closes without an options menu", (tester) async {
    final client = _Client();
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    addTearDown(controller.dispose);
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchPollCard(
            data: client.snapshot,
            controller: controller,
            pendingTransactions: const {},
            refresh: () async {},
            dismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text("Option 4"), findsNothing);
    await tester.tap(find.byTooltip("Expand poll"));
    await tester.pump();
    expect(find.text("Option 4"), findsOneWidget);
    await tester.tap(find.byTooltip("Minimize poll"));
    await tester.pump();
    expect(find.text("Option 4"), findsNothing);
    await tester.tap(find.byTooltip("Close poll"));
    await tester.pump();
    expect(dismissed, isTrue);
    expect(find.text("Option 4"), findsNothing);
  });

  testWidgets("four poll choices show vote bars and preserve a paid retry after switching cards", (
    tester,
  ) async {
    final client = _Client()..snapshotReflectsVote = false;
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    final data = ValueNotifier(client.snapshot);
    final transactions = <(String, String, String, String, int), String>{};
    addTearDown(controller.dispose);
    addTearDown(data.dispose);
    Widget app() => MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: data,
          builder: (_, value, _) => TwitchPollCard(
            data: value,
            controller: controller,
            pendingTransactions: transactions,
            refresh: () async => data.value = client.snapshot,
            dismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.tap(find.text("What next?"));
    await tester.pump();
    expect(find.text("Option 4"), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.text("${i * 10}% (${i * 10})"), findsOneWidget);
      final bar = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.byKey(ValueKey("poll-choice-choice-$i")),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(bar.widthFactor, i / 10);
    }
    await tester.tap(find.text("Option 4"));
    await tester.pump();
    final chosenRow = find.byKey(const ValueKey("poll-choice-choice-4"));
    expect(
      find.descendant(of: chosenRow, matching: find.byIcon(Icons.radio_button_checked)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsNothing);
    await tester.tap(find.text("Vote"));
    await tester.pumpAndSettle();
    expect(client.points, [0]);
    expect(client.snapshot.poll!.votedChoiceIds, isEmpty);
    expect(
      find.descendant(of: chosenRow, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.check_circle)).semanticLabel, "Voted");
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(find.text("Extra vote · 100 points"), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey("poll-choice-choice-1"))).onTap,
      isNull,
    );

    client.failNextVote = true;
    await tester.tap(find.text("Extra vote · 100 points"));
    await tester.pumpAndSettle();
    expect(find.text("Connection interrupted."), findsOneWidget);
    final retryId = client.voteIds.last;
    expect(retryId, matches(RegExp(r"^[0-9a-f]{32}$")));
    expect(transactions.values, contains(retryId));

    client.snapshotReflectsVote = true;
    data.value = client.snapshot;
    await tester.pumpWidget(const MaterialApp(home: Text("Another highlight")));
    await tester.pumpWidget(app());
    await tester.tap(find.text("What next?"));
    await tester.pump();
    expect(
      find.descendant(of: chosenRow, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    await tester.tap(find.text("Extra vote · 100 points"));
    await tester.pumpAndSettle();
    expect(client.voteIds.last, retryId);
    expect(transactions, isEmpty);

    await tester.tap(find.text("Extra vote · 100 points"));
    await tester.pumpAndSettle();
    expect(client.voteIds.last, isNot(retryId));
    expect(client.points, [0, 100, 100, 100]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("changing accounts resets the choice and cannot inherit a completed free vote", (
    tester,
  ) async {
    final client = _Client()..pendingVote = Completer<void>();
    final controller = TwitchChatController(
      clientLoader: () async => client,
      channel: "channel",
      autoConnect: false,
    );
    final data = ValueNotifier(client.snapshot);
    final transactions = <(String, String, String, String, int), String>{};
    addTearDown(controller.dispose);
    addTearDown(data.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: data,
            builder: (_, value, _) => TwitchPollCard(
              data: value,
              controller: controller,
              pendingTransactions: transactions,
              refresh: () async {},
              dismiss: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("What next?"));
    await tester.pump();
    await tester.tap(find.text("Option 4"));
    await tester.pump();
    await tester.tap(find.text("Vote"));
    await tester.pump();
    client.viewerId = "new-viewer";
    data.value = client.snapshot;
    await tester.pump();
    client.pendingVote!.complete();
    await tester.pumpAndSettle();
    expect(find.text("Extra vote · 100 points"), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.text("Option 1"));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Client extends TwitchApiClient {
  _Client() : super(clientId: "client", accessToken: "");

  String viewerId = "viewer";
  bool hasVoted = false;
  bool snapshotReflectsVote = true;
  bool failNextVote = false;
  Completer<void>? pendingVote;
  final points = <int>[];
  final voteIds = <String>[];

  TwitchChannelPoll get snapshot => TwitchChannelPoll(
    channelId: "channel-id",
    viewerId: viewerId,
    balance: 1000,
    poll: TwitchPoll(
      id: "poll",
      title: "What next?",
      status: "ACTIVE",
      startedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      closesAt: DateTime.now().add(const Duration(minutes: 5)),
      votes: 100,
      viewerStateAvailable: true,
      baseVotes: hasVoted && snapshotReflectsVote ? 1 : 0,
      votedChoiceIds: hasVoted && snapshotReflectsVote ? {"choice-4"} : {},
      pointsVoteCost: 100,
      choices: [
        for (var i = 1; i <= 4; i++)
          TwitchPollChoice(id: "choice-$i", title: "Option $i", votes: i * 10),
      ],
    ),
  );

  @override
  Future<void> voteInPoll({
    required String channelLogin,
    required String pollId,
    required String choiceId,
    required String voteId,
    required String viewerId,
    int points = 0,
  }) async {
    this.points.add(points);
    voteIds.add(voteId);
    if (failNextVote) {
      failNextVote = false;
      throw TwitchApiException("Connection interrupted.");
    }
    if (pendingVote case final pending?) {
      return pending.future;
    }
    hasVoted = true;
  }
}
