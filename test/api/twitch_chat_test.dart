import "dart:async";
import "dart:io";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late _ChatServer server;

  setUp(() async => server = await _ChatServer.start());
  tearDown(() => server.close());

  TwitchChatController controller({String channel = "channel", bool signedIn = true}) {
    final chat = TwitchChatController(
      channel: channel,
      clientLoader: () async => _Client(signedIn: signedIn),
      socketConnector: server.connect,
      loadPins: false,
    );
    addTearDown(chat.dispose);
    return chat;
  }

  test(
    "authenticates the saved account and parses only its channel, emotes and moderation",
    () async {
      final chat = controller(channel: " Channel ");
      await server.join(chat);
      expect(server.commands, contains("PASS oauth:web-token\r\n"));
      expect(server.commands, contains("NICK viewer\r\n"));
      expect(server.commands, contains("JOIN #channel\r\n"));
      expect(chat.canSend, isTrue);

      server.send(
        "PING :tmi.twitch.tv\r\n"
        "@followers-only=1;slow=10;emote-only=0 :tmi.twitch.tv ROOMSTATE #channel\r\n"
        "@id=wrong :other!other@tmi.twitch.tv PRIVMSG #another :wrong channel\r\n"
        "@id=one;user-id=456;first-msg=1;color=#12ABCD;display-name=Some\\sName;badges=moderator/1;emotes=25:2-6 "
        ":someone!someone@tmi.twitch.tv PRIVMSG #channel :😀 Kap",
      );
      server.send("pa\r\n@id=one :someone!someone@tmi.twitch.tv PRIVMSG #channel :duplicate\r\n");
      await _waitFor(() => chat.messages.length == 1);
      await _waitFor(() => server.commands.contains("PONG :tmi.twitch.tv\r\n"));
      final message = chat.messages.single;
      expect(message.text, "😀 Kappa");
      expect(message.displayName, "Some Name");
      expect(message.color, "#12ABCD");
      expect(message.badges, ["moderator/1"]);
      expect(message.userId, "456");
      expect(message.isFirstMessage, isTrue);
      expect(chat.roomState["followers-only"], "1");
      expect(chat.roomState["slow"], "10");
      expect(message.emotes.single.id, "25");
      expect(
        message.text.substring(message.emotes.single.start, message.emotes.single.end),
        "Kappa",
      );
      expect(() => chat.messages.clear(), throwsUnsupportedError);

      server.send(
        "@target-msg-id=one :tmi.twitch.tv CLEARMSG #another :wrong channel\r\n"
        "@id=two :someone!someone@tmi.twitch.tv PRIVMSG #channel :second\r\n",
      );
      await _waitFor(() => chat.messages.length == 2);
      expect(chat.messages.first.isDeleted, isFalse);
      server.send("@target-msg-id=one :tmi.twitch.tv CLEARMSG #channel :deleted\r\n");
      await _waitFor(() => chat.messages.first.isDeleted);
      expect(chat.messages.length, 2);
      expect(chat.messages.first.text, "😀 Kappa");
      expect(chat.messages.first.isFirstMessage, isTrue);
      expect(chat.messages.first.userId, "456");
      expect(chat.messages.first.badges, ["moderator/1"]);
      expect(chat.messages.first.emotes.single.id, "25");
      expect(chat.messages.last.isDeleted, isFalse);
      server.send(":tmi.twitch.tv CLEARCHAT #channel :someone\r\n");
      await _waitFor(() => chat.messages.every((message) => message.isDeleted));
      expect(chat.recentHistory.every((message) => message.isDeleted), isTrue);
    },
  );

  test("keeps only 300 recent messages and handles action and whole-room clear", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      List.generate(310, (i) => "@id=$i :person!p@tmi PRIVMSG #channel :message $i\r\n").join(),
    );
    await _waitFor(() => chat.messages.length == 300);
    expect(chat.messages.first.id, "10");
    server.send("@id=action :person!p@tmi PRIVMSG #channel :\u0001ACTION waves\u0001\r\n");
    await _waitFor(() => chat.messages.last.id == "action");
    expect(chat.messages.last.text, "waves");
    expect(chat.messages.last.isAction, isTrue);
    server.send(":tmi.twitch.tv CLEARCHAT #channel\r\n");
    await _waitFor(() => chat.messages.last.moderation == TwitchChatModeration.cleared);
    expect(chat.messages.take(299).every((message) => message.isDeleted), isTrue);
    expect(chat.messages.last.noticeText, "Chat was cleared.");
    expect(chat.messages.last.isDeleted, isFalse);
    expect(chat.messages.length, 300);
    expect(chat.recentHistory.length, 312);
  });

  test("retains reply parent and root context, including escaped original text", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      "@id=reply;reply-parent-msg-id=parent;reply-parent-user-id=77;reply-parent-user-login=alice;"
      "reply-parent-display-name=Alice;reply-parent-msg-body=hello\\sworld\\:\\sKappa;"
      "reply-thread-parent-msg-id=root;reply-thread-parent-user-login=original "
      ":bob!b@tmi PRIVMSG #channel :@alice yes\r\n"
      "@id=reply :bob!b@tmi PRIVMSG #channel :duplicate\r\n",
    );
    await _waitFor(() => chat.messages.isNotEmpty);
    final reply = chat.messages.single;
    expect(reply.parentMessageId, "parent");
    expect(reply.parentUserId, "77");
    expect(reply.parentLogin, "alice");
    expect(reply.parentDisplayName, "Alice");
    expect(reply.parentText, "hello world; Kappa");
    expect(reply.threadRootId, "root");
    expect(reply.threadRootLogin, "original");
    expect(chat.receivedMessageCount, 1);
    server.send("@target-msg-id=reply :tmi.twitch.tv CLEARMSG #channel :@alice yes\r\n");
    await _waitFor(() => chat.messages.single.isDeleted);
    expect(chat.messages.single.parentText, reply.parentText);
    expect(chat.messages.single.threadRootId, "root");
    expect(chat.receivedMessageCount, 1);
  });

  test("attaches timeout duration and permanent bans by stable user ID", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      "@id=one;user-id=77 :alice!a@tmi PRIVMSG #channel :first\r\n"
      "@id=two;user-id=77 :alice!a@tmi PRIVMSG #channel :second\r\n"
      "@id=other;user-id=88 :alice!a@tmi PRIVMSG #channel :different account\r\n"
      "@id=unknown :bob!b@tmi PRIVMSG #channel :no user id\r\n",
    );
    await _waitFor(() => chat.messages.length == 4);
    server.send(
      "@ban-duration=350;target-user-id=77;tmi-sent-ts=1642719320727 "
      ":tmi.twitch.tv CLEARCHAT #channel :alice\r\n",
    );
    await _waitFor(() => chat.messages.first.isDeleted);
    expect(chat.messages.take(2).every((message) => message.timeoutSeconds == 350), isTrue);
    expect(chat.messages.first.moderation, TwitchChatModeration.timeout);
    expect(chat.messages.first.moderatedAt?.millisecondsSinceEpoch, 1642719320727);
    expect(chat.messages[2].isDeleted, isFalse);
    expect(chat.messages[3].isDeleted, isFalse);
    server.send("@target-user-id=77 :tmi.twitch.tv CLEARCHAT #channel :alice\r\n");
    await _waitFor(() => chat.messages.first.moderation == TwitchChatModeration.ban);
    expect(chat.messages.first.timeoutSeconds, isNull);
    expect(chat.recentHistory.first.moderation, TwitchChatModeration.ban);
    server.send("@target-user-id=99 :tmi.twitch.tv CLEARCHAT #channel\r\n");
    await _waitFor(() => chat.messages.length == 5);
    expect(chat.messages[3].isDeleted, isFalse);
    expect(chat.messages.last.noticeType, "moderation");
    expect(chat.messages.last.isDeleted, isFalse);
    expect(chat.messages.last.noticeText, "A chatter was permanently banned.");
    server.send(
      "@ban-duration=60;target-user-id=100 :tmi.twitch.tv CLEARCHAT #channel :newchatter\r\n",
    );
    await _waitFor(() => chat.messages.length == 6);
    expect(chat.messages.last.noticeText, "newchatter was timed out for 60 seconds.");
  });

  test("retains subscription, announcement and raid notices with identity and system text", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      "@id=resub;msg-id=resub;login=ronni;user-id=456;display-name=Ronni;badges=subscriber/6;emotes=25:0-4;system-msg=Ronni\\ssubscribed\\sfor\\s6\\smonths! "
      ":tmi.twitch.tv USERNOTICE #channel :Kappa\r\n"
      "@id=announcement;msg-id=announcement;login=moderator;user-id=789;display-name=Moderator "
      ":tmi.twitch.tv USERNOTICE #channel :Welcome to the stream!\r\n"
      "@id=raid;msg-id=raid;login=raider;user-id=789;display-name=Raider;system-msg=100\\sraiders\\sjoined! "
      ":tmi.twitch.tv USERNOTICE #channel\r\n"
      "@id=wrong;msg-id=sub :tmi.twitch.tv USERNOTICE #another :ignored\r\n",
    );
    await _waitFor(() => chat.messages.length == 3);
    final subscription = chat.messages.first;
    expect(subscription.noticeType, "resub");
    expect(subscription.noticeText, "Ronni subscribed for 6 months!");
    expect(subscription.login, "ronni");
    expect(subscription.userId, "456");
    expect(subscription.badges, ["subscriber/6"]);
    expect(subscription.emotes.single.id, "25");
    expect(subscription.text, "Kappa");
    expect(chat.messages[1].noticeType, "announcement");
    expect(chat.messages[1].text, "Welcome to the stream!");
    expect(chat.messages.last.noticeType, "raid");
    expect(chat.messages.last.noticeText, "100 raiders joined!");
    expect(chat.messages.last.text, isEmpty);
  });

  test("keeps a bounded session history beyond the feed and marks older deletions", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      List.generate(5005, (i) => "@id=$i :person!p@tmi PRIVMSG #channel :message $i\r\n").join(),
    );
    await _waitFor(() => chat.recentHistory.length == 5000);
    expect(chat.messages.length, 300);
    expect(chat.recentHistory.first.id, "5");
    expect(chat.messages.first.id, "4705");
    expect(chat.receivedMessageCount, 5005);
    expect(() => chat.recentHistory.clear(), throwsUnsupportedError);
    server.send("@target-msg-id=10 :tmi.twitch.tv CLEARMSG #channel :deleted\r\n");
    await _waitFor(() => chat.recentHistory.singleWhere((item) => item.id == "10").isDeleted);
    expect(chat.messages.any((item) => item.isDeleted), isFalse);
    chat.reconnect();
    await server.join(chat, connection: 2);
    expect(chat.recentHistory.length, 5000);
    expect(chat.receivedMessageCount, 5006);
    expect(chat.recentHistory.singleWhere((item) => item.id == "10").text, "message 10");
  });

  test("awaits send confirmation, rejects invalid input and retains unconfirmed drafts", () async {
    final chat = controller();
    await server.join(chat);
    expect(await chat.send("hello\r\nJOIN #other"), isFalse);
    expect(await chat.send("a" * 501), isFalse);
    expect(server.commands.where((command) => command.startsWith("PRIVMSG")), isEmpty);

    final rejected = chat.send("first message");
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :first message\r\n"));
    expect(chat.messages, isEmpty);
    server.send("@msg-id=msg_subsonly :tmi.twitch.tv NOTICE #channel :Subscribers only\r\n");
    expect(await rejected, isFalse);
    expect(chat.error, "Subscribers only");
    expect(chat.messages, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 1050));
    const parent = TwitchChatMessage(
      id: "parent-id",
      login: "alice",
      displayName: "Alice",
      text: "Original message",
      userId: "77",
      threadRootId: "root-id",
      threadRootLogin: "original",
    );
    final sent = chat.send("second message", replyTo: parent);
    await _waitFor(
      () => server.commands.contains(
        "@reply-parent-msg-id=parent-id PRIVMSG #channel :second message\r\n",
      ),
    );
    server.send("@color=#FFFFFF :tmi.twitch.tv USERSTATE #channel\r\n");
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(chat.messages, isEmpty);
    server.send(
      "@id=sent-id;color=#FFFFFF;badges=subscriber/1 :tmi.twitch.tv USERSTATE #channel\r\n",
    );
    expect(await sent, isTrue);
    expect(chat.messages.single.id, "sent-id");
    expect(chat.messages.single.isOwn, isTrue);
    expect(chat.messages.single.text, "second message");
    expect(chat.messages.single.userId, "123");
    expect(chat.messages.single.badges, ["subscriber/1"]);
    expect(chat.messages.single.parentMessageId, "parent-id");
    expect(chat.messages.single.parentText, "Original message");
    expect(chat.messages.single.threadRootId, "root-id");
    expect(chat.receivedMessageCount, 1);
    expect(chat.error, isNull);
    expect(await chat.send("too fast"), isFalse);
    expect(chat.error, contains("too quickly"));

    await Future<void>.delayed(const Duration(milliseconds: 1050));
    final interrupted = chat.send("pending message");
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :pending message\r\n"));
    unawaited(server.sockets.last.close());
    expect(await interrupted, isFalse);
    expect(chat.status, TwitchChatStatus.reconnecting);
    expect(chat.messages.length, 1);
  });

  test("joins anonymously and reconnects automatically to the same channel", () async {
    final chat = controller(signedIn: false);
    await server.join(chat);
    expect(server.commands.where((command) => command.startsWith("PASS")), isEmpty);
    expect(chat.canSend, isFalse);
    expect(chat.isSignedIn, isFalse);
    expect(await chat.send("cannot send"), isFalse);
    server.send("@id=one :person!p@tmi PRIVMSG #channel :before loss\r\n");
    await _waitFor(() => chat.messages.isNotEmpty);
    unawaited(server.sockets.last.close());
    await _waitFor(() => chat.status == TwitchChatStatus.reconnecting);
    await _waitFor(() => server.sockets.length == 2);
    await server.join(chat, connection: 2);
    expect(chat.messages.single.text, "before loss");
    expect(server.commands.where((command) => command == "JOIN #channel\r\n").length, 2);
    server.send(":tmi.twitch.tv RECONNECT\r\n");
    await _waitFor(() => chat.status == TwitchChatStatus.reconnecting);
    chat.reconnect();
    await server.join(chat, connection: 3);
    expect(chat.status, TwitchChatStatus.connected);
  });

  test(
    "falls back to reading when Twitch rejects sign-in, without retrying bad credentials",
    () async {
      final chat = controller();
      await _waitFor(() => server.commands.contains("JOIN #channel\r\n"));
      server.send(":tmi.twitch.tv NOTICE * :Login authentication failed\r\n");
      await server.join(chat, connection: 2);
      expect(chat.canSend, isFalse);
      expect(chat.error, contains("Sign in again"));
      expect(server.commands.where((command) => command.startsWith("PASS")).length, 1);
      chat.reconnect();
      await server.join(chat, connection: 3);
      expect(chat.canSend, isTrue);
      expect(chat.error, isNull);
    },
  );

  test("disposal prevents stale credential loads from opening a previous channel", () async {
    final client = Completer<TwitchApiClient>();
    final previous = TwitchChatController(
      channel: "previous",
      clientLoader: () => client.future,
      socketConnector: server.connect,
    );
    previous.dispose();
    final current = controller();
    await server.join(current);
    client.complete(_Client());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.sockets.length, 1);
    expect(server.commands, isNot(contains("JOIN #previous\r\n")));
  });

  test("invalid channel cannot inject IRC commands or schedule a connection", () async {
    final chat = controller(channel: "channel\r\nJOIN #other");
    expect(chat.status, TwitchChatStatus.disconnected);
    chat.reconnect();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(server.sockets, isEmpty);
  });

  testWidgets("disposing an unfinished socket connection cancels its deadline", (tester) async {
    final opening = Completer<WebSocket>();
    var attempts = 0;
    final chat = TwitchChatController(
      clientLoader: () async => _Client(signedIn: false),
      channel: "channel",
      socketConnector: () {
        attempts++;
        return opening.future;
      },
    );
    await tester.pump();
    expect(attempts, 1);
    chat.dispose();
    await tester.pump(const Duration(seconds: 16));
    expect(attempts, 1);
  });
}

