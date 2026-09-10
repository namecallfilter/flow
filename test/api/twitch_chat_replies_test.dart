import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test(
    "loads the original message and server replies with rich content and parent context",
    () async {
      const label = "[Pink Ladies Yes GIF by Paramount+]";
      const gifUrl =
          "https://media4.giphy.com/media/example/giphy.gif?cid=example&rid=giphy.gif&ct=g";
      final client = TwitchApiClient(
        clientId: "client",
        accessToken: "",
        httpClient: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload["variables"], {"messageID": "root"});
          expect(payload["query"], contains("... on GifContent"));
          expect(request.headers["authorization"], isNull);
          return http.Response(
            jsonEncode({
              "data": {
                "message": {
                  "id": "root",
                  "sentAt": "2026-09-07T20:00:00Z",
                  "sender": {"id": "1", "login": "alice", "displayName": "Alice"},
                  "senderChatColor": "#123456",
                  "senderBadges": [
                    {"setID": "moderator", "version": "1"},
                  ],
                  "content": {
                    "text": "😀 Kappa $label",
                    "fragments": [
                      {"text": "😀 ", "content": null},
                      {
                        "text": "Kappa",
                        "content": {"__typename": "Emote", "emoteID": "25"},
                      },
                      {"text": " "},
                      {
                        "text": label,
                        "content": {
                          "__typename": "GifContent",
                          "gifID": "example",
                          "gifURL": gifUrl,
                        },
                      },
                    ],
                  },
                  "replies": {
                    "totalCount": 1,
                    "nodes": [
                      {
                        "id": "reply",
                        "sentAt": "2026-09-07T20:00:01Z",
                        "deletedAt": "2026-09-07T20:00:02Z",
                        "sender": {"id": "2", "login": "bob", "displayName": "Bob"},
                        "content": {"text": "@alice yes", "fragments": <Object>[]},
                        "parentMessage": {
                          "id": "root",
                          "content": {
                            "text": "😀 Kappa $label",
                            "fragments": [
                              {"text": "😀 "},
                              {
                                "text": "Kappa",
                                "content": {"__typename": "Emote", "emoteID": "25"},
                              },
                              {"text": " "},
                              {
                                "text": label,
                                "content": {
                                  "__typename": "GifContent",
                                  "gifID": "example",
                                  "gifURL": gifUrl,
                                },
                              },
                            ],
                          },
                          "sender": {"id": "1", "login": "alice", "displayName": "Alice"},
                        },
                      },
                    ],
                  },
                },
              },
            }),
            200,
            headers: {"content-type": "application/json"},
          );
        }),
      );

      final messages = await client.fetchChatReplyThread("root");
      expect(messages.map((message) => message.id), ["root", "reply"]);
      expect(messages.first.color, "#123456");
      expect(messages.first.badges, ["moderator/1"]);
      expect(messages.first.emotes.single.start, 3);
      expect(messages.first.emotes.single.end, 8);
      expect(messages.first.gifs.single.url, gifUrl);
      expect(messages.first.gifs.single.start, 9);
      expect(messages.first.timestamp?.toUtc(), DateTime.utc(2026, 9, 7, 20));
      final reply = messages.last;
      expect(reply.threadRootId, "root");
      expect(reply.threadRootLogin, "alice");
      expect(reply.parentMessageId, "root");
      expect(reply.parentUserId, "1");
      expect(reply.parentText, "😀 Kappa $label");
      expect(reply.parentEmotes.single.id, "25");
      expect(reply.parentEmotes.single.start, 3);
      expect(reply.parentEmotes.single.end, 8);
      expect(reply.parentGifs.single.url, gifUrl);
      expect(reply.parentGifs.single.start, 9);
      expect(
        reply.parentText!.substring(reply.parentGifs.single.start, reply.parentGifs.single.end),
        label,
      );
      expect(reply.isDeleted, isTrue);
    },
  );

  test("a nested reply resolves the thread root and loads older sibling replies", () async {
    final requested = <String>[];
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "",
      httpClient: MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final id = (payload["variables"] as Map<String, dynamic>)["messageID"] as String;
        requested.add(id);
        return http.Response(
          jsonEncode({
            "data": {
              "message": {
                "id": id,
                "sender": {"id": "1", "login": "alice", "displayName": "Alice"},
                if (id == "nested") ...{
                  "parentMessage": {"id": "parent"},
                  "threadParentMessage": {"id": "root"},
                },
                "replies": {
                  "totalCount": id == "root" ? 3 : 0,
                  "nodes": [
                    if (id == "root")
                      for (final replyId in ["older-sibling", "parent", "nested"])
                        {
                          "id": replyId,
                          "parentMessage": {"id": replyId == "nested" ? "parent" : "root"},
                          "sender": {"id": "2", "login": "bob", "displayName": "Bob"},
                          "content": {"text": replyId},
                        },
                  ],
                },
              },
            },
          }),
          200,
          headers: {"content-type": "application/json"},
        );
      }),
    );
    final messages = await client.fetchChatReplyThread("nested");
    expect(requested, ["nested", "root"]);
    expect(messages.map((message) => message.id), ["root", "older-sibling", "parent", "nested"]);
    expect(messages.skip(1).every((message) => message.threadRootId == "root"), isTrue);
    expect(messages.last.parentMessageId, "parent");
  });

  test("walks direct parents when thread root metadata is absent and rejects cycles", () async {
    final requested = <String>[];
    final parents = {
      "nested": "parent",
      "parent": "root",
      "cycle-a": "cycle-b",
      "cycle-b": "cycle-a",
    };
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "",
      httpClient: MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final id = (payload["variables"] as Map<String, dynamic>)["messageID"] as String;
        requested.add(id);
        return http.Response(
          jsonEncode({
            "data": {
              "message": {
                "id": id,
                if (parents[id] != null) "parentMessage": {"id": parents[id]},
                "replies": {"totalCount": 0, "nodes": <Object>[]},
              },
            },
          }),
          200,
          headers: {"content-type": "application/json"},
        );
      }),
    );
    expect((await client.fetchChatReplyThread("nested")).single.id, "root");
    expect(requested, ["nested", "parent", "root"]);
    requested.clear();
    await expectLater(client.fetchChatReplyThread("cycle-a"), throwsA(isA<TwitchApiException>()));
    expect(requested, ["cycle-a", "cycle-b"]);
  });

  test("unavailable threads return empty history and request failures remain errors", () async {
    var requests = 0;
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "",
      httpClient: MockClient((_) async {
        requests++;
        return http.Response(
          requests == 1 ? '{"data":{"message":null}}' : '{"errors":[{"message":"Unavailable"}]}',
          200,
          headers: {"content-type": "application/json"},
        );
      }),
    );
    expect(await client.fetchChatReplyThread(""), isEmpty);
    expect(requests, 0);
    expect(await client.fetchChatReplyThread("missing"), isEmpty);
    await expectLater(client.fetchChatReplyThread("missing"), throwsA(isA<TwitchApiException>()));
  });
}
