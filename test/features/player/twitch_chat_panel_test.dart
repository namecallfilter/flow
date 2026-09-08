import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_vod_chat.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/twitch_chat_panel.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  Widget panel(
    _ChatController controller, {
    bool chatOnly = false,
    bool isLive = true,
    Brightness brightness = Brightness.light,
    FlowPreferences? preferences,
    AppSettingsStore? settingsStore,
    Future<void> Function()? onOpenSettings,
    TwitchChatAssets? assets,
    int? latencyMs,
  }) => MaterialApp(
    theme: buildFlowTheme(brightness),
    home: Scaffold(
      body: TwitchChatPanel(
        controller: controller,
        chatOnly: chatOnly,
        isLive: isLive,
        preferences: preferences ?? MemoryFlowPreferences(),
        settingsStore: settingsStore,
        onOpenSettings: onOpenSettings,
        assets: assets,
        latencyMs: latencyMs,
        onToggleChatOnly: () => controller.toggles++,
      ),
    ),
  );

  testWidgets("shows connection state while retaining chat history", (tester) async {
    final controller = _ChatController()..connectionStatus = TwitchChatStatus.connecting;
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    expect(find.text("Connecting to chat…"), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      "Connecting to chat…",
    );
    expect(find.textContaining("Welcome to"), findsNothing);
    expect(find.text("Waiting for connection…"), findsNothing);
    controller.items.add(_message(1));
    controller.connectionStatus = TwitchChatStatus.reconnecting;
    controller.update();
    await tester.pump();
    expect(find.text("Connecting to chat…"), findsNothing);
    expect(find.text("Reconnecting to chat…"), findsOneWidget);
    expect(find.textContaining("message 1", findRichText: true), findsOneWidget);
    controller.connectionStatus = TwitchChatStatus.connected;
    controller.update();
    await tester.pump();
    expect(find.text("Reconnecting to chat…"), findsNothing);
    expect(find.text("Connected"), findsNothing);
  });

  testWidgets("uses grey for near-white light-mode names and near-black dark-mode names", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    for (final entry in {
      "White": "#FFFFFF",
      "NearWhite": "#FFFEFE",
      "Snow": "#FFFAFA",
      "Black": "#000000",
      "NearBlack": "#010101",
      "Green": "#00FF00",
      "LightYellow": "#FFFFE0",
    }.entries) {
      controller.items.add(
        TwitchChatMessage(
          id: entry.key,
          login: entry.key.toLowerCase(),
          displayName: entry.key,
          color: entry.value,
          text: "hello",
        ),
      );
    }
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(panel(controller, brightness: brightness));
      await tester.pumpAndSettle();
      for (final entry in {
        "White": brightness == Brightness.light ? const Color(0xFF808080) : Colors.white,
        "NearWhite": brightness == Brightness.light
            ? const Color(0xFF808080)
            : const Color(0xFFFFFEFE),
        "Snow": brightness == Brightness.light ? const Color(0xFF808080) : const Color(0xFFFFFAFA),
        "Black": brightness == Brightness.dark ? const Color(0xFF808080) : Colors.black,
        "NearBlack": brightness == Brightness.dark
            ? const Color(0xFF808080)
            : const Color(0xFF010101),
        "Green": const Color(0xFF00FF00),
        "LightYellow": const Color(0xFFFFFFE0),
      }.entries) {
        final message = tester.widget<RichText>(
          find.text("${entry.key}: hello", findRichText: true),
        );
        Color? color;
        message.text.visitChildren((span) {
          if (span is TextSpan && span.text == "${entry.key}: ") {
            color = span.style?.color;
          }
          return true;
        });
        expect(color, entry.value);
      }
    }
  });

  testWidgets("keeps the draft until sending succeeds and supports keyboard send", (tester) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    final input = find.byKey(const ValueKey("chat_message_input"));
    final send = find.byKey(const ValueKey("chat_send"));
    expect(find.byTooltip("Chat options"), findsOneWidget);
    expect(send, findsNothing);
    await tester.enterText(input, "Hello Twitch");
    await tester.pump();
    expect(find.byTooltip("Chat options"), findsNothing);
    final result = Completer<bool>();
    controller.sendResult = result.future;
    await tester.tap(send);
    await tester.pump();
    expect(controller.sent, ["Hello Twitch"]);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    expect(tester.widget<TextField>(input).controller!.text, "Hello Twitch");
    result.complete(false);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, "Hello Twitch");
    controller.sendResult = Future.value(true);
    await tester.showKeyboard(input);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(controller.sent, ["Hello Twitch", "Hello Twitch"]);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    final pending = Completer<bool>();
    controller.sendResult = pending.future;
    await tester.enterText(input, "Sending this");
    await tester.pump();
    await tester.tap(send);
    await tester.enterText(input, "My next message");
    pending.complete(true);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, "My next message");
  });

  testWidgets("explains sign-in and reconnects live chat", (tester) async {
    final controller = _ChatController()..signedIn = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, chatOnly: true));
    expect(find.text("Live chat"), findsNothing);
    expect(find.text("Connected"), findsNothing);
    expect(find.text("Sign in from Following to chat"), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await _openMenu(tester);
    await tester.tap(find.text("Show video"));
    await tester.pumpAndSettle();
    expect(controller.toggles, 1);
    controller.signedIn = true;
    controller.connectionStatus = TwitchChatStatus.reconnecting;
    controller.notice = "Connection lost. Retrying…";
    controller.update();
    await tester.pump();
    expect(find.text("Connection lost. Retrying…"), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      "Reconnecting to chat…",
    );
    expect(find.text("Waiting for connection…"), findsNothing);
    await _openMenu(tester);
    await tester.tap(find.text("Reconnect"));
    await tester.pumpAndSettle();
    expect(controller.retries, 1);
    controller.connectionStatus = TwitchChatStatus.connected;
    controller.notice = null;
    controller.update();
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(find.byTooltip("Reconnect chat"), findsNothing);
  });

  testWidgets("VOD replay has recorded messages, a watch action and no live composer", (
    tester,
  ) async {
    final replay = _ReplayController();
    addTearDown(replay.dispose);
    var watching = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchChatPanel(
            replayController: replay,
            chatOnly: true,
            isLive: false,
            preferences: MemoryFlowPreferences(),
            onToggleChatOnly: () => watching = true,
          ),
        ),
      ),
    );
    expect(find.text("Chat replay"), findsOneWidget);
    expect(find.text("Synced to video"), findsNothing);
    expect(find.textContaining("recorded message", findRichText: true), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip("Send message"), findsNothing);
    await _openMenu(tester);
    await tester.tap(find.text("Show video"));
    await tester.pumpAndSettle();
    expect(watching, isTrue);
  });

  testWidgets("follows new messages only at the bottom and jumps to latest", (tester) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    controller.items.addAll(List.generate(100, _message));
    await tester.pumpWidget(panel(controller));
    await tester.pump();
    final list = find.byKey(const ValueKey("chat_messages"));
    final scroll = tester.widget<ListView>(list).controller!;
    expect(scroll.position.extentBefore, 0);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(find.text("Jump to latest"), findsOneWidget);
    final offset = scroll.offset;
    final before = tester.getTopLeft(find.textContaining("message 1", findRichText: true).first);
    controller.items.add(_message(100));
    controller.update();
    await tester.pump();
    expect(scroll.offset, offset);
    expect(tester.getTopLeft(find.textContaining("message 1", findRichText: true).first), before);
    expect(find.textContaining("message 100", findRichText: true), findsNothing);
    expect(find.text("1 new message"), findsOneWidget);
    await tester.tap(find.text("1 new message"));
    await tester.pump();
    await tester.pump();
    expect(scroll.position.extentBefore, 0);
    expect(find.text("Jump to latest"), findsNothing);
    controller.items.add(_message(101));
    controller.update();
    await tester.pump();
    await tester.pump();
    expect(scroll.position.extentBefore, 0);
    expect(find.textContaining("message 101", findRichText: true), findsOneWidget);
  });

  testWidgets("counts paused arrivals beyond the 300-message feed cap", (tester) async {
    final controller = _ChatController()..items.addAll(List.generate(300, _message));
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(find.byKey(const ValueKey("chat_messages"))).controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    controller.received = 701;
    controller.items
      ..clear()
      ..addAll(List.generate(300, (index) => _message(index + 401)));
    controller.update();
    await tester.pump();
    expect(find.text("401 new messages"), findsOneWidget);
    await tester.tap(find.text("401 new messages"));
    await tester.pumpAndSettle();
    expect(find.text("401 new messages"), findsNothing);
    expect(find.textContaining("message 700", findRichText: true), findsOneWidget);
  });

  testWidgets("attaches one moderation notice and preserves deleted-text preference", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    final time = DateTime(2026, 5, 12);
    controller.items.addAll([
      _message(1).copyWith(
        isDeleted: true,
        moderation: TwitchChatModeration.timeout,
        timeoutSeconds: 60,
        moderatedAt: time,
      ),
      _message(2).copyWith(
        isDeleted: true,
        moderation: TwitchChatModeration.timeout,
        timeoutSeconds: 60,
        moderatedAt: time,
      ),
    ]);
    await tester.pumpWidget(panel(controller, settingsStore: settings));
    await tester.pumpAndSettle();
    expect(find.textContaining("was timed out for 60s"), findsOneWidget);
    expect(find.textContaining("message 1", findRichText: true), findsNothing);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(showDeletedMessages: true));
    await tester.pumpAndSettle();
    expect(find.textContaining("message 1", findRichText: true), findsOneWidget);
    expect(find.textContaining("was timed out for 60s"), findsOneWidget);
    for (var index = 0; index < controller.items.length; index++) {
      controller.items[index] = controller.items[index].copyWith(
        moderation: TwitchChatModeration.ban,
      );
    }
    controller.update();
    await tester.pumpAndSettle();
    expect(find.textContaining("was permanently banned"), findsOneWidget);
    expect(find.textContaining("was timed out"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "standalone moderation notices remain visible when alerts and deleted text are hidden",
    (tester) async {
      final controller = _ChatController();
      addTearDown(controller.dispose);
      final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
      await settings.load();
      await settings.setChatPreferences(
        const ChatPreferences(
          showSubscriptionNotices: false,
          showAnnouncements: false,
          showRaidNotices: false,
        ),
      );
      controller.items.addAll(const [
        TwitchChatMessage(
          id: "ban",
          login: "banned",
          displayName: "Banned",
          text: "",
          noticeType: "moderation",
          noticeText: "Banned was permanently banned.",
          moderation: TwitchChatModeration.ban,
        ),
        TwitchChatMessage(
          id: "timeout",
          login: "timed",
          displayName: "Timed",
          text: "",
          noticeType: "moderation",
          noticeText: "Timed was timed out for 60 seconds.",
          moderation: TwitchChatModeration.timeout,
          timeoutSeconds: 60,
        ),
        TwitchChatMessage(
          id: "clear",
          login: "",
          displayName: "",
          text: "",
          noticeType: "moderation",
          noticeText: "Chat was cleared.",
          moderation: TwitchChatModeration.cleared,
        ),
      ]);
      await tester.pumpWidget(panel(controller, settingsStore: settings));
      await tester.pumpAndSettle();
      expect(find.text("Banned was permanently banned."), findsOneWidget);
      expect(find.text("Timed was timed out for 60 seconds."), findsOneWidget);
      expect(find.text("Chat was cleared."), findsOneWidget);
      expect(find.textContaining("was permanently banned"), findsOneWidget);
      expect(find.textContaining("was timed out"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("switching channels clears the draft and detaches the old controller", (
    tester,
  ) async {
    final first = _ChatController()..items.add(_message(1));
    final second = _ChatController(channel: "second")..items.add(_message(2));
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(panel(first));
    await tester.enterText(find.byType(TextField), "For the first channel");
    await tester.pumpWidget(panel(second));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.textContaining("message 1", findRichText: true), findsNothing);
    expect(find.textContaining("message 2", findRichText: true), findsOneWidget);
    expect(first.listening, isFalse);
    expect(second.listening, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(second.listening, isFalse);
    second.update();
    expect(tester.takeException(), isNull);
  });

  testWidgets("delays live chat for latency, releases it on time and supports manual timing", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    controller.items.add(
      TwitchChatMessage(
        id: "delayed",
        login: "viewer",
        displayName: "Viewer",
        text: "timed message",
        timestamp: DateTime.now(),
      ),
    );
    await tester.pumpWidget(panel(controller, settingsStore: settings, latencyMs: 1000));
    expect(find.textContaining("timed message", findRichText: true), findsNothing);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining("timed message", findRichText: true), findsOneWidget);
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(autoSyncChat: false, manualChatDelaySeconds: 30),
    );
    await tester.pump();
    expect(find.textContaining("timed message", findRichText: true), findsNothing);
    controller.items.add(
      TwitchChatMessage(
        id: "own",
        login: "me",
        displayName: "Me",
        text: "my own message",
        timestamp: DateTime.now(),
        isOwn: true,
      ),
    );
    controller.update();
    await tester.pump();
    expect(find.textContaining("my own message", findRichText: true), findsOneWidget);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(manualChatDelaySeconds: 0));
    await tester.pump();
    expect(find.textContaining("timed message", findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("filters deletions and notices and highlights first-time chatters", (tester) async {
    final controller = _ChatController()
      ..items.addAll([
        const TwitchChatMessage(
          id: "deleted",
          login: "viewer",
          displayName: "Viewer",
          text: "removed words",
          isDeleted: true,
        ),
        const TwitchChatMessage(
          id: "first",
          login: "newviewer",
          displayName: "Newviewer",
          text: "first hello",
          isFirstMessage: true,
        ),
        const TwitchChatMessage(
          id: "sub",
          login: "subscriber",
          displayName: "Subscriber",
          text: "sub hello",
          noticeType: "resub",
          noticeText: "Subscribed for 3 months",
        ),
        const TwitchChatMessage(
          id: "raid",
          login: "raider",
          displayName: "Raider",
          text: "",
          noticeType: "raid",
          noticeText: "Raided with 10 viewers",
        ),
        const TwitchChatMessage(
          id: "announcement",
          login: "mod",
          displayName: "Mod",
          text: "Announcement body",
          noticeType: "announcement",
        ),
      ]);
    addTearDown(controller.dispose);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    await tester.pumpWidget(panel(controller, settingsStore: settings));
    expect(find.textContaining("removed words", findRichText: true), findsNothing);
    expect(find.text("First-time chatter"), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.text("Subscribed for 3 months"), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.text("Raided with 10 viewers"), findsOneWidget);
    expect(find.text("Announcement"), findsOneWidget);
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(
        showDeletedMessages: true,
        highlightFirstMessages: false,
        showSubscriptionNotices: false,
        showAnnouncements: false,
        showRaidNotices: false,
      ),
    );
    await tester.pump();
    expect(find.textContaining("removed words (deleted)", findRichText: true), findsOneWidget);
    expect(find.text("First-time chatter"), findsNothing);
    expect(find.text("Subscribed for 3 months"), findsNothing);
    expect(find.text("Raided with 10 viewers"), findsNothing);
    expect(find.textContaining("Announcement body", findRichText: true), findsNothing);
    expect(find.textContaining("first hello", findRichText: true), findsOneWidget);
  });

  testWidgets("scales message text, emotes, badges and spacing independently", (tester) async {
    final controller = _ChatController()
      ..items.add(
        const TwitchChatMessage(
          id: "scaled",
          login: "author",
          displayName: "LongViewerNameThatWraps",
          text: "HeyGuys",
          isOwn: true,
          badges: ["moderator/1"],
        ),
      );
    final assets = _Assets();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    await settings.setChatPreferences(
      const ChatPreferences(
        fontSize: 20,
        messageScale: 1.5,
        emoteScale: 2,
        badgeScale: 0.5,
        messageSpacing: 12,
      ),
    );
    await tester.pumpWidget(panel(controller, settingsStore: settings, assets: assets));
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.singleWhere((image) => image.semanticLabel == "HeyGuys").height, 102);
    expect(images.singleWhere((image) => image.semanticLabel == "moderator").height, 18);
    final text = tester.widget<RichText>(
      find.textContaining("LongViewerNameThatWraps:", findRichText: true),
    );
    expect(text.text.style!.fontSize, 30);
    final row = tester.widget<Container>(
      find.ancestor(of: find.byWidget(text), matching: find.byType(Container)).first,
    );
    expect(row.margin, const EdgeInsets.symmetric(vertical: 6));
    expect(tester.takeException(), isNull);
  });

  testWidgets("drawer exposes requested actions and opens the app settings callback", (
    tester,
  ) async {
    final controller = _ChatController()
      ..items.add(_message(1))
      ..room.addAll({
        "followers-only": "30",
        "slow": "10",
        "subs-only": "1",
        "emote-only": "1",
        "r9k": "1",
      });
    final preferences = MemoryFlowPreferences();
    var settingsOpened = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      panel(controller, preferences: preferences, onOpenSettings: () async => settingsOpened++),
    );
    await tester.pump();
    final message = tester.widget<RichText>(find.textContaining("message 1", findRichText: true));
    final spans = <TextSpan>[];
    message.text.visitChildren((span) {
      if (span is TextSpan) {
        spans.add(span);
      }
      return true;
    });
    expect(
      spans.singleWhere((span) => span.text == "Viewer: ").style!.color,
      const Color(0xFF00FF00),
    );
    await _openMenu(tester);
    for (final mode in [
      "Followers · 30m",
      "Slow mode · 10s",
      "Subscribers only",
      "Emotes only",
      "Unique chat",
    ]) {
      expect(find.text(mode), findsOneWidget);
    }
    for (final label in [
      "Chat only",
      "Refresh emotes and badges",
      "Reconnect",
      "Chatters",
      "Settings",
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text("Sleep timer"), findsNothing);
    expect(find.text("Add chat"), findsNothing);
    await tester.tap(find.text("Settings"));
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);
    expect(find.text("Refresh emotes and badges"), findsNothing);
    expect(find.byKey(const ValueKey("chat_font_size")), findsNothing);
  });

  testWidgets("shared settings update mounted chat and retain its draft and messages", (
    tester,
  ) async {
    final controller = _ChatController()..items.add(_message(1));
    final preferences = MemoryFlowPreferences();
    await preferences.saveChatPreferences(const ChatPreferences(fontSize: 18));
    final store = AppSettingsStore(preferences: preferences);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, settingsStore: store));
    await tester.pump();
    double fontSize() => tester
        .widget<RichText>(find.textContaining("message 1", findRichText: true))
        .text
        .style!
        .fontSize!;
    expect(fontSize(), 18);
    await tester.enterText(find.byType(TextField), "Unsent draft");
    await store.setChatPreferences(store.chatPreferences.copyWith(fontSize: 20));
    await tester.pump();
    expect(fontSize(), 20);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, "Unsent draft");
    expect(controller.items.single.text, "message 1");
    expect(controller.retries, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await store.setChatPreferences(store.chatPreferences.copyWith(fontSize: 22));
    expect(tester.takeException(), isNull);
  });

  testWidgets("chatters displays Twitch groups and identifies a partial roster", (tester) async {
    final client = _ChattersClient();
    final controller = _ChatController(client: client);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await _openMenu(tester);
    await tester.tap(find.text("Chatters"));
    await tester.pumpAndSettle();
    expect(client.channel, "testchannel");
    expect(find.text("Chatters · 200"), findsOneWidget);
    expect(find.text("Showing 2 names returned by Twitch"), findsOneWidget);
    expect(find.text("Moderators"), findsOneWidget);
    expect(find.text("channelmod"), findsOneWidget);
    expect(find.text("someone"), findsOneWidget);
  });

  testWidgets("only own messages without native emote ranges use the Twitch dictionary", (
    tester,
  ) async {
    final controller = _ChatController()
      ..items.addAll([
        for (final own in [false, true])
          TwitchChatMessage(
            id: "$own",
            login: "author",
            displayName: "Author",
            text: "HeyGuys",
            isOwn: own,
          ),
        const TwitchChatMessage(
          id: "native",
          login: "author",
          displayName: "Author",
          text: "HeyGuys Kappa",
          isOwn: true,
          emotes: [TwitchChatEmote(id: "25", start: 8, end: 13)],
        ),
      ]);
    final assets = _Assets();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets));
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as NetworkImage).url);
    expect(
      urls,
      unorderedEquals([
        "https://example.com/HeyGuys.png",
        "https://static-cdn.jtvnw.net/emoticons/v2/25/default/light/2.0",
      ]),
    );
  });

  testWidgets("renders native badges and all providers while keeping native ranges authoritative", (
    tester,
  ) async {
    await svg.cache.putIfAbsent(
      const SvgNetworkLoader("https://example.com/bttv-badge.svg").cacheKey(null),
      () => const SvgStringLoader(
        '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><rect width="18" height="18"/></svg>',
      ).loadBytes(null),
    );
    addTearDown(svg.cache.clear);
    final controller = _ChatController()
      ..items.add(
        const TwitchChatMessage(
          id: "assets",
          login: "viewer",
          displayName: "Viewer",
          text: "Kappa Bttv Seven Ffz",
          badges: ["moderator/1"],
          emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
        ),
      );
    final assets = _Assets();
    final preferences = MemoryFlowPreferences();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets, preferences: preferences));
    await tester.pump();
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as NetworkImage).url)
        .toList();
    expect(urls, contains("https://example.com/moderator.png"));
    expect(urls, contains("https://example.com/seventv-badge.webp"));
    expect(urls, contains("https://example.com/ffz-badge.png"));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(urls, contains("https://static-cdn.jtvnw.net/emoticons/v2/25/default/light/2.0"));
    for (final name in ["Bttv", "Seven", "Ffz"]) {
      expect(urls, contains("https://example.com/$name.png"));
    }
    expect(urls, isNot(contains("https://example.com/Kappa.png")));
    await _openMenu(tester);
    await tester.tap(find.text("Refresh emotes and badges"));
    await tester.pumpAndSettle();
    expect(assets.refreshes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await preferences.saveChatPreferences(
      const ChatPreferences(
        twitchEmotes: false,
        sevenTvEmotes: false,
        bttvEmotes: false,
        ffzEmotes: false,
        twitchBadges: false,
        sevenTvBadges: false,
        bttvBadges: false,
        ffzBadges: false,
      ),
    );
    await tester.pumpWidget(panel(controller, assets: assets, preferences: preferences));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.textContaining("Kappa Bttv Seven Ffz", findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip("Chat options"));
  await tester.pumpAndSettle();
}

