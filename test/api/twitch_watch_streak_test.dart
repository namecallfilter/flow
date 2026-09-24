import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test(
    "watch streak shares require provider eligibility and a successful mutation payload",
    () async {
      var status = "CAN_SHARE";
      Map<String, Object?>? response = {
        "error": {"code": "NOT_ELIGIBLE"},
      };
      var mutations = 0;
      final client = TwitchApiClient(
        clientId: "test",
        accessToken: "",
        gqlAccessToken: "web-token",
        httpClient: MockClient((request) async {
          expect(request.headers["authorization"], "OAuth web-token");
          final body = jsonDecode(request.body) as Map;
          if ((body["query"] as String).contains("query FlowWatchStreak")) {
            expect(body["variables"], {"channelID": "1"});
            return http.Response(
              jsonEncode({
                "data": {
                  "channel": {
                    "self": {
                      "watchStreakMilestone": {
                        "watchStreakMilestone": {
                          "id": "milestone",
                          "value": "15",
                          "shareStatus": status,
                        },
                      },
                    },
                  },
                },
              }),
              200,
            );
          }
          mutations++;
          expect(body["variables"], {
            "input": {"channelID": "1", "milestoneID": "milestone", "messageBody": "hello"},
          });
          return http.Response(
            jsonEncode({
              "data": {"shareViewerMilestone": response},
            }),
            200,
          );
        }),
      );
      final milestone = await client.fetchWatchStreak("1");
      expect(milestone!.id, "milestone");
      expect(milestone.value, 15);
      expect(milestone.canShare, isTrue);
      for (final value in ["SHARED", "CANNOT_SHARE", "UNKNOWN"]) {
        status = value;
        expect((await client.fetchWatchStreak("1"))!.canShare, isFalse);
      }
      Future<void> share([String message = "hello"]) =>
          client.shareWatchStreak(channelId: "1", milestoneId: "milestone", message: message);
      await expectLater(share(), throwsA(isA<TwitchApiException>()));
      response = null;
      await expectLater(share(), throwsA(isA<TwitchApiException>()));
      response = {"error": null};
      await share();
      expect(mutations, 3);
      await expectLater(share("x" * 501), throwsA(isA<TwitchApiException>()));
      expect(mutations, 3);
      final anonymous = TwitchApiClient(
        clientId: "test",
        accessToken: "",
        httpClient: MockClient((_) async => fail("Must not request")),
      );
      expect(await anonymous.fetchWatchStreak("1"), isNull);
      await expectLater(
        anonymous.shareWatchStreak(channelId: "1", milestoneId: "milestone", message: ""),
        throwsA(isA<TwitchApiException>()),
      );
    },
  );
}
