import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("poll snapshots retain all four choices, totals and the viewer's vote", () async {
    final client = _client((request) async {
      expect(request.headers["authorization"], "OAuth token");
      expect((jsonDecode(request.body) as Map<String, Object?>)["variables"], {"login": "channel"});
      return _response(_data(baseVotes: 1, selected: "choice-4", pointsCost: 100));
    });
    final snapshot = await client.fetchPoll(" CHANNEL ");
    expect(snapshot.channelId, "1");
    expect(snapshot.viewerId, "2");
    expect(snapshot.balance, 1000);
    expect(snapshot.poll!.choices.map((choice) => choice.id), [
      "choice-1",
      "choice-2",
      "choice-3",
      "choice-4",
    ]);
    expect(snapshot.poll!.choices.last.votes, 40);
    expect(snapshot.poll!.votes, 100);
    expect(snapshot.poll!.votedChoiceIds, {"choice-4"});
    expect(snapshot.poll!.baseVotes, 1);
    expect(snapshot.poll!.pointsVoteCost, 100);
    expect(snapshot.poll!.isOpen, isTrue);
  });

  test("only Twitch's viewable statuses appear, with no guessed results expiry", () async {
    for (final status in [
      "ACTIVE",
      "COMPLETED",
      "TERMINATED",
      "ARCHIVED",
      "MODERATED",
      "INVALID",
    ]) {
      final client = _client(
        (_) async => _response(
          _data(
            status: status,
            startedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ),
      );
      final poll = (await client.fetchPoll("channel")).poll;
      expect(poll != null, const {"ACTIVE", "COMPLETED", "TERMINATED"}.contains(status));
      expect(poll?.isOpen ?? false, isFalse);
    }
    final empty = _data();
    empty["user"] = {...empty["user"]! as Map<String, Object?>, "viewablePoll": null};
    expect((await _client((_) async => _response(empty)).fetchPoll("channel")).poll, isNull);
  });

  test("voting checks fresh eligibility and confirms the exact viewer, poll and choice", () async {
    final operations = <String>[];
    final client = _client((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final operation = body["operationName"]! as String;
      operations.add(operation);
      if (operation == "FlowPoll") {
        return _response(_data());
      }
      expect(body["variables"], {
        "input": {
          "pollID": "poll",
          "choiceID": "choice-4",
          "userID": "2",
          "voteID": "vote",
          "tokens": null,
        },
      });
      return _response({"voteInPoll": _acknowledgement()});
    });
    await _vote(client);
    expect(operations, ["FlowPoll", "FlowVoteInPoll"]);
  });

  test("closed, expired, banned, stale-account and already-voted polls never submit", () async {
    for (final data in [
      _data(status: "COMPLETED"),
      _data(startedAt: DateTime.now().subtract(const Duration(hours: 1))),
      _data(isBanned: true),
      _data(viewerId: "other-viewer"),
      _data(viewerState: false),
      _data(baseVotes: 1, selected: "choice-4"),
    ]) {
      var requests = 0;
      final client = _client((request) async {
        requests++;
        expect((jsonDecode(request.body) as Map<String, Object?>)["operationName"], "FlowPoll");
        return _response(data);
      });
      await expectLater(_vote(client), throwsA(isA<TwitchApiException>()));
      expect(requests, 1);
    }
  });

  test(
    "paid votes require the displayed cost, balance, prior free vote and permitted choice",
    () async {
      final scenarios = <(Map<String, Object?>, bool)>[
        (_data(baseVotes: 1, selected: "choice-4", pointsCost: 100), true),
        (_data(baseVotes: 1, selected: "choice-4", pointsCost: 200), false),
        (_data(baseVotes: 1, selected: "choice-4", pointsCost: 100, balance: 99), false),
        (_data(pointsCost: 100), false),
        (_data(baseVotes: 1, selected: "choice-3", pointsCost: 100), false),
        (_data(baseVotes: 1, selected: "choice-3", pointsCost: 100, multichoice: true), true),
        (_data(baseVotes: 1, selected: "choice-4", pointsCost: 100, viewerId: "1"), false),
      ];
      for (final (data, allowed) in scenarios) {
        var mutations = 0;
        final client = _client((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          if (body["operationName"] == "FlowPoll") {
            return _response(data);
          }
          mutations++;
          expect(((body["variables"]! as Map)["input"]! as Map)["tokens"], {"channelPoints": 100});
          return _response({"voteInPoll": _acknowledgement()});
        });
        final future = _vote(client, points: 100);
        if (allowed) {
          await future;
        } else {
          await expectLater(future, throwsA(isA<TwitchApiException>()));
        }
        expect(mutations, allowed ? 1 : 0);
      }
    },
  );

  test("missing, rejected and mismatched acknowledgements never report success", () async {
    for (final acknowledgement in <Object?>[
      null,
      <String, Object?>{},
      {"error": null},
      {
        "error": {"code": "POLL_CLOSED"},
      },
      _acknowledgement(viewerId: "other-viewer"),
      _acknowledgement(pollId: "other-poll"),
      _acknowledgement(choiceId: "choice-1"),
      _acknowledgement(votes: 0),
    ]) {
      final client = _client((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        return _response(
          body["operationName"] == "FlowPoll" ? _data() : {"voteInPoll": acknowledgement},
        );
      });
      await expectLater(_vote(client), throwsA(isA<TwitchApiException>()));
    }
  });
}

