import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("channel point bonuses use fresh authenticated channel data", () async {
    var requests = 0;
    final client = _client((request) async {
      expect(request.headers["authorization"], "OAuth web-token");
      expect((jsonDecode(request.body) as Map)["variables"], {"login": "channel"});
      requests++;
      return _json({
        "data": {
          "user": {
            "id": "1",
            "login": "channel",
            "channel": {
              "id": "1",
              "self": {
                "communityPoints": {
                  "availableClaim": requests == 1 ? {"id": "claim"} : null,
                },
              },
            },
          },
        },
      });
    });
    expect(await client.fetchAvailableChannelPointsClaim(" Channel "), (
      channelId: "1",
      claimId: "claim",
    ));
    expect(await client.fetchAvailableChannelPointsClaim("channel"), isNull);
    expect(requests, 2);
    expect(
      await _client(
        (_) async => fail("No anonymous points query"),
        signedIn: false,
      ).fetchAvailableChannelPointsClaim("channel"),
      isNull,
    );
  });

  test("claiming channel points requires the exact acknowledged claim and amount", () async {
    var requests = 0;
    final client = _client((request) async {
      expect(request.headers["authorization"], "OAuth web-token");
      expect((jsonDecode(request.body) as Map)["variables"], {
        "channelID": "1",
        "claimID": "claim",
      });
      requests++;
      return _json({
        "data": {
          "claimCommunityPoints": {
            "claim": {
              "id": requests == 2 ? "different" : "claim",
              "pointsEarnedTotal": requests == 3 ? null : 60,
            },
            "error": requests == 4 ? {"code": "CLAIM_NOT_FOUND"} : null,
          },
        },
      });
    });
    expect(await client.claimChannelPoints(" 1 ", " claim "), 60);
    for (var attempt = 0; attempt < 3; attempt++) {
      await expectLater(
        client.claimChannelPoints("1", "claim"),
        throwsA(isA<TwitchApiException>()),
      );
    }
    await expectLater(
      client.claimChannelPoints("invalid", "claim"),
      throwsA(isA<TwitchApiException>()),
    );
    await expectLater(client.claimChannelPoints("1", ""), throwsA(isA<TwitchApiException>()));
    expect(requests, 4);
    await expectLater(
      _client(
        (_) async => fail("No anonymous claim"),
        signedIn: false,
      ).claimChannelPoints("1", "claim"),
      throwsA(isA<TwitchApiException>()),
    );
  });

  test("channel point lookup rejects a mismatched channel before offering a claim", () async {
    final client = _client(
      (_) async => _json({
        "data": {
          "user": {
            "id": "1",
            "login": "channel",
            "channel": {"id": "2"},
          },
        },
      }),
    );
    await expectLater(
      client.fetchAvailableChannelPointsClaim("channel"),
      throwsA(isA<TwitchApiException>()),
    );
  });

  test("loads channel rules, follow date, and privileged roles from the current account", () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      expect(request.headers["authorization"], "OAuth web-token");
      expect((jsonDecode(request.body) as Map<String, dynamic>)["variables"], {"login": "channel"});
      return _json({
        "data": {
          "user": {
            "id": "1",
            "login": "channel",
            "displayName": "Channel",
            "chatSettings": {
              "rules": ["Be kind", "", "No spoilers"],
            },
            "self": {
              "follower": {"followedAt": "2026-09-08T12:00:00Z"},
              "isModerator": true,
              "isVIP": false,
              "chatRestrictedReasons": requests == 1 ? ["SLOW_MODE", "FOLLOWERS_ONLY"] : <String>[],
              "lastRecentChatMessageAt": "2026-09-09T12:34:56Z",
            },
          },
        },
      });
    });
    final access = await client.fetchChatAccess(" Channel ");
    expect(access.channelId, "1");
    expect(access.channelDisplayName, "Channel");
    expect(access.rules, ["Be kind", "No spoilers"]);
    expect(access.isFollowing, isTrue);
    expect(access.followedAt?.toUtc(), DateTime.utc(2026, 9, 8, 12));
    expect(access.isModerator, isTrue);
    expect(access.isVip, isFalse);
    expect(access.isSlowModeRestricted, isTrue);
    expect(access.lastRecentChatMessageAt?.toUtc(), DateTime.utc(2026, 9, 9, 12, 34, 56));
    expect((await client.fetchChatAccess("channel")).isSlowModeRestricted, isFalse);
    expect(requests, 2);
  });

  test("anonymous rules are readable but missing signed-in status remains an error", () async {
    Future<http.Response> response(http.Request request) async => _json({
      "data": {
        "user": {
          "id": "1",
          "login": "channel",
          "displayName": "Channel",
          "chatSettings": {"rules": <String>[]},
          "self": null,
        },
      },
    });
    final anonymous = await _client(response, signedIn: false).fetchChatAccess("channel");
    expect(anonymous.rules, isEmpty);
    expect(anonymous.isFollowing, isFalse);
    expect(anonymous.isSlowModeRestricted, isNull);
    await expectLater(
      _client(response).fetchChatAccess("channel"),
      throwsA(isA<TwitchApiException>()),
    );
    await expectLater(
      _client(
        (_) async => _json({
          "data": {"user": null},
        }),
      ).fetchChatAccess("channel"),
      throwsA(isA<TwitchApiException>()),
    );
  });

  test("following requires an authenticated acknowledgement for the selected channel", () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      expect(request.headers["authorization"], "OAuth web-token");
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload["variables"], {"targetID": "1"});
      expect(payload["query"], contains("disableNotifications: false"));
      return _json({
        "data": {
          "followUser": {
            "follow": {
              "followedAt": "2026-09-08T12:00:00Z",
              "user": {"id": requests == 1 ? "1" : "wrong"},
            },
          },
        },
      });
    });
    expect((await client.followChannel("1")).toUtc(), DateTime.utc(2026, 9, 8, 12));
    await expectLater(client.followChannel("1"), throwsA(isA<TwitchApiException>()));
    await expectLater(client.followChannel("invalid"), throwsA(isA<TwitchApiException>()));
    expect(requests, 2);
    await expectLater(
      _client(
        (_) async => fail("Signed-out follow must not send a request"),
        signedIn: false,
      ).followChannel("1"),
      throwsA(isA<TwitchApiException>()),
    );
  });

  test("unfollowing requires an authenticated acknowledgement for the selected channel", () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      expect(request.headers["authorization"], "OAuth web-token");
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload["query"], contains("mutation FlowUnfollowUser"));
      expect(payload["variables"], {"targetID": "1"});
      return _json({
        "data": {
          "unfollowUser": requests == 3
              ? null
              : {
                  "follow": {
                    "user": {"id": requests == 1 ? "1" : "wrong"},
                  },
                },
        },
      });
    });
    await client.unfollowChannel(" 1 ");
    await expectLater(client.unfollowChannel("1"), throwsA(isA<TwitchApiException>()));
    await expectLater(client.unfollowChannel("1"), throwsA(isA<TwitchApiException>()));
    await expectLater(client.unfollowChannel("invalid"), throwsA(isA<TwitchApiException>()));
    expect(requests, 3);
    await expectLater(
      _client(
        (_) async => fail("Signed-out unfollow must not send a request"),
        signedIn: false,
      ).unfollowChannel("1"),
      throwsA(isA<TwitchApiException>()),
    );
  });

  test("unlocked emotes load every available set page for the signed-in channel context", () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      final variables = payload["variables"] as Map<String, dynamic>;
      expect(variables["channelID"], "1");
      expect(variables["cursor"], requests == 1 ? null : "next");
      return _json(_emotePage(requests == 1));
    });
    expect(await client.fetchUnlockedChatEmotes("1"), {"First": "first", "Second": "second"});
    expect(requests, 2);
    final anonymous = _client(
      (_) async => fail("No unlocked request when signed out"),
      signedIn: false,
    );
    expect(await anonymous.fetchUnlockedChatEmotes("1"), isEmpty);
  });

  test("unlocked emote pagination rejects repeated cursors and unavailable account data", () async {
    await expectLater(
      _client((_) async => _json(_emotePage(true))).fetchUnlockedChatEmotes("1"),
      throwsA(isA<TwitchApiException>()),
    );
    await expectLater(
      _client(
        (_) async => _json({
          "data": {
            "channel": {"id": "1", "self": null},
          },
        }),
      ).fetchUnlockedChatEmotes("1"),
      throwsA(isA<TwitchApiException>()),
    );
  });
}

TwitchApiClient _client(
  Future<http.Response> Function(http.Request) handler, {
  bool signedIn = true,
}) => TwitchApiClient(
  clientId: "client",
  accessToken: "",
  gqlAccessToken: signedIn ? "web-token" : null,
  httpClient: MockClient(handler),
);

Map<String, Object?> _emotePage(bool first) => {
  "data": {
    "channel": {
      "id": "1",
      "self": {
        "availableEmoteSetsPaginated": {
          "edges": [
            {
              "cursor": "next",
              "node": {
                "id": first ? "one" : "two",
                "emotes": [
                  {"id": first ? "first" : "second", "token": first ? "First" : "Second"},
                ],
              },
            },
          ],
          "pageInfo": {"hasNextPage": first},
        },
      },
    },
  },
};

http.Response _json(Object? value) =>
    http.Response(jsonEncode(value), 200, headers: {"content-type": "application/json"});
