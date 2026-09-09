import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_private_chat.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/testing.dart";

void main() {
  TwitchApiClient client() => TwitchApiClient(
    clientId: "test",
    accessToken: "",
    gqlAccessToken: "web-token",
    httpClient: MockClient((_) async => fail("Achievement events must not query GraphQL.")),
  );

  testWidgets(
    "authenticates and publishes only actual Twitch achievement events for this channel",
    (tester) async {
      final socket = _Socket();
      final notices = <String>[];
      final service = TwitchPrivateChatNotices(
        channelId: "1",
        userId: "123",
        clientLoader: () async => client(),
        socketConnector: () async => socket,
        onNotice: ({required id, required type, required text}) => notices.add("$id|$type|$text"),
      );
      await tester.pump();
      expect(socket.sent, isEmpty);
      socket.welcome();
      final auth = socket.sent.last;
      expect(auth["authenticate"], {"token": "web-token"});
      socket.receive({
        "type": "authenticateResponse",
        "parentId": "other",
        "authenticateResponse": {"result": "ok"},
      });
      expect(socket.sent, hasLength(1));
      socket.authenticate();
      expect((socket.sent.last["subscribe"]! as Map)["pubsub"], {"topic": "viewer-milestones.123"});
      socket.subscribe();
      await tester.pump(const Duration(minutes: 1));
      expect(notices, isEmpty);
      for (final event in [
        {
          "type": "watch-streak",
          "data": {"channel_id": "1", "watch_streak_value": "7"},
        },
        {
          "type": "viewer-milestones-update",
          "data": {"event_type": "updated", "channel_id": "1", "watch_streak_value": "7"},
        },
        {
          "type": "viewer-milestones-update",
          "data": {"event_type": "achieved", "channel_id": "2", "watch_streak_value": "7"},
        },
        {
          "type": "viewer-milestones-update",
          "data": {"event_type": "achieved", "channel_id": "1", "watch_streak_value": "0"},
        },
      ]) {
        socket.event("ignored", event);
      }
      await tester.pump();
      expect(notices, isEmpty);
      socket.event("real-event", _achievement);
      await tester.pump();
      expect(notices, [
        "watch-streak:real-event|watch-streak|You reached a 7-stream watch streak!",
      ]);
      service.dispose();
    },
  );

  testWidgets("authentication rejection retries without subscribing or publishing", (tester) async {
    final sockets = <_Socket>[];
    final service = TwitchPrivateChatNotices(
      channelId: "1",
      userId: "123",
      clientLoader: () async => client(),
      socketConnector: () async {
        final socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      onNotice: ({required id, required type, required text}) => fail("No unauthenticated notice"),
    );
    await tester.pump();
    sockets.first.welcome();
    sockets.first.authenticate(result: "error");
    await tester.pump();
    expect(sockets.first.closed, isTrue);
    expect(sockets.first.sent, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(sockets, hasLength(2));
    expect(sockets.last.sent, isEmpty);
    service.dispose();
  });

  testWidgets("a missing web token retries when the session becomes available", (tester) async {
    var hasToken = false;
    var connections = 0;
    final socket = _Socket();
    final service = TwitchPrivateChatNotices(
      channelId: "1",
      userId: "123",
      clientLoader: () async =>
          hasToken ? client() : TwitchApiClient(clientId: "test", accessToken: ""),
      socketConnector: () async {
        connections++;
        return socket;
      },
      onNotice: ({required id, required type, required text}) => fail("No achievement received"),
    );
    await tester.pump();
    expect(connections, 0);
    hasToken = true;
    await tester.pump(const Duration(seconds: 1));
    expect(connections, 1);
    socket.welcome();
    expect(socket.sent.last["authenticate"], {"token": "web-token"});
    service.dispose();
  });

  testWidgets("revoked subscriptions reconnect and require a fresh authenticated subscription", (
    tester,
  ) async {
    final sockets = <_Socket>[];
    final notices = <String>[];
    final service = TwitchPrivateChatNotices(
      channelId: "1",
      userId: "123",
      clientLoader: () async => client(),
      socketConnector: () async {
        final socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      onNotice: ({required id, required type, required text}) => notices.add(id),
    );
    await tester.pump();
    sockets.first
      ..welcome()
      ..authenticate()
      ..subscribe();
    sockets.first.receive({"type": "subscriptionRevocation"});
    await tester.pump(const Duration(seconds: 1));
    expect(sockets, hasLength(2));
    sockets.last
      ..welcome()
      ..authenticate()
      ..subscribe();
    sockets.last.event("fresh", _achievement);
    await tester.pump();
    expect(notices, ["watch-streak:fresh"]);
    service.dispose();
  });

  testWidgets("disposal blocks pending credential validation and late socket connections", (
    tester,
  ) async {
    final pending = Completer<TwitchApiClient>();
    final socket = _Socket();
    var validate = false;
    final notices = <String>[];
    final service = TwitchPrivateChatNotices(
      channelId: "1",
      userId: "123",
      clientLoader: () => validate ? pending.future : Future.value(client()),
      socketConnector: () async => socket,
      onNotice: ({required id, required type, required text}) => notices.add(id),
    );
    await tester.pump();
    socket
      ..welcome()
      ..authenticate()
      ..subscribe();
    validate = true;
    socket.event("late", _achievement);
    await tester.pump();
    service.dispose();
    pending.complete(client());
    await tester.pump(const Duration(minutes: 2));
    expect(notices, isEmpty);
    expect(socket.closed, isTrue);

    final opening = Completer<WebSocket>();
    final lateService = TwitchPrivateChatNotices(
      channelId: "1",
      userId: "123",
      clientLoader: () async => client(),
      socketConnector: () => opening.future,
      onNotice: ({required id, required type, required text}) => fail("Disposed"),
    );
    await tester.pump();
    lateService.dispose();
    final lateSocket = _Socket();
    opening.complete(lateSocket);
    await tester.pump(const Duration(seconds: 20));
    expect(lateSocket.closed, isTrue);
    expect(lateSocket.sent, isEmpty);
  });
}

const _achievement = {
  "type": "viewer-milestones-update",
  "data": {"event_type": "achieved", "channel_id": "1", "watch_streak_value": "7"},
};

class _Socket extends Stream<Object?> implements WebSocket {
  final _incoming = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  void receive(Map<String, Object?> message) => _incoming.add(jsonEncode(message));
  void welcome() => receive({
    "type": "welcome",
    "welcome": {"keepaliveSec": 600},
  });
  void authenticate({String result = "ok"}) => receive({
    "type": "authenticateResponse",
    "parentId": sent.last["id"],
    "authenticateResponse": {"result": result},
  });
  void subscribe() => receive({
    "type": "subscribeResponse",
    "parentId": sent.last["id"],
    "subscribeResponse": {"result": "ok"},
  });
  void event(String id, Map<String, Object?> event) => receive({
    "type": "notification",
    "id": id,
    "notification": {
      "type": "pubsub",
      "subscription": {"id": (sent.last["subscribe"]! as Map)["id"]},
      "pubsub": jsonEncode(event),
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
