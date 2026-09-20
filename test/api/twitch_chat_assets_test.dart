import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:ui" as ui;

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  _AssetTestBinding();
  testWidgets("live provider events update catalogues and ignore other channels", (tester) async {
    final sockets = <String, _EmoteSocket>{};
    final responses = <String, http.Response>{};
    final requests = <String>[];
    final assets = _assets(
      liveUpdates: true,
      socketConnector: (url) async => sockets[Uri.parse(url).host] = _EmoteSocket(),
      httpClient: MockClient((request) async {
        requests.add(request.url.toString());
        return responses[request.url.toString()] ?? _response(request.url);
      }),
    );
    await assets.refresh();
    await tester.pump();
    final seven = sockets["events.7tv.io"]!;
    seven.receive({
      "op": 1,
      "d": {"heartbeat_interval": 25000},
    });
    expect(seven.sent.map((event) => (event["d"]! as Map)["condition"]), [
      {"object_id": "global-set"},
      {"object_id": "channel-set"},
      {"object_id": "seven-user"},
    ]);
    expect(sockets["sockets.betterttv.net"]!.sent.single, {
      "name": "join_channel",
      "data": {"name": "twitch:123"},
    });
    requests.clear();
    const sevenUrl = "https://7tv.io/v3/users/twitch/123";
    responses[sevenUrl] = _json({
      "user": {"id": "seven-user"},
      "emote_set": {
        "id": "channel-set",
        "emotes": [_seven("NewAlias", "new-emote")],
      },
    });
    seven.receive({
      "op": 0,
      "d": {
        "type": "emote_set.update",
        "body": {"id": "other-set"},
      },
    });
    await tester.pump();
    expect(requests, isEmpty);
    seven.receive({
      "op": 0,
      "d": {
        "type": "emote_set.update",
        "body": {"id": "channel-set"},
      },
    });
    await tester.pump();
    expect(requests, [sevenUrl]);
    expect(assets.emotesByName["NewAlias"]?.id, "new-emote");
    expect(assets.emotesByName["Alias"], isNull);
    expect(assets.emotesByName["Same"]?.id, "bttv-channel");
    expect(
      assets.emotesFor(ChatEmoteProvider.sevenTv, ChatEmoteScope.channel).single.name,
      "NewAlias",
    );

    const bttvUrl = "https://api.betterttv.net/3/cached/users/twitch/123";
    responses[bttvUrl] = _json({
      "channelEmotes": <Object?>[],
      "sharedEmotes": [
        {"code": "NewBTTV", "id": "new-bttv"},
      ],
    });
    final bttv = sockets["sockets.betterttv.net"]!;
    bttv.receive({
      "name": "emote_create",
      "data": {"channel": "twitch:other"},
    });
    await tester.pump();
    expect(requests, [sevenUrl]);
    bttv.receive({
      "name": "emote_update",
      "data": {"channel": "twitch:123"},
    });
    await tester.pump();
    expect(assets.emotesByName["NewBTTV"]?.id, "new-bttv");
    expect(assets.emotesByName["BTTVShared"], isNull);
    expect(assets.emotesByName["Same"]?.id, "seven-global");

    responses["https://api.frankerfacez.com/v1/room/creator"] = _json({
      "sets": {
        "3": {
          "emoticons": [_ffz("NewFFZ", 42)],
        },
      },
    });
    final ffz = sockets["pubsub.workers.frankerfacez.com"]!;
    ffz.receive({
      "topic": "twitch/123",
      "data": {
        "cmd": "add_emote",
        "data": {"set_id": 3},
      },
    });
    await tester.pump();
    expect(assets.emotesByName["NewFFZ"]?.id, "42");
    expect(assets.emotesByName["FFZChannel"], isNull);
    responses["https://api.frankerfacez.com/v1/set/global"] = _json({
      "default_sets": [1],
      "sets": {
        "1": {"emoticons": <Object?>[]},
      },
    });
    ffz.receive({
      "topic": "global",
      "data": {
        "cmd": "remove_emote",
        "data": {"set_id": 1},
      },
    });
    await tester.pump();
    expect(assets.emotesByName["FFZGlobal"], isNull);
    assets.dispose();
    await tester.pump();
    expect(sockets.values.every((socket) => socket.closed), isTrue);
  });

  testWidgets("live sockets resubscribe after set changes and recover missed updates", (
    tester,
  ) async {
    final sockets = <String, List<_EmoteSocket>>{};
    var setId = "channel-set";
    var emoteName = "Initial";
    final delayedGlobal = Completer<http.Response>();
    final assets = _assets(
      liveUpdates: true,
      socketConnector: (url) async {
        final socket = _EmoteSocket();
        sockets.putIfAbsent(Uri.parse(url).host, () => []).add(socket);
        return socket;
      },
      httpClient: MockClient((request) async {
        if (request.url.host == "api.frankerfacez.com" &&
            request.url.path.endsWith("global") &&
            !delayedGlobal.isCompleted) {
          return delayedGlobal.future;
        }
        if (request.url.host == "7tv.io" && request.url.path.contains("users")) {
          return _json({
            "user": {"id": "seven-user"},
            "emote_set": {
              "id": setId,
              "emotes": [_seven(emoteName, "emote")],
            },
          });
        }
        return _response(request.url);
      }),
    );
    final initialRefresh = assets.refresh();
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await initialRefresh;
    expect(assets.errors, contains("Some chat images could not be loaded. Retry to load them."));
    expect(sockets.length, 3);
    delayedGlobal.complete(_response(Uri.parse("https://api.frankerfacez.com/v1/set/global")));
    await tester.pump();
    var socket = sockets["events.7tv.io"]!.last;
    setId = "replacement-set";
    emoteName = "Replacement";
    socket.receive({
      "op": 0,
      "d": {
        "type": "user.update",
        "body": {"id": "seven-user"},
      },
    });
    await tester.pump();
    expect(socket.closed, isTrue);
    socket = sockets["events.7tv.io"]!.last;
    socket.receive({
      "op": 1,
      "d": {"heartbeat_interval": 25000},
    });
    expect(
      socket.sent.any((event) => ((event["d"]! as Map)["condition"] as Map)["object_id"] == setId),
      isTrue,
    );
    expect(assets.emotesByName["Replacement"], isNotNull);
    setId = "manual-refresh-set";
    emoteName = "ManualRefresh";
    await assets.refresh(force: false);
    await tester.pump();
    expect(socket.closed, isTrue);
    socket = sockets["events.7tv.io"]!.last;
    socket.receive({
      "op": 1,
      "d": {"heartbeat_interval": 25000},
    });
    expect(
      socket.sent.any((event) => ((event["d"]! as Map)["condition"] as Map)["object_id"] == setId),
      isTrue,
    );
    expect(assets.emotesByName["ManualRefresh"], isNotNull);
    emoteName = "DuringDisconnect";
    await socket.close();
    await tester.pump(const Duration(seconds: 1));
    expect(assets.emotesByName["DuringDisconnect"], isNotNull);
    assets.dispose();
    await tester.pump(const Duration(seconds: 31));
    expect(sockets.values.expand((group) => group).every((socket) => socket.closed), isTrue);
  });
  testWidgets("7TV terminal closures stop retries while recoverable closures reconnect", (
    tester,
  ) async {
    final sockets = <_EmoteSocket>[];
    Completer<http.Response>? pendingSet;
    final assets = _assets(
      liveUpdates: true,
      socketConnector: (url) async {
        final socket = _EmoteSocket();
        if (Uri.parse(url).host == "events.7tv.io") {
          sockets.add(socket);
        }
        return socket;
      },
      httpClient: MockClient((request) async {
        if (request.url.host == "7tv.io" && request.url.path.contains("users")) {
          return pendingSet?.future ?? _response(request.url);
        }
        return _response(request.url);
      }),
    );
    await assets.refresh();
    await tester.pump();
    for (final code in [4001, 4002, 4003, 4004, 4005, 4009, 4010, 4011]) {
      final count = sockets.length;
      pendingSet = Completer<http.Response>();
      sockets.last.receive({
        "op": 0,
        "d": {
          "type": "user.update",
          "body": {"id": "seven-user"},
        },
      });
      await tester.pump();
      sockets.last.receive({
        "op": 7,
        "d": {"code": code},
      });
      pendingSet.complete(
        _json({
          "emote_set": {"id": "replacement-set", "emotes": <Object?>[]},
        }),
      );
      pendingSet = null;
      await tester.pump();
      await tester.pump(const Duration(minutes: 6));
      expect(sockets.last.closed, isTrue);
      expect(sockets, hasLength(count));
      await assets.refresh();
      await tester.pump();
      expect(sockets, hasLength(count + 1));
    }
    final terminalCount = sockets.length;
    await sockets.last.close(1008);
    await tester.pump(const Duration(minutes: 6));
    expect(sockets, hasLength(terminalCount));
    await assets.refresh();
    await tester.pump();
    for (final code in [4000, 4006, 4008, 4012]) {
      final count = sockets.length;
      sockets.last.receive({
        "op": 7,
        "d": {"code": code},
      });
      await tester.pump(const Duration(seconds: 1));
      expect(sockets, hasLength(count + 1));
    }
    final maintenanceCount = sockets.length;
    sockets.last.receive({
      "op": 7,
      "d": {"code": 4007},
    });
    await tester.pump(const Duration(seconds: 299));
    expect(sockets, hasLength(maintenanceCount));
    await tester.pump(const Duration(seconds: 61));
    expect(sockets, hasLength(maintenanceCount + 1));
    assets.dispose();
    await tester.pump();
  });

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
    expect(assets.broadcaster?.login, "creator");
    expect(assets.broadcaster?.chatColor, "#000000");
    expect(assets.badgeUrls, {"subscriber/1": "https://example.com/badge.png"});
    expect(assets.badgesById["subscriber/1"]!.title, "Subscriber");
    expect(assets.badgesById["subscriber/1"]!.provider, ChatEmoteProvider.twitch);
    expect(assets.emotesByName["Kappa"]!.provider, ChatEmoteProvider.twitch);
    expect(assets.emotesByName["Same"]!.id, "seven-channel");
    expect(assets.emotesByName["Alias"]!.id, "seven-alias");
    expect(assets.emotesByName["Alias"]!.zeroWidth, isTrue);
    expect(assets.emotesByName["Alias"]!.author, "Emote Artist");
    expect(assets.emotesByName["Alias"]!.originalName, "OriginalAlias");
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
    expect(assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.global).single.name, "Kappa");
    expect(assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.channel).single.name, "Same");
    expect(
      assets.emotesFor(ChatEmoteProvider.sevenTv, ChatEmoteScope.global).single.id,
      "seven-global",
    );
    expect(
      assets
          .emotesFor(ChatEmoteProvider.sevenTv, ChatEmoteScope.channel)
          .map((emote) => emote.name),
      ["Alias", "Same"],
    );
    expect(assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.unlocked), isEmpty);
    expect(
      assets.emotesByName["Kappa"]!.urlForBrightness(Brightness.light),
      endsWith("/light/2.0"),
    );
    expect(
      assets.emotesByName["Alias"]!.urlForBrightness(Brightness.light),
      assets.emotesByName["Alias"]!.url,
    );
  });

  test("unlocked emotes load lazily, use viewer results, and can retry errors", () async {
    var calls = 0;
    final client = _Client(
      onUnlocked: (id) async {
        expect(id, "123");
        if (++calls == 1) {
          throw TwitchApiException("try again");
        }
        return {"MySubEmote": "mine"};
      },
    );
    final assets = _assets(
      client: client,
      httpClient: MockClient((request) async => _response(request.url)),
    );
    addTearDown(assets.dispose);
    await assets.refresh();
    expect(calls, 0);
    await assets.loadUnlockedEmotes();
    expect(assets.unlockedError, isNotNull);
    expect(assets.isLoadingUnlocked, isFalse);
    await assets.loadUnlockedEmotes();
    expect(assets.unlockedError, isNull);
    expect(
      assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.unlocked).single.name,
      "MySubEmote",
    );
    expect(assets.emotesByName["MySubEmote"]!.id, "mine");
    expect(
      assets
          .emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.unlocked)
          .any((emote) => emote.name == "Same"),
      isFalse,
    );
  });

  test("unlocked emote labels use global names by ID and retain private set membership", () async {
    final assets = _assets(
      channelLogin: "canonical_emotes",
      client: _Client(
        onLoad: () async => const TwitchNativeChatAssets(
          channelId: "123",
          badgeUrls: {},
          emoteIdsByName: {},
          globalEmoteIdsByName: {"O_O": "1", ">O": "2", "<3": "3", "Kappa": "25"},
        ),
        onUnlocked: (_) async => {
          r"[oO](_|\.)[oO]": "1",
          r"\&gt;O": "2",
          r"\&lt;3": "3",
          "MySubEmote": "mine",
        },
      ),
      httpClient: MockClient((request) async => _response(request.url)),
    );
    addTearDown(assets.dispose);
    await assets.loadUnlockedEmotes();
    expect(assets.unlockedError, isNull);
    expect(
      {
        for (final emote in assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.unlocked))
          emote.name: emote.id,
      },
      {"O_O": "1", ">O": "2", "<3": "3", "MySubEmote": "mine"},
    );
  });

  test("unlocked refresh keeps the current session's catalogue through a failure", () async {
    final pending = Completer<Map<String, String>>();
    var refresh = false;
    var client = _Client(
      gqlAccessToken: "first-session",
      onUnlocked: (_) async => refresh ? pending.future : {"MySubEmote": "mine"},
    );
    final assets = TwitchChatAssets(
      clientLoader: () async => client,
      channelLogin: "retained_unlocked",
      autoLoad: false,
    );
    addTearDown(assets.dispose);
    await assets.loadUnlockedEmotes();
    refresh = true;
    final refreshing = assets.loadUnlockedEmotes();
    await Future<void>.delayed(Duration.zero);
    expect(assets.isLoadingUnlocked, isTrue);
    expect(assets.emotesByName["MySubEmote"]?.id, "mine");
    pending.completeError(TwitchApiException("temporary failure"));
    await refreshing;
    expect(assets.unlockedError, isNotNull);
    expect(assets.emotesByName["MySubEmote"]?.id, "mine");

    client = _Client(
      gqlAccessToken: "second-session",
      onUnlocked: (_) async => throw TwitchApiException("temporary failure"),
    );
    await assets.loadUnlockedEmotes();
    expect(assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.unlocked), isEmpty);
    expect(assets.emotesByName["MySubEmote"], isNull);
    client = _Client(
      gqlAccessToken: "second-session",
      onUnlocked: (_) async => {"OtherSubEmote": "other"},
    );
    await assets.loadUnlockedEmotes();
    expect(assets.emotesByName["OtherSubEmote"]?.id, "other");
    client = _Client();
    await assets.loadUnlockedEmotes();
    expect(assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.unlocked), isEmpty);
    expect(assets.emotesByName["OtherSubEmote"], isNull);
  });

  for (final fails in [false, true]) {
    test(
      "unlocked refresh discards a previous account's ${fails ? "failed" : "late"} result",
      () async {
        final pending = Completer<Map<String, String>>();
        var refresh = false;
        var client = _Client(
          gqlAccessToken: "first-session",
          onUnlocked: (_) async => refresh ? pending.future : {"MySubEmote": "mine"},
        );
        final assets = TwitchChatAssets(
          clientLoader: () async => client,
          channelLogin: "switched_unlocked",
          autoLoad: false,
        );
        addTearDown(assets.dispose);
        await assets.loadUnlockedEmotes();
        refresh = true;
        final refreshing = assets.loadUnlockedEmotes();
        await Future<void>.delayed(Duration.zero);
        client = _Client(gqlAccessToken: "second-session");
        if (fails) {
          pending.completeError(TwitchApiException("temporary failure"));
        } else {
          pending.complete({"LateSubEmote": "late"});
        }
        await refreshing;
        expect(assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.unlocked), isEmpty);
        expect(assets.emotesByName["MySubEmote"], isNull);
        expect(assets.emotesByName["LateSubEmote"], isNull);
      },
    );
  }

  testWidgets("precaches only sent images and reuses decoded images with the current theme", (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache as _RecordingImageCache;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
      final picture = recorder.endRecording();
      cache.pixel = await picture.toImage(1, 1);
      picture.dispose();
    });
    addTearDown(() {
      cache.clear();
      cache.pixel?.dispose();
      cache.pixel = null;
      cache.requested.clear();
    });
    final assets = _assets(httpClient: MockClient((request) async => _response(request.url)));
    addTearDown(assets.dispose);
    await assets.refresh();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    const messages = [
      TwitchChatMessage(
        id: "one",
        login: "other",
        displayName: "Other",
        text: "Same Alias ordinary words",
        badges: ["subscriber/1"],
        emotes: [TwitchChatEmote(id: "unlisted", start: 0, end: 4)],
        gifs: [
          TwitchChatGif(
            id: "gif",
            url: "https://media4.giphy.com/media/gif/giphy.gif?cid=kept&rid=giphy.gif&ct=g",
            start: 5,
            end: 10,
          ),
        ],
        parentGifs: [
          TwitchChatGif(id: "parent", url: "https://example.com/parent.gif", start: 0, end: 5),
        ],
      ),
    ];
    assets.precacheMessages(context, messages);
    await tester.pump();
    expect(cache.requested, {
      "https://media4.giphy.com/media/gif/giphy.webp?cid=kept&rid=giphy.webp&ct=g",
      "https://example.com/parent.gif",
      "https://static-cdn.jtvnw.net/emoticons/v2/unlisted/default/light/2.0",
      "https://cdn.7tv.app/emote/seven-alias/2x.webp",
      "https://example.com/badge.png",
      "https://cdn.frankerfacez.com/badge/3/2",
    });
    cache.requested.clear();
    assets.precacheMessages(context, messages);
    await tester.pump();
    expect(cache.requested, isEmpty);
    expect(tester.takeException(), isNull);
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
    expect(second.broadcaster, same(first.broadcaster));
    expect(second.broadcaster?.chatColor, "#000000");
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

  testWidgets("7TV badges prefer animated images over their static previews", (tester) async {
    const static = {
      "url": "https://cdn.7tv.app/badge/test/2x_static.webp",
      "mime": "image/webp",
      "scale": 2,
      "frameCount": 1,
    };
    const animatedWebp = {
      "url": "https://cdn.7tv.app/badge/test/2x.webp",
      "mime": "image/webp",
      "scale": 2,
      "frameCount": 100,
    };
    const animatedGif = {
      "url": "https://cdn.7tv.app/badge/test/2x.gif",
      "mime": "image/gif",
      "scale": 2,
      "frameCount": 100,
    };
    final requests = <http.Request>[];
    final assets = _assets(
      httpClient: MockClient((request) async {
        requests.add(request);
        return _json([
          _sevenBadgeResult(true, badgeImages: [static, animatedGif, animatedWebp]),
          _sevenBadgeResult(true, badgeImages: [static, animatedGif]),
          _sevenBadgeResult(true, badgeImages: [static]),
        ]);
      }),
    );
    addTearDown(assets.dispose);
    assets.observeMessages([
      for (var index = 0; index < 3; index++)
        TwitchChatMessage(
          id: "badge-$index",
          login: "badge$index",
          displayName: "Badge$index",
          text: "hello",
          userId: "${99700000 + index}",
        ),
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(requests, hasLength(1));
    expect(
      (jsonDecode(requests.single.body) as List<Object?>).first,
      containsPair(
        "query",
        contains("activeBadge { id name images { url mime scale frameCount } }"),
      ),
    );
    expect(assets.errors, isEmpty);
    expect(assets.userBadgesByLogin["badge0"]!.single.url, animatedWebp["url"]);
    expect(assets.userBadgesByLogin["badge1"]!.single.url, animatedGif["url"]);
    expect(assets.userBadgesByLogin["badge2"]!.single.url, static["url"]);
  });

  testWidgets("7TV styles batch sender IDs and cache badges, full paints, and empty results", (
    tester,
  ) async {
    final batches = <int>[];
    final requests = <http.Request>[];
    final assets = _assets(
      httpClient: MockClient((request) async {
        requests.add(request);
        final queries = jsonDecode(request.body) as List<Object?>;
        batches.add(queries.length);
        return _json([
          for (var index = 0; index < queries.length; index++)
            _sevenBadgeResult(index == 0, paint: index < 2 ? _sevenPaintDefinition() : null),
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
    final paint = assets.userPaintsByLogin["user0"]!;
    expect(paint.id, "paint-id");
    expect(paint.name, "Full paint");
    expect(paint.layers.map((layer) => layer.type), [
      ChatPaintLayerType.color,
      ChatPaintLayerType.linearGradient,
      ChatPaintLayerType.radialGradient,
      ChatPaintLayerType.radialGradient,
      ChatPaintLayerType.image,
    ]);
    expect(paint.layers.first.color, const Color(0x800A141E));
    expect(paint.layers.first.opacity, 0.4);
    final linear = paint.layers[1];
    expect(linear.angle, 135);
    expect(linear.repeating, isTrue);
    expect(linear.stops.map((stop) => stop.at), [-0.25, 0.5, 1.25]);
    expect(linear.stops[1].color, const Color(0x4000FF00));
    expect(paint.layers[2].shape, ChatPaintRadialShape.circle);
    expect(paint.layers[3].shape, ChatPaintRadialShape.ellipse);
    expect(paint.layers[3].repeating, isTrue);
    final images = paint.layers.last.images;
    expect(images.map((image) => image.frameCount), [1, 48]);
    expect(images.map((image) => image.scale), [1, 2]);
    expect(images.last.mime, "image/webp");
    expect(images.last.width, 256);
    expect(images.last.height, 64);
    expect(images.last.size, 23456);
    expect(paint.shadows, [
      const Shadow(color: Color(0xA0010203), offset: Offset(-2, 3.5), blurRadius: 4.5),
      const Shadow(color: Color(0xFF040506), offset: Offset(1, -1)),
    ]);
    expect(assets.userPaintsByLogin["user1"]!.id, paint.id);
    expect(assets.userPaintsByLogin["user2"], isNull);
    expect(() => assets.userPaintsByLogin.clear(), throwsUnsupportedError);
    expect(paint.layers.clear, throwsUnsupportedError);
    expect(linear.stops.clear, throwsUnsupportedError);
    expect(images.clear, throwsUnsupportedError);
    expect(paint.shadows.clear, throwsUnsupportedError);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(batches, [30, 2]);
    assets.observeMessages(messages);
    await tester.pump(const Duration(seconds: 3));
    expect(batches, [30, 2]);
    final otherChannel = _assets(httpClient: MockClient((_) async => throw StateError("Cached")));
    otherChannel.observeMessages(messages);
    await tester.pump(const Duration(seconds: 3));
    expect(otherChannel.userPaintsByLogin["user0"], same(paint));
    expect(
      otherChannel.userBadgesByLogin["user0"]!.single,
      same(assets.userBadgesByLogin["user0"]!.single),
    );
    expect(otherChannel.userPaintsByLogin["user2"], isNull);
    expect(otherChannel.errors, isEmpty);
    otherChannel.dispose();
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
    response.complete(_json([_sevenBadgeResult(true, paint: _sevenPaintDefinition())]));
    await tester.pump(const Duration(seconds: 20));
    expect(assets.userBadgesByLogin, isEmpty);
    expect(assets.userPaintsByLogin, isEmpty);
  });

  testWidgets("refreshing 7TV styles removes inactive paints without removing active badges", (
    tester,
  ) async {
    var hasPaint = true;
    var styleCalls = 0;
    final assets = _assets(
      httpClient: MockClient((request) async {
        if (request.method != "POST") {
          return _response(request.url);
        }
        styleCalls++;
        return _json([_sevenBadgeResult(true, paint: hasPaint ? _sevenPaintDefinition() : null)]);
      }),
    );
    addTearDown(assets.dispose);
    assets.observeMessages(const [
      TwitchChatMessage(
        id: "1",
        login: "refresh",
        displayName: "Refresh",
        text: "hi",
        userId: "99000300",
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(assets.userPaintsByLogin["refresh"]!.id, "paint-id");
    hasPaint = false;
    await assets.refresh();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(styleCalls, 2);
    expect(assets.userPaintsByLogin["refresh"], isNull);
    expect(assets.userBadgesByLogin["refresh"]!.single.id, "7tv/badge-id");
    expect(assets.errors, isEmpty);
  });

  testWidgets("malformed or unsupported paint layers leave badges usable", (tester) async {
    final assets = _assets(
      httpClient: MockClient(
        (_) async => _json([
          _sevenBadgeResult(
            true,
            paint: {
              "id": "invalid-paint",
              "name": "Invalid paint",
              "data": {
                "layers": [
                  {
                    "id": "unknown",
                    "ty": {"__typename": "UnknownPaintLayer"},
                  },
                  {
                    "id": "invalid-color",
                    "ty": {
                      "__typename": "PaintLayerTypeSingleColor",
                      "color": {"r": 255, "g": 0, "b": 0, "a": 999},
                    },
                  },
                  {
                    "id": "unsafe-image",
                    "ty": {
                      "__typename": "PaintLayerTypeImage",
                      "images": [
                        {"url": "file:///paint.webp", "mime": "image/webp"},
                      ],
                    },
                  },
                  {
                    "id": "invalid-gradient",
                    "ty": {
                      "__typename": "PaintLayerTypeLinearGradient",
                      "stops": [
                        {
                          "at": "invalid",
                          "color": {"r": 1, "g": 2, "b": 3, "a": 255},
                        },
                      ],
                    },
                  },
                ],
                "shadows": [
                  {
                    "color": {"r": 1, "g": 2, "b": 3, "a": 255},
                    "blur": -1,
                  },
                ],
              },
            },
          ),
        ]),
      ),
    );
    addTearDown(assets.dispose);
    assets.observeMessages(const [
      TwitchChatMessage(
        id: "1",
        login: "invalid",
        displayName: "Invalid",
        text: "hi",
        userId: "99000400",
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(assets.userPaintsByLogin, isEmpty);
    expect(assets.userBadgesByLogin["invalid"]!.single.id, "7tv/badge-id");
    expect(assets.errors, isEmpty);
  });

  testWidgets("7TV failures retry with a delay and clear the error after recovery", (tester) async {
    var calls = 0;
    final assets = _assets(
      httpClient: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response("unavailable", 503)
            : _json([_sevenBadgeResult(false, paint: _sevenPaintDefinition())]);
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
    expect(assets.errors, ["7TV badges and paints could not be loaded."]);
    await tester.pump(const Duration(seconds: 29));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 2);
    expect(assets.errors, isEmpty);
    expect(assets.userPaintsByLogin["retry"]!.id, "paint-id");
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
        expect(query, contains("profileImageURL(width: 70)"));
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
              "login": "creator",
              "displayName": "Creator",
              "profileImageURL": "https://example.com/creator.png",
              "chatColor": "#000000",
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
    expect(data.broadcaster?.id, "123");
    expect(data.broadcaster?.login, "creator");
    expect(data.broadcaster?.displayName, "Creator");
    expect(data.broadcaster?.profileImageUrl, "https://example.com/creator.png");
    expect(data.broadcaster?.chatColor, "#000000");
    expect(data.badgeUrls["subscriber/1"], "https://example.com/channel.png");
    expect(data.badgeTitles["subscriber/1"], "One-month subscriber");
    expect(data.emoteIdsByName, {"Kappa": "25", "SubEmote": "sub", "LocalEmote": "local"});
    final chatters = await client.fetchChatters("creator");
    expect(chatters.count, 800);
    expect(chatters.groups["broadcasters"], ["creator"]);
    expect(chatters.groups["moderators"], ["moderator"]);
    expect(chatters.groups["viewers"], ["viewer"]);
  });

  testWidgets("shared channel portraits are batched, cached, and ignored after disposal", (
    tester,
  ) async {
    var response = Completer<Map<String, TwitchUser>>();
    final batches = <List<String>>[];
    final client = _Client(
      onUsers: (ids) {
        batches.add(ids);
        return response.future;
      },
    );
    final assets = TwitchChatAssets(
      clientLoader: () async => client,
      channelLogin: "creator",
      httpClient: MockClient((request) async => _response(request.url)),
      autoLoad: false,
      liveUpdates: false,
    );
    await assets.refresh();
    TwitchChatMessage source(String id) => TwitchChatMessage(
      id: id,
      login: "viewer",
      displayName: "Viewer",
      text: "hello",
      sourceRoomId: id,
    );
    final messages = [source("123"), source("456"), source("456"), source("invalid")];
    assets.observeMessages(messages);
    assets.observeMessages(messages);
    await tester.pump();
    expect(batches, [
      ["456"],
    ]);
    const other = TwitchUser(id: "456", login: "other", displayName: "Other");
    response.complete({"456": other});
    await tester.pump();
    expect(assets.sharedChannels["123"], same(assets.broadcaster));
    expect(assets.sharedChannels["456"], same(other));
    expect(() => assets.sharedChannels.clear(), throwsUnsupportedError);
    assets.observeMessages(messages);
    await tester.pump();
    expect(batches, hasLength(1));

    response = Completer();
    assets.observeMessages([source("789")]);
    await tester.pump();
    response.completeError(StateError("unavailable"));
    await tester.pump();
    assets.observeMessages([source("789")]);
    await tester.pump();
    expect(batches, hasLength(2));

    await tester.pump(const Duration(seconds: 29));
    assets.observeMessages([source("789")]);
    await tester.pump();
    expect(batches, hasLength(2));
    response = Completer();
    await tester.pump(const Duration(seconds: 1));
    assets.observeMessages([source("789")]);
    await tester.pump();
    expect(batches, hasLength(3));
    const recovered = TwitchUser(id: "789", login: "recovered", displayName: "Recovered");
    response.complete({"789": recovered});
    await tester.pump();
    expect(assets.sharedChannels["789"], same(recovered));
    assets.observeMessages([source("789")]);
    await tester.pump();
    expect(batches, hasLength(3));

    response = Completer();
    assets.observeMessages([source("999")]);
    await tester.pump();
    assets.dispose();
    response.complete({"999": const TwitchUser(id: "999", login: "late", displayName: "Late")});
    await tester.pump();
    expect(assets.sharedChannels["999"], isNull);
  });
}

const _native = TwitchNativeChatAssets(
  channelId: "123",
  broadcaster: TwitchUser(
    id: "123",
    login: "creator",
    displayName: "Creator",
    chatColor: "#000000",
  ),
  badgeUrls: {"subscriber/1": "https://example.com/badge.png", "unsafe/1": "file:///secret"},
  badgeTitles: {"subscriber/1": "Subscriber"},
  emoteIdsByName: {"Kappa": "25", "Same": "native-same"},
  globalEmoteIdsByName: {"Kappa": "25"},
  channelEmoteIdsByName: {"Same": "native-same"},
);

class _Client extends TwitchApiClient {
  _Client({this.onLoad, this.onUnlocked, this.onUsers, super.gqlAccessToken})
    : super(clientId: "test", accessToken: "");
  final Future<TwitchNativeChatAssets> Function()? onLoad;
  final Future<Map<String, String>> Function(String channelId)? onUnlocked;
  final Future<Map<String, TwitchUser>> Function(List<String> ids)? onUsers;
  @override
  Future<Map<String, TwitchUser>> fetchUsersByIds(List<String> ids) async =>
      onUsers == null ? const {} : onUsers!(ids);
  @override
  Future<TwitchNativeChatAssets> fetchChatAssets(String login) async =>
      onLoad == null ? _native : onLoad!();
  @override
  Future<Map<String, String>> fetchUnlockedChatEmotes(String channelId) async =>
      onUnlocked == null ? const {} : onUnlocked!(channelId);
}

TwitchChatAssets _assets({
  String channelLogin = "creator",
  _Client? client,
  required http.Client httpClient,
  bool liveUpdates = false,
  Future<WebSocket> Function(String url)? socketConnector,
}) => TwitchChatAssets(
  clientLoader: () async => client ?? _Client(),
  channelLogin: channelLogin,
  httpClient: httpClient,
  autoLoad: false,
  liveUpdates: liveUpdates,
  socketConnector: socketConnector,
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
        "user": {"id": "seven-user"},
        "emote_set": {
          "id": "channel-set",
          "emotes": [_seven("Same", "seven-channel"), _seven("Alias", "seven-alias", flags: 1)],
        },
      });
    }
    return _json({
      "id": "global-set",
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
    "name": name == "Alias" ? "OriginalAlias" : name,
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

class _EmoteSocket extends Stream<Object?> implements WebSocket {
  final _incoming = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, Object?>>[];
  bool closed = false;
  @override
  int? closeCode;
  @override
  Duration? pingInterval;

  void receive(Map<String, Object?> event) => _incoming.add(jsonEncode(event));
  @override
  void add(Object? data) => sent.add(jsonDecode(data! as String) as Map<String, Object?>);
  @override
  Future<void> close([int? code, String? reason]) async {
    if (closed) {
      return;
    }
    closed = true;
    closeCode = code;
    await Future<void>.value();
    await _incoming.close();
  }

  @override
  StreamSubscription<Object?> listen(
    void Function(Object?)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _incoming.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

http.Response _json(Object? data) =>
    http.Response(jsonEncode(data), 200, headers: {"content-type": "application/json"});

Map<String, Object?> _sevenBadgeResult(
  bool hasBadge, {
  Object? paint,
  List<Map<String, Object?>>? badgeImages,
}) => {
  "data": {
    "users": {
      "userByConnection": {
        "style": {
          "activePaint": paint,
          "activeBadge": hasBadge
              ? {
                  "id": "badge-id",
                  "name": "7TV Supporter",
                  "images":
                      badgeImages ??
                      [
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

Map<String, Object?> _sevenPaintDefinition() => {
  "id": "paint-id",
  "name": "Full paint",
  "data": {
    "layers": [
      {
        "id": "base",
        "opacity": 0.4,
        "ty": {
          "__typename": "PaintLayerTypeSingleColor",
          "color": {"r": 10, "g": 20, "b": 30, "a": 128},
        },
      },
      {
        "id": "linear",
        "opacity": 1,
        "ty": {
          "__typename": "PaintLayerTypeLinearGradient",
          "angle": 135,
          "repeating": true,
          "stops": [
            {
              "at": -0.25,
              "color": {"r": 255, "g": 0, "b": 0, "a": 255},
            },
            {
              "at": 0.5,
              "color": {"r": 0, "g": 255, "b": 0, "a": 64},
            },
            {
              "at": 1.25,
              "color": {"r": 0, "g": 0, "b": 255, "a": 255},
            },
          ],
        },
      },
      for (final shape in ["CIRCLE", "ELLIPSE"])
        {
          "id": shape.toLowerCase(),
          "opacity": 0.75,
          "ty": {
            "__typename": "PaintLayerTypeRadialGradient",
            "shape": shape,
            "repeating": shape == "ELLIPSE",
            "stops": [
              {
                "at": 0,
                "color": {"r": 255, "g": 255, "b": 255, "a": 255},
              },
              {
                "at": 1,
                "color": {"r": 0, "g": 0, "b": 0, "a": 0},
              },
            ],
          },
        },
      {
        "id": "image",
        "opacity": 0.6,
        "ty": {
          "__typename": "PaintLayerTypeImage",
          "images": [
            {
              "url": "https://cdn.7tv.app/paint/test/1x_static.webp",
              "mime": "image/webp",
              "scale": 1,
              "width": 128,
              "height": 32,
              "frameCount": 1,
              "size": 1234,
            },
            {
              "url": "https://cdn.7tv.app/paint/test/2x.webp",
              "mime": "image/webp",
              "scale": 2,
              "width": 256,
              "height": 64,
              "frameCount": 48,
              "size": 23456,
            },
          ],
        },
      },
    ],
    "shadows": [
      {
        "color": {"r": 1, "g": 2, "b": 3, "a": 160},
        "offsetX": -2,
        "offsetY": 3.5,
        "blur": 4.5,
      },
      {
        "color": {"r": 4, "g": 5, "b": 6, "a": 255},
        "offsetX": 1,
        "offsetY": -1,
        "blur": 0,
      },
    ],
  },
};

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

class _AssetTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => _RecordingImageCache();
}

class _RecordingImageCache extends ImageCache {
  ui.Image? pixel;
  final Set<String> requested = {};

  @override
  ImageStreamCompleter? putIfAbsent(
    Object key,
    ImageStreamCompleter Function() loader, {
    ImageErrorListener? onError,
  }) {
    if (key is NetworkImage && pixel != null) {
      requested.add(key.url);
      return super.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: pixel!.clone()))),
        onError: onError,
      );
    }
    return super.putIfAbsent(key, loader, onError: onError);
  }
}
