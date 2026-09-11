import "dart:async";
import "dart:convert";
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
      loadPrivateNotices: false,
    );
    addTearDown(chat.dispose);
    return chat;
  }

  Future<TwitchChatController> historyChat(
    WidgetTester tester,
    _Client client,
    _Socket socket,
  ) async {
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: () async => socket,
      loadPins: false,
      loadPrivateNotices: false,
    );
    await tester.pump();
    expect(client.historyLoads, 0);
    socket._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await tester.pump();
    expect(client.historyLoads, 1);
    return chat;
  }

  testWidgets(
    "merges recent history chronologically without replacing live messages or unread counts",
    (
      tester,
    ) async {
      final response = Completer<List<TwitchChatMessage>>();
      final client = _Client()..loadHistory = () => response.future;
      final socket = _Socket();
      final chat = await historyChat(tester, client, socket);
      socket._incoming.add(
        "@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n"
        "@id=live;tmi-sent-ts=3000 :alice!a@tmi PRIVMSG #channel :live version\r\n"
        "@id=new;tmi-sent-ts=4000 :alice!a@tmi PRIVMSG #channel :new message\r\n",
      );
      await tester.pump();
      expect(client.historyLoads, 1);
      response.complete([
        _historyMessage("own", 2000, userId: "123"),
        _historyMessage("live", 3000, text: "stale snapshot"),
        _historyMessage("first", 1000),
        _historyMessage("first", 1000, text: "snapshot duplicate"),
      ]);
      await tester.pump();
      expect(chat.conversation.map((message) => message.id), ["first", "own", "live", "new"]);
      expect(chat.conversation[2].text, "live version");
      expect(chat.conversation[2].isHistorical, isFalse);
      expect(chat.conversation[1].isOwn, isTrue);
      expect(chat.conversation[1].isHistorical, isTrue);
      expect(chat.conversation[1].copyWith(isDeleted: true).isHistorical, isTrue);
      expect(chat.receivedMessageCount, 2);

      socket._incoming.add(
        "@id=own;user-id=123;display-name=Viewer;color=#123456;badges=subscriber/12;tmi-sent-ts=2000 :viewer!v@tmi PRIVMSG #channel :IRC metadata\r\n"
        "@id=own;tmi-sent-ts=2000 :viewer!v@tmi PRIVMSG #channel :duplicate IRC\r\n",
      );
      await tester.pump();
      final own = chat.conversation.singleWhere((message) => message.id == "own");
      expect(own.text, "IRC metadata");
      expect(own.color, "#123456");
      expect(own.badges, ["subscriber/12"]);
      expect(own.isHistorical, isTrue);
      expect(chat.receivedMessageCount, 2);
      expect(chat.conversation, hasLength(4));
      chat.dispose();
    },
  );

  testWidgets("in-flight history respects unknown deletes, user moderation and whole-room clears", (
    tester,
  ) async {
    final response = Completer<List<TwitchChatMessage>>();
    final client = _Client()..loadHistory = () => response.future;
    final socket = _Socket();
    final chat = await historyChat(tester, client, socket);
    socket._incoming.add(
      "@target-msg-id=deleted;tmi-sent-ts=10000 :tmi.twitch.tv CLEARMSG #channel :gone\r\n"
      "@target-msg-id=late-live;tmi-sent-ts=10000 :tmi.twitch.tv CLEARMSG #channel :gone\r\n"
      "@target-user-id=77;ban-duration=60;tmi-sent-ts=11000 :tmi.twitch.tv CLEARCHAT #channel :oldlogin\r\n"
      "@tmi-sent-ts=12000 :tmi.twitch.tv CLEARCHAT #channel :loginonly\r\n"
      "@tmi-sent-ts=14000 :tmi.twitch.tv CLEARCHAT #channel\r\n"
      "@id=late-live;tmi-sent-ts=9000 :alice!a@tmi PRIVMSG #channel :late deleted IRC\r\n"
      "@id=after-clear;tmi-sent-ts=15000 :alice!a@tmi PRIVMSG #channel :after clear\r\n",
    );
    final countBefore = chat.receivedMessageCount;
    response.complete([
      _historyMessage("deleted", 8000),
      _historyMessage("timed-out", 8000, userId: "77", login: "newlogin"),
      _historyMessage("banned", 8000, login: "loginonly"),
      _historyMessage("cleared", 8000),
      _historyMessage("late-live", 9000),
      _historyMessage("after-clear", 15000),
      _historyMessage("new-history", 16000),
    ]);
    await tester.pump();
    TwitchChatMessage message(String id) =>
        chat.messages.singleWhere((message) => message.id == id);
    expect(message("deleted").moderation, TwitchChatModeration.deleted);
    expect(message("timed-out").moderation, TwitchChatModeration.timeout);
    expect(message("timed-out").timeoutSeconds, 60);
    expect(message("banned").moderation, TwitchChatModeration.ban);
    expect(message("cleared").moderation, TwitchChatModeration.cleared);
    expect(message("late-live").isDeleted, isTrue);
    expect(message("late-live").text, "late deleted IRC");
    expect(message("after-clear").isDeleted, isFalse);
    expect(message("new-history").isDeleted, isFalse);
    expect(chat.receivedMessageCount, countBefore);

    socket._incoming.add(
      "@id=timed-out;user-id=77;tmi-sent-ts=8000 :newlogin!a@tmi PRIVMSG #channel :late metadata\r\n",
    );
    await tester.pump();
    expect(message("timed-out").text, "late metadata");
    expect(message("timed-out").isDeleted, isTrue);
    expect(message("timed-out").moderation, TwitchChatModeration.timeout);
    expect(message("timed-out").isHistorical, isTrue);
    expect(chat.receivedMessageCount, countBefore);
    chat.dispose();
  });

  testWidgets("keeps the newest 300 feed and 5000 history rows after an initial snapshot", (
    tester,
  ) async {
    final client = _Client()
      ..loadHistory = () async => [
        for (var index = 0; index < 5005; index++) _historyMessage("history-$index", index),
      ];
    final socket = _Socket();
    final chat = await historyChat(tester, client, socket);
    expect(chat.messages, hasLength(300));
    expect(chat.recentHistory, hasLength(5000));
    expect(chat.recentHistory.first.id, "history-7");
    expect(chat.receivedMessageCount, 0);
    final timestamps = chat.recentHistory.map((message) => message.timestamp!).toList();
    expect(timestamps, orderedEquals([...timestamps]..sort()));
    chat.dispose();
  });

  testWidgets("ignores old connection and disposed history results and leaves failures nonfatal", (
    tester,
  ) async {
    final first = Completer<List<TwitchChatMessage>>();
    final second = Completer<List<TwitchChatMessage>>();
    final client = _Client();
    client.loadHistory = () => client.historyLoads == 1 ? first.future : second.future;
    final sockets = <_Socket>[];
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: () async {
        final socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      loadPins: false,
      loadPrivateNotices: false,
    );
    await tester.pump();
    sockets.first._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await tester.pump();
    chat.reconnect();
    await tester.pump();
    sockets.last._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await tester.pump();
    expect(client.historyLoads, 2);
    first.complete([_historyMessage("stale", 1000)]);
    await tester.pump();
    expect(chat.conversation, isEmpty);
    second.completeError(TwitchApiException("History unavailable"));
    await tester.pump();
    expect(chat.status, TwitchChatStatus.connected);
    expect(chat.error, isNull);
    sockets.last._incoming.add("@id=live :alice!a@tmi PRIVMSG #channel :still connected\r\n");
    await tester.pump();
    expect(chat.conversation.single.text, "still connected");
    final disposed = Completer<List<TwitchChatMessage>>();
    client.loadHistory = () => disposed.future;
    chat.reconnect();
    await tester.pump();
    sockets.last._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await tester.pump();
    chat.dispose();
    disposed.complete([_historyMessage("disposed", 1000)]);
    await tester.pump(const Duration(seconds: 20));
    expect(chat.conversation.map((message) => message.id), ["live"]);
  });

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
      await _waitFor(() => chat.conversation.length == 1);
      await _waitFor(() => server.commands.contains("PONG :tmi.twitch.tv\r\n"));
      final message = chat.conversation.single;
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
      await _waitFor(() => chat.conversation.length == 2);
      expect(chat.conversation.first.isDeleted, isFalse);
      server.send("@target-msg-id=one :tmi.twitch.tv CLEARMSG #channel :deleted\r\n");
      await _waitFor(() => chat.conversation.first.isDeleted);
      expect(chat.conversation.length, 2);
      expect(chat.conversation.first.text, "😀 Kappa");
      expect(chat.conversation.first.isFirstMessage, isTrue);
      expect(chat.conversation.first.userId, "456");
      expect(chat.conversation.first.badges, ["moderator/1"]);
      expect(chat.conversation.first.emotes.single.id, "25");
      expect(chat.conversation.last.isDeleted, isFalse);
      server.send(":tmi.twitch.tv CLEARCHAT #channel :someone\r\n");
      await _waitFor(() => chat.conversation.every((message) => message.isDeleted));
      expect(chat.conversationHistory.every((message) => message.isDeleted), isTrue);
    },
  );

  testWidgets("retries failed recent history on the next room state", (tester) async {
    final client = _Client()
      ..loadHistory = () => Future.error(TwitchApiException("Temporary history failure"));
    final socket = _Socket();
    final chat = await historyChat(tester, client, socket);
    client.loadHistory = () async => [_historyMessage("retry", 1000)];
    socket._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await tester.pump();
    expect(client.historyLoads, 2);
    expect(chat.conversation.single.id, "retry");
    socket._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await tester.pump();
    expect(client.historyLoads, 2);
    chat.dispose();
  });

  test("retains highlighted chat and identifies only watch-streak milestone notices", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      "@id=highlight;msg-id=highlighted-message :viewer!v@tmi PRIVMSG #channel :Highlighted chat\r\n"
      "@id=ordinary :viewer!v@tmi PRIVMSG #channel :Normal chat\r\n"
      "@id=streak;msg-id=viewermilestone;msg-param-category=watch-streak;system-msg=Watched\\s3\\sstreams "
      ":tmi.twitch.tv USERNOTICE #channel\r\n"
      "@id=other;msg-id=viewermilestone;msg-param-category=other "
      ":tmi.twitch.tv USERNOTICE #channel\r\n",
    );
    await _waitFor(() => chat.conversation.length == 4);
    expect(chat.conversation.first.isHighlighted, isTrue);
    expect(chat.conversation.first.noticeType, isNull);
    expect(chat.conversation[1].isHighlighted, isFalse);
    expect(chat.conversation[2].noticeType, "watch-streak");
    expect(chat.conversation[2].noticeText, "Watched 3 streams");
    expect(chat.conversation[2].isHighlighted, isFalse);
    expect(chat.conversation[3].noticeType, "viewermilestone");
    server.send("@target-msg-id=highlight :tmi.twitch.tv CLEARMSG #channel :Highlighted chat\r\n");
    await _waitFor(() => chat.conversation.first.isDeleted);
    expect(chat.conversation.first.isHighlighted, isTrue);
    expect(chat.conversationHistory.first.isHighlighted, isTrue);
  });

  test(
    "receives Twitch native GIF ranges and preserves their full URLs through replies and moderation",
    () async {
      // Official Twitch IRC GIF example: https://dev.twitch.tv/docs/chat/irc/#privmsg-tags
      const label = "[Y A Y Yes GIF by Djemilah Birnie]";
      const url =
          "https://media4.giphy.com/media/joSNxeswxuc74Juo8X/giphy.gif?cid=095d7a5dzizsiwgabonagkmigggv8v1spfai91ac3x0dsiy0&ep=v1_gifs_trending&rid=giphy.gif&ct=g";
      final chat = controller();
      await server.join(chat);
      expect(chat.currentUserLogin, "viewer");
      final end = 2 + label.runes.length - 1;
      server.send(
        "@id=gif;gifs=2-$end|joSNxeswxuc74Juo8X|$url;emotes=25:${end + 2}-${end + 6} :other!o@tmi PRIVMSG #channel :😀 $label Kappa\r\n",
      );
      await _waitFor(() => chat.conversation.length == 1);
      final message = chat.conversation.single;
      final gif = message.gifs.single;
      expect(gif.id, "joSNxeswxuc74Juo8X");
      expect(gif.url, url);
      expect(gif.start, 3);
      expect(message.text.substring(gif.start, gif.end), label);
      expect(
        message.text.substring(message.emotes.single.start, message.emotes.single.end),
        "Kappa",
      );
      final escapedParent = message.text.replaceAll(" ", r"\s");
      server.send(
        "@id=gif-reply;reply-parent-msg-id=gif;reply-parent-user-login=other;reply-parent-msg-body=$escapedParent :another!a@tmi PRIVMSG #channel :Reply\r\n"
        "@id=gif-invalid;gifs=0-999|outside|$url,9-1|backwards|$url,0-1|bad-url|file:///bad.gif,invalid :other!o@tmi PRIVMSG #channel :plain text\r\n",
      );
      await _waitFor(() => chat.conversation.length == 3);
      expect(chat.conversation[1].parentGifs.single, same(gif));
      expect(chat.conversation.last.gifs, isEmpty);
      server.send("@target-msg-id=gif :tmi.twitch.tv CLEARMSG #channel :deleted\r\n");
      await _waitFor(() => chat.conversation.first.isDeleted);
      expect(chat.conversation.first.gifs.single.url, url);
      expect(chat.conversation.first.copyWith(isHistorical: true).gifs.single, same(gif));
    },
  );

  test(
    "records connection transitions once and keeps userless notices through reconnect and moderation",
    () async {
      final chat = controller();
      expect(chat.messages.single.noticeText, "Connecting to chat...");
      await server.join(chat);
      expect(chat.messages.last.noticeText, "Welcome to channel's Chat!");
      expect(chat.messages.every((message) => message.noticeType == "system"), isTrue);
      expect(chat.messages.every((message) => message.login.isEmpty), isTrue);
      expect(chat.receivedMessageCount, 0);
      chat.addSystemMessage("Chat is delayed by 2.5 seconds.");
      expect(chat.messages.length, 3);
      server.send(":tmi.twitch.tv CLEARCHAT #channel\r\n");
      await _waitFor(() => chat.messages.length == 4);
      expect(chat.messages.take(3).every((message) => !message.isDeleted), isTrue);
      chat.reconnect();
      await server.join(chat, connection: 2);
      expect(
        chat.messages.where((message) => message.noticeText == "Welcome to channel's Chat!"),
        hasLength(1),
      );
      expect(
        chat.messages.where((message) => message.noticeText == "Reconnecting to chat..."),
        hasLength(1),
      );
      server.send(":tmi.twitch.tv RECONNECT\r\n:tmi.twitch.tv RECONNECT\r\n");
      await _waitFor(() => chat.status == TwitchChatStatus.reconnecting);
      chat.reconnect();
      await server.join(chat, connection: 3);
      expect(
        chat.messages.where((message) => message.noticeText == "Reconnecting to chat..."),
        hasLength(2),
      );
    },
  );

  test("system countdown updates preserve the row order, timestamp, and history", () async {
    final chat = controller();
    await server.join(chat);
    chat.upsertSystemMessage("system-sync", "Chat will sync in 3s...");
    final original = chat.messages.last;
    server.send("@id=one :person!p@tmi PRIVMSG #channel :hello\r\n");
    await _waitFor(() => chat.conversation.length == 1);
    final ids = chat.messages.map((message) => message.id).toList();
    for (var seconds = 2; seconds >= 0; seconds--) {
      chat.upsertSystemMessage("system-sync", "Chat will sync in ${seconds}s...");
    }
    expect(chat.messages.map((message) => message.id), ids);
    final updated = chat.messages.singleWhere((message) => message.id == "system-sync");
    expect(updated.noticeText, "Chat will sync in 0s...");
    expect(updated.timestamp, original.timestamp);
    expect(updated.login, isEmpty);
    chat.upsertSystemMessage("system-sync", "Chat will sync in 0s...");
    expect(chat.messages.singleWhere((message) => message.id == "system-sync"), same(updated));
    expect(
      chat.recentHistory.singleWhere((message) => message.id == "system-sync").noticeText,
      updated.noticeText,
    );
    expect(chat.receivedMessageCount, 1);
  });

  test(
    "followers-only mode blocks outgoing chat until confirmed following and the duration elapses",
    () async {
      final client = _Client();
      final chat = TwitchChatController(
        channel: "channel",
        clientLoader: () async => client,
        socketConnector: server.connect,
        loadPins: false,
        loadPrivateNotices: false,
      );
      addTearDown(chat.dispose);
      await server.join(chat);
      server.send("@followers-only=0 :tmi.twitch.tv ROOMSTATE #channel\r\n");
      await _waitFor(() => chat.followersOnlyMinutes == 0 && !chat.isCheckingChatAccess);
      expect(chat.canSend, isFalse);
      expect(await chat.send("Blocked"), isFalse);
      expect(server.commands.any((command) => command.contains("PRIVMSG")), isFalse);
      expect(await chat.followChannel(), isTrue);
      expect(client.followCalls, 1);
      expect(chat.chatAccess?.isFollowing, isTrue);
      expect(chat.canSend, isTrue);
      client.access = TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Channel",
        rules: [],
        isFollowing: true,
        followedAt: DateTime.now(),
      );
      server.send("@followers-only=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
      await _waitFor(() => chat.followersOnlyMinutes == 1 && !chat.isCheckingChatAccess);
      expect(chat.canSend, isFalse);
      expect(chat.followingWaitRemaining, greaterThan(const Duration(seconds: 55)));
      client.access = TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Channel",
        rules: [],
        isFollowing: true,
        followedAt: DateTime.now().subtract(const Duration(milliseconds: 59800)),
      );
      await chat.refreshChatAccess();
      await _waitFor(() => chat.canSend);
      expect(chat.followingWaitRemaining, Duration.zero);
      expect(server.commands.any((command) => command.contains("PRIVMSG")), isFalse);
    },
  );

  test(
    "unfollow retains eligibility until acknowledged and preserves following on failure",
    () async {
      final client = _Client()
        ..access = TwitchChatAccess(
          channelId: "1",
          channelDisplayName: "Channel",
          rules: ["Be kind"],
          isFollowing: true,
          followedAt: DateTime.now().subtract(const Duration(days: 1)),
        );
      final chat = TwitchChatController(
        channel: "channel",
        clientLoader: () async => client,
        socketConnector: server.connect,
        loadPins: false,
        loadPrivateNotices: false,
      );
      addTearDown(chat.dispose);
      await server.join(chat);
      server.send("@followers-only=0 :tmi.twitch.tv ROOMSTATE #channel\r\n");
      await _waitFor(() => chat.followersOnlyMinutes == 0 && !chat.isCheckingChatAccess);
      final failed = Completer<void>();
      client.onUnfollow = () => failed.future;
      final rejected = chat.unfollowChannel();
      await _waitFor(() => client.unfollowCalls == 1);
      expect(chat.isFollowingChannel, isTrue);
      expect(chat.chatAccess?.isFollowing, isTrue);
      expect(chat.canSend, isTrue);
      expect(await chat.followChannel(), isFalse);
      failed.completeError(TwitchApiException("Unfollow failed"));
      expect(await rejected, isFalse);
      expect(chat.isFollowingChannel, isFalse);
      expect(chat.chatAccess?.isFollowing, isTrue);
      expect(chat.chatAccessError, "Unfollow failed");
      expect(chat.canSend, isTrue);

      final accepted = Completer<void>();
      client.onUnfollow = () => accepted.future;
      final unfollowed = chat.unfollowChannel();
      await _waitFor(() => client.unfollowCalls == 2);
      expect(chat.chatAccess?.isFollowing, isTrue);
      accepted.complete();
      expect(await unfollowed, isTrue);
      expect(chat.isFollowingChannel, isFalse);
      expect(chat.chatAccess?.isFollowing, isFalse);
      expect(chat.chatAccess?.followedAt, isNull);
      expect(chat.chatAccess?.rules, ["Be kind"]);
      expect(chat.chatAccessError, isNull);
      expect(chat.followingWaitRemaining, Duration.zero);
      expect(chat.canSend, isFalse);
      expect(await chat.unfollowChannel(), isTrue);
      expect(client.unfollowCalls, 2);
    },
  );

  test("subscribers-only chat preserves subscriber and privileged access and refreshes", () async {
    final client = _Client();
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: server.connect,
      loadPins: false,
      loadPrivateNotices: false,
    );
    addTearDown(chat.dispose);
    await server.join(chat);
    server.send("@subs-only=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.roomState["subs-only"] == "1" && !chat.isCheckingChatAccess);
    expect(chat.subscriberChatEligible, isFalse);
    expect(await chat.send("Blocked"), isFalse);
    expect(server.commands.any((command) => command.contains("PRIVMSG")), isFalse);
    for (final role in ["subscriber", "founder", "moderator", "broadcaster", "vip"]) {
      server.send("@badges=$role/1 :tmi.twitch.tv USERSTATE #channel\r\n");
      await _waitFor(() => chat.canSend);
      server.send("@badges=;subscriber=0;mod=0 :tmi.twitch.tv USERSTATE #channel\r\n");
      await _waitFor(() => !chat.canSend);
    }
    server.send("@badges=;subscriber=1 :tmi.twitch.tv USERSTATE #channel\r\n");
    await _waitFor(() => chat.canSend);
    server.send("@msg-id=msg_subsonly :tmi.twitch.tv NOTICE #channel :Subscribers only.\r\n");
    await _waitFor(() => !chat.canSend && !chat.isCheckingChatAccess);
    expect(chat.error, isNull);
    client.subscribed = true;
    await chat.refreshChatAccess();
    expect(chat.canSend, isTrue);
    client.subscribed = false;
    server.send("@badges= :tmi.twitch.tv USERSTATE #channel\r\n");
    await _waitFor(() => !chat.canSend);
    server.send("@subs-only=0 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.canSend);
  });

  for (final subscribed in [false, true]) {
    test(
      "newer USERSTATE subscriber=$subscribed supersedes a pending subscription query",
      () async {
        final requested = Completer<void>();
        final response = Completer<bool>();
        final client = _Client()
          ..loadSubscription = () {
            requested.complete();
            return response.future;
          };
        final chat = TwitchChatController(
          channel: "channel",
          clientLoader: () async => client,
          socketConnector: server.connect,
          loadPins: false,
          loadPrivateNotices: false,
        );
        addTearDown(chat.dispose);
        await server.join(chat);
        server.send("@subs-only=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
        await requested.future;
        server.send(
          "@subscriber=${subscribed ? 1 : 0} :tmi.twitch.tv USERSTATE #channel\r\n"
          "PING :subscription-state\r\n",
        );
        await _waitFor(() => server.commands.contains("PONG :subscription-state\r\n"));
        response.complete(!subscribed);
        await _waitFor(() => !chat.isCheckingChatAccess);
        expect(chat.subscriberChatEligible, subscribed);
      },
    );
  }

  test("moderators, VIPs, and the broadcaster bypass the follower wait", () async {
    final client = _Client();
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: server.connect,
      loadPins: false,
      loadPrivateNotices: false,
    );
    addTearDown(chat.dispose);
    await server.join(chat);
    server.send("@followers-only=100 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.followersOnlyMinutes == 100 && !chat.isCheckingChatAccess);
    for (final role in ["moderator", "vip", "broadcaster"]) {
      server.send("@badges=$role/1 :tmi.twitch.tv USERSTATE #channel\r\n");
      await _waitFor(() => chat.canSend);
      server.send("@badges= :tmi.twitch.tv USERSTATE #channel\r\n");
      await _waitFor(() => !chat.canSend);
    }
    client.access = const TwitchChatAccess(
      channelId: "1",
      channelDisplayName: "Channel",
      rules: [],
      isVip: true,
    );
    await chat.refreshChatAccess();
    expect(chat.canSend, isTrue);
  });

  test(
    "unknown follower status stays blocked and follower rejections refresh without a red error",
    () async {
      final pending = Completer<TwitchChatAccess>();
      final client = _Client()..loadAccess = () => pending.future;
      final chat = TwitchChatController(
        channel: "channel",
        clientLoader: () async => client,
        socketConnector: server.connect,
        loadPins: false,
        loadPrivateNotices: false,
      );
      addTearDown(chat.dispose);
      await server.join(chat);
      server.send("@followers-only=0 :tmi.twitch.tv ROOMSTATE #channel\r\n");
      await _waitFor(() => chat.followersOnlyMinutes == 0);
      expect(chat.isCheckingChatAccess, isTrue);
      expect(chat.canSend, isFalse);
      pending.completeError(TwitchApiException("Status unavailable"));
      await _waitFor(() => !chat.isCheckingChatAccess);
      expect(chat.chatAccessError, "Status unavailable");
      expect(chat.canSend, isFalse);
      client.loadAccess = null;
      client.access = const TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Channel",
        rules: [],
        isFollowing: true,
      );
      server.send(
        "@msg-id=msg_followersonly_zero :tmi.twitch.tv NOTICE #channel :Old followers-only error\r\n",
      );
      await _waitFor(() => chat.canSend);
      expect(chat.error, isNull);
      expect(chat.chatAccessError, isNull);
    },
  );

  test("keeps only 300 recent messages and handles action and whole-room clear", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      List.generate(310, (i) => "@id=$i :person!p@tmi PRIVMSG #channel :message $i\r\n").join(),
    );
    await _waitFor(() => chat.conversation.length == 300);
    expect(chat.conversation.first.id, "10");
    server.send("@id=action :person!p@tmi PRIVMSG #channel :\u0001ACTION waves\u0001\r\n");
    await _waitFor(() => chat.conversation.last.id == "action");
    expect(chat.conversation.last.text, "waves");
    expect(chat.conversation.last.isAction, isTrue);
    server.send(":tmi.twitch.tv CLEARCHAT #channel\r\n");
    await _waitFor(() => chat.conversation.last.moderation == TwitchChatModeration.cleared);
    expect(chat.conversation.take(299).every((message) => message.isDeleted), isTrue);
    expect(chat.conversation.last.noticeText, "Chat was cleared.");
    expect(chat.conversation.last.isDeleted, isFalse);
    expect(chat.conversation.length, 300);
    expect(chat.conversationHistory.length, 312);
  });

  test("retains reply parent and root context, including escaped original text", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      "@id=parent;emotes=25:13-17 :alice!a@tmi PRIVMSG #channel :hello world; Kappa\r\n"
      "@id=reply;reply-parent-msg-id=parent;reply-parent-user-id=77;reply-parent-user-login=alice;"
      "reply-parent-display-name=Alice;reply-parent-msg-body=hello\\sworld\\:\\sKappa;"
      "reply-thread-parent-msg-id=root;reply-thread-parent-user-login=original "
      ":bob!b@tmi PRIVMSG #channel :@alice yes\r\n"
      "@id=reply :bob!b@tmi PRIVMSG #channel :duplicate\r\n",
    );
    await _waitFor(() => chat.conversation.length == 2);
    final reply = chat.conversation.last;
    expect(reply.parentMessageId, "parent");
    expect(reply.parentUserId, "77");
    expect(reply.parentLogin, "alice");
    expect(reply.parentDisplayName, "Alice");
    expect(reply.parentText, "hello world; Kappa");
    expect(reply.parentEmotes.single.id, "25");
    expect(reply.parentEmotes.single.start, 13);
    expect(reply.parentEmotes.single.end, 18);
    expect(reply.threadRootId, "root");
    expect(reply.threadRootLogin, "original");
    expect(chat.receivedMessageCount, 2);
    server.send("@target-msg-id=reply :tmi.twitch.tv CLEARMSG #channel :@alice yes\r\n");
    await _waitFor(() => chat.conversation.last.isDeleted);
    expect(chat.conversation.last.parentText, reply.parentText);
    expect(chat.conversation.last.parentEmotes.single.start, 13);
    expect(chat.conversation.last.threadRootId, "root");
    expect(chat.receivedMessageCount, 2);
    server.send(
      "@id=mismatched;reply-parent-msg-id=parent;reply-parent-msg-body=other "
      ":bob!b@tmi PRIVMSG #channel :reply\r\n",
    );
    await _waitFor(() => chat.conversation.last.id == "mismatched");
    expect(chat.conversation.last.parentEmotes, isEmpty);
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
    await _waitFor(() => chat.conversation.length == 4);
    server.send(
      "@ban-duration=350;target-user-id=77;tmi-sent-ts=1642719320727 "
      ":tmi.twitch.tv CLEARCHAT #channel :alice\r\n",
    );
    await _waitFor(() => chat.conversation.first.isDeleted);
    expect(chat.conversation.take(2).every((message) => message.timeoutSeconds == 350), isTrue);
    expect(chat.conversation.first.moderation, TwitchChatModeration.timeout);
    expect(chat.conversation.first.moderatedAt?.millisecondsSinceEpoch, 1642719320727);
    expect(chat.conversation[2].isDeleted, isFalse);
    expect(chat.conversation[3].isDeleted, isFalse);
    server.send("@target-user-id=77 :tmi.twitch.tv CLEARCHAT #channel :alice\r\n");
    await _waitFor(() => chat.conversation.first.moderation == TwitchChatModeration.ban);
    expect(chat.conversation.first.timeoutSeconds, isNull);
    expect(chat.conversationHistory.first.moderation, TwitchChatModeration.ban);
    server.send("@target-user-id=99 :tmi.twitch.tv CLEARCHAT #channel\r\n");
    await _waitFor(() => chat.conversation.length == 5);
    expect(chat.conversation[3].isDeleted, isFalse);
    expect(chat.conversation.last.noticeType, "moderation");
    expect(chat.conversation.last.isDeleted, isFalse);
    expect(chat.conversation.last.noticeText, "A chatter was permanently banned.");
    server.send(
      "@ban-duration=60;target-user-id=100 :tmi.twitch.tv CLEARCHAT #channel :newchatter\r\n",
    );
    await _waitFor(() => chat.conversation.length == 6);
    expect(chat.conversation.last.noticeText, "newchatter was timed out for 60 seconds.");
  });

  test("retains subscription, announcement and raid notices with identity and system text", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      "@id=resub;msg-id=resub;msg-param-sub-plan=Prime;login=ronni;user-id=456;display-name=Ronni;badges=subscriber/6;emotes=25:0-4;system-msg=Ronni\\ssubscribed\\sfor\\s6\\smonths! "
      ":tmi.twitch.tv USERNOTICE #channel :Kappa\r\n"
      "@id=announcement;msg-id=announcement;login=moderator;user-id=789;display-name=Moderator "
      ":tmi.twitch.tv USERNOTICE #channel :Welcome to the stream!\r\n"
      "@id=raid;msg-id=raid;login=raider;user-id=789;display-name=Raider;system-msg=100\\sraiders\\sjoined! "
      ":tmi.twitch.tv USERNOTICE #channel\r\n"
      "@id=wrong;msg-id=sub :tmi.twitch.tv USERNOTICE #another :ignored\r\n",
    );
    await _waitFor(() => chat.conversation.length == 3);
    final subscription = chat.conversation.first;
    expect(subscription.noticeType, "resub");
    expect(subscription.isPrimeSubscription, isTrue);
    expect(subscription.copyWith(isDeleted: true).isPrimeSubscription, isTrue);
    expect(subscription.noticeText, "Ronni subscribed for 6 months!");
    expect(subscription.login, "ronni");
    expect(subscription.userId, "456");
    expect(subscription.badges, ["subscriber/6"]);
    expect(subscription.emotes.single.id, "25");
    expect(subscription.text, "Kappa");
    expect(chat.conversation[1].noticeType, "announcement");
    expect(chat.conversation[1].isPrimeSubscription, isFalse);
    expect(chat.conversation[1].text, "Welcome to the stream!");
    expect(chat.conversation.last.noticeType, "raid");
    expect(chat.conversation.last.noticeText, "100 raiders joined!");
    expect(chat.conversation.last.text, isEmpty);
  });

  test("retains advance subscription duration without changing complete or ongoing notices", () async {
    final chat = controller();
    await server.join(chat);
    const basic = "akaza0004 subscribed at Tier 1.";
    const full = "akaza0004 subscribed at Tier 1 for 6 months in advance.";
    final cases = [
      (id: "advance", type: "sub", duration: "6", tenure: "0", notice: basic, expected: full),
      (id: "complete", type: "sub", duration: "6", tenure: "0", notice: full, expected: full),
      (id: "ongoing", type: "resub", duration: "6", tenure: "1", notice: basic, expected: basic),
      (
        id: "missing-tenure",
        type: "sub",
        duration: "6",
        tenure: "",
        notice: basic,
        expected: basic,
      ),
      (id: "one-month", type: "sub", duration: "1", tenure: "0", notice: basic, expected: basic),
      (
        id: "resub",
        type: "resub",
        duration: "3",
        tenure: "0",
        notice: "$basic They've subscribed for 12 months, currently on a 4 month streak!",
        expected:
            "akaza0004 subscribed at Tier 1 for 3 months in advance. They've subscribed for 12 months, currently on a 4 month streak!",
      ),
    ];
    for (final entry in cases) {
      final escaped = entry.notice.replaceAll(" ", r"\s");
      server.send(
        "@id=${entry.id};msg-id=${entry.type};login=akaza0004;display-name=akaza0004;msg-param-sub-plan=1000;msg-param-cumulative-months=6;msg-param-multimonth-duration=${entry.duration};msg-param-multimonth-tenure=${entry.tenure};system-msg=$escaped "
        ":tmi.twitch.tv USERNOTICE #channel :Great stream!\r\n",
      );
    }
    await _waitFor(() => chat.conversation.length == cases.length);
    for (final entry in cases) {
      final message = chat.conversation.singleWhere((message) => message.id == entry.id);
      expect(message.noticeText, entry.expected, reason: entry.id);
      expect(message.text, "Great stream!");
      expect(message.copyWith(isDeleted: true).noticeText, entry.expected);
    }
  });

  test("keeps a bounded session history beyond the feed and marks older deletions", () async {
    final chat = controller();
    await server.join(chat);
    server.send(
      List.generate(5005, (i) => "@id=$i :person!p@tmi PRIVMSG #channel :message $i\r\n").join(),
    );
    await _waitFor(() => chat.conversationHistory.length == 5000);
    expect(chat.conversation.length, 300);
    expect(chat.conversationHistory.first.id, "5");
    expect(chat.conversation.first.id, "4705");
    expect(chat.receivedMessageCount, 5005);
    expect(() => chat.recentHistory.clear(), throwsUnsupportedError);
    server.send("@target-msg-id=10 :tmi.twitch.tv CLEARMSG #channel :deleted\r\n");
    await _waitFor(() => chat.conversationHistory.singleWhere((item) => item.id == "10").isDeleted);
    expect(chat.conversation.any((item) => item.isDeleted), isFalse);
    chat.reconnect();
    await server.join(chat, connection: 2);
    expect(chat.recentHistory.length, 5000);
    expect(chat.conversationHistory.length, 4999);
    expect(chat.recentHistory.last.noticeText, "Reconnecting to chat...");
    expect(chat.receivedMessageCount, 5006);
    expect(chat.conversationHistory.singleWhere((item) => item.id == "10").text, "message 10");
  });

  test("awaits send confirmation, rejects invalid input and retains unconfirmed drafts", () async {
    final chat = controller();
    await server.join(chat);
    expect(await chat.send("hello\r\nJOIN #other"), isFalse);
    expect(await chat.send("a" * 501), isFalse);
    expect(chat.messages.where((message) => message.isPrivate), hasLength(1));
    expect(chat.messages.last.noticeText, "Use a message of 1–500 characters on a single line.");
    expect(server.commands.where((command) => command.startsWith("PRIVMSG")), isEmpty);

    var immediatelyDisplayed = false;
    chat.addListener(() {
      immediatelyDisplayed = chat.conversation.any((message) => message.text == "first message");
    });
    final rejected = chat.send("first message");
    expect(immediatelyDisplayed, isTrue);
    expect(chat.conversation.single.id, startsWith("pending:"));
    expect(chat.conversation.single.isOwn, isTrue);
    expect(chat.conversation.single.text, "first message");
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :first message\r\n"));
    server.send("@msg-id=msg_subsonly :tmi.twitch.tv NOTICE #channel :Subscribers only\r\n");
    expect(await rejected, isFalse);
    expect(chat.error, isNull);
    expect(chat.conversation, isEmpty);
    server.send("@subs-only=0 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.canSend);

    await Future<void>.delayed(const Duration(milliseconds: 1050));
    const parent = TwitchChatMessage(
      id: "parent-id",
      login: "alice",
      displayName: "Alice",
      text: "Original Kappa",
      emotes: [TwitchChatEmote(id: "25", start: 9, end: 14)],
      userId: "77",
      threadRootId: "root-id",
      threadRootLogin: "original",
    );
    final sent = chat.send("second message", replyTo: parent);
    final localId = chat.conversation.single.id;
    final localTimestamp = chat.conversation.single.timestamp;
    expect(localId, startsWith("pending:"));
    expect(chat.conversation.single.parentMessageId, "parent-id");
    expect(chat.conversation.single.parentEmotes.single.id, "25");
    await _waitFor(
      () => server.commands.contains(
        "@reply-parent-msg-id=parent-id PRIVMSG #channel :second message\r\n",
      ),
    );
    server.send("@color=#FFFFFF :tmi.twitch.tv USERSTATE #channel\r\n");
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(chat.conversation.single.id, localId);
    server.send(
      "@id=sent-id;color=#FFFFFF;badges=subscriber/1 :tmi.twitch.tv USERSTATE #channel\r\n"
      "@id=sent-id;color=#FFFFFF;badges=subscriber/1 :tmi.twitch.tv USERSTATE #channel\r\n",
    );
    expect(await sent, isTrue);
    expect(chat.conversation.single.id, "sent-id");
    expect(chat.conversation.single.timestamp, localTimestamp);
    expect(chat.conversation.single.isOwn, isTrue);
    expect(chat.conversation.single.text, "second message");
    expect(chat.conversation.single.userId, "123");
    expect(chat.conversation.single.badges, ["subscriber/1"]);
    expect(chat.conversation.single.parentMessageId, "parent-id");
    expect(chat.conversation.single.parentText, "Original Kappa");
    expect(chat.conversation.single.parentEmotes.single.start, 9);
    expect(chat.conversation.single.parentEmotes.single.end, 14);
    expect(chat.conversation.single.threadRootId, "root-id");
    expect(chat.receivedMessageCount, 1);
    expect(chat.recentHistory.any((message) => message.id == localId), isFalse);
    expect(chat.error, isNull);
    expect(await chat.send("too fast"), isFalse);
    expect(chat.error, contains("too quickly"));
    expect(chat.messages.last.isPrivate, isTrue);
    expect(chat.messages.last.noticeText, chat.error);

    await Future<void>.delayed(const Duration(milliseconds: 1050));
    final interrupted = chat.send("pending message");
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :pending message\r\n"));
    unawaited(server.sockets.last.close());
    expect(await interrupted, isFalse);
    expect(chat.status, TwitchChatStatus.reconnecting);
    expect(chat.conversation.length, 1);
  });

  test("slow mode blocks sends until expiry and reacts to role and room changes", () async {
    final chat = controller();
    await server.join(chat);
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    server.send("@slow=2 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.roomState["slow"] == "2");
    expect(chat.canSend, isTrue);
    final sent = chat.send("slow mode message");
    final initialWait = chat.slowModeWaitRemaining;
    expect(chat.slowModeWaitRemaining, greaterThan(Duration.zero));
    expect(chat.canSend, isFalse);
    expect(await chat.send("blocked while pending"), isFalse);
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :slow mode message\r\n"));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    server.send("@id=slow-own :tmi.twitch.tv USERSTATE #channel\r\n");
    expect(await sent, isTrue);
    expect(chat.slowModeWaitRemaining, lessThan(initialWait - const Duration(milliseconds: 100)));
    expect(await chat.send("blocked after confirmation"), isFalse);
    expect(server.commands.where((value) => value.startsWith("PRIVMSG")), hasLength(1));
    for (final role in ["moderator", "vip", "broadcaster"]) {
      server.send("@badges=$role/1 :tmi.twitch.tv USERSTATE #channel\r\n");
      await _waitFor(() => chat.canSend);
      expect(chat.slowModeWaitRemaining, Duration.zero);
      server.send("@badges= :tmi.twitch.tv USERSTATE #channel\r\n");
      await _waitFor(() => !chat.canSend);
    }
    var expiryNotified = false;
    chat.addListener(() => expiryNotified |= chat.canSend);
    await _waitFor(() => expiryNotified);
    expect(chat.slowModeWaitRemaining, Duration.zero);
    server.send("@id=other-client :viewer!v@tmi PRIVMSG #channel :sent from another client\r\n");
    await _waitFor(() => !chat.canSend);
    server.send("@slow=0 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.canSend);
    expect(chat.slowModeWaitRemaining, Duration.zero);
  });

  testWidgets("restores server slow-mode history and honors subscriber exemptions", (tester) async {
    final lastSentAt = DateTime.now().subtract(const Duration(seconds: 5));
    final client = _Client()
      ..access = TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Channel",
        rules: const [],
        isSlowModeRestricted: false,
        lastRecentChatMessageAt: lastSentAt,
      );
    final socket = _Socket();
    final chat = await historyChat(tester, client, socket);
    socket._incoming.add(
      "@subscriber=1;badges=subscriber/1 :tmi.twitch.tv USERSTATE #channel\r\n"
      "@slow=30 :tmi.twitch.tv ROOMSTATE #channel\r\n",
    );
    await tester.pump();
    expect(chat.canSend, isTrue);
    expect(chat.slowModeWaitRemaining, Duration.zero);
    client.access = TwitchChatAccess(
      channelId: "1",
      channelDisplayName: "Channel",
      rules: const [],
      isSlowModeRestricted: true,
      lastRecentChatMessageAt: lastSentAt,
    );
    await chat.refreshChatAccess();
    expect(chat.canSend, isFalse);
    expect(chat.slowModeWaitRemaining, greaterThan(const Duration(seconds: 24)));
    expect(chat.slowModeWaitRemaining, lessThanOrEqualTo(const Duration(seconds: 25)));
    final newer = DateTime.now().subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;
    final older = lastSentAt.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
    socket._incoming.add(
      "@id=newer-own;tmi-sent-ts=$newer :viewer!v@tmi PRIVMSG #channel :newer message\r\n"
      "@id=older-own;tmi-sent-ts=$older :viewer!v@tmi PRIVMSG #channel :delayed old message\r\n",
    );
    expect(chat.canSend, isFalse);
    expect(chat.slowModeWaitRemaining, greaterThan(const Duration(seconds: 28)));
    chat.dispose();
  });

  testWidgets("room changes supersede an in-flight slow-mode exemption query", (tester) async {
    final stale = Completer<TwitchChatAccess>();
    final client = _Client();
    var accessLoads = 0;
    client.loadAccess = () async {
      if (++accessLoads == 1) {
        return stale.future;
      }
      return TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Channel",
        rules: const [],
        isSlowModeRestricted: true,
        lastRecentChatMessageAt: DateTime.now(),
      );
    };
    final socket = _Socket();
    final chat = await historyChat(tester, client, socket);
    expect(accessLoads, 1);
    socket._incoming.add("@slow=30 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await tester.pump();
    expect(accessLoads, 2);
    expect(chat.chatAccess?.isSlowModeRestricted, isTrue);
    stale.complete(
      const TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Channel",
        rules: [],
        isSlowModeRestricted: false,
      ),
    );
    await tester.pump();
    expect(chat.chatAccess?.isSlowModeRestricted, isTrue);
    expect(chat.canSend, isFalse);
    chat.dispose();
  });

  test("uses Twitch's slow-mode rejection countdown and clears a rejected local attempt", () async {
    final chat = controller();
    await server.join(chat);
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    server.send("@slow=20 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.roomState["slow"] == "20");
    final rejected = chat.send("rejected local attempt");
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :rejected local attempt\r\n"));
    server.send(
      "@msg-id=msg_slowmode :tmi.twitch.tv NOTICE #channel :This room is in slow mode and you are sending messages too quickly. You will be able to talk again in 1 seconds.\r\n",
    );
    expect(await rejected, isFalse);
    expect(chat.conversation, isEmpty);
    expect(chat.canSend, isFalse);
    expect(chat.slowModeWaitRemaining, lessThanOrEqualTo(const Duration(seconds: 1)));
    await _waitFor(() => chat.canSend);
    final blocked = chat.send("moderation rejected attempt");
    await _waitFor(
      () => server.commands.contains("PRIVMSG #channel :moderation rejected attempt\r\n"),
    );
    server.send("@msg-id=msg_subsonly :tmi.twitch.tv NOTICE #channel :Subscribers only\r\n");
    expect(await blocked, isFalse);
    expect(chat.slowModeWaitRemaining, Duration.zero);
    expect(chat.canSend, isFalse);
    server.send("@subs-only=0 :tmi.twitch.tv ROOMSTATE #channel\r\n");
    await _waitFor(() => chat.canSend);
  });

  test("confirms an own send when recent history arrives before its acknowledgement", () async {
    final response = Completer<List<TwitchChatMessage>>();
    final client = _Client()..loadHistory = () => response.future;
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: server.connect,
      loadPins: false,
      loadPrivateNotices: false,
    );
    addTearDown(chat.dispose);
    await server.join(chat);
    await _waitFor(() => client.historyLoads == 1);
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    final sent = chat.send("my own message");
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :my own message\r\n"));
    response.complete([
      _historyMessage(
        "own-id",
        DateTime.now().millisecondsSinceEpoch,
        userId: "123",
        login: "viewer",
        text: "my own message",
      ),
    ]);
    await _waitFor(() => chat.messages.any((message) => message.id == "own-id"));
    server.send(
      "@target-msg-id=own-id;tmi-sent-ts=1000 :tmi.twitch.tv CLEARMSG #channel :my own message\r\n"
      "@id=own-id;badges=subscriber/1 :tmi.twitch.tv USERSTATE #channel\r\n",
    );
    expect(await sent, isTrue);
    expect(chat.conversation, hasLength(1));
    expect(chat.conversation.single.id, "own-id");
    expect(chat.conversation.single.isHistorical, isFalse);
    expect(chat.conversation.single.badges, ["subscriber/1"]);
    expect(chat.conversation.single.isDeleted, isTrue);
    expect(chat.conversation.single.moderation, TwitchChatModeration.deleted);
    expect(chat.conversation.single.moderatedAt, DateTime.fromMillisecondsSinceEpoch(1000));
    expect(chat.receivedMessageCount, 1);
    expect(chat.recentHistory.where((message) => message.id == "own-id"), hasLength(1));
    expect(chat.recentHistory.any((message) => message.id.startsWith("pending:")), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 1050));
    final timedOut = chat.send("another own message");
    await _waitFor(() => server.commands.contains("PRIVMSG #channel :another own message\r\n"));
    server.send(
      "@target-user-id=123;ban-duration=60;tmi-sent-ts=2000 :tmi.twitch.tv CLEARCHAT #channel :viewer\r\n"
      "@id=second-own-id :tmi.twitch.tv USERSTATE #channel\r\n",
    );
    expect(await timedOut, isTrue);
    final second = chat.conversation.singleWhere((message) => message.id == "second-own-id");
    expect(second.isDeleted, isTrue);
    expect(second.moderation, TwitchChatModeration.timeout);
    expect(second.timeoutSeconds, 60);
    expect(second.moderatedAt, DateTime.fromMillisecondsSinceEpoch(2000));
    expect(chat.receivedMessageCount, 2);
    expect(chat.recentHistory.any((message) => message.id.startsWith("pending:")), isFalse);
  });

  test("joins anonymously and reconnects automatically to the same channel", () async {
    final chat = controller(signedIn: false);
    await server.join(chat);
    expect(server.commands.where((command) => command.startsWith("PASS")), isEmpty);
    expect(chat.canSend, isFalse);
    expect(chat.isSignedIn, isFalse);
    expect(await chat.send("cannot send"), isFalse);
    expect(chat.messages.last.isPrivate, isTrue);
    expect(chat.messages.last.noticeText, "Sign in to Twitch to chat.");
    server.send("@id=one :person!p@tmi PRIVMSG #channel :before loss\r\n");
    await _waitFor(() => chat.conversation.isNotEmpty);
    unawaited(server.sockets.last.close());
    await _waitFor(() => chat.status == TwitchChatStatus.reconnecting);
    await _waitFor(() => server.sockets.length == 2);
    await server.join(chat, connection: 2);
    expect(chat.conversation.single.text, "before loss");
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
      expect(chat.messages.where((message) => message.isPrivate), hasLength(1));
      expect(chat.messages.singleWhere((message) => message.isPrivate).noticeText, chat.error);
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

  test("actual private events dedupe across history eviction and same-viewer reconnect", () async {
    final client = _Client();
    final privateSockets = <_Socket>[];
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: server.connect,
      loadPins: false,
      privateSocketConnector: () async {
        final socket = _Socket();
        privateSockets.add(socket);
        return socket;
      },
    );
    addTearDown(chat.dispose);
    await server.join(chat);
    await _waitFor(() => privateSockets.isNotEmpty && privateSockets.last._incoming.hasListener);
    final socket = privateSockets.single;
    socket.authenticateHermes();
    socket.achievement("event-one");
    await _waitFor(() => chat.messages.any((message) => message.isPrivate));
    expect(chat.messages.last.noticeText, "You reached a 7-stream watch streak!");
    socket.achievement("event-one");
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(chat.messages.where((message) => message.isPrivate), hasLength(1));
    server.send(
      List.generate(
        5001,
        (index) => "@id=history-$index :person!p@tmi PRIVMSG #channel :message\r\n",
      ).join(),
    );
    await _waitFor(() => chat.receivedMessageCount == 5001);
    expect(chat.recentHistory.where((message) => message.isPrivate), isEmpty);
    chat.reconnect();
    await server.join(chat, connection: 2);
    await _waitFor(() => privateSockets.length == 2 && privateSockets.last._incoming.hasListener);
    privateSockets.last
      ..authenticateHermes()
      ..achievement("event-one");
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(chat.messages.where((message) => message.isPrivate), isEmpty);
    privateSockets.last.achievement("event-two");
    await _waitFor(() => chat.messages.any((message) => message.isPrivate));
    expect(chat.messages.where((message) => message.isPrivate), hasLength(1));
  });

  for (final autoClaim in [true, false]) {
    testWidgets(
      "changed credentials rebind chat before private subscription and claims (auto-claim: $autoClaim)",
      (tester) async {
        final verified = Completer<TwitchUser>();
        final first = _Client();
        final second = _Client(webToken: "second-token");
        second.loadUser = () => verified.future;
        var client = first;
        final sockets = <_Socket>[];
        final privateSockets = <_Socket>[];
        final chat = TwitchChatController(
          channel: "channel",
          clientLoader: () async => client,
          loadPins: false,
          socketConnector: () async {
            final socket = _Socket();
            sockets.add(socket);
            return socket;
          },
          privateSocketConnector: () async {
            final socket = _Socket();
            privateSockets.add(socket);
            return socket;
          },
        );
        chat.setAutoClaimChannelPoints(enabled: autoClaim);
        await tester.pump();
        sockets.last._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
        await tester.pump();
        privateSockets.single
          ..authenticateHermes()
          ..achievement("old-event");
        await tester.pump();
        expect(first.pointClaims, autoClaim ? 1 : 0);
        expect(chat.messages.where((message) => message.isPrivate), hasLength(autoClaim ? 2 : 1));
        client = second;
        await tester.pump(const Duration(minutes: 1));
        expect(chat.status, TwitchChatStatus.reconnecting);
        expect(chat.currentUserId, isNull);
        expect(chat.messages.where((message) => message.isPrivate), isEmpty);
        expect(chat.recentHistory.where((message) => message.isPrivate), isEmpty);
        expect(second.pointChecks, 0);
        expect(second.pointClaims, 0);
        expect(privateSockets, hasLength(1));
        expect(privateSockets.single.closed, isTrue);
        verified.complete(const TwitchUser(id: "456", login: "second", displayName: "Second"));
        await tester.pump();
        expect(chat.currentUserId, "456");
        second.onClaim = () async {
          expectSync(chat.currentUserId, "456");
          return 70;
        };
        sockets.last._incoming.add("@room-id=1 :tmi.twitch.tv ROOMSTATE #channel\r\n");
        await tester.pump();
        expect(second.pointClaims, autoClaim ? 1 : 0);
        expect(privateSockets, hasLength(2));
        privateSockets.last.authenticateHermes();
        final subscription = jsonDecode(privateSockets.last.sent.last) as Map;
        expect((subscription["subscribe"] as Map)["pubsub"], {"topic": "viewer-milestones.456"});
        privateSockets.last.achievement("old-event");
        await tester.pump();
        expect(chat.messages.where((message) => message.isPrivate), hasLength(autoClaim ? 2 : 1));
        expect(
          chat.messages.any((message) => message.noticeText == "Claimed 70 channel points."),
          autoClaim,
        );
        chat.dispose();
      },
    );
  }
  test("IRC notices are private, retained, and never sent to other chatters", () async {
    final chat = controller();
    await server.join(chat);
    final sent = server.commands.toList();
    server.send(
      "@msg-id=followers_on :tmi.twitch.tv NOTICE #channel :Followers-only mode enabled.\r\n",
    );
    await _waitFor(() => chat.messages.any((message) => message.isPrivate));
    final notice = chat.messages.last;
    expect(notice.noticeText, "Followers-only mode enabled.");
    expect(notice.noticeType, "notice");
    expect(notice.copyWith(noticeText: "updated").isPrivate, isTrue);
    expect(chat.receivedMessageCount, 0);
    expect(chat.messages.first.isPrivate, isFalse);
    server.send(":tmi.twitch.tv CLEARCHAT #channel\r\n");
    await _waitFor(() => chat.messages.last.noticeType == "moderation");
    expect(chat.messages.singleWhere((message) => message.id == notice.id).isDeleted, isFalse);
    expect(server.commands, sent);
  });

  test(
    "a rejected send has one private notice and preserves its error without a public row",
    () async {
      final chat = controller();
      await server.join(chat);
      const reason = "Your message is identical to the previous one you sent.";
      server.send(
        "@id=rejection;msg-id=msg_duplicate :tmi.twitch.tv NOTICE #channel :$reason\r\n"
        "@id=rejection;msg-id=msg_duplicate :tmi.twitch.tv NOTICE #channel :$reason\r\n",
      );
      await _waitFor(() => chat.error == reason);
      expect(chat.messages.where((message) => message.isPrivate), hasLength(1));
      expect(chat.messages.last.noticeText, reason);
      expect(chat.conversation, isEmpty);
      expect(chat.receivedMessageCount, 0);
    },
  );

  testWidgets("auto claim stays off by default and requires a signed-in connected viewer", (
    tester,
  ) async {
    for (final signedIn in [true, false]) {
      final client = _Client(signedIn: signedIn);
      final socket = _Socket();
      final chat = TwitchChatController(
        channel: "channel",
        clientLoader: () async => client,
        socketConnector: () async => socket,
        loadPins: false,
        loadPrivateNotices: false,
      );
      await tester.pump();
      socket.acknowledgeJoin();
      await tester.pump(const Duration(minutes: 2));
      expect(client.pointChecks, 0);
      if (!signedIn) {
        chat.setAutoClaimChannelPoints(enabled: true);
        await tester.pump(const Duration(minutes: 2));
        expect(client.pointChecks, 0);
      }
      chat.dispose();
    }
  });

  testWidgets("auto claim waits for confirmation, dedupes, and cancels after disabling", (
    tester,
  ) async {
    final confirmed = Completer<int>();
    final client = _Client()..onClaim = () => confirmed.future;
    final socket = _Socket();
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: () async => socket,
      loadPins: false,
      loadPrivateNotices: false,
    );
    chat.setAutoClaimChannelPoints(enabled: true);
    await tester.pump();
    expect(client.pointChecks, 0);
    socket.acknowledgeJoin();
    await tester.pump();
    expect(client.pointChecks, 1);
    expect(client.pointClaims, 1);
    expect(chat.messages.where((message) => message.isPrivate), isEmpty);
    socket.acknowledgeJoin();
    await tester.pump(const Duration(minutes: 2));
    expect(client.pointClaims, 1);
    confirmed.complete(60);
    await tester.pump();
    final notice = chat.messages.last;
    expect(notice.noticeType, "channel-points");
    expect(notice.noticeText, "Claimed 60 channel points.");
    expect(notice.isPrivate, isTrue);
    expect(chat.receivedMessageCount, 0);
    await tester.pump(const Duration(seconds: 60));
    expect(client.pointChecks, 2);
    expect(client.pointClaims, 1);
    expect(chat.messages.where((message) => message.isPrivate), hasLength(1));
    chat.setAutoClaimChannelPoints(enabled: false);
    await tester.pump(const Duration(minutes: 2));
    expect(client.pointChecks, 2);
    chat.dispose();
  });

  testWidgets("auto claim retries failure without a success row and ignores stale queries", (
    tester,
  ) async {
    final available = Completer<({String channelId, String claimId})?>();
    final client = _Client()..loadPointClaim = () => available.future;
    final socket = _Socket();
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: () async => socket,
      loadPins: false,
      loadPrivateNotices: false,
    );
    await tester.pump();
    socket.acknowledgeJoin();
    chat.setAutoClaimChannelPoints(enabled: true);
    await tester.pump();
    chat.setAutoClaimChannelPoints(enabled: false);
    available.complete((channelId: "1", claimId: "claim"));
    await tester.pump();
    expect(client.pointClaims, 0);
    client.loadPointClaim = null;
    client.onClaim = () async => throw TwitchApiException("Claim expired");
    chat.setAutoClaimChannelPoints(enabled: true);
    await tester.pump();
    expect(client.pointClaims, 1);
    expect(chat.messages.where((message) => message.isPrivate), isEmpty);
    client.onClaim = () async => 50;
    await tester.pump(const Duration(seconds: 60));
    expect(client.pointClaims, 2);
    expect(chat.messages.last.noticeText, "Claimed 50 channel points.");
    chat.dispose();
    await tester.pump(const Duration(minutes: 2));
    expect(client.pointClaims, 2);
  });

  testWidgets("disposing auto claim ignores a late mutation acknowledgement", (tester) async {
    final confirmed = Completer<int>();
    final client = _Client()..onClaim = () => confirmed.future;
    final socket = _Socket();
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: () async => socket,
      loadPins: false,
      loadPrivateNotices: false,
    );
    chat.setAutoClaimChannelPoints(enabled: true);
    await tester.pump();
    socket.acknowledgeJoin();
    await tester.pump();
    expect(client.pointClaims, 1);
    chat.dispose();
    confirmed.complete(50);
    await tester.pump(const Duration(minutes: 2));
    expect(chat.messages.where((message) => message.isPrivate), isEmpty);
    expect(client.pointChecks, 1);
  });

  testWidgets("connection phases allow slow verification without restarting the attempt", (
    tester,
  ) async {
    final verified = Completer<TwitchUser>();
    var verifications = 0;
    final client = _Client()
      ..loadUser = () {
        verifications++;
        return verified.future;
      };
    final socket = _Socket();
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: () async => socket,
      loadPins: false,
      loadPrivateNotices: false,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(verifications, 1);
    expect(chat.status, TwitchChatStatus.connecting);
    expect(socket.sent, isEmpty);
    verified.complete(await _Client().fetchCurrentUser());
    await tester.pump();
    expect(socket.sent, contains("PASS oauth:web-token\r\n"));
    expect(socket.sent, contains("JOIN #channel\r\n"));
    socket.acknowledgeJoin();
    expect(chat.status, TwitchChatStatus.connected);
    expect(chat.currentUserId, "123");
    chat.dispose();
  });

  testWidgets("connection phases fall back after verification timeout and ignore a late identity", (
    tester,
  ) async {
    final verified = Completer<TwitchUser>();
    final client = _Client()..loadUser = () => verified.future;
    final socket = _Socket();
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => client,
      socketConnector: () async => socket,
      loadPins: false,
      loadPrivateNotices: false,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(socket.sent, contains("JOIN #channel\r\n"));
    expect(socket.sent.any((command) => command.startsWith("PASS")), isFalse);
    socket.acknowledgeJoin();
    expect(chat.status, TwitchChatStatus.connected);
    expect(chat.isSignedIn, isFalse);
    verified.complete(await _Client().fetchCurrentUser());
    await tester.pump();
    expect(chat.currentUserId, isNull);
    expect(chat.canSend, isFalse);
    expect(socket.sent.where((command) => command == "JOIN #channel\r\n"), hasLength(1));
    chat.dispose();
  });

  testWidgets("connection phases still retry stalled sockets and close their late results", (
    tester,
  ) async {
    final opening = Completer<WebSocket>();
    final socket = _Socket();
    var attempts = 0;
    final chat = TwitchChatController(
      channel: "channel",
      clientLoader: () async => _Client(signedIn: false),
      socketConnector: () => ++attempts == 1 ? opening.future : Future.value(socket),
      loadPins: false,
      loadPrivateNotices: false,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(chat.status, TwitchChatStatus.reconnecting);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 2);
    socket.acknowledgeJoin();
    expect(chat.status, TwitchChatStatus.connected);
    final lateSocket = _Socket();
    opening.complete(lateSocket);
    await tester.pump();
    expect(lateSocket.closed, isTrue);
    expect(lateSocket.sent, isEmpty);
    expect(chat.status, TwitchChatStatus.connected);
    chat.dispose();
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

extension on TwitchChatController {
  List<TwitchChatMessage> get conversation =>
      messages.where((message) => message.noticeType != "system" && !message.isPrivate).toList();
  List<TwitchChatMessage> get conversationHistory => recentHistory
      .where((message) => message.noticeType != "system" && !message.isPrivate)
      .toList();
}

TwitchChatMessage _historyMessage(
  String id,
  int timestamp, {
  String text = "history",
  String login = "alice",
  String? userId,
}) => TwitchChatMessage(
  id: id,
  login: login,
  displayName: login,
  userId: userId,
  text: text,
  timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
);

class _Client extends TwitchApiClient {
  _Client({bool signedIn = true, String webToken = "web-token"})
    : super(
        clientId: "test",
        accessToken: signedIn ? "oauth-token" : "",
        gqlAccessToken: signedIn ? webToken : null,
      );

  TwitchChatAccess access = const TwitchChatAccess(
    channelId: "1",
    channelDisplayName: "Channel",
    rules: [],
  );
  Future<TwitchChatAccess> Function()? loadAccess;
  bool subscribed = false;
  Future<bool> Function()? loadSubscription;

  @override
  Future<bool> fetchChannelSubscriptionStatus(String login) =>
      loadSubscription?.call() ?? Future.value(subscribed);

  Future<TwitchUser> Function()? loadUser;
  Future<List<TwitchChatMessage>> Function()? loadHistory;
  int historyLoads = 0;
  @override
  Future<List<TwitchChatMessage>> fetchRecentChat(String channelId) {
    expectSync(channelId, "1");
    historyLoads++;
    return loadHistory?.call() ?? Future.value(const []);
  }

  int followCalls = 0;
  Future<void> Function()? onUnfollow;
  int unfollowCalls = 0;
  int pointChecks = 0;
  int pointClaims = 0;
  Future<({String channelId, String claimId})?> Function()? loadPointClaim;
  Future<int> Function()? onClaim;
  @override
  Future<({String channelId, String claimId})?> fetchAvailableChannelPointsClaim(
    String login,
  ) async {
    pointChecks++;
    return loadPointClaim != null ? loadPointClaim!() : (channelId: "1", claimId: "claim");
  }

  @override
  Future<int> claimChannelPoints(String channelId, String claimId) async {
    expectSync(channelId, "1");
    expectSync(claimId, "claim");
    pointClaims++;
    return onClaim != null ? onClaim!() : 50;
  }

  @override
  Future<TwitchChatAccess> fetchChatAccess(String login) =>
      loadAccess?.call() ?? Future.value(access);

  @override
  Future<DateTime> followChannel(String channelId) async {
    followCalls++;
    return DateTime.now();
  }

  @override
  Future<void> unfollowChannel(String channelId) async {
    unfollowCalls++;
    await onUnfollow?.call();
  }

  @override
  Future<TwitchUser> fetchCurrentUser() async => loadUser != null
      ? loadUser!()
      : const TwitchUser(
          id: "123",
          login: "Viewer",
          displayName: "Viewer",
        );
}

class _Socket extends Stream<Object?> implements WebSocket {
  final _incoming = StreamController<Object?>.broadcast(sync: true);
  final sent = <String>[];
  bool closed = false;
  @override
  Duration? pingInterval;
  void acknowledgeJoin() => _incoming.add(":tmi.twitch.tv ROOMSTATE #channel\r\n");
  void authenticateHermes() {
    _incoming.add(
      jsonEncode({
        "type": "welcome",
        "welcome": {"keepaliveSec": 600},
      }),
    );
    var request = jsonDecode(sent.last) as Map;
    _incoming.add(
      jsonEncode({
        "type": "authenticateResponse",
        "parentId": request["id"],
        "authenticateResponse": {"result": "ok"},
      }),
    );
    request = jsonDecode(sent.last) as Map;
    _incoming.add(
      jsonEncode({
        "type": "subscribeResponse",
        "parentId": request["id"],
        "subscribeResponse": {"result": "ok"},
      }),
    );
  }

  void achievement(String id) {
    final request = jsonDecode(sent.last) as Map;
    _incoming.add(
      jsonEncode({
        "type": "notification",
        "id": id,
        "notification": {
          "type": "pubsub",
          "subscription": {"id": (request["subscribe"] as Map)["id"]},
          "pubsub": jsonEncode({
            "type": "viewer-milestones-update",
            "data": {"event_type": "achieved", "channel_id": "1", "watch_streak_value": "7"},
          }),
        },
      }),
    );
  }

  @override
  void add(Object? data) => sent.add(data! as String);
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
