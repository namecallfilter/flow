import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("loads recorded offsets, identities, badges and UTF-16 emote fragments", () async {
    final client = _client(
      _page([
        _edge("later", 12),
        _edge(
          "earlier",
          10,
          message: {
            "fragments": [
              {"text": "😀 ", "emote": null},
              {
                "text": "Kappa",
                "emote": {"emoteID": "25"},
              },
              {"text": " hello", "emote": null},
            ],
            "userColor": "#123456",
            "userBadges": [
              {"setID": "moderator", "version": "1"},
            ],
          },
        ),
      ], hasNextPage: true),
      onRequest: (request) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body["query"], contains("query FlowVodChat"));
        expect(body["variables"], {"videoId": "123", "offsetSeconds": 10, "cursor": null});
        expect(body["query"], contains("emoteID"));
      },
    );
    final page = await client.fetchVodChatPage(" 123 ", offsetSeconds: 10);
    expect(page.hasNextPage, isTrue);
    expect(page.cursor, "next");
    expect(page.messages.map((message) => message.id), ["earlier", "later"]);
    final first = page.messages.first;
    expect(first.offsetSeconds, 10);
    expect(first.timestamp?.toUtc(), DateTime.utc(2026, 9, 10, 13, 30));
    expect(first.login, "viewer");
    expect(first.displayName, "Viewer");
    expect(first.text, "😀 Kappa hello");
    expect(first.color, "#123456");
    expect(first.badges, ["moderator/1"]);
    expect(first.emotes.single.start, 3);
    expect(first.emotes.single.end, 8);
    expect(first.emotes.single.imageUrl, contains("/25/"));
  });

  test(
    "enriches replay GIFs and replies in one request while retaining recorded presentation",
    () async {
      var detailRequests = 0;
      final client = _client(
        _page([
          _edge(
            "reply",
            10,
            message: {
              "fragments": [
                {"text": "😀 [Wave GIF by Friends]"},
              ],
              "userColor": "#123456",
              "userBadges": [
                {"setID": "subscriber", "version": "12"},
              ],
            },
          ),
          _edge("unavailable", 11),
        ]),
        replayDetails: {
          "m0": {
            "id": "reply",
            "content": {
              "text": "😀 [Wave GIF by Friends]",
              "fragments": [
                {"text": "😀 "},
                {
                  "text": "[Wave GIF by Friends]",
                  "content": {
                    "__typename": "GifContent",
                    "gifID": "wave",
                    "gifURL": "https://media.example/wave.gif?size=small&animated=true",
                  },
                },
              ],
            },
            "parentMessage": {
              "id": "parent",
              "sender": {"id": "99", "login": "friend", "displayName": "Friend"},
              "content": {
                "text": "Kappa",
                "fragments": [
                  {
                    "text": "Kappa",
                    "content": {"__typename": "Emote", "emoteID": "25"},
                  },
                ],
              },
            },
            "threadParentMessage": {
              "id": "root",
              "sender": {"login": "rootuser"},
            },
          },
          "m1": null,
        },
        onDetailsRequest: (request) {
          detailRequests++;
          final query = (jsonDecode(request.body) as Map<String, Object?>)["query"]! as String;
          expect(query, contains('m0: message(id: "reply")'));
          expect(query, contains('m1: message(id: "unavailable")'));
          expect(query, contains("GifContent"));
        },
      );
      final page = await client.fetchVodChatPage("123");
      final reply = page.messages.first;
      expect(detailRequests, 1);
      expect(reply.text, "😀 [Wave GIF by Friends]");
      expect(reply.displayName, "Viewer");
      expect(reply.color, "#123456");
      expect(reply.badges, ["subscriber/12"]);
      expect(reply.offsetSeconds, 10);
      expect(reply.gifs.single.start, 3);
      expect(reply.gifs.single.end, reply.text.length);
      expect(reply.gifs.single.url, "https://media.example/wave.gif?size=small&animated=true");
      expect(reply.parentMessageId, "parent");
      expect(reply.parentUserId, "99");
      expect(reply.parentDisplayName, "Friend");
      expect(reply.parentText, "Kappa");
      expect(reply.parentEmotes.single.id, "25");
      expect(reply.threadRootId, "root");
      expect(page.messages.last.text, "hello");
    },
  );

  test("missing, changed, or failing detail data leaves recorded chat usable", () async {
    for (final status in [200, 503]) {
      final client = _client(
        _page([_edge("original", 10)]),
        detailsStatus: status,
        replayDetails: {
          "m0": {
            "id": "original",
            "content": {"text": "different message"},
          },
        },
      );
      final page = await client.fetchVodChatPage("123");
      expect(page.messages.single.text, "hello");
      expect(page.messages.single.offsetSeconds, 10);
    }
  });

  test("recorded subscription and watch-streak notices keep their separate message body", () async {
    const mintyNotice =
        "minty11e subscribed at Tier 1. They've subscribed for 10 months, "
        "currently on a 9 month streak!";
    const primeNotice = "Viewer subscribed with Prime. They've subscribed for 1 month!";
    final client = _client(
      _page([
        _edge(
          "resub",
          10,
          login: "minty11e",
          displayName: "minty11e",
          message: {
            "fragments": [
              {"text": mintyNotice},
            ],
          },
        ),
        _edge(
          "prime",
          11,
          message: {
            "fragments": [
              {"text": "$primeNotice 😀 "},
              {
                "text": "Kappa",
                "emote": {"emoteID": "25"},
              },
            ],
          },
        ),
        _edge(
          "watch",
          12,
          message: {
            "fragments": [
              {"text": "Viewer watched 25 consecutive streams and sparked a watch streak! hello"},
            ],
          },
        ),
        _edge(
          "sub",
          13,
          message: {
            "fragments": [
              {"text": "Viewer subscribed at Tier 2. "},
            ],
          },
        ),
        _edge(
          "advance",
          14,
          message: {
            "fragments": [
              {"text": "Viewer subscribed at Tier 3 for 3 months in advance. hello"},
            ],
          },
        ),
      ]),
    );
    final messages = (await client.fetchVodChatPage("123")).messages;
    expect(messages[0].noticeType, "resub");
    expect(messages[0].noticeText, mintyNotice);
    expect(messages[0].text, isEmpty);
    expect(messages[0].displayName, "minty11e");
    expect(messages[1].noticeType, "resub");
    expect(messages[1].noticeText, primeNotice);
    expect(messages[1].isPrimeSubscription, isTrue);
    expect(messages[1].text, "😀 Kappa");
    expect(messages[1].emotes.single.start, 3);
    expect(messages[1].emotes.single.end, 8);
    expect(messages[2].noticeType, "watch-streak");
    expect(
      messages[2].noticeText,
      "Viewer watched 25 consecutive streams and sparked a watch streak!",
    );
    expect(messages[2].text, "hello");
    expect(messages[3].noticeType, "sub");
    expect(messages[3].text, isEmpty);
    expect(messages[4].noticeText, "Viewer subscribed at Tier 3 for 3 months in advance.");
    expect(messages[4].text, "hello");
  });

  test(
    "ordinary subscription discussion and bot announcements stay ordinary replay messages",
    () async {
      const texts = [
        "I'm subbed",
        "minty11e subscribed at Tier 1. They've subscribed for 10 months!",
        "@Viewer subscribed with Prime.",
        "Viewer subscribed to this channel",
        "Viewer subscribed at Tier 4.",
        "Viewer watched 25 streams today",
        "Bot says: Viewer subscribed at Tier 1.",
      ];
      final messages = (await _client(
        _page([
          for (var index = 0; index < texts.length; index++)
            _edge(
              "$index",
              index,
              message: {
                "fragments": [
                  {"text": texts[index]},
                ],
              },
            ),
        ]),
      ).fetchVodChatPage("123")).messages;
      expect(messages.map((message) => message.text), texts);
      expect(messages.every((message) => message.noticeType == null), isTrue);
      expect(messages.every((message) => message.noticeText == null), isTrue);
    },
  );

  test("replay retains the future deletion time without immediately dimming the message", () async {
    final page = await _client(
      _page([_edge("future-delete", 53, createdAt: "2026-09-09T18:55:01.524Z")]),
      replayDetails: {
        "m0": {
          "id": "future-delete",
          "deletedAt": "2026-09-09T19:21:27.899593615Z",
          "content": {
            "text": "hello",
            "fragments": [
              {"text": "hello"},
            ],
          },
        },
      },
    ).fetchVodChatPage("123");
    final message = page.messages.single;
    expect(message.text, "hello");
    expect(message.isDeleted, isFalse);
    expect(message.moderation, isNull);
    expect(message.moderatedAt?.toUtc(), DateTime.parse("2026-09-09T19:21:27.899593615Z"));
    expect(message.moderatedAt!.difference(message.timestamp!).inMicroseconds, 1586375593);
  });

  test("cursor pagination omits an offset and an empty terminal page is valid", () async {
    final client = _client(
      _page([]),
      onRequest: (request) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body["variables"], {"videoId": "123", "offsetSeconds": null, "cursor": "page-two"});
      },
    );
    final page = await client.fetchVodChatPage("123", cursor: " page-two ", offsetSeconds: 100);
    expect(page.messages, isEmpty);
    expect(page.hasNextPage, isFalse);
    expect(page.cursor, isNull);
  });

  test("negative seeks start at zero and deleted accounts keep recorded text", () async {
    final edge = _edge("deleted", 0);
    (edge["node"]! as Map<String, Object?>)["commenter"] = null;
    final client = _client(
      _page([edge]),
      onRequest: (request) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect((body["variables"]! as Map<String, Object?>)["offsetSeconds"], 0);
      },
    );
    final page = await client.fetchVodChatPage("123", offsetSeconds: -30);
    expect(page.messages.single.displayName, "Deleted user");
    expect(page.messages.single.text, "hello");
  });

  test("missing replay data or malformed messages report an error", () async {
    for (final video in <Object?>[
      null,
      {},
      {"comments": null},
      {
        "comments": {"edges": <Object?>[]},
      },
      {
        "comments": {
          "pageInfo": {"hasNextPage": false},
        },
      },
      _page([
        {"node": null},
      ]),
      _page([_edge("negative", -1)]),
      _page([
        _edge(
          "missing-text",
          0,
          message: {
            "fragments": [<String, Object?>{}],
          },
        ),
      ]),
    ]) {
      await expectLater(_client(video).fetchVodChatPage("123"), throwsA(isA<TwitchApiException>()));
    }
  });

  test("incomplete or repeated page cursors cannot loop forever", () async {
    for (final video in [
      _page([], hasNextPage: true),
      _page([_edge("one", 5)], hasNextPage: true),
    ]) {
      await expectLater(
        _client(video).fetchVodChatPage("123", cursor: "next"),
        throwsA(isA<TwitchApiException>()),
      );
    }
  });

  test("connection loss remains a retryable replay error", () async {
    final client = TwitchApiClient(
      clientId: "test",
      accessToken: "",
      httpClient: MockClient((_) async => http.Response("Service unavailable", 503)),
    );
    await expectLater(
      client.fetchVodChatPage("123"),
      throwsA(
        isA<TwitchApiException>().having((error) => error.isTransient, "isTransient", isTrue),
      ),
    );
  });
}

