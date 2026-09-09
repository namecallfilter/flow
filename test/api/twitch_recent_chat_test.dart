import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("loads authenticated recent chat with original rich message metadata", () async {
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "native-token",
      gqlAccessToken: "website-token",
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body["variables"], {"channelID": "1"});
        expect(request.headers["authorization"], "OAuth website-token");
        expect(body["query"], contains("senderBadges(channelID:"));
        return _response({
          "id": "1",
          "recentChatMessages": [
            {
              "id": "old",
              "sentAt": "2026-09-08T12:00:00Z",
              "deletedAt": "2026-09-08T12:00:01Z",
              "sender": {"id": "77", "login": "alice", "displayName": "Alice"},
              "senderChatColor": "#123456",
              "senderBadges": [
                {"setID": "moderator", "version": "1"},
                {"setID": "subscriber", "version": "12"},
              ],
              "content": {
                "text": "😀 Kappa",
                "fragments": [
                  {"text": "😀 "},
                  {
                    "text": "Kappa",
                    "content": {"__typename": "Emote", "emoteID": "25"},
                  },
                ],
              },
              "parentMessage": {
                "id": "parent",
                "content": {
                  "text": "😀 Kappa",
                  "fragments": [
                    {"text": "😀 "},
                    {
                      "text": "Kappa",
                      "content": {"__typename": "Emote", "emoteID": "25"},
                    },
                  ],
                },
                "sender": {"id": "88", "login": "bob", "displayName": "Bob"},
              },
              "threadParentMessage": {
                "id": "root",
                "sender": {"login": "carol"},
              },
            },
          ],
        });
      }),
    );

    final message = (await client.fetchRecentChat(" 1 ")).single;
    expect(message.id, "old");
    expect(message.timestamp?.toUtc(), DateTime.utc(2026, 9, 8, 12));
    expect(message.moderatedAt?.toUtc(), DateTime.utc(2026, 9, 8, 12, 0, 1));
    expect(message.isDeleted, isTrue);
    expect(message.moderation, TwitchChatModeration.deleted);
    expect(message.userId, "77");
    expect(message.login, "alice");
    expect(message.displayName, "Alice");
    expect(message.badges, ["moderator/1", "subscriber/12"]);
    expect(message.color, "#123456");
    expect(message.text, "😀 Kappa");
    expect(message.emotes.single.id, "25");
    expect(message.emotes.single.start, 3);
    expect(message.emotes.single.end, 8);
    expect(message.parentMessageId, "parent");
    expect(message.parentUserId, "88");
    expect(message.parentLogin, "bob");
    expect(message.parentDisplayName, "Bob");
    expect(message.parentText, "😀 Kappa");
    expect(message.parentEmotes.single.id, "25");
    expect(message.parentEmotes.single.start, 3);
    expect(message.parentEmotes.single.end, 8);
    expect(message.threadRootId, "root");
    expect(message.threadRootLogin, "carol");
  });

  test("signed-out history is unavailable without making a request", () async {
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "native-only",
      httpClient: MockClient((_) async => fail("Recent history requires website authentication")),
    );
    expect(await client.fetchRecentChat("1"), isEmpty);
  });

  test("rejects wrong-channel or unavailable history and accepts an empty snapshot", () async {
    for (final channel in [
      null,
      {"id": "2", "recentChatMessages": <Object>[]},
      {"id": "1"},
    ]) {
      final client = TwitchApiClient(
        clientId: "client",
        accessToken: "",
        gqlAccessToken: "website-token",
        httpClient: MockClient((_) async => _response(channel)),
      );
      await expectLater(client.fetchRecentChat("1"), throwsA(isA<TwitchApiException>()));
    }
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "",
      gqlAccessToken: "website-token",
      httpClient: MockClient((_) async => _response({"id": "1", "recentChatMessages": <Object>[]})),
    );
    expect(await client.fetchRecentChat("1"), isEmpty);
  });
}

http.Response _response(Object? channel) => http.Response(
  jsonEncode({
    "data": {"channel": channel},
  }),
  200,
  headers: {"content-type": "application/json"},
);
