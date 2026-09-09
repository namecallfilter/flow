import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flow/api/twitch_chat_pins.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("fetches fresh initial pin content with native badges, emotes, and reply context", () async {
    var requests = 0;
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "",
      httpClient: MockClient((request) async {
        requests++;
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body["variables"], {"channelID": "123"});
        expect(request.headers["authorization"], isNull);
        return http.Response(
          jsonEncode({
            "data": {
              "channel": {
                "id": "123",
                "pinnedChatMessages": {
                  "edges": [
                    {
                      "node": {
                        "id": "pin",
                        "startsAt": "2026-09-07T22:30:00Z",
                        "endsAt": "2026-09-07T23:00:00Z",
                        "pinnedBy": {
                          if (requests == 1) "id": "99",
                          "login": "pinner",
                          "displayName": "Pinner",
                        },
                        "pinnedMessage": {
                          "id": "message",
                          "sentAt": "2026-09-07T22:00:00Z",
                          "senderChatColor": "#123456",
                          "senderBadges": [
                            {"setID": "moderator", "version": "1"},
                            {"setID": "subscriber", "version": "72"},
                            {"setID": "bot-badge", "version": "1"},
                          ],
                          "sender": {
                            "id": "77",
                            "login": "alice",
                            "displayName": "Alice",
                            "chatColor": "#000000",
                            "displayBadges": [
                              {"setID": "partner", "version": "1"},
                            ],
                          },
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
                            "sender": {"id": "88", "login": "bob", "displayName": "Bob"},
                            "content": {"text": "Original"},
                          },
                          "threadParentMessage": {
                            "id": "root",
                            "sender": {"login": "original"},
                          },
                        },
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
    final pin = (await client.fetchPinnedChat("123"))!;
    expect(pin.id, "pin");
    expect(pin.startsAt?.toUtc(), DateTime.utc(2026, 9, 7, 22, 30));
    expect(pin.endsAt?.toUtc(), DateTime.utc(2026, 9, 7, 23));
    expect(pin.message.userId, "77");
    expect(pin.pinnedBy, (id: "99", login: "pinner", displayName: "Pinner"));
    expect(pin.message.color, "#123456");
    expect(pin.message.badges, ["moderator/1", "subscriber/72", "bot-badge/1"]);
    expect(pin.message.emotes.single.start, 3);
    expect(pin.message.emotes.single.end, 8);
    expect(pin.message.parentText, "Original");
    expect(pin.message.threadRootId, "root");
    expect((await client.fetchPinnedChat("123"))?.pinnedBy, isNull);
    expect(requests, 2);
  });

  test("distinguishes an empty initial pin from missing channels and query failures", () async {
    final responses = <Object?>[
      {
        "data": {
          "channel": {
            "id": "123",
            "pinnedChatMessages": {"edges": <Object?>[]},
          },
        },
      },
      {
        "data": {"channel": null},
      },
      {
        "data": {
          "channel": {
            "id": "wrong",
            "pinnedChatMessages": {"edges": <Object?>[]},
          },
        },
      },
      {
        "errors": [
          {"message": "Unavailable"},
        ],
      },
    ];
    final client = TwitchApiClient(
      clientId: "client",
      accessToken: "",
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(responses.removeAt(0)),
          200,
          headers: {"content-type": "application/json"},
        ),
      ),
    );
    expect(await client.fetchPinnedChat("123"), isNull);
    for (var index = 0; index < 3; index++) {
      await expectLater(client.fetchPinnedChat("123"), throwsA(isA<TwitchApiException>()));
    }
  });

  testWidgets("subscribes to the channel, loads its initial pin, and applies live updates", (
    tester,
  ) async {
    final socket = _Socket();
    var loads = 0;
    final pins = TwitchChatPins(
      channelId: "123",
      socketConnector: () async => socket,
      loadInitial: () async {
        loads++;
        return _initialPin;
      },
    );
    await tester.pump();
    expect(loads, 0);
    socket.welcome();
    final request = socket.sent.single;
    final subscribe = request["subscribe"]! as Map<String, Object?>;
    expect(subscribe["pubsub"], {"topic": "pinned-chat-updates-v1.123"});
    expect(subscribe["type"], "pubsub");
    expect(request.containsKey("authenticate"), isFalse);
    socket.acknowledge();
    await tester.pump();
    expect(loads, 1);
    expect(pins.pin?.id, "initial-pin");

    socket.event("pin-message", _eventPin("current"), subscriptionId: "another-channel");
    expect(pins.pin?.id, "initial-pin");
    socket.event("pin-message", _eventPin("cheer", type: "CHEER"));
    expect(pins.pin?.id, "initial-pin");
    socket.event("pin-message", _eventPin("current"));
    expect(pins.pin?.id, "current");
    final message = pins.pin!.message;
    expect(message.id, "message-current");
    expect(message.text, "😀 Kappa");
    expect(message.userId, "77");
    expect(pins.pin!.pinnedBy, (id: "99", login: "pinner", displayName: "Pinner"));
    expect(message.displayName, "Alice");
    expect(message.color, "#123456");
    expect(message.badges, ["moderator/1"]);
    expect(message.text.substring(message.emotes.single.start, message.emotes.single.end), "Kappa");
    expect(message.parentMessageId, "parent");
    expect(message.parentText, "😀 Kappa");
    expect(message.parentEmotes.single.id, "25");
    expect(message.parentEmotes.single.start, 3);
    expect(message.parentEmotes.single.end, 8);
    expect(message.threadRootId, "root");
    socket.event("unpin-message", {"id": "initial-pin"});
    expect(pins.pin?.id, "current");
    socket.event("unpin-message", {"id": "current"});
    expect(pins.pin, isNull);
    pins.dispose();
    await tester.pump();
    expect(socket.closed, isTrue);
  });

  testWidgets("does not overwrite a live pin or removal with an older initial response", (
    tester,
  ) async {
    final initial = Completer<TwitchPinnedChat?>();
    final socket = _Socket();
    final pins = TwitchChatPins(
      channelId: "123",
      socketConnector: () async => socket,
      loadInitial: () => initial.future,
    );
    await tester.pump();
    socket.welcome();
    socket.acknowledge();
    socket.event("pin-message", _eventPin("current"));
    socket.event("unpin-message", {"id": "current"});
    initial.complete(_initialPin);
    await tester.pump();
    expect(pins.pin, isNull);
    pins.dispose();
  });

  testWidgets("merges removals and duration updates that arrive before initial loading completes", (
    tester,
  ) async {
    for (final change in [
      {
        "type": "unpin-message",
        "data": {"id": "unrelated-cheer"},
      },
      {
        "type": "unpin-message",
        "data": {"id": "initial-pin"},
      },
      {
        "type": "update-message",
        "data": {"id": "initial-pin", "ends_at": 1},
      },
    ]) {
      final initial = Completer<TwitchPinnedChat?>();
      final socket = _Socket();
      final pins = TwitchChatPins(
        channelId: "123",
        socketConnector: () async => socket,
        loadInitial: () => initial.future,
      );
      await tester.pump();
      socket.welcome();
      socket.acknowledge();
      final data = change["data"]! as Map<String, Object?>;
      socket.event(change["type"]! as String, data);
      initial.complete(_initialPin);
      await tester.pump();
      expect(
        pins.pin?.id,
        data["id"] == "unrelated-cheer" || change["type"] == "update-message"
            ? "initial-pin"
            : null,
      );
      if (change["type"] == "update-message") {
        expect(pins.pin?.endsAt, DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
      }
      pins.dispose();
    }
  });

  testWidgets("updates pin timing but waits for Twitch to remove an expired pin", (tester) async {
    final socket = _Socket();
    final pins = TwitchChatPins(
      channelId: "123",
      socketConnector: () async => socket,
      loadInitial: () async => null,
    );
    await tester.pump();
    socket.welcome();
    socket.acknowledge();
    await tester.pump();
    final ending = DateTime.now().add(const Duration(seconds: 2)).millisecondsSinceEpoch / 1000;
    socket.event("pin-message", _eventPin("current", endsAt: ending));
    final startsAt = pins.pin?.startsAt;
    expect(startsAt, DateTime.fromMillisecondsSinceEpoch(1642719340000, isUtc: true));
    expect(pins.pin?.endsAt, isNotNull);
    socket.event("update-message", {"id": "current", "ends_at": null});
    await tester.pump(const Duration(seconds: 3));
    expect(pins.pin?.id, "current");
    expect(pins.pin?.endsAt, isNull);
    expect(pins.pin?.startsAt, startsAt);
    expect(pins.pin?.pinnedBy?.id, "99");
    socket.event("update-message", {"id": "other", "ends_at": 1});
    expect(pins.pin?.id, "current");
    socket.event("update-message", {
      "id": "current",
      "ends_at": DateTime.now().add(const Duration(seconds: 2)).millisecondsSinceEpoch / 1000,
    });
    await tester.pump(const Duration(seconds: 2));
    expect(pins.pin?.id, "current");
    socket.event("unpin-message", {"id": "current"});
    expect(pins.pin, isNull);
    socket.event("pin-message", _eventPin("expired", endsAt: 1));
    expect(pins.pin?.id, "expired");
    socket.event("pin-message", _eventPin("unknown-pinner")..remove("pinned_by"));
    expect(pins.pin?.id, "unknown-pinner");
    expect(pins.pin?.pinnedBy, isNull);
    socket.event(
      "pin-message",
      _eventPin("missing-pinner-id")..["pinned_by"] = {"login": "pinner"},
    );
    expect(pins.pin?.id, "missing-pinner-id");
    expect(pins.pin?.pinnedBy, isNull);
    pins.dispose();
  });

  testWidgets("reconnects after server reconnect and reloads authoritative pin state", (
    tester,
  ) async {
    final sockets = <_Socket>[];
    var loads = 0;
    final pins = TwitchChatPins(
      channelId: "123",
      socketConnector: () async {
        final socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      loadInitial: () async => ++loads == 1 ? _initialPin : null,
    );
    await tester.pump();
    sockets.single.welcome();
    sockets.single.acknowledge();
    await tester.pump();
    expect(pins.pin, isNotNull);
    sockets.single.receive({"type": "reconnect"});
    expect(pins.pin, same(_initialPin));
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 2);
    sockets.last.welcome();
    sockets.last.acknowledge();
    await tester.pump();
    expect(loads, 2);
    expect(pins.pin, isNull);
    pins.dispose();
    await tester.pump(const Duration(minutes: 1));
    expect(sockets.length, 2);
  });

  testWidgets("retries missing acknowledgments, failed snapshots, and lost keepalives", (
    tester,
  ) async {
    final sockets = <_Socket>[];
    var loads = 0;
    final pins = TwitchChatPins(
      channelId: "123",
      socketConnector: () async {
        final socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      loadInitial: () async {
        if (++loads == 1) {
          throw const SocketException("offline");
        }
        return null;
      },
    );
    await tester.pump();
    sockets.last.welcome();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 2);
    sockets.last.welcome();
    sockets.last.acknowledge();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(sockets.length, 3);
    sockets.last.welcome();
    sockets.last.acknowledge();
    await tester.pump();
    expect(loads, 2);
    await tester.pump(const Duration(seconds: 18));
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 4);
    pins.dispose();
  });

  testWidgets(
    "disposing pending socket and snapshot work ignores late results and cancels timers",
    (tester) async {
      final socketFuture = Completer<WebSocket>();
      final initial = Completer<TwitchPinnedChat?>();
      var loads = 0;
      final pending = TwitchChatPins(
        channelId: "old",
        socketConnector: () => socketFuture.future,
        loadInitial: () async {
          loads++;
          return null;
        },
      );
      pending.dispose();
      final lateSocket = _Socket();
      socketFuture.complete(lateSocket);
      await tester.pump();
      expect(lateSocket.closed, isTrue);
      expect(loads, 0);
      final socket = _Socket();
      final pins = TwitchChatPins(
        channelId: "123",
        socketConnector: () async => socket,
        loadInitial: () => initial.future,
      );
      await tester.pump();
      socket.welcome();
      socket.acknowledge();
      pins.dispose();
      initial.complete(_initialPin);
      await tester.pump(const Duration(minutes: 1));
      expect(pins.pin, isNull);
      expect(socket.closed, isTrue);
    },
  );
}

const _initialPin = TwitchPinnedChat(
  id: "initial-pin",
  message: TwitchChatMessage(id: "original", login: "mod", displayName: "Mod", text: "Welcome"),
);

Map<String, Object?> _eventPin(String id, {String type = "MOD", num? endsAt}) => {
  "id": id,
  "pinned_by": {"id": "99", "login": "pinner", "display_name": "Pinner"},
  "message": {
    "id": "message-$id",
    "type": type,
    "starts_at": 1642719340,
    "ends_at": endsAt,
    "sent_at": 1642719320,
    "sender": {
      "id": "77",
      "login": "alice",
      "display_name": "Alice",
      "chat_color": "#123456",
      "badges": [
        {"id": "moderator", "version": "1"},
      ],
    },
    "content": {
      "text": "😀 Kappa",
      "fragments": [
        {"text": "😀 "},
        {
          "text": "Kappa",
          "emoticon": {"emoticonID": "25"},
        },
      ],
    },
  },
  "parent_message": {
    "id": "parent",
    "sender": {"id": "88", "login": "parent", "display_name": "Parent"},
    "content": {
      "text": "😀 Kappa",
      "fragments": [
        {"text": "😀 "},
        {
          "text": "Kappa",
          "emoticon": {"emoticonID": "25"},
        },
      ],
    },
  },
  "thread_parent_message": {
    "id": "root",
    "sender": {"login": "original"},
  },
};

class _Socket extends Stream<Object?> implements WebSocket {
  final _incoming = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  void receive(Map<String, Object?> message) => _incoming.add(jsonEncode(message));

  void welcome() => receive({
    "type": "welcome",
    "welcome": {"keepaliveSec": 15},
  });

  void acknowledge() => receive({
    "type": "subscribeResponse",
    "parentId": sent.last["id"],
    "subscribeResponse": {"result": "ok"},
  });

  void event(String type, Map<String, Object?> data, {String? subscriptionId}) => receive({
    "type": "notification",
    "notification": {
      "type": "pubsub",
      "subscription": {
        "id": subscriptionId ?? (sent.last["subscribe"]! as Map<String, Object?>)["id"],
      },
      "pubsub": jsonEncode({"type": type, "data": data}),
    },
  });

  @override
  void add(Object? data) => sent.add(jsonDecode(data! as String) as Map<String, Object?>);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
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