TwitchChatMessage _message(int index) => TwitchChatMessage(
  id: "$index",
  login: "viewer",
  displayName: "Viewer",
  text: "message $index",
  color: "#00FF00",
);

class _ChatController extends TwitchChatController {
  _ChatController({super.channel = "testchannel", TwitchApiClient? client})
    : super(
        clientLoader: () async => client ?? (throw StateError("Unused in widget tests")),
        autoConnect: false,
      );

  final items = <TwitchChatMessage>[];
  final sent = <String>[];
  final room = <String, String>{};
  TwitchChatStatus connectionStatus = TwitchChatStatus.connected;
  String? notice;
  bool signedIn = true;
  int retries = 0;
  int toggles = 0;
  Future<bool>? sendResult;
  int? received;

  bool get listening => hasListeners;

  @override
  List<TwitchChatMessage> get recentHistory => items;

  @override
  Map<String, String> get roomState => room;

  @override
  List<TwitchChatMessage> get messages => items;

  @override
  int get receivedMessageCount => received ?? items.length;

  @override
  TwitchChatStatus get status => connectionStatus;

  @override
  String? get error => notice;

  @override
  bool get isSignedIn => signedIn;

  @override
  bool get canSend => signedIn && status == TwitchChatStatus.connected;

  @override
  Future<bool> send(String text, {TwitchChatMessage? replyTo}) {
    sent.add(text);
    return sendResult ?? Future.value(true);
  }

