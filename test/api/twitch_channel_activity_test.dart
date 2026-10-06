import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_raids.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("raid messages preserve destinations and distinguish go from cancellation", () {
    final event = <String, Object?>{
      "type": "raid_update_v2",
      "raid": {
        "id": "raid-1",
        "source_id": "1",
        "target_id": "2",
        "target_login": "destination",
        "target_display_name": "Destination",
        "viewer_count": 11858,
        "remaining_duration_seconds": 30,
        "transition_jitter_seconds": 5,
      },
    };
    final raid = TwitchRaid.fromPubSub(event)!;
    expect(raid.targetLogin, "destination");
    expect(raid.viewerCount, 11858);
    expect(raid.remainingDurationSeconds, 30);
    expect(raid.transitionJitterSeconds, 5);
    expect(raid.isEnded, isFalse);
    expect(TwitchRaid.fromPubSub({...event, "type": "raid_go_v2"})!.isGoing, isTrue);
    final cancelled = TwitchRaid.fromPubSub({...event, "type": "raid_cancel_v2"})!;
    expect(cancelled.isEnded, isTrue);
    expect(cancelled.isGoing, isFalse);
    expect(TwitchRaid.fromPubSub({...event, "type": "unknown"}), isNull);
    expect(TwitchRaid.fromPubSub({"type": "raid_update_v2", "raid": <String, Object?>{}}), isNull);
    final payload = event["raid"]! as Map<String, Object?>;
    for (final field in ["id", "source_id", "target_id", "target_login"]) {
      expect(
        TwitchRaid.fromPubSub({
          ...event,
          "raid": {...payload, field: 123},
        }),
        isNull,
      );
    }
    final malformedMetadata = TwitchRaid.fromPubSub({
      ...event,
      "raid": {
        ...payload,
        "target_display_name": false,
        "target_profile_image": <Object?>[],
        "viewer_count": "unknown",
        "remaining_duration_seconds": -1,
        "transition_jitter_seconds": double.nan,
      },
    })!;
    expect(malformedMetadata.targetDisplayName, "destination");
    expect(malformedMetadata.targetProfileImageUrl, isNull);
    expect(malformedMetadata.viewerCount, 0);
    expect(malformedMetadata.remainingDurationSeconds, 0);
    expect(malformedMetadata.transitionJitterSeconds, 0);
  });

  test("only active partner celebrations offer the partner anniversary message", () async {
    var type = "PartnerAnniversaryStreamEventCelebration";
    final client = TwitchApiClient(
      clientId: "test",
      accessToken: "",
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body["query"], contains("activeStreamEventCelebration"));
        expect(body["variables"], {"channelID": "1"});
        return http.Response(
          jsonEncode({
            "data": {
              "channel": {
                "id": "1",
                "activeStreamEventCelebration": {"id": "celebration-1", "__typename": type},
              },
            },
          }),
          200,
        );
      }),
    );
    expect((await client.fetchPartnerAnniversary("1"))!.id, "celebration-1");
    type = "AffiliateAnniversaryStreamEventCelebration";
    expect(await client.fetchPartnerAnniversary("1"), isNull);
  });

  test("raid participation requires authentication and a matching acknowledgement", () async {
    var joined = true;
    String? returnedId = "raid-1";
    final client = TwitchApiClient(
      clientId: "test",
      accessToken: "",
      gqlAccessToken: "web-token",
      httpClient: MockClient((request) async {
        expect(request.headers["authorization"], "OAuth web-token");
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body["query"], contains(joined ? "JoinRaidInput!" : "LeaveRaidInput!"));
        expect(body["variables"], {
          "input": {"raidID": "raid-1"},
        });
        return http.Response(
          jsonEncode({
            "data": {
              joined ? "joinRaid" : "leaveRaid": {"raidID": returnedId},
            },
          }),
          200,
        );
      }),
    );
    await client.setRaidParticipation(raidId: "raid-1", joined: true);
    joined = false;
    await client.setRaidParticipation(raidId: "raid-1", joined: false);
    returnedId = "another-raid";
    await expectLater(
      client.setRaidParticipation(raidId: "raid-1", joined: false),
      throwsA(isA<TwitchApiException>()),
    );
    final anonymous = TwitchApiClient(
      clientId: "test",
      accessToken: "",
      httpClient: MockClient((_) async => fail("Must not request")),
    );
    await expectLater(
      anonymous.setRaidParticipation(raidId: "raid-1", joined: true),
      throwsA(isA<TwitchApiException>()),
    );
  });
}