class _Client extends TwitchApiClient {
  _Client({bool signedIn = true})
    : super(
        clientId: "test",
        accessToken: signedIn ? "oauth-token" : "",
        gqlAccessToken: signedIn ? "web-token" : null,
      );

  @override
  Future<TwitchUser> fetchCurrentUser() async => const TwitchUser(
    id: "123",
    login: "Viewer",
    displayName: "Viewer",
  );
}

class _ChatServer {
  _ChatServer(this.server) {
    subscription = server.transform(WebSocketTransformer()).listen((socket) {
      sockets.add(socket);
      socket.cast<Object?>().listen((data) {
        if (data is String) {
          commands.add(data);
        }
      });
    });
  }

  final HttpServer server;
  late final StreamSubscription<WebSocket> subscription;
  final List<WebSocket> sockets = [];
  final List<String> commands = [];

  static Future<_ChatServer> start() async =>
      _ChatServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<WebSocket> connect() => WebSocket.connect("ws://127.0.0.1:${server.port}");

  void send(String message) => sockets.last.add(message);

  Future<void> join(TwitchChatController chat, {int connection = 1}) async {
    await _waitFor(
      () =>
          commands.where((command) => command == "JOIN #${chat.channel}\r\n").length >= connection,
    );
    send(
      "@color=#123456 :tmi.twitch.tv USERSTATE #${chat.channel}\r\n"
      "@room-id=1 :tmi.twitch.tv ROOMSTATE #${chat.channel}\r\n",
    );
    await _waitFor(() => chat.status == TwitchChatStatus.connected);
  }

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await subscription.cancel();
    await server.close(force: true);
  }
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail("Chat did not reach the expected state before timeout.");
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