TwitchApiClient _client(
  Object? video, {
  void Function(http.Request request)? onRequest,
  void Function(http.Request request)? onDetailsRequest,
  Map<String, Object?> replayDetails = const {},
  int detailsStatus = 200,
}) => TwitchApiClient(
  clientId: "test",
  accessToken: "",
  httpClient: MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    if ((body["query"]! as String).contains("query FlowVodChatDetails")) {
      onDetailsRequest?.call(request);
      return http.Response(
        jsonEncode({"data": replayDetails}),
        detailsStatus,
        headers: {"content-type": "application/json"},
      );
    }
    onRequest?.call(request);
    return http.Response(
      jsonEncode({
        "data": {"video": video},
      }),
      200,
      headers: {"content-type": "application/json"},
    );
  }),
);

Map<String, Object?> _page(List<Map<String, Object?>> edges, {bool hasNextPage = false}) => {
  "comments": {
    "edges": edges,
    "pageInfo": {"hasNextPage": hasNextPage},
  },
};

Map<String, Object?> _edge(
  String id,
  int offset, {
  Map<String, Object?>? message,
  String login = "viewer",
  String displayName = "Viewer",
  String createdAt = "2026-09-10T13:30:00Z",
}) => {
  "cursor": "next",
  "node": <String, Object?>{
    "id": id,
    "createdAt": createdAt,
    "contentOffsetSeconds": offset,
    "commenter": {"login": login, "displayName": displayName},
    "message":
        message ??
        {
          "fragments": [
            {"text": "hello"},
          ],
        },
  },
};
