import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("loads provider globals and channel aliases, native badges and emote names", () async {
    final requests = <Uri>[];
    final assets = _assets(
      httpClient: MockClient((request) async {
        requests.add(request.url);
        expect(request.headers["authorization"], isNull);
        return _response(request.url);
      }),
    );
    addTearDown(assets.dispose);
    await assets.refresh();
    expect(requests.length, 8);
    expect(assets.isLoading, isFalse);
    expect(assets.errors, isEmpty);
    expect(assets.badgeUrls, {"subscriber/1": "https://example.com/badge.png"});
    expect(assets.badgesById["subscriber/1"]!.title, "Subscriber");
    expect(assets.badgesById["subscriber/1"]!.provider, ChatEmoteProvider.twitch);
    expect(assets.emotesByName["Kappa"]!.provider, ChatEmoteProvider.twitch);
    expect(assets.emotesByName["Same"]!.id, "seven-channel");
    expect(assets.emotesByName["Alias"]!.id, "seven-alias");
    expect(assets.emotesByName["Alias"]!.zeroWidth, isTrue);
    expect(assets.emotesByName["Alias"]!.author, "Emote Artist");
    expect(assets.emotesByName["Alias"]!.url, "https://cdn.7tv.app/emote/seven-alias/2x.webp");
    expect(assets.emotesByName["BTTVShared"]!.provider, ChatEmoteProvider.bttv);
    expect(assets.emotesByName["FFZChannel"]!.url, "https://cdn.frankerfacez.com/emote/3/2");
    expect(assets.emotesByName["FFZPrivate"], isNull);
    expect(assets.userBadgesByLogin["viewer"]!.map((badge) => badge.provider).toSet(), {
      ChatEmoteProvider.ffz,
      ChatEmoteProvider.bttv,
    });
    expect(assets.userBadgesByLogin["other"]!.single.color, "#123456");
    expect(assets.userBadgesByLogin["viewer"]!.any((badge) => badge.url.endsWith(".svg")), isTrue);
    expect(() => assets.emotesByName.clear(), throwsUnsupportedError);
    expect(() => assets.badgesById.clear(), throwsUnsupportedError);
  });

  test(
    "one provider failing leaves other emotes readable and missing channel sets are normal",
    () async {
      final assets = _assets(
        httpClient: MockClient((request) async {
          if (request.url.host == "api.frankerfacez.com" && request.url.path.endsWith("global")) {
            return http.Response("unavailable", 503);
          }
          if (request.url.host == "api.betterttv.net" && request.url.path.contains("users")) {
            return http.Response("not found", 404);
          }
          return _response(request.url);
        }),
      );
      addTearDown(assets.dispose);
      await assets.refresh();
      expect(assets.errors.length, 1);
      expect(assets.errors.single, contains("FFZ global"));
      expect(assets.emotesByName["Alias"], isNotNull);
      expect(assets.emotesByName["BTTVGlobal"], isNotNull);
      expect(assets.emotesByName["BTTVShared"], isNull);
    },
  );

  test("resolves missing broadcaster ID and reuses bounded channel/global caches", () async {
    var apiCalls = 0;
    var httpCalls = 0;
    final client = _Client(
      onLoad: () async {
        apiCalls++;
        return _native;
      },
    );
    final httpClient = MockClient((request) async {
      httpCalls++;
      if (request.url.path.contains("/users/twitch/")) {
        expect(request.url.path.endsWith("/123"), isTrue);
      }
      return _response(request.url);
    });
    final first = _assets(channelLogin: "cache_channel", client: client, httpClient: httpClient);
    final second = _assets(channelLogin: "cache_channel", client: client, httpClient: httpClient);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.refresh();
    await second.refresh(force: false);
    expect(apiCalls, 1);
    expect(httpCalls, 8);
    expect(second.emotesByName["Alias"], isNotNull);
  });

  test("late provider response from an older refresh cannot overwrite refreshed assets", () async {
    final old = Completer<http.Response>();
    var calls = 0;
    final assets = _assets(
      httpClient: MockClient((request) async {
        if (request.url.host == "7tv.io" && request.url.path.endsWith("global")) {
          calls++;
          if (calls == 1) {
            return old.future;
          }
          return _json({
            "emotes": [_seven("Fresh", "fresh")],
          });
        }
        return _response(request.url);
      }),
    );
    addTearDown(assets.dispose);
    final previous = assets.refresh();
    await _waitFor(() => calls == 1);
    await assets.refresh();
    await previous;
    old.complete(
      _json({
        "emotes": [_seven("Stale", "stale")],
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(assets.emotesByName["Fresh"], isNotNull);
    expect(assets.emotesByName["Stale"], isNull);
  });

  testWidgets("disposing pending asset loads cancels deadlines and prevents updates", (
    tester,
  ) async {
    final pending = Completer<TwitchNativeChatAssets>();
    final assets = _assets(
      client: _Client(onLoad: () => pending.future),
      httpClient: MockClient((_) async => http.Response("missing", 404)),
    );
    var notifications = 0;
    assets.addListener(() => notifications++);
    final refresh = assets.refresh();
    await tester.pump();
    assets.dispose();
    final before = notifications;
    pending.complete(_native);
    await tester.pump(const Duration(seconds: 16));
    await refresh;
    expect(notifications, before);
    expect(assets.badgeUrls, isEmpty);
  });

  testWidgets("7TV badges batch sender IDs and cache both badge and empty results", (tester) async {
    final batches = <int>[];
    final requests = <http.Request>[];
    final assets = _assets(
      httpClient: MockClient((request) async {
        requests.add(request);
        final queries = jsonDecode(request.body) as List<Object?>;
        batches.add(queries.length);
        return _json([
          for (var index = 0; index < queries.length; index++) _sevenBadgeResult(index == 0),
        ]);
      }),
    );
    final messages = List.generate(
      32,
      (index) => TwitchChatMessage(
        id: "$index",
        login: "user$index",
        displayName: "User$index",
        text: "hello",
        userId: "${99000000 + index}",
      ),
    );
    assets.observeMessages([...messages, ...messages]);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(requests.single.method, "POST");
    expect(requests.single.url.toString(), "https://7tv.io/v4/gql");
    expect(requests.single.headers["authorization"], isNull);
    expect(batches, [30]);
    expect(assets.userBadgesByLogin["user0"]!.single.provider, ChatEmoteProvider.sevenTv);
    expect(assets.userBadgesByLogin["user1"], isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(batches, [30, 2]);
    assets.observeMessages(messages);
    await tester.pump(const Duration(seconds: 3));
    expect(batches, [30, 2]);
    assets.dispose();
  });

  testWidgets("disposing pending 7TV lookups cancels deadlines and ignores the response", (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final assets = _assets(httpClient: MockClient((_) => response.future));
    assets.observeMessages(const [
      TwitchChatMessage(
        id: "1",
        login: "late",
        displayName: "Late",
        text: "hi",
        userId: "99000100",
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    assets.dispose();
    response.complete(_json([_sevenBadgeResult(true)]));
    await tester.pump(const Duration(seconds: 20));
    expect(assets.userBadgesByLogin, isEmpty);
  });

  testWidgets("7TV failures retry with a delay and clear the error after recovery", (tester) async {
    var calls = 0;
    final assets = _assets(
      httpClient: MockClient((_) async {
        calls++;
        return calls == 1 ? http.Response("unavailable", 503) : _json([_sevenBadgeResult(false)]);
      }),
    );
    assets.observeMessages(const [
      TwitchChatMessage(
        id: "1",
        login: "retry",
        displayName: "Retry",
        text: "hi",
        userId: "99000200",
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(calls, 1);
    expect(assets.errors, ["7TV badges could not be loaded."]);
    await tester.pump(const Duration(seconds: 29));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 2);
    expect(assets.errors, isEmpty);
    assets.dispose();
  });

  test("Twitch query maps channel badge overrides, native emotes and real chatter roles", () async {
    final client = TwitchApiClient(
      clientId: "test",
      accessToken: "",
      httpClient: MockClient((request) async {
        final query = (jsonDecode(request.body) as Map<String, Object?>)["query"]! as String;
        if (query.contains("FlowChatters")) {
          return _json({
            "data": {
              "user": {
                "channel": {
                  "chatters": {
                    "count": 800,
                    "broadcasters": [
                      {"login": "creator"},
                    ],
                    "moderators": [
                      {"login": "moderator"},
                    ],
                    "vips": <Object?>[],
                    "staff": <Object?>[],
                    "viewers": [
                      {"login": "viewer"},
                    ],
                  },
                },
              },
            },
          });
        }
        return _json({
          "data": {
            "badges": [
              {
                "setID": "subscriber",
                "version": "1",
                "title": "Subscriber",
                "imageURL": "https://example.com/global.png",
              },
            ],
            "emoteSet": {
              "emotes": [
                {"id": "25", "token": "Kappa"},
              ],
            },
            "user": {
              "id": "123",
              "broadcastBadges": [
                {
                  "setID": "subscriber",
                  "version": "1",
                  "title": "One-month subscriber",
                  "imageURL": "https://example.com/channel.png",
                },
              ],
              "subscriptionProducts": [
                {
                  "emotes": [
                    {"id": "sub", "token": "SubEmote"},
                  ],
                },
              ],
              "channel": {
                "localEmoteSets": [
                  {
                    "emotes": [
                      {"id": "local", "token": "LocalEmote"},
                    ],
                  },
                ],
              },
            },
          },
        });
      }),
    );
    final data = await client.fetchChatAssets("creator");
    expect(data.channelId, "123");
    expect(data.badgeUrls["subscriber/1"], "https://example.com/channel.png");
    expect(data.badgeTitles["subscriber/1"], "One-month subscriber");
    expect(data.emoteIdsByName, {"Kappa": "25", "SubEmote": "sub", "LocalEmote": "local"});
    final chatters = await client.fetchChatters("creator");
    expect(chatters.count, 800);
    expect(chatters.groups["broadcasters"], ["creator"]);
    expect(chatters.groups["moderators"], ["moderator"]);
    expect(chatters.groups["viewers"], ["viewer"]);
  });
}

const _native = TwitchNativeChatAssets(
  channelId: "123",
  badgeUrls: {"subscriber/1": "https://example.com/badge.png", "unsafe/1": "file:///secret"},
  badgeTitles: {"subscriber/1": "Subscriber"},
  emoteIdsByName: {"Kappa": "25", "Same": "native-same"},
);

class _Client extends TwitchApiClient {
  _Client({this.onLoad}) : super(clientId: "test", accessToken: "");
  final Future<TwitchNativeChatAssets> Function()? onLoad;
  @override
  Future<TwitchNativeChatAssets> fetchChatAssets(String login) async =>
      onLoad == null ? _native : onLoad!();
}

TwitchChatAssets _assets({
  String channelLogin = "creator",
  _Client? client,
  required http.Client httpClient,
}) => TwitchChatAssets(
  clientLoader: () async => client ?? _Client(),
  channelLogin: channelLogin,
  httpClient: httpClient,
  autoLoad: false,
);

http.Response _response(Uri uri) {
  if (uri.host == "api.betterttv.net" && uri.path.endsWith("/badges")) {
    return _json([
      {
        "name": "Viewer",
        "badge": {
          "type": 1,
          "description": "BTTV Developer",
          "svg": "https://cdn.betterttv.net/badges/developer.svg",
        },
      },
    ]);
  }
  if (uri.host == "api.frankerfacez.com" && uri.path.endsWith("/badges")) {
    return _json({
      "badges": [
        {
          "id": 3,
          "title": "FFZ Supporter",
          "color": "#123456",
          "urls": {"2": "https://cdn.frankerfacez.com/badge/3/2"},
        },
      ],
      "users": {
        "3": ["Viewer", "other"],
      },
    });
  }
  if (uri.host == "7tv.io") {
    if (uri.path.contains("users")) {
      return _json({
        "emote_set": {
          "emotes": [_seven("Same", "seven-channel"), _seven("Alias", "seven-alias", flags: 1)],
        },
      });
    }
    return _json({
      "emotes": [_seven("Same", "seven-global")],
    });
  }
  if (uri.host == "api.betterttv.net") {
    if (uri.path.contains("users")) {
      return _json({
        "channelEmotes": [
          {"code": "Same", "id": "bttv-channel"},
        ],
        "sharedEmotes": [
          {"code": "BTTVShared", "id": "bttv-shared"},
        ],
      });
    }
    return _json([
      {"code": "BTTVGlobal", "id": "bttv-global"},
    ]);
  }
  if (uri.path.endsWith("global")) {
    return _json({
      "default_sets": [1],
      "sets": {
        "1": {
          "emoticons": [_ffz("FFZGlobal", 1)],
        },
        "2": {
          "emoticons": [_ffz("FFZPrivate", 2)],
        },
      },
    });
  }
  return _json({
    "sets": {
      "3": {
        "emoticons": [_ffz("FFZChannel", 3)],
      },
    },
  });
}

Map<String, Object?> _seven(String name, String id, {int flags = 0}) => {
  "id": id,
  "name": name,
  "flags": flags,
  "data": {
    "owner": {"username": "emote_artist", "display_name": "Emote Artist"},
    "host": {
      "url": "//cdn.7tv.app/emote/$id",
      "files": [
        {"name": "1x.webp"},
        {"name": "2x.webp"},
      ],
    },
  },
};
Map<String, Object?> _ffz(String name, int id) => {
  "id": id,
  "name": name,
  "urls": {"2": "//cdn.frankerfacez.com/emote/$id/2"},
};
http.Response _json(Object? data) =>
    http.Response(jsonEncode(data), 200, headers: {"content-type": "application/json"});

Map<String, Object?> _sevenBadgeResult(bool hasBadge) => {
  "data": {
    "users": {
      "userByConnection": {
        "style": {
          "activeBadge": hasBadge
              ? {
                  "id": "badge-id",
                  "name": "7TV Supporter",
                  "images": [
                    {
                      "url": "https://cdn.7tv.app/badge/test/2x.webp",
                      "mime": "image/webp",
                      "scale": 2,
                    },
                  ],
                }
              : null,
        },
      },
    },
  },
};

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}
