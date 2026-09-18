import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("prediction snapshots retain totals, restrictions, balance and the viewer's pick", () async {
    final client = _client((request) async {
      expect(request.headers["authorization"], "OAuth token");
      expect((jsonDecode(request.body) as Map<String, Object?>)["variables"], {"login": "channel"});
      return _response(_data(selected: "blue", spent: 200, restriction: "REGION_LOCKED"));
    });
    final snapshot = await client.fetchPredictions(" CHANNEL ");
    expect(snapshot.balance, 1000);
    expect(snapshot.hasAcceptedTerms, isTrue);
    expect(snapshot.events.single.isOpen, isTrue);
    expect(snapshot.events.single.selectedOutcomeId, "blue");
    expect(snapshot.events.single.pointsSpent, 200);
    expect(snapshot.events.single.isPointsRestricted, isTrue);
    expect(snapshot.events.single.outcomes.first.points, 3911760);
  });

  test(
    "predictions require a fresh eligible state and explicit terms before a single mutation",
    () async {
      final operations = <String>[];
      final client = _client((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final operation = body["operationName"]! as String;
        operations.add(operation);
        if (operation == "FlowPredictions") {
          return _response(_data(terms: false));
        }
        if (operation == "FlowAcceptPredictionTerms") {
          expect(body["query"], contains("hasAcceptedTOS: true"));
          expect(body["query"], isNot(contains("isTemporaryChatBadgeEnabled")));
          return _response({
            "updateUserPredictionSettings": {
              "error": null,
              "settings": {"hasAcceptedTOS": true},
            },
          });
        }
        expect(body["variables"], {
          "input": {
            "eventID": "event",
            "outcomeID": "blue",
            "points": 100,
            "transactionID": "transaction",
          },
        });
        return _response({
          "makePrediction": {"error": null},
        });
      });
      await expectLater(_predict(client), throwsA(isA<TwitchApiException>()));
      expect(operations, ["FlowPredictions"]);
      operations.clear();
      await _predict(client, acceptTerms: true);
      expect(operations, ["FlowPredictions", "FlowAcceptPredictionTerms", "FlowMakePrediction"]);
    },
  );

  test(
    "closed, own, stale-account, changed-choice, restricted and over-budget predictions never submit",
    () async {
      for (final data in [
        _data(status: "LOCKED"),
        _data(createdAt: DateTime.now().subtract(const Duration(hours: 1))),
        _data(viewer: "1"),
        _data(viewer: "different-viewer"),
        _data(selected: "pink"),
        _data(restriction: "REGION_LOCKED"),
        _data(restriction: "BANNED"),
        _data(balance: 99),
        _data(spent: 249950, selected: "blue"),
        _data(viewerState: false),
      ]) {
        var requests = 0;
        final client = _client((request) async {
          requests++;
          expect(
            (jsonDecode(request.body) as Map<String, Object?>)["operationName"],
            "FlowPredictions",
          );
          return _response(data);
        });
        await expectLater(_predict(client), throwsA(isA<TwitchApiException>()));
        expect(requests, 1);
      }
    },
  );

  test(
    "zero-point regional predictions are allowed, missing acknowledgements are errors",
    () async {
      for (final payload in <Object?>[
        null,
        <String, Object?>{},
        {
          "error": {"code": "EVENT_LOCKED"},
        },
        {"error": null},
      ]) {
        final client = _client((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          if (body["operationName"] == "FlowPredictions") {
            return _response(_data(restriction: "REGION_LOCKED"));
          }
          return _response({"makePrediction": payload});
        });
        if (payload is Map<String, Object?> &&
            payload.containsKey("error") &&
            payload["error"] == null) {
          await _predict(client, points: 0);
        } else {
          await expectLater(_predict(client, points: 0), throwsA(isA<TwitchApiException>()));
        }
      }
    },
  );
}

Future<void> _predict(TwitchApiClient client, {bool acceptTerms = false, int points = 100}) =>
    client.makePrediction(
      channelLogin: "channel",
      eventId: "event",
      outcomeId: "blue",
      points: points,
      transactionId: "transaction",
      viewerId: "2",
      acceptTerms: acceptTerms,
    );

TwitchApiClient _client(Future<http.Response> Function(http.Request) handler) => TwitchApiClient(
  clientId: "client",
  accessToken: "",
  gqlAccessToken: "token",
  httpClient: MockClient(handler),
);

http.Response _response(Object? data) =>
    http.Response(jsonEncode({"data": data}), 200, headers: {"content-type": "application/json"});

Map<String, Object?> _data({
  String status = "ACTIVE",
  String viewer = "2",
  String? selected,
  String? restriction,
  int spent = 0,
  int balance = 1000,
  bool terms = true,
  bool viewerState = true,
  DateTime? createdAt,
}) => {
  "user": {
    "id": "1",
    "login": "channel",
    "channel": {
      "id": "1",
      "activePredictionEvents": [
        {
          "id": "event",
          "title": "Who wins?",
          "status": status,
          "createdAt": (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
          "predictionWindowSeconds": 300,
          "self": viewerState ? {"restriction": restriction} : null,
          "outcomes": [
            {
              "id": "blue",
              "title": "Lions",
              "color": "BLUE",
              "totalPoints": 3911760,
              "totalUsers": 42,
            },
            {
              "id": "pink",
              "title": "Bills",
              "color": "PINK",
              "totalPoints": 7887357,
              "totalUsers": 55,
            },
          ],
        },
      ],
      "lockedPredictionEvents": <Object?>[],
      "resolvedPredictionEvents": {"edges": <Object?>[]},
      "self": {
        "communityPoints": {"balance": balance},
        "recentPredictions": [
          if (selected != null)
            {
              "event": {"id": "event"},
              "outcome": {"id": selected},
              "points": spent,
            },
        ],
      },
    },
  },
  "currentUser": {
    "id": viewer,
    "predictionsSettings": {"hasAcceptedTOS": terms},
  },
};
