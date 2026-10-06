import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test(
    "channel notification enrollment saves every choice and respects legacy disabling",
    () async {
      var state = "PERSONALIZED";
      var enabled = true;
      var legacyDisabled = false;
      var reject = false;
      final changes = <String>[];
      final client = TwitchApiClient(
        clientId: "test",
        accessToken: "",
        gqlAccessToken: "web-token",
        httpClient: MockClient((request) async {
          expect(request.headers["authorization"], "OAuth web-token");
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final query = body["query"] as String;
          final variables = body["variables"] as Map<String, dynamic>;
          final input = variables["input"] as Map<String, dynamic>?;
          final Map<String, Object?> data;
          if (query.contains("FlowSetChannelNotificationSetting")) {
            expect(input?["channelID"], "123");
            changes.add("setting:${input?["settingState"]}");
            if (!reject) {
              state = input!["settingState"] as String;
            }
            data = {
              "setLiveNotificationsEnrollment": {"error": reject ? "REJECTED" : null},
            };
          } else {
            expect(variables, {"login": "creator"});
            data = {
              "user": {
                "self": {
                  "follower": {
                    "disableNotifications": legacyDisabled,
                    "notificationSettings": {"isEnabled": enabled, "followsSettingState": state},
                  },
                },
              },
            };
          }
          return http.Response(jsonEncode({"data": data}), 200);
        }),
      );
      expect(
        await client.fetchChannelNotificationSetting("Creator"),
        TwitchChannelNotificationSetting.personalized,
      );
      for (final setting in [
        TwitchChannelNotificationSetting.always,
        TwitchChannelNotificationSetting.goLiveOnly,
        TwitchChannelNotificationSetting.never,
        TwitchChannelNotificationSetting.personalized,
      ]) {
        await client.setChannelNotificationSetting("123", setting: setting);
        expect(await client.fetchChannelNotificationSetting("creator"), setting);
      }
      expect(changes, [
        "setting:ALWAYS",
        "setting:LIVE_UP_ONLY",
        "setting:NEVER",
        "setting:PERSONALIZED",
      ]);
      reject = true;
      await expectLater(
        client.setChannelNotificationSetting(
          "123",
          setting: TwitchChannelNotificationSetting.always,
        ),
        throwsA(isA<TwitchApiException>()),
      );
      legacyDisabled = true;
      expect(
        await client.fetchChannelNotificationSetting("creator"),
        TwitchChannelNotificationSetting.never,
      );
      legacyDisabled = false;
      enabled = false;
      expect(
        await client.fetchChannelNotificationSetting("creator"),
        TwitchChannelNotificationSetting.never,
      );
    },
  );

  test(
    "live notifications use explicit Twitch bell choices across all pages and reject incomplete syncs",
    () async {
      var malformed = false;
      var repeated = false;
      var pages = 0;
      Map<String, Object?> edge(String id, String state, {bool enabled = true}) => {
        "cursor": "page-2",
        "node": {"id": id},
        "notificationSettings": malformed
            ? null
            : {"isEnabled": enabled, "followsSettingState": state},
      };
      final client = TwitchApiClient(
        clientId: "test",
        accessToken: "",
        gqlAccessToken: "web-token",
        httpClient: MockClient((request) async {
          pages++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers["authorization"], "OAuth web-token");
          expect(body["query"], contains("notificationEnrollmentFollows"));
          final variables = body["variables"] as Map<String, dynamic>;
          final first = variables["after"] == null;
          return http.Response(
            jsonEncode({
              "data": {
                "currentUser": {
                  "notificationEnrollmentFollows": {
                    "edges": first
                        ? [
                            edge("1", "ALWAYS"),
                            edge("2", "LIVE_UP_ONLY"),
                            edge("3", "PERSONALIZED"),
                            edge("4", "NEVER"),
                            edge("5", "ALWAYS", enabled: false),
                          ]
                        : [edge("1", "ALWAYS"), edge("6", "LIVE_UP_ONLY")],
                    "pageInfo": {"hasNextPage": first || repeated},
                  },
                },
              },
            }),
            200,
          );
        }),
      );
      expect(await client.fetchLiveNotificationChannelIds(), {"1", "2", "6"});
      expect(pages, 2);
      malformed = true;
      await expectLater(
        client.fetchLiveNotificationChannelIds(),
        throwsA(isA<TwitchApiException>()),
      );
      malformed = false;
      repeated = true;
      await expectLater(
        client.fetchLiveNotificationChannelIds(),
        throwsA(isA<TwitchApiException>()),
      );
      final anonymous = TwitchApiClient(
        clientId: "test",
        accessToken: "",
        httpClient: MockClient((_) async => fail("Must not request")),
      );
      await expectLater(
        anonymous.fetchLiveNotificationChannelIds(),
        throwsA(isA<TwitchApiException>()),
      );
    },
  );
}