Future<void> _vote(TwitchApiClient client, {int points = 0}) => client.voteInPoll(
  channelLogin: "channel",
  pollId: "poll",
  choiceId: "choice-4",
  voteId: "vote",
  viewerId: "2",
  points: points,
);

TwitchApiClient _client(Future<http.Response> Function(http.Request) handler) => TwitchApiClient(
  clientId: "client",
  accessToken: "",
  gqlAccessToken: "token",
  httpClient: MockClient(handler),
);

http.Response _response(Object? data) =>
    http.Response(jsonEncode({"data": data}), 200, headers: {"content-type": "application/json"});

Map<String, Object?> _acknowledgement({
  String viewerId = "2",
  String pollId = "poll",
  String choiceId = "choice-4",
  int votes = 1,
}) => {
  "error": null,
  "voter": {
    "user": {"id": viewerId},
    "poll": {"id": pollId},
    "choices": [
      {
        "pollChoice": {"id": choiceId},
        "votes": {"total": votes},
      },
    ],
  },
};

Map<String, Object?> _data({
  String status = "ACTIVE",
  String viewerId = "2",
  int baseVotes = 0,
  String? selected,
  bool viewerState = true,
  bool isBanned = false,
  int? pointsCost,
  int balance = 1000,
  bool multichoice = false,
  DateTime? startedAt,
}) => {
  "currentUser": {"id": viewerId},
  "user": {
    "id": "1",
    "login": "channel",
    "self": {
      "banStatus": isBanned ? {"isPermanent": true} : null,
    },
    "channel": {
      "self": {
        "communityPoints": {"balance": balance},
      },
    },
    "viewablePoll": {
      "id": "poll",
      "title": "What next?",
      "status": status,
      "startedAt": (startedAt ?? DateTime.now()).toUtc().toIso8601String(),
      "durationSeconds": 300,
      "ownedBy": {"id": "1"},
      "votes": {"total": 100},
      "choices": [
        for (var i = 1; i <= 4; i++)
          {
            "id": "choice-$i",
            "title": "Option $i",
            "votes": {"total": i * 10},
          },
      ],
      "settings": {
        "multichoice": {"isEnabled": multichoice},
        "communityPointsVotes": {"isEnabled": pointsCost != null, "cost": pointsCost},
      },
      "self": viewerState
          ? {
              "voter": selected == null
                  ? null
                  : {
                      "votes": {"base": baseVotes, "total": baseVotes},
                      "choices": [
                        {
                          "pollChoice": {"id": selected},
                        },
                      ],
                    },
            }
          : null,
    },
  },
};
