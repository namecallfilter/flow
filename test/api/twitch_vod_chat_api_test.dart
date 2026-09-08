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
    expect(first.login, "viewer");
    expect(first.displayName, "Viewer");
    expect(first.text, "😀 Kappa hello");
    expect(first.color, "#123456");
    expect(first.badges, ["moderator/1"]);
    expect(first.emotes.single.start, 3);
    expect(first.emotes.single.end, 8);
    expect(first.emotes.single.imageUrl, contains("/25/"));
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

TwitchApiClient _client(Object? video, {void Function(http.Request request)? onRequest}) =>
    TwitchApiClient(
      clientId: "test",
      accessToken: "",
      httpClient: MockClient((request) async {
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

Map<String, Object?> _edge(String id, int offset, {Map<String, Object?>? message}) => {
  "cursor": "next",
  "node": <String, Object?>{
    "id": id,
    "contentOffsetSeconds": offset,
    "commenter": {"login": "viewer", "displayName": "Viewer"},
    "message":
        message ??
        {
          "fragments": [
            {"text": "hello"},
          ],
        },
  },
};