  @override
  void reconnect() => retries++;

  void update() => notifyListeners();
}

class _ChattersClient extends TwitchApiClient {
  _ChattersClient() : super(clientId: "test", accessToken: "");

  String? channel;

  @override
  Future<TwitchChatters> fetchChatters(String login) async {
    channel = login;
    return const TwitchChatters(
      count: 200,
      groups: {
        "moderators": ["channelmod"],
        "viewers": ["someone"],
      },
    );
  }
}

class _ReplayController extends TwitchVodChatController {
  _ReplayController()
    : super(
        clientLoader: () async => throw StateError("Unused in widget tests"),
        videoId: "123",
        autoLoad: false,
      );

  @override
  TwitchChatStatus get status => TwitchChatStatus.connected;

  @override
  List<TwitchChatMessage> get messages => const [
    TwitchChatMessage(
      id: "recorded",
      login: "viewer",
      displayName: "Viewer",
      text: "recorded message",
    ),
  ];
}

class _Assets extends TwitchChatAssets {
  _Assets()
    : super(
        clientLoader: () async => throw StateError("Unused"),
        channelLogin: "testchannel",
        autoLoad: false,
      );

  int refreshes = 0;

  @override
  Map<String, String> get badgeUrls => const {"moderator/1": "https://example.com/moderator.png"};

