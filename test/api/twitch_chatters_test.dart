import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test(
    "loads every returned chatter group using website auth and recovers integrity checks",
    () async {
      var requests = 0;
      var integrityLoads = 0;
      final client = TwitchApiClient(
        clientId: "client",
        accessToken: "native-token",
        gqlAccessToken: "website-token",
        integrityContextLoader: (authorization) async {
          expect(authorization, "OAuth website-token");
          integrityLoads++;
          return {
            "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
            "X-Device-ID": "browser-device",
            "Client-Session-Id": "page-session",
            "Client-Version": "page-build",
            "Client-Integrity": "issued-grant",
          };
        },
        httpClient: MockClient((request) async {
          requests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body["variables"], {"login": "creator"});
          expect(body["query"], contains("chatbots"));
          expect(request.headers["authorization"], "OAuth website-token");
          if (requests == 1) {
            return _json({
              "errors": [
                {"message": "failed integrity check"},
              ],
            });
          }
          expect(request.headers["Client-Integrity"], "issued-grant");
          return _roster({
            "count": 5000,
            "broadcasters": [
              {"login": "creator"},
            ],
            "moderators": [
              {"login": "moderator"},
            ],
            "vips": [
              {"login": "vip"},
            ],
            "staff": [
              {"login": "staff"},
            ],
            "chatbots": [
              {"login": "robot"},
            ],
            "viewers": [
              for (var index = 0; index < 1200; index++) {"login": "viewer$index"},
              {"login": "ROBOT"},
              {"login": ""},
            ],
          });
        }),
      );

      final chatters = await client.fetchChatters(" Creator ");
      expect(requests, 2);
      expect(integrityLoads, 1);
      expect(chatters.count, 5000);
      expect(chatters.groups["viewers"], hasLength(1201));
      expect(chatters.groups["chatbots"], ["robot"]);
      expect(chatters.groups["staff"], ["staff"]);
      expect(chatters.listedCount, 1205);
      expect(chatters.isPartial, isTrue);
    },
  );

  test("signed-out roster remains anonymous and counts unique returned names", () async {
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "native-only",
      httpClient: MockClient((request) async {
        expect(request.headers["authorization"], isNull);
        return _roster({
          "count": 3,
          "moderators": [
            {"login": "alice"},
          ],
          "chatbots": [
            {"login": "robot"},
          ],
          "viewers": [
            {"login": "ALICE"},
            {"login": "bob"},
          ],
        });
      }),
    );
    final chatters = await client.fetchChatters("creator");
    expect(chatters.listedCount, 3);
    expect(chatters.isPartial, isFalse);
  });

  test("unavailable roster stays an error rather than an empty complete list", () async {
    for (final chatters in [null, <String, Object?>{}]) {
      final client = TwitchApiClient(
        clientId: "client",
        accessToken: "",
        gqlAccessToken: "website-token",
        httpClient: MockClient((_) async => _roster(chatters)),
      );
      await expectLater(client.fetchChatters("creator"), throwsA(isA<TwitchApiException>()));
    }
  });
}

http.Response _roster(Object? chatters) => _json({
  "data": {
    "user": {
      "channel": {"chatters": chatters},
    },
  },
});

http.Response _json(Object? value) => http.Response(
  jsonEncode(value),
  200,
  headers: {"content-type": "application/json"},
);
