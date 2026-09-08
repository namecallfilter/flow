import "dart:ui" as ui;

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/twitch_chat_panel.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

const _avatar = "https://example.com/avatar.png";
const _emoteUrl = "https://example.com/party.png";
const _badgeUrl = "https://example.com/moderator.png";
const _twitchEmoteUrl = "https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/2.0";

void main() {
  testWidgets(
    "holding names and emotes opens message actions; paste preserves selection without sending",
    (tester) async {
      await _cacheImages(tester);
      final client = _Client();
      final controller = _Controller(client);
      final assets = _Assets(client);
      const message = TwitchChatMessage(
        id: "visible",
        login: "viewer",
        displayName: "Viewer",
        text: "Kappa Party",
        emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
      );
      controller.items.add(message);
      controller.history.add(message);
      addTearDown(controller.dispose);
      addTearDown(assets.dispose);
      final copied = <String>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == "Clipboard.setData") {
          copied.add((call.arguments as Map<Object?, Object?>)["text"]! as String);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_panel(controller, assets: assets));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey("visible"));
      final name = find.descendant(of: row, matching: find.byType(RichText)).first;
      await tester.longPressAt(tester.getTopLeft(name) + const Offset(12, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("chat_message_preview")), findsOneWidget);
      expect(client.lookups, isEmpty);
      await tester.tap(find.text("Copy message"));
      await tester.pumpAndSettle();
      expect(copied, ["Kappa Party"]);
      await tester.enterText(find.byType(TextField), "before SELECT after");
      final input = tester.widget<TextField>(find.byType(TextField));
      input.controller!.selection = const TextSelection(baseOffset: 7, extentOffset: 13);
      await tester.longPress(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (widget) => widget is Image && widget.semanticLabel == "Party",
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("7TV emote"), findsNothing);
      await tester.tap(find.text("Copy message and paste"));
      await tester.pumpAndSettle();
      expect(copied, ["Kappa Party", "Kappa Party"]);
      expect(input.controller!.text, "before Kappa Party after");
      expect(input.controller!.selection.baseOffset, 18);
      expect(input.focusNode!.hasFocus, isTrue);
      expect(controller.sent, isEmpty);
      await _tapName(tester, "visible");
      await tester.longPress(find.byKey(const ValueKey("log-visible")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Reply to message"));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("chat_user_history")), findsNothing);
      expect(find.byKey(const ValueKey("chat_message_preview")), findsNothing);
      expect(input.controller!.text, "@viewer before Kappa Party after");
      expect(input.focusNode!.hasFocus, isTrue);
      expect(controller.sent, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "a stacked reply shows the resolved root, siblings, and live descendants without repeated metadata",
    (tester) async {
      final client = _Client();
      final controller = _Controller(client);
      client.thread.addAll([
        TwitchChatMessage(
          id: "root",
          login: "parent",
          displayName: "Parent",
          text: "Root question",
          timestamp: DateTime(2026, 5, 12, 9),
        ),
        const TwitchChatMessage(
          id: "parent-reply",
          login: "first",
          displayName: "First",
          text: "Parent answer",
          parentMessageId: "root",
          threadRootId: "root",
        ),
        const TwitchChatMessage(
          id: "sibling",
          login: "second",
          displayName: "Second",
          text: "Sibling answer",
          parentMessageId: "root",
          threadRootId: "root",
        ),
      ]);
      const stacked = TwitchChatMessage(
        id: "stacked",
        login: "viewer",
        displayName: "Viewer",
        text: "Stacked answer",
        parentMessageId: "parent-reply",
        parentLogin: "first",
        parentText: "Parent answer",
      );
      controller.items.add(stacked);
      controller.history.add(stacked);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("reply-context-stacked")));
      await tester.pumpAndSettle();
      final thread = find.byKey(const ValueKey("chat_reply_thread"));
      for (final text in ["Root question", "Parent answer", "Sibling answer", "Stacked answer"]) {
        expect(_log(thread, text), findsOneWidget);
      }
      expect(_log(thread, "09:00"), findsNothing);
      expect(
        find.descendant(of: thread, matching: find.byIcon(Icons.format_quote_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: thread, matching: find.byIcon(Icons.subdirectory_arrow_right_rounded)),
        findsNWidgets(3),
      );
      controller.history.add(
        const TwitchChatMessage(
          id: "deepest",
          login: "third",
          displayName: "Third",
          text: "Newest nested answer",
          parentMessageId: "stacked",
        ),
      );
      controller.update();
      await tester.pumpAndSettle();
      expect(_log(thread, "Newest nested answer"), findsOneWidget);
      controller.history
        ..clear()
        ..add(
          const TwitchChatMessage(
            id: "unrelated",
            login: "other",
            displayName: "Other",
            text: "Another thread",
            threadRootId: "different-root",
          ),
        );
      controller.update();
      await tester.pumpAndSettle();
      expect(_log(thread, "Newest nested answer"), findsOneWidget);
      expect(_log(thread, "Another thread"), findsNothing);
      controller.history
        ..clear()
        ..add(
          const TwitchChatMessage(
            id: "deepest",
            login: "third",
            displayName: "Third",
            text: "Newest nested answer",
            parentMessageId: "stacked",
            isDeleted: true,
          ),
        );
      controller.update();
      await tester.pumpAndSettle();
      expect(_log(thread, "Newest nested answer"), findsNothing);
      controller.history.clear();
      controller.update();
      await tester.pumpAndSettle();
      expect(_log(thread, "Newest nested answer"), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("reply context opens the full thread and follows live replies with send metadata", (
    tester,
  ) async {
    final client = _Client();
    final controller = _Controller(client);
    const parent = TwitchChatMessage(
      id: "root",
      login: "parent",
      displayName: "Parent",
      text: "Original question from server",
    );
    const reply = TwitchChatMessage(
      id: "reply",
      login: "viewer",
      displayName: "Viewer",
      text: "First answer",
      parentMessageId: "root",
      parentLogin: "parent",
      parentDisplayName: "Parent",
      parentText: "Original question",
      threadRootId: "root",
    );
    client.thread.add(parent);
    controller.history.add(reply);
    controller.items.add(reply);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("reply-context-reply")));
    await tester.pumpAndSettle();
    final thread = find.byKey(const ValueKey("chat_reply_thread"));
    expect(find.text("REPLIES"), findsOneWidget);
    expect(
      find.descendant(of: thread, matching: find.byIcon(Icons.format_quote_rounded)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: thread,
        matching: find.text("Parent: Original question from server", findRichText: true),
      ),
      findsOneWidget,
    );
    expect(_log(thread, "Viewer: First answer"), findsOneWidget);
    controller.history.add(
      const TwitchChatMessage(
        id: "later",
        login: "other",
        displayName: "Other",
        text: "Live second answer",
        parentMessageId: "reply",
        threadRootId: "root",
      ),
    );
    controller.update();
    await tester.pumpAndSettle();
    expect(_log(thread, "Live second answer"), findsOneWidget);
    expect(
      find.descendant(of: thread, matching: find.byIcon(Icons.subdirectory_arrow_right_rounded)),
      findsNWidgets(2),
    );
    await tester.longPress(find.byKey(const ValueKey("thread-reply")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reply to message"));
    await tester.pumpAndSettle();
    expect(thread, findsNothing);
    expect(find.textContaining("Replying to Viewer"), findsOneWidget);
    await tester.enterText(find.byType(TextField), "@viewer My answer");
    await tester.tap(find.byTooltip("Send message"));
    await tester.pumpAndSettle();
    expect(controller.sent, [(text: "@viewer My answer", replyTo: reply)]);
    expect(find.byTooltip("Cancel reply"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "replying from a thread's user profile closes both drawers and focuses the composer",
    (tester) async {
      await _cacheImages(tester);
      final client = _Client();
      final controller = _Controller(client);
      client.thread.add(
        const TwitchChatMessage(
          id: "root",
          login: "parent",
          displayName: "Parent",
          text: "Original question",
        ),
      );
      controller.items.add(
        const TwitchChatMessage(
          id: "reply",
          login: "viewer",
          displayName: "Viewer",
          text: "An answer",
          parentMessageId: "root",
          parentLogin: "parent",
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("reply-context-reply")));
      await tester.pumpAndSettle();
      final name = find
          .descendant(
            of: find.byKey(const ValueKey("thread-root")),
            matching: find.byType(RichText),
          )
          .first;
      await tester.tapAt(tester.getTopLeft(name) + const Offset(12, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("chat_user_history")), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey("chat_user_reply")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("chat_user_history")), findsNothing);
      expect(find.byKey(const ValueKey("chat_reply_thread")), findsNothing);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.controller!.text, "@parent ");
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(controller.sent, isEmpty);
      expect(controller.listening, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("mentions use the chatter's exact color and open profiles; URLs open externally", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    controller.history.add(
      const TwitchChatMessage(
        id: "known",
        login: "viewer",
        userId: "1234",
        displayName: "Viewer",
        color: "#00FF00",
        text: "Earlier message",
      ),
    );
    controller.items.add(
      const TwitchChatMessage(
        id: "links",
        login: "other",
        displayName: "Other",
        text:
            "Hi @Viewer, see https://example.com/watch?x=1. (https://en.wikipedia.org/wiki/Twitch_(service)). "
            "twitch.tv/channel, discord.gg/invite! example.com?x=1. "
            "person.name@example.com -invalid.com bad_.com a.-invalid.com hi.ok https://hi.ok",
      ),
    );
    addTearDown(controller.dispose);
    const external = MethodChannel("flow/external_url");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final opened = <String>[];
    messenger.setMockMethodCallHandler(external, (call) async {
      opened.add(call.arguments as String);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(external, null));
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    final rich = tester.widget<RichText>(find.textContaining("Hi @Viewer", findRichText: true));
    final spans = <String, TextSpan>{};
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer != null) {
        spans[span.text!] = span;
      }
      return true;
    });
    expect(spans["@Viewer"]!.style!.color, const Color(0xFF00FF00));
    expect(spans["@Viewer"]!.style!.fontWeight, FontWeight.w700);
    (spans["https://example.com/watch?x=1"]!.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(opened, ["https://example.com/watch?x=1"]);
    (spans["https://en.wikipedia.org/wiki/Twitch_(service)"]!.recognizer! as TapGestureRecognizer)
        .onTap!();
    await tester.pumpAndSettle();
    expect(opened.last, "https://en.wikipedia.org/wiki/Twitch_(service)");
    for (final domain in ["twitch.tv/channel", "discord.gg/invite", "example.com?x=1"]) {
      (spans[domain]!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pumpAndSettle();
      expect(opened.last, "https://$domain");
    }
    expect(
      spans.keys,
      unorderedEquals([
        "Other: ",
        "@Viewer",
        "https://example.com/watch?x=1",
        "https://en.wikipedia.org/wiki/Twitch_(service)",
        "twitch.tv/channel",
        "discord.gg/invite",
        "example.com?x=1",
      ]),
    );
    (spans["@Viewer"]!.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(client.lookups, [(userId: "1234", login: "viewer")]);
    expect(find.byKey(const ValueKey("chat_user_history")), findsOneWidget);
    expect(find.text("@viewer"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("changing channels closes the previous user drawer and detaches its history", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final first = _Controller(client);
    final second = _Controller(client, channel: "second");
    final active = ValueNotifier(first);
    final message = _message("visible", "first channel message", minute: 32);
    first.items.add(message);
    first.history.add(message);
    second.items.add(
      const TwitchChatMessage(
        id: "next",
        login: "nextuser",
        displayName: "Next user",
        text: "second channel message",
      ),
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: Scaffold(
          body: ValueListenableBuilder<_Controller>(
            valueListenable: active,
            builder: (context, controller, child) => TwitchChatPanel(
              controller: controller,
              preferences: MemoryFlowPreferences(),
              chatOnly: true,
              isLive: true,
              onToggleChatOnly: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapName(tester, "visible");
    expect(find.byTooltip("Reply"), findsOneWidget);
    active.value = second;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("chat_user_history")), findsNothing);
    expect(find.byTooltip("Reply"), findsNothing);
    expect(find.textContaining("first channel message", findRichText: true), findsNothing);
    expect(find.textContaining("second channel message", findRichText: true), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(first.listening, isFalse);
    expect(second.listening, isTrue);
    first.update();
    expect(tester.takeException(), isNull);
  });

  testWidgets("an immediate profile failure keeps the user drawer usable", (tester) async {
    final client = _FailingProfileClient();
    final controller = _Controller(client);
    final message = _message("visible", "latest message", minute: 32);
    controller.items.add(message);
    controller.history.add(message);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    await _tapName(tester, "visible");
    expect(find.text("@viewer"), findsOneWidget);
    expect(find.byTooltip("Reply"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("an immediate chatters failure displays retry without an uncaught error", (
    tester,
  ) async {
    final client = _FailingChattersClient();
    final controller = _Controller(client);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Chat options"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Chatters"));
    await tester.pumpAndSettle();
    expect(find.text("Could not load chatters"), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);
    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();
    expect(find.text("Could not load chatters"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("an immediate thread failure retains the reply and supports retry", (tester) async {
    final controller = _Controller(_FailingThreadClient());
    controller.items.add(
      const TwitchChatMessage(
        id: "reply",
        login: "viewer",
        displayName: "Viewer",
        text: "Local answer",
        parentMessageId: "root",
        parentLogin: "parent",
        parentText: "Original question",
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("reply-context-reply")));
    await tester.pumpAndSettle();
    expect(find.text("Could not load older replies"), findsOneWidget);
    expect(_log(find.byKey(const ValueKey("chat_reply_thread")), "Local answer"), findsOneWidget);
    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();
    expect(find.text("Could not load older replies"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "pin uses separate pinner metadata, rich sender details, and local collapse and close",
    (tester) async {
      await _cacheImages(tester);
      final client = _Client();
      final controller = _Controller(client);
      final assets = _PinnedAssets(client);
      addTearDown(assets.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_panel(controller, assets: assets));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("chat_pinned_message")), findsNothing);
      controller.pin = TwitchPinnedChat(
        id: "pin-event-1",
        pinnedBy: (id: "99", login: "pinner", displayName: "Pinner"),
        message: TwitchChatMessage(
          id: "pin",
          login: "viewer",
          displayName: "Viewer",
          badges: ["moderator/1"],
          text: "A pinned message with full details and a https://example.com link",
          timestamp: DateTime(2026, 5, 12, 10, 1),
        ),
      );
      controller.update();
      await tester.pumpAndSettle();
      final box = find.byKey(const ValueKey("chat_pinned_message"));
      expect(find.textContaining("Pinned by", findRichText: true), findsOneWidget);
      expect(find.textContaining("Pinner", findRichText: true), findsOneWidget);
      expect(find.textContaining("Viewer sent at", findRichText: true), findsOneWidget);
      expect(
        find.descendant(
          of: box,
          matching: find.byWidgetPredicate(
            (widget) => widget is Image && widget.semanticLabel == "Supporter",
          ),
        ),
        findsOneWidget,
      );
      final material = tester.widget<Material>(box);
      expect(material.color, buildFlowTheme(Brightness.dark).scaffoldBackgroundColor);
      expect((material.shape! as RoundedRectangleBorder).side.style, BorderStyle.solid);
      await tester.tap(find.byTooltip("Minimize pinned message"));
      await tester.pumpAndSettle();
      expect(find.textContaining("sent at", findRichText: true), findsNothing);
      expect(find.byTooltip("Expand pinned message"), findsOneWidget);
      await tester.tap(find.byTooltip("Expand pinned message"));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining("A pinned message", findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text("Pinned message"), findsOneWidget);
      expect(
        _log(find.byKey(const ValueKey("chat_reply_thread")), controller.pin!.message.text),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip("Close thread"));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey("pinned-pin-event-1")));
      await tester.pumpAndSettle();
      expect(find.text("Copy message"), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Close pinned message"));
      await tester.pumpAndSettle();
      controller.update();
      await tester.pumpAndSettle();
      expect(box, findsNothing);
      controller.pin = TwitchPinnedChat(
        id: "pin-event-2",
        message: controller.pin!.message,
        pinnedBy: controller.pin!.pinnedBy,
      );
      controller.update();
      await tester.pumpAndSettle();
      expect(box, findsOneWidget);
      controller.pin = null;
      controller.update();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("chat_pinned_message")), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("user drawer loads profile, timestamps existing and new logs, and inserts a reply", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final older = _message("old", "older message", minute: 30);
    final current = _message("visible", "latest message", minute: 32);
    controller.history.addAll([older, current]);
    controller.items.add(current);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "existing draft");
    await _tapName(tester, "visible");
    expect(client.lookups, [(userId: "1234", login: "viewer")]);
    expect(find.text("Viewer Profile"), findsOneWidget);
    expect(find.text("@viewer"), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any((image) => (image.image as NetworkImage).url == _avatar),
      isTrue,
    );
    final history = find.byKey(const ValueKey("chat_user_history"));
    expect(_log(history, "09:30 Viewer: older message"), findsOneWidget);
    expect(_log(history, "09:32 Viewer: latest message"), findsOneWidget);
    expect(
      tester.getTopLeft(_log(history, "older message")).dy,
      lessThan(tester.getTopLeft(_log(history, "latest message")).dy),
    );
    controller.history.addAll([
      _message("next", "arrived while open", minute: 33),
      const TwitchChatMessage(
        id: "other",
        login: "other",
        displayName: "Other",
        text: "not this user",
      ),
    ]);
    controller.update();
    await tester.pumpAndSettle();
    expect(_log(history, "09:33 Viewer: arrived while open"), findsOneWidget);
    expect(_log(history, "not this user"), findsNothing);
    await tester.tap(find.byTooltip("Reply"));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("chat_user_history")), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      "@viewer existing draft",
    );
    expect(client.blocked, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets("blocking requires confirmation and targets the resolved Twitch account ID", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final current = _message("visible", "latest message", minute: 32);
    controller.items.add(current);
    controller.history.add(current);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    await _tapName(tester, "visible");
    await _openBlockConfirmation(tester);
    expect(client.blocked, isEmpty);
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
    expect(client.blocked, isEmpty);
    expect(find.byKey(const ValueKey("chat_user_history")), findsOneWidget);
    await _openBlockConfirmation(tester);
    await tester.tap(find.widgetWithText(FilledButton, "Block"));
    await tester.pumpAndSettle();
    expect(client.blocked, ["1234"]);
    expect(tester.takeException(), isNull);
  });

  testWidgets("removing the player closes stacked user and asset drawers and detaches listeners", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _Assets(client);
    final visible = ValueNotifier(true);
    final message = _message("visible", "Party", minute: 32);
    controller.items.add(message);
    controller.history.add(message);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, show, child) => show
                ? TwitchChatPanel(
                    controller: controller,
                    assets: assets,
                    preferences: MemoryFlowPreferences(),
                    chatOnly: true,
                    isLive: true,
                    onToggleChatOnly: () {},
                  )
                : const Text("Player closed"),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapName(tester, "visible");
    final history = find.byKey(const ValueKey("chat_user_history"));
    await tester.tap(
      find.descendant(
        of: history,
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && widget.semanticLabel == "Party",
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("7TV emote"), findsOneWidget);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.text("Player closed"), findsOneWidget);
    expect(find.text("7TV emote"), findsNothing);
    expect(history, findsNothing);
    expect(controller.listening, isFalse);
    controller.update();
    expect(tester.takeException(), isNull);
  });

  testWidgets("report invokes the in-app action without blocking or closing live logs", (
    tester,
  ) async {
    await _cacheImages(tester);
    final opened = <String>[];
    final client = _Client();
    final controller = _Controller(client);
    final current = _message("visible", "latest message", minute: 32);
    controller.items.add(current);
    controller.history.add(current);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, onReportUser: (login) async => opened.add(login)));
    await tester.pumpAndSettle();
    await _tapName(tester, "visible");
    await tester.tap(find.byTooltip("User options"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Report Viewer"));
    await tester.pumpAndSettle();
    expect(opened, ["viewer"]);
    expect(client.blocked, isEmpty);
    expect(find.text("Block Viewer?"), findsNothing);
    final history = find.byKey(const ValueKey("chat_user_history"));
    expect(history, findsOneWidget);
    controller.history.add(_message("next", "still receiving messages", minute: 33));
    controller.update();
    await tester.pumpAndSettle();
    expect(_log(history, "09:33 Viewer: still receiving messages"), findsOneWidget);
    expect(controller.listening, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets("emote and badge drawers show metadata and use clipboard and browser channels", (
    tester,
  ) async {
    await _cacheImages(tester);
    final copied = <String>[];
    final opened = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const external = MethodChannel("flow/external_url");
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.setData") {
        copied.add((call.arguments as Map<Object?, Object?>)["text"]! as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(external, (call) async {
      expect(call.method, "openExternalUrl");
      opened.add(call.arguments as String);
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(external, null);
    });
    final client = _Client();
    final controller = _Controller(client)
      ..items.add(
        const TwitchChatMessage(
          id: "asset",
          login: "viewer",
          displayName: "Viewer",
          text: "Kappa Party",
          badges: ["moderator/1"],
          emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
        ),
      );
    final assets = _Assets(client);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is Image && widget.semanticLabel == "Party"),
    );
    await tester.pumpAndSettle();
    expect(find.text("Party"), findsOneWidget);
    expect(find.text("7TV emote"), findsOneWidget);
    expect(find.text("By Emote Artist"), findsOneWidget);
    expect(find.text("Open in browser"), findsOneWidget);
    await tester.tap(find.text("Copy name"));
    await tester.pump();
    await tester.tap(find.text("Copy image URL"));
    await tester.pump();
    await tester.tap(find.text("Open in browser"));
    await tester.pump();
    expect(copied, ["Party", _emoteUrl]);
    expect(opened, [_emoteUrl]);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is Image && widget.semanticLabel == "Moderator"),
    );
    await tester.pumpAndSettle();
    expect(find.text("Moderator"), findsOneWidget);
    expect(find.text("Twitch badge"), findsOneWidget);
    expect(find.text("Open in browser"), findsOneWidget);
    await tester.tap(find.text("Open in browser"));
    await tester.pump();
    expect(opened.last, _badgeUrl);
    expect(find.text("Copy image URL"), findsOneWidget);
    expect(find.textContaining("By "), findsNothing);
    await tester.tap(find.text("Copy name"));
    await tester.pump();
    expect(copied.last, "Moderator");
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is Image && widget.semanticLabel == "Kappa"),
    );
    await tester.pumpAndSettle();
    expect(find.text("Kappa"), findsOneWidget);
    expect(find.text("Twitch emote"), findsOneWidget);
    expect(find.text("Open in browser"), findsOneWidget);
    await tester.tap(find.text("Open in browser"));
    await tester.pump();
    expect(opened.last, _twitchEmoteUrl);
    expect(find.text("Copy name"), findsOneWidget);
    await tester.tap(find.text("Copy image URL"));
    await tester.pump();
    expect(copied.last, _twitchEmoteUrl);
    expect(opened, [_emoteUrl, _badgeUrl, _twitchEmoteUrl]);
    expect(client.blocked, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Widget _panel(
  _Controller controller, {
  TwitchChatAssets? assets,
  Future<void> Function(String)? onReportUser,
}) => MaterialApp(
  theme: buildFlowTheme(Brightness.dark),
  home: Scaffold(
    body: TwitchChatPanel(
      controller: controller,
      assets: assets,
      onReportUser: onReportUser,
      preferences: MemoryFlowPreferences(),
      chatOnly: true,
      isLive: true,
      onToggleChatOnly: () {},
    ),
  ),
);

Finder _log(Finder history, String text) => find.descendant(
  of: history,
  matching: find.textContaining(text, findRichText: true),
);

Future<void> _tapName(WidgetTester tester, String id) async {
  final text = find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(RichText)).first;
  await tester.tapAt(tester.getTopLeft(text) + const Offset(12, 10));
  await tester.pumpAndSettle();
}

Future<void> _openBlockConfirmation(WidgetTester tester) async {
  await tester.tap(find.byTooltip("User options"));
  await tester.pumpAndSettle();
  await tester.tap(find.text("Block Viewer"));
  await tester.pumpAndSettle();
  expect(find.text("Block Viewer?"), findsOneWidget);
}

TwitchChatMessage _message(String id, String text, {required int minute}) => TwitchChatMessage(
  id: id,
  login: "viewer",
  userId: "1234",
  displayName: "Viewer",
  text: text,
  timestamp: DateTime(2026, 5, 12, 9, minute),
);

Future<void> _cacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
    final picture = recorder.endRecording();
    final pixel = await picture.toImage(1, 1);
    picture.dispose();
    for (final url in [_avatar, _emoteUrl, _badgeUrl, _twitchEmoteUrl]) {
      PaintingBinding.instance.imageCache.putIfAbsent(
        NetworkImage(url),
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: pixel.clone()))),
      );
    }
    pixel.dispose();
  });
}

class _Client extends TwitchApiClient {
  _Client() : super(clientId: "test", accessToken: "test", gqlAccessToken: "test");

  final lookups = <({String? userId, String? login})>[];
  final blocked = <String>[];
  final thread = <TwitchChatMessage>[];

  @override
  Future<List<TwitchChatMessage>> fetchChatReplyThread(String messageId) async => thread;

  @override
  Future<TwitchUser?> fetchChatUser({String? userId, String? login}) async {
    lookups.add((userId: userId, login: login));
    return const TwitchUser(
      id: "1234",
      login: "viewer",
      displayName: "Viewer Profile",
      profileImageUrl: _avatar,
    );
  }

  @override
  Future<void> blockUser(String userId) async => blocked.add(userId);
}

class _Controller extends TwitchChatController {
  _Controller(_Client client, {super.channel = "channel"})
    : super(clientLoader: () async => client, autoConnect: false);

  final items = <TwitchChatMessage>[];
  final history = <TwitchChatMessage>[];
  final sent = <({String text, TwitchChatMessage? replyTo})>[];
  TwitchPinnedChat? pin;

  @override
  TwitchChatMessage? get pinnedMessage => pin?.message;

  @override
  TwitchPinnedChat? get pinnedChat => pin;

  bool get listening => hasListeners;

  @override
  List<TwitchChatMessage> get messages => items;

  @override
  List<TwitchChatMessage> get recentHistory => history;

  @override
  TwitchChatStatus get status => TwitchChatStatus.connected;

  @override
  bool get isSignedIn => true;

  @override
  bool get canSend => true;

  @override
  Future<bool> send(String text, {TwitchChatMessage? replyTo}) async {
    sent.add((text: text, replyTo: replyTo));
    return true;
  }

  void update() => notifyListeners();
}

class _FailingProfileClient extends _Client {
  @override
  Future<TwitchUser?> fetchChatUser({String? userId, String? login}) async =>
      throw TwitchApiException("Offline");
}

class _FailingChattersClient extends _Client {
  @override
  Future<TwitchChatters> fetchChatters(String login) async => throw TwitchApiException("Offline");
}

class _FailingThreadClient extends _Client {
  @override
  Future<List<TwitchChatMessage>> fetchChatReplyThread(String messageId) async =>
      throw TwitchApiException("Offline");
}

class _Assets extends TwitchChatAssets {
  _Assets(_Client client)
    : super(clientLoader: () async => client, channelLogin: "channel", autoLoad: false);

  @override
  Map<String, ChatAssetEmote> get emotesByName => const {
    "Party": ChatAssetEmote(
      name: "Party",
      id: "party-id",
      url: _emoteUrl,
      provider: ChatEmoteProvider.sevenTv,
      author: "Emote Artist",
    ),
  };

  @override
  Map<String, String> get badgeUrls => const {"moderator/1": _badgeUrl};

  @override
  Map<String, ChatAssetBadge> get badgesById => const {
    "moderator/1": ChatAssetBadge(
      id: "moderator/1",
      title: "Moderator",
      url: _badgeUrl,
      provider: ChatEmoteProvider.twitch,
    ),
  };
}

class _PinnedAssets extends _Assets {
  _PinnedAssets(super.client);

  @override
  Map<String, List<ChatAssetBadge>> get userBadgesByLogin => const {
    "viewer": [
      ChatAssetBadge(
        id: "supporter",
        title: "Supporter",
        url: _emoteUrl,
        provider: ChatEmoteProvider.sevenTv,
      ),
    ],
    "pinner": [
      ChatAssetBadge(
        id: "supporter",
        title: "Supporter",
        url: _emoteUrl,
        provider: ChatEmoteProvider.sevenTv,
      ),
    ],
  };
}