  @override
  Map<String, List<ChatAssetBadge>> get userBadgesByLogin => const {
    "viewer": [
      ChatAssetBadge(
        id: "7tv",
        title: "7TV supporter",
        url: "https://example.com/seventv-badge.webp",
        provider: ChatEmoteProvider.sevenTv,
      ),
      ChatAssetBadge(
        id: "bttv",
        title: "BetterTTV",
        url: "https://example.com/bttv-badge.svg",
        provider: ChatEmoteProvider.bttv,
      ),
      ChatAssetBadge(
        id: "ffz",
        title: "FrankerFaceZ",
        url: "https://example.com/ffz-badge.png",
        provider: ChatEmoteProvider.ffz,
        color: "#755000",
      ),
    ],
  };

  @override
  Map<String, ChatAssetEmote> get emotesByName => {
    for (final entry in {
      "HeyGuys": ChatEmoteProvider.twitch,
      "Kappa": ChatEmoteProvider.sevenTv,
      "Bttv": ChatEmoteProvider.bttv,
      "Seven": ChatEmoteProvider.sevenTv,
      "Ffz": ChatEmoteProvider.ffz,
    }.entries)
      entry.key: ChatAssetEmote(
        name: entry.key,
        id: entry.key,
        url: "https://example.com/${entry.key}.png",
        provider: entry.value,
      ),
  };

  @override
  Future<void> refresh({bool force = true}) async => refreshes++;
}
