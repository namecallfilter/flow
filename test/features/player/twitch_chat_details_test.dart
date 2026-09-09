import "dart:async";
import "dart:ui" as ui;

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/chat_username.dart";
import "package:flow/features/player/twitch_chat_panel.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";

const _avatar = "https://example.com/avatar.png";
const _emoteUrl = "https://example.com/party.png";
const _badgeUrl = "https://example.com/moderator.png";
const _twitchEmoteUrl = "https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/2.0";
const _emotePyramid =
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ sadE ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ sadE sadE ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ sadE sadE sadE ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ sadE sadE sadE sadE ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ sadE sadE sadE sadE sadE ͏";
const _brailleArtRows = [
  "⠄⢀⣀⣀⣀⣀⡀⢀⣀⡀⠄⠄⣀⡀⠄⠄⢀⣀⣀⡀⠄⠄⣀⣀⠄⠄⣀⣀⡀⠄",
  "⠄⢸⣿⡟⠛⠛⠃⢸⣿⡇⠄⠄⣿⡇⠄⣼⣿⠟⠻⣿⣆⠄⣿⣿⢠⣾⣿⠋⠄⠄",
  "⠄⢸⣿⣷⣶⣶⠄⢸⣿⡇⠄⠄⣿⡇⠄⣿⡏⠄⠄⠄⠄⠄⣿⣿⣿⣿⣇⠄⠄⠄",
  "⠄⢸⣿⡇⠄⠄⠄⠘⣿⣧⣀⣰⣿⡇⠄⢿⣿⣀⣠⣿⡶⠄⣿⣿⠃⢹⣿⣆⠄⠄",
  "⠄⠘⠛⠃⠄⠄⠄⠄⠘⠛⠛⠛⠋⠄⠄⠈⠛⠛⠛⠛⠁⠄⠛⠛⠄⠄⠛⠛⠃⠄",
  "⠄⠄⠄⠄⢠⣤⡄⠄⠄⣤⣤⠄⢀⣠⣤⣄⡀⠄⢠⣤⡄⠄⠄⣤⣤⠄⠄⠄⠄⠄",
  "⠄⠄⠄⠄⠄⢻⣿⣄⣼⣿⠃⣰⣿⠟⠛⢿⣿⡄⢸⣿⡇⠄⠄⣿⣿⠄⠄⠄⠄⠄",
  "⠄⠄⠄⠄⠄⠄⠻⣿⡿⠁⠄⣿⣿⠄⠄⢸⣿⡇⢸⣿⡇⠄⠄⣿⣿⠄⠄⠄⠄⠄",
  "⠄⠄⠄⠄⠄⠄⠄⣿⡇⠄⠄⠹⣿⣦⣤⣼⣿⠃⠄⣿⣷⣤⣴⣿⡏⠄⠄⠄⠄⠄",
  "⠄⠄⠄⠄⠄⠄⠄⠛⠃⠄⠄⠄⠈⠛⠛⠋⠁⠄⠄⠈⠙⠛⠛⠉⠄⠄⠄⠄⠄⠄",
  "⠄⠄⢀⣠⣤⣤⣄⡀⠄⣤⣤⠄⠄⣤⣤⠄⠄⠄⣤⣤⡄⠄⣤⣤⣤⣤⣤⣤⠄⠄",
  "⠄⠄⣾⣿⠋⠙⠿⠗⠄⣿⣿⣀⣀⣿⣿⠄⠄⣸⣿⢿⣷⠄⠛⠛⣿⣿⠛⠛⠄⠄",
  "⠄⠄⣿⣿⠄⠄⣀⠄⠄⣿⣿⠿⠿⣿⣿⠄⢠⣿⣏⣸⣿⡆⠄⠄⣿⣿⠄⠄⠄⠄",
  "⠄⠄⠻⣿⣦⣴⣿⡟⠄⣿⣿⠄⠄⣿⣿⠄⣼⣿⠿⠿⢿⣿⡀⠄⣿⣿⠄⠄⠄⠄",
  "⠄⠄⠄⠈⠉⠉⠉⠄⠄⠉⠉⠄⠄⠉⠉⠄⠉⠉⠄⠄⠈⠉⠁⠄⠉⠉⠄⠄⠄⠄",
];

void main() {
  testWidgets("mentions and replies highlight and sound once without replaying history", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sounds = <MethodCall>[];
    const channel = MethodChannel("flow/chat_notifications");
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => sounds.add(call),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final controller = _Controller(_Client())
      ..viewerId = "self"
      ..viewerLogin = "my_login"
      ..items.add(_message("existing", "Existing @MY_LOGIN", minute: 1));
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, settingsStore: settings));
    await tester.pumpAndSettle();
    expect(_highlight(tester, "existing").border, isNotNull);
    expect(sounds, isEmpty);

    controller.items.addAll([
      _message("mention", "Hello (@My_Login)!", minute: 2),
      _message("other", "@my_login_extra @other email@my_login", minute: 2),
      _message("own", "@my_login", minute: 2).copyWith(isOwn: true),
      _message("history", "Old @my_login", minute: 2).copyWith(isHistorical: true),
      _message("deleted", "@my_login", minute: 2).copyWith(isDeleted: true),
    ]);
    controller.update();
    await tester.pumpAndSettle();
    expect(sounds.map((call) => call.method), ["mention"]);
    expect(_highlight(tester, "mention").border, isNotNull);
    expect(_highlight(tester, "history").border, isNotNull);
    expect(_highlight(tester, "other").border, isNull);
    expect(_highlight(tester, "own").border, isNull);
    controller.update();
    await tester.pumpAndSettle();
    expect(sounds, hasLength(1));

    controller.items.add(
      const TwitchChatMessage(
        id: "reply",
        login: "other",
        displayName: "Other",
        text: "A reply without an @mention",
        parentMessageId: "parent",
        parentUserId: "self",
        parentLogin: "previous_login",
        parentText: "My message",
      ),
    );
    controller.update();
    await tester.pumpAndSettle();
    expect(_highlight(tester, "reply").border, isNotNull);
    expect(sounds, hasLength(2));

    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(highlightMentions: false, mentionSounds: false),
    );
    controller.items.add(_message("muted", "@my_login", minute: 3));
    controller.update();
    await tester.pumpAndSettle();
    expect(_highlight(tester, "reply").border, isNull);
    expect(_highlight(tester, "muted").border, isNull);
    expect(sounds, hasLength(2));
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(highlightMentions: true, mentionSounds: true),
    );
    await tester.pumpAndSettle();
    expect(_highlight(tester, "muted").border, isNotNull);
    expect(sounds, hasLength(2));
    controller.viewerId = "second";
    controller.viewerLogin = "other";
    controller.update();
    await tester.pumpAndSettle();
    expect(_highlight(tester, "reply").border, isNull);
    expect(sounds, hasLength(2));
    controller.items.add(_message("new-account", "@other", minute: 4));
    controller.update();
    await tester.pumpAndSettle();
    expect(sounds, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets("mention sounds follow the display delay and skip muted arrivals", (tester) async {
    final sounds = <MethodCall>[];
    const channel = MethodChannel("flow/chat_notifications");
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => sounds.add(call),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final controller = _Controller(_Client())
      ..viewerId = "self"
      ..viewerLogin = "my_login";
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(autoSyncChat: false, manualChatDelaySeconds: 2),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, settingsStore: settings, chatOnly: false));
    await tester.pumpAndSettle();
    controller.items.add(
      TwitchChatMessage(
        id: "delayed-mention",
        login: "viewer",
        displayName: "Viewer",
        text: "@my_login",
        timestamp: DateTime.now(),
      ),
    );
    controller.update();
    await tester.pump();
    expect(find.byKey(const ValueKey("delayed-mention")), findsNothing);
    expect(sounds, isEmpty);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2100)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("delayed-mention")), findsOneWidget);
    expect(sounds, hasLength(1));
    await settings.setChatPreferences(settings.chatPreferences.copyWith(mentionSounds: false));
    controller.items.add(_message("silent", "@my_login", minute: 1));
    controller.update();
    await tester.pumpAndSettle();
    expect(_highlight(tester, "silent").border, isNotNull);
    expect(sounds, hasLength(1));
    await settings.setChatPreferences(settings.chatPreferences.copyWith(mentionSounds: true));
    await tester.pumpAndSettle();
    expect(sounds, hasLength(1));
  });

  testWidgets("native GIFs render alongside emotes and in quoted replies without changing URLs", (
    tester,
  ) async {
    const url =
        "https://media4.giphy.com/media/joSNxeswxuc74Juo8X/giphy.gif?cid=example&ep=v1_gifs_trending&rid=giphy.gif&ct=g";
    const label = "[Y A Y Yes GIF by Djemilah Birnie]";
    await _cacheImages(tester);
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.green, ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 120);
      picture.dispose();
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(url),
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
      );
    });
    addTearDown(PaintingBinding.instance.imageCache.clear);
    tester.view.physicalSize = const Size(240, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _Client();
    final assets = _Assets(client);
    const gif = TwitchChatGif(id: "joSNxeswxuc74Juo8X", url: url, start: 6, end: 6 + label.length);
    const parent = TwitchChatMessage(
      id: "gif-parent",
      login: "viewer",
      displayName: "Viewer",
      text: "Kappa $label Party",
      emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
      gifs: [gif],
    );
    final controller = _Controller(client)..items.add(parent);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey("gif-parent"));
    final image = find.byKey(const ValueKey("chat_gif-gif-parent-6"));
    expect((tester.widget<Image>(image).image as NetworkImage).url, url);
    expect(find.descendant(of: body, matching: find.byType(Image)), findsNWidgets(3));
    expect(tester.getSize(image).width, greaterThan(100));
    expect(tester.getSize(image).width, lessThanOrEqualTo(180));
    expect(tester.getSize(image).height, lessThanOrEqualTo(120));
    controller.items.add(
      TwitchChatMessage(
        id: "gif-reply",
        login: "other",
        displayName: "Other",
        text: "Reply",
        parentMessageId: parent.id,
        parentLogin: parent.login,
        parentDisplayName: parent.displayName,
        parentText: parent.text,
        parentEmotes: parent.emotes,
        parentGifs: parent.gifs,
      ),
    );
    controller.update();
    await tester.pumpAndSettle();
    final quoted = find.descendant(
      of: find.byKey(const ValueKey("reply-context-gif-reply")),
      matching: find.byType(Image),
    );
    expect(quoted, findsNWidgets(3));
    final quotedGif = find.descendant(
      of: find.byKey(const ValueKey("reply-context-gif-reply")),
      matching: image,
    );
    expect(tester.getSize(quotedGif).height, lessThanOrEqualTo(21));
    expect(tester.takeException(), isNull);
  });

  testWidgets("Braille art preserves complete rows and fits narrow or enlarged chat", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = _Client();
    final controller = _Controller(client)
      ..items.add(_message("art", _brailleArtRows.join(" "), minute: 1));
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, settingsStore: settings));
    for (final (width, fontSize) in [
      (392.0, 14.0),
      (240.0, 14.0),
      (392.0, 24.0),
      (640.0, 14.0),
    ]) {
      tester.view.physicalSize = Size(width, 1000);
      await settings.setChatPreferences(settings.chatPreferences.copyWith(fontSize: fontSize));
      await tester.pumpAndSettle();
      final art = find.byKey(const ValueKey("chat_message_art-art"));
      expect(art, findsOneWidget);
      final rich = find.descendant(of: art, matching: find.byType(RichText));
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      expect(paragraph.text.toPlainText(), _brailleArtRows.join("\n"));
      final lines = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length),
      );
      expect(lines.map((box) => box.top).toSet(), hasLength(15));
      final bounds = _paintedBounds(tester, rich);
      expect(bounds.left, closeTo(12, 0.01));
      expect(bounds.right, closeTo(width - 12, 0.01));
      expect(bounds.width / bounds.height, closeTo(paragraph.size.aspectRatio, 0.001));
      expect(_log(find.byKey(const ValueKey("art")), "Viewer: "), findsOneWidget);
      expect(controller.items.single.text, _brailleArtRows.join(" "));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("small Braille grids stay at text size and align with the message gutter", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(392, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _Controller(_Client())
      ..items.add(_message("small-art", "⣿⠄⣿ ⠄⣿⠄ ⣿⠄⣿", minute: 1));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    final art = find.byKey(const ValueKey("chat_message_art-small-art"));
    final rich = find.descendant(of: art, matching: find.byType(RichText));
    final paragraph = tester.renderObject<RenderParagraph>(rich);
    final bounds = _paintedBounds(tester, rich);
    expect(bounds.left, closeTo(12, 0.01));
    expect(bounds.width, closeTo(paragraph.size.width, 0.01));
    expect(bounds.height, closeTo(paragraph.size.height, 0.01));
    expect(paragraph.text.toPlainText(), "⣿⠄⣿\n⠄⣿⠄\n⣿⠄⣿");
    expect(tester.takeException(), isNull);
  });

  for (final name in ["sadE", "dancer", "Kappa"]) {
    testWidgets("$name Braille pyramid stays centered and preserves controls and raw text", (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _cacheImages(tester);
      final copied = <String>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == "Clipboard.setData") {
          copied.add((call.arguments as Map<Object?, Object?>)["text"]! as String);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final raw = _emotePyramid.replaceAll("sadE", name);
      final client = _Client();
      final controller = _Controller(client)
        ..items.add(
          TwitchChatMessage(
            id: "art",
            login: "viewer",
            userId: "1234",
            displayName: "Viewer",
            text: raw,
            emotes: name == "Kappa"
                ? [
                    for (final match in RegExp(name).allMatches(raw))
                      TwitchChatEmote(id: "25", start: match.start, end: match.end),
                  ]
                : const [],
          ),
        );
      final assets = _ArtAssets(client);
      final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
      await settings.load();
      addTearDown(controller.dispose);
      addTearDown(assets.dispose);
      await tester.pumpWidget(_panel(controller, assets: assets, settingsStore: settings));
      final art = find.byKey(const ValueKey("chat_message_art-art"));
      final images = find.descendant(
        of: art,
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && widget.semanticLabel == name,
        ),
      );
      for (final (width, fontSize) in [(392.0, 14.0), (240.0, 14.0), (240.0, 24.0)]) {
        tester.view.physicalSize = Size(width, 1000);
        await settings.setChatPreferences(settings.chatPreferences.copyWith(fontSize: fontSize));
        await tester.pumpAndSettle();
        expect(images, findsNWidgets(15));
        final rows = <int, List<Rect>>{};
        for (var index = 0; index < 15; index++) {
          final bounds = _paintedBounds(tester, images.at(index));
          rows.putIfAbsent(bounds.center.dy.round(), () => []).add(bounds);
          expect(bounds.left, greaterThanOrEqualTo(12 - 0.01));
          expect(bounds.right, lessThanOrEqualTo(width - 12 + 0.01));
        }
        expect(rows.values.map((row) => row.length), [1, 2, 3, 4, 5]);
        for (final row in rows.values) {
          expect((row.first.left + row.last.right) / 2, closeTo(width / 2, 0.01));
        }
        expect(tester.takeException(), isNull);
      }
      final tap = await tester.startGesture(_paintedBounds(tester, images.first).center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_highlight(tester, "art").color?.a ?? 0, 0);
      await tap.up();
      await tester.pumpAndSettle();
      expect(find.text(name == "Kappa" ? "Twitch emote" : "7TV emote"), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      final feed = find.byKey(const ValueKey("art"));
      await tester.tapAt(_textPoint(tester, feed, "Viewer: ") + const Offset(1, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("chat_user_history")), findsOneWidget);
      expect(client.lookups.last, (userId: "1234", login: "viewer"));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await settings.setChatPreferences(
        settings.chatPreferences.copyWith(sevenTvEmotes: false, twitchEmotes: false),
      );
      await tester.pumpAndSettle();
      expect(images, findsNothing);
      final rich = find.descendant(of: art, matching: find.byType(RichText));
      expect(
        tester.widget<RichText>(rich).text.toPlainText().split("\n"),
        [for (var count = 1; count <= 5; count++) List.filled(count, name).join(" ")],
      );
      await tester.longPress(art);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Copy message"));
      await tester.pumpAndSettle();
      expect(copied, [raw]);
      await tester.longPress(art);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Reply to message"));
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey("chat_message_input"));
      await tester.enterText(composer, "reply");
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(controller.sent.single.replyTo?.text, raw);
      expect(controller.items.single.text, raw);
      if (name == "Kappa") {
        controller.items[0] = _message("art", raw, minute: 1);
        controller.update();
        await tester.pumpAndSettle();
        expect(art, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("ordinary Braille text and non-pyramid emote patterns keep normal layout", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _ArtAssets(client);
    final messages = [
      "Ordinary ⠄⠄⠄ ⠁⠁⠁ ⠂⠂⠂ text",
      "⠄⠄⠄ ⠁⠁ ⠂⠂⠂",
      "⠀⠀⠀⠀⠀⠀ sadE ⠀⠀⠀⠀ sadE sadE",
      "⠀⠀⠀⠀⠀⠀ sadE ⠀⠀⠀⠀ sadE sadE ⠀⠀ sadE sadE",
      "⠀⠀⠀⠀⠀⠀ sadE ⠀⠀⠀⠀ sadE dancer ⠀⠀ sadE sadE sadE",
      "⠀⠀⠀⠀ sadE ⠀⠀⠀⠀ sadE sadE ⠀⠀ sadE sadE sadE",
      _emotePyramid.replaceAll("sadE", "unknown"),
    ];
    for (var index = 0; index < messages.length; index++) {
      controller.items.add(_message("plain-$index", messages[index], minute: index));
    }
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    for (var index = 0; index < messages.length; index++) {
      expect(find.byKey(ValueKey("chat_message_art-plain-$index")), findsNothing);
      expect(find.byKey(ValueKey("plain-$index")), findsOneWidget);
      expect(controller.items[index].text, messages[index]);
    }
    expect(tester.takeException(), isNull);
  });

  for (final moderation in [TwitchChatModeration.ban, TwitchChatModeration.timeout]) {
    testWidgets(
      "${moderation.name} grays message images in feed, preview, logs, and thread without disabling taps",
      (tester) async {
        PaintingBinding.instance.imageCache.clear();
        await _cacheImages(tester, color: Colors.greenAccent);
        final client = _Client();
        final controller = _Controller(client);
        final assets = _Assets(client);
        final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
        await settings.load();
        await settings.setChatPreferences(
          settings.chatPreferences.copyWith(showDeletedMessages: true),
        );
        const original = TwitchChatMessage(
          id: "gray",
          login: "viewer",
          userId: "1234",
          displayName: "Viewer",
          text: "Kappa Party",
          color: "#FF0000",
          badges: ["moderator/1"],
          emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
          parentMessageId: "root",
          parentLogin: "parent",
          parentText: "Original question",
        );
        controller.items.add(original);
        controller.history.add(original);
        addTearDown(controller.dispose);
        addTearDown(assets.dispose);
        addTearDown(PaintingBinding.instance.imageCache.clear);
        const frame = ValueKey("moderation-frame");
        await tester.pumpWidget(
          RepaintBoundary(
            key: frame,
            child: _panel(controller, assets: assets, settingsStore: settings),
          ),
        );
        await tester.pumpAndSettle();
        Finder asset(Finder row, String label) => find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (widget) => widget is Image && widget.semanticLabel == label,
          ),
        );
        final feed = find.byKey(const ValueKey("gray"));
        final originalColor = await _pixelAt(tester, frame, tester.getCenter(asset(feed, "Party")));
        expect(originalColor.g, greaterThan(originalColor.r));
        final deleted = original.copyWith(
          isDeleted: true,
          moderation: moderation,
          timeoutSeconds: moderation == TwitchChatModeration.timeout ? 60 : null,
          moderatedAt: DateTime(2026, 5, 12),
        );
        controller.items[0] = deleted;
        controller.history[0] = deleted;
        controller.update();
        await tester.pumpAndSettle();
        Future<void> checkGray(Finder row) async {
          for (final label in ["Party", "Kappa", "Moderator"]) {
            final color = await _pixelAt(tester, frame, tester.getCenter(asset(row, label)));
            expect((color.r - color.g).abs(), lessThan(0.01), reason: "$label should be grayscale");
            expect((color.r - color.b).abs(), lessThan(0.01), reason: "$label should be grayscale");
            expect(
              color.r,
              inExclusiveRange(0.05, 0.65),
              reason: "$label should be dimmed but readable",
            );
          }
          expect(_log(row, "(deleted)"), findsNothing);
        }

        await checkGray(feed);
        final tap = await tester.startGesture(
          tester.getCenter(asset(feed, "Party")) + const Offset(2, 2),
        );
        await tester.pump(const Duration(milliseconds: 80));
        await tap.up();
        await tester.pumpAndSettle();
        expect(find.text("7TV emote"), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.longPress(feed);
        await tester.pumpAndSettle();
        await checkGray(find.byKey(const ValueKey("chat_message_preview")));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tapAt(_textPoint(tester, feed, "Viewer: "));
        await tester.pumpAndSettle();
        await checkGray(find.byKey(const ValueKey("log-gray")));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey("reply-context-gray")));
        await tester.pumpAndSettle();
        await checkGray(find.byKey(const ValueKey("thread-gray")));
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final incoming in [false, true]) {
    testWidgets(
      "asset and reply taps survive rendered pointer-down frames${incoming ? ' and incoming chat' : ''}",
      (tester) async {
        await _cacheImages(tester);
        final client = _Client();
        final controller = _Controller(client);
        final assets = _Assets(client);
        const message = TwitchChatMessage(
          id: "target",
          login: "viewer",
          displayName: "Viewer",
          text: "Kappa Party",
          emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
          badges: ["moderator/1"],
          parentMessageId: "parent",
          parentLogin: "parent",
          parentText: "Original question",
        );
        controller.items.add(message);
        controller.history.add(message);
        addTearDown(controller.dispose);
        addTearDown(assets.dispose);
        await tester.pumpWidget(_panel(controller, assets: assets));
        await tester.pumpAndSettle();
        for (final label in ["Party", "Kappa", "Moderator", "Reply"]) {
          final target = label == "Reply"
              ? find.byKey(const ValueKey("reply-context-target"))
              : find.byWidgetPredicate(
                  (widget) => widget is Image && widget.semanticLabel == label,
                );
          final bounds = tester.getRect(target);
          final gesture = await tester.startGesture(
            bounds.topLeft + Offset(bounds.width * 0.7, bounds.height * 0.6),
          );
          await tester.pump();
          expect(_highlight(tester, "target").color?.a ?? 0, 0);
          await tester.pump(const Duration(milliseconds: 40));
          expect(_highlight(tester, "target").color?.a ?? 0, 0);
          if (incoming) {
            final next = TwitchChatMessage(
              id: "new-$label",
              login: "newviewer",
              displayName: "New viewer",
              text: "An incoming message",
            );
            controller.items.add(next);
            controller.history.add(next);
            controller.update();
          }
          await gesture.moveBy(const Offset(1, 1));
          await tester.pump(const Duration(milliseconds: 40));
          expect(_highlight(tester, "target").color?.a ?? 0, 0);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey("chat_message_preview")), findsNothing);
          expect(
            label == "Reply" ? find.text("REPLIES") : find.text(label),
            findsOneWidget,
            reason: "$label must respond to a normal tap across rendered frames",
          );
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets("interactive text keeps its background and ordinary text feedback fades in and out", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _Assets(client);
    for (final id in ["ordinary", "first", "notice", "highlighted"]) {
      controller.items.add(
        TwitchChatMessage(
          id: id,
          login: "viewer",
          displayName: "Viewer",
          text: "ordinary @Other example.com",
          badges: ["moderator/1"],
          isFirstMessage: id == "first",
          isHighlighted: id == "highlighted",
          noticeType: id == "notice" ? "announcement" : null,
        ),
      );
    }
    controller.history.addAll(controller.items);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final chatBounds = tester.getRect(find.byKey(const ValueKey("chat_messages")));
    final nameX = _textPoint(tester, find.byKey(const ValueKey("ordinary")), "Viewer: ").dx;
    for (final id in ["ordinary", "first", "notice", "highlighted"]) {
      final row = find.byKey(ValueKey(id));
      final bounds = tester.getRect(find.byKey(ValueKey("chat_message_highlight-$id")));
      expect(bounds.left, chatBounds.left);
      expect(bounds.right, chatBounds.right);
      expect(tester.getTopLeft(_log(row, "ordinary")).dx, chatBounds.left + 12);
      final badge = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && widget.semanticLabel == "Moderator",
        ),
      );
      expect(tester.getTopLeft(badge).dx, closeTo(chatBounds.left + 12, 0.01));
      expect(_textPoint(tester, row, "Viewer: ").dx, closeTo(nameX, 0.01));
      if (id == "highlighted") {
        expect(
          find.descendant(of: row, matching: find.text("Highlighted message")),
          findsOneWidget,
        );
        expect(find.descendant(of: row, matching: find.byType(Icon)), findsNothing);
        expect(find.descendant(of: row, matching: find.byType(SvgPicture)), findsNothing);
      }
      final background = _highlight(tester, id);
      if (id != "ordinary") {
        expect(background.color!.a, greaterThan(0));
        expect(background.border, isNotNull);
      }
      for (final label in ["Viewer: ", "@Other", "example.com"]) {
        final gesture = await tester.startGesture(
          _textPoint(tester, row, label) + const Offset(1, 0),
        );
        await tester.pump();
        expect(_highlight(tester, id), background);
        await tester.pump(const Duration(milliseconds: 75));
        expect(_highlight(tester, id), background);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_highlight(tester, id), background);
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
    }
    final row = find.byKey(const ValueKey("ordinary"));
    final gesture = await tester.startGesture(_textPoint(tester, row, "ordinary"));
    await tester.pump();
    expect(_highlight(tester, "ordinary").color?.a ?? 0, 0);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_highlight(tester, "ordinary").color!.a, inExclusiveRange(0, 0.18));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_highlight(tester, "ordinary").color!.a, closeTo(0.18, 0.001));
    await gesture.cancel();
    await tester.pump();
    expect(_highlight(tester, "ordinary").color!.a, closeTo(0.18, 0.001));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_highlight(tester, "ordinary").color!.a, inExclusiveRange(0, 0.18));
    await tester.pumpAndSettle();
    expect(_highlight(tester, "ordinary").color?.a ?? 0, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("holding interactive chat targets highlights the row and release clears it", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _Assets(client);
    const message = TwitchChatMessage(
      id: "hold-target",
      login: "viewer",
      displayName: "Viewer",
      text: "Kappa Party @Other example.com",
      emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
      badges: ["moderator/1"],
      parentMessageId: "parent",
      parentLogin: "parent",
      parentText: "Original question",
    );
    controller.items.add(message);
    controller.history.add(message);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey("hold-target"));
    double highlightAlpha() =>
        (tester
                    .widget<DecoratedBox>(
                      find.descendant(of: row, matching: find.byType(DecoratedBox)).first,
                    )
                    .decoration
                as BoxDecoration)
            .color
            ?.a ??
        0;
    final quote = tester.widget<Transform>(
      find
          .ancestor(
            of: find.descendant(of: row, matching: find.byIcon(Icons.format_quote_rounded)),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(quote.transform.entry(0, 0), -1);
    expect(quote.transform.entry(1, 1), -1);
    for (final label in [
      "Viewer: ",
      "@Other",
      "example.com",
      "Party",
      "Kappa",
      "Moderator",
      "Reply",
    ]) {
      final position = label == "Reply"
          ? tester.getCenter(find.byKey(const ValueKey("reply-context-hold-target")))
          : ["Party", "Kappa", "Moderator"].contains(label)
          ? tester.getCenter(
              find.descendant(
                of: row,
                matching: find.byWidgetPredicate(
                  (widget) => widget is Image && widget.semanticLabel == label,
                ),
              ),
            )
          : _textPoint(tester, row, label);
      final gesture = await tester.startGesture(position + const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(highlightAlpha(), 0);
      await tester.pump(kLongPressTimeout - const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 75));
      expect(highlightAlpha(), inExclusiveRange(0, 0.18));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const ValueKey("chat_message_preview")), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(highlightAlpha(), 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("a user log ignores its own name and self mentions while opening other users", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final message = _message("self-log", "Hello @Other and @Viewer", minute: 32);
    controller.items.add(message);
    controller.history.addAll([
      message,
      const TwitchChatMessage(
        id: "other-user",
        login: "other",
        userId: "7777",
        displayName: "Other",
        text: "Hello",
      ),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    await _tapName(tester, "self-log");
    final row = find.byKey(const ValueKey("log-self-log"));
    for (final label in ["Viewer: ", "@Viewer"]) {
      final gesture = await tester.startGesture(_textPoint(tester, row, label));
      await tester.pump(const Duration(milliseconds: 40));
      controller.update();
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(client.lookups, [(userId: "1234", login: "viewer")]);
      expect(find.byKey(const ValueKey("chat_user_history")), findsOneWidget);
    }
    final gesture = await tester.startGesture(_textPoint(tester, row, "@Other"));
    await tester.pump(const Duration(milliseconds: 40));
    controller.update();
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(client.lookups.last, (userId: "7777", login: "other"));
    expect(find.text("@other"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets("an emote tap survives a new message arriving in the open user log", (tester) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _Assets(client);
    final message = _message("target-log", "Party", minute: 32);
    controller.items.add(message);
    controller.history.add(message);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    await _tapName(tester, "target-log");
    final emote = find.descendant(
      of: find.byKey(const ValueKey("log-target-log")),
      matching: find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == "Party",
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(emote) + const Offset(2, 2));
    await tester.pump(const Duration(milliseconds: 40));
    controller.history.add(_message("new-log", "An incoming log message", minute: 33));
    controller.update();
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text("7TV emote"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("an emote tap survives a nested reply inserted before the pressed thread row", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _Assets(client);
    const message = TwitchChatMessage(
      id: "target-thread",
      login: "viewer",
      displayName: "Viewer",
      text: "Party",
      parentMessageId: "root",
      parentLogin: "parent",
    );
    client.thread.addAll([
      const TwitchChatMessage(id: "root", login: "parent", displayName: "Parent", text: "Question"),
      const TwitchChatMessage(
        id: "first",
        login: "first",
        displayName: "First",
        text: "First reply",
        parentMessageId: "root",
      ),
      message,
    ]);
    controller.items.add(message);
    controller.history.add(message);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("reply-context-target-thread")));
    await tester.pumpAndSettle();
    final emote = find.descendant(
      of: find.byKey(const ValueKey("thread-target-thread")),
      matching: find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == "Party",
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(emote) + const Offset(2, 2));
    await tester.pump(const Duration(milliseconds: 40));
    controller.history.add(
      const TwitchChatMessage(
        id: "nested",
        login: "nested",
        displayName: "Nested",
        text: "A nested reply",
        parentMessageId: "first",
      ),
    );
    controller.update();
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text("7TV emote"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      final haptics = <Object?>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == "Clipboard.setData") {
          copied.add((call.arguments as Map<Object?, Object?>)["text"]! as String);
        } else if (call.method == "HapticFeedback.vibrate") {
          haptics.add(call.arguments);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_panel(controller, assets: assets));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey("visible"));
      final name = find.descendant(of: row, matching: find.byType(RichText)).first;
      final hold = await tester.startGesture(tester.getTopLeft(name) + const Offset(12, 10));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_highlight(tester, "visible").color?.a ?? 0, 0);
      await tester.pump(kLongPressTimeout);
      await hold.up();
      await tester.pumpAndSettle();
      expect(haptics, ["HapticFeedbackType.selectionClick"]);
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
      expect(haptics, ["HapticFeedbackType.selectionClick", "HapticFeedbackType.selectionClick"]);
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
      expect(input.controller!.text, "before Kappa Party after");
      expect(tester.widget<TextField>(find.byType(TextField)).decoration!.hintText, "@viewer");
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
      final parentPosition = tester.getTopLeft(find.byKey(const ValueKey("thread-parent-reply")));
      final stackedPosition = tester.getTopLeft(find.byKey(const ValueKey("thread-stacked")));
      final siblingPosition = tester.getTopLeft(find.byKey(const ValueKey("thread-sibling")));
      expect(stackedPosition.dx, greaterThan(parentPosition.dx));
      expect(stackedPosition.dy, greaterThan(parentPosition.dy));
      expect(siblingPosition.dy, greaterThan(stackedPosition.dy));
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
      expect(
        tester.getTopLeft(find.byKey(const ValueKey("thread-deepest"))).dx,
        greaterThan(stackedPosition.dx),
      );
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

  testWidgets("thread bodies omit the parent mention and share feed colors and emote offsets", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    const root = TwitchChatMessage(
      id: "root",
      login: "parent",
      displayName: "Parent",
      text: "Question",
      color: "#123456",
    );
    const reply = TwitchChatMessage(
      id: "reply",
      login: "viewer",
      displayName: "Viewer",
      text: "@parent Kappa @Server @MiXeD",
      color: "#FF1493",
      emotes: [TwitchChatEmote(id: "25", start: 8, end: 13)],
      parentMessageId: "root",
      parentLogin: "parent",
      parentText: "@Viewer @Server",
      threadRootId: "root",
    );
    client.thread.addAll([
      root,
      const TwitchChatMessage(
        id: "server",
        login: "server",
        displayName: "Server",
        text: "Another reply",
        color: "#AB1234",
        parentMessageId: "root",
        threadRootId: "root",
      ),
    ]);
    controller.items.add(reply);
    controller.history.add(reply);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, brightness: Brightness.light));
    await tester.pumpAndSettle();
    final feed = find.byKey(const ValueKey("reply"));
    final preview = find.byKey(const ValueKey("reply-context-reply"));
    expect(
      _span(tester, preview, "@Viewer").style!.color,
      _span(tester, feed, "Viewer: ").style!.color,
    );
    final fallback = _span(tester, feed, "@MiXeD").style!.color;
    expect(_log(feed, "@parent"), findsNothing);
    await tester.tap(find.byKey(const ValueKey("reply-context-reply")));
    await tester.pumpAndSettle();
    final threadReply = find.byKey(const ValueKey("thread-reply"));
    expect(_log(threadReply, "@parent"), findsNothing);
    expect(_span(tester, threadReply, "@Server").style!.color, const Color(0xFFAB1234));
    expect(_span(tester, feed, "@Server").style!.color, const Color(0xFFAB1234));
    expect(_span(tester, preview, "@Server").style!.color, const Color(0xFFAB1234));
    expect(_span(tester, threadReply, "@MiXeD").style!.color, fallback);
    final emote = tester.widget<Image>(
      find.descendant(
        of: threadReply,
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && widget.semanticLabel == "Kappa",
        ),
      ),
    );
    expect(
      (emote.image as NetworkImage).url,
      "https://static-cdn.jtvnw.net/emoticons/v2/25/default/light/2.0",
    );
    await tester.longPress(threadReply);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reply to message"));
    await tester.pumpAndSettle();
    expect(
      _span(tester, find.byKey(const ValueKey("chat_composer_reply_preview")), "@Server")
          .style!
          .color,
      const Color(0xFFAB1234),
    );
    await tester.enterText(find.byType(TextField), "Answer");
    await tester.pump();
    await tester.tap(find.byTooltip("Send message"));
    await tester.pumpAndSettle();
    expect(controller.sent.single.replyTo!.text, "@parent Kappa @Server @MiXeD");
    expect(tester.takeException(), isNull);
  });

  testWidgets("reply context and composer render inline emotes and retain thread taps", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _Assets(client);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    const parent = TwitchChatMessage(
      id: "parent",
      login: "parent",
      displayName: "Parent",
      text: "Kappa Party",
      emotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
    );
    const reply = TwitchChatMessage(
      id: "reply-emotes",
      login: "viewer",
      displayName: "Viewer",
      text: "@parent Kappa Party",
      emotes: [TwitchChatEmote(id: "25", start: 8, end: 13)],
      parentMessageId: "parent",
      parentLogin: "parent",
      parentDisplayName: "Parent",
      parentText: "Kappa Party",
      parentEmotes: [TwitchChatEmote(id: "25", start: 0, end: 5)],
    );
    controller.items.add(reply);
    client.thread.addAll([parent, reply]);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets, settingsStore: settings));
    await tester.pumpAndSettle();
    final context = find.byKey(const ValueKey("reply-context-reply-emotes"));
    final contextImages = find.descendant(of: context, matching: find.byType(Image));
    expect(contextImages, findsNWidgets(2));
    expect(tester.widgetList<Image>(contextImages).map((image) => image.semanticLabel), [
      "Kappa",
      "Party",
    ]);
    final tap = await tester.startGesture(tester.getCenter(contextImages.first));
    await tester.pump(const Duration(milliseconds: 80));
    await tap.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("chat_reply_thread")), findsOneWidget);
    expect(find.text("Copy image URL"), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("thread-parent")),
        matching: find.byType(Image),
      ),
      findsNWidgets(2),
    );
    await tester.longPress(find.byKey(const ValueKey("thread-reply-emotes")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reply to message"));
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey("chat_composer_reply_preview"));
    expect(find.descendant(of: preview, matching: find.byType(Image)), findsNWidgets(2));
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(twitchEmotes: false, sevenTvEmotes: false),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: preview, matching: find.byType(Image)), findsNothing);
    expect(
      find.text("Replying to Viewer: @parent Kappa Party", findRichText: true),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey("chat_message_input")), "Answer");
    await tester.pump();
    await tester.tap(find.byTooltip("Send message"));
    await tester.pumpAndSettle();
    expect(controller.sent.single.replyTo!.text, reply.text);
    expect(tester.takeException(), isNull);
  });

  testWidgets("reply display removes only the matching leading parent mention", (tester) async {
    final controller = _Controller(_Client());
    const cases = [
      ("@PaReNt hello @parent", "hello @parent"),
      ("hello @parent", "hello @parent"),
      ("@other hello", "@other hello"),
      ("@parentish hello", "@parentish hello"),
      ("@parent, hello", "@parent, hello"),
    ];
    for (var index = 0; index < cases.length; index++) {
      controller.items.add(
        TwitchChatMessage(
          id: "$index",
          login: "viewer",
          displayName: "Viewer",
          text: cases[index].$1,
          parentMessageId: "parent",
          parentLogin: "parent",
        ),
      );
    }
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    for (var index = 0; index < cases.length; index++) {
      final row = find.byKey(ValueKey("$index"));
      final text = tester.widget<RichText>(_log(row, "Viewer: ")).text.toPlainText();
      expect(text, "Viewer: ${cases[index].$2}");
      expect(controller.items[index].text, cases[index].$1);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("7TV painted names preserve plain punctuation, profile taps, and hold actions", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _PaintAssets(client);
    const message = TwitchChatMessage(
      id: "painted",
      login: "viewer",
      userId: "1234",
      displayName: "Viewer",
      color: "#00FF00",
      text: "@Hivise hi hivise body",
    );
    controller.items.add(message);
    controller.history.addAll([
      message,
      const TwitchChatMessage(
        id: "known-paint",
        login: "hivise",
        userId: "567",
        displayName: "Hivise",
        text: "Hello",
        color: "#00FF00",
      ),
    ]);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    const frame = ValueKey("paint-frame");
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: _panel(controller, assets: assets),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey("painted"));
    expect(
      tester
          .widgetList<ChatUsername>(find.descendant(of: row, matching: find.byType(ChatUsername)))
          .map((name) => name.name),
      ["Viewer", "@Hivise", "hivise"],
    );
    expect(_span(tester, row, ": ").style!.color, const Color(0xFF00FF00));
    expect(_span(tester, row, "hi").style, isNull);
    final painted = await _pixelAt(
      tester,
      frame,
      tester.getCenter(_paintName(row, "Viewer")) + const Offset(1, 0),
    );
    expect(painted.r, greaterThan(0.9));
    expect(painted.g, lessThan(0.1));
    expect(painted.b, greaterThan(0.9));
    final colon = await _pixelAt(tester, frame, _textPoint(tester, row, ":") + const Offset(1, 0));
    expect(colon.g, greaterThan(0.9));
    expect(colon.r, lessThan(0.1));
    for (final entry in {
      "Viewer": (userId: "1234", login: "viewer"),
      "@Hivise": (userId: "567", login: "hivise"),
      "hivise": (userId: "567", login: "hivise"),
    }.entries) {
      final tap = await tester.startGesture(tester.getCenter(_paintName(row, entry.key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      controller.items.add(_message("arrival-${entry.key}", "Incoming message", minute: 3));
      controller.update();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_highlight(tester, "painted").color?.a ?? 0, 0);
      await tap.up();
      await tester.pumpAndSettle();
      expect(client.lookups.last, entry.value);
      expect(find.byKey(const ValueKey("chat_message_preview")), findsNothing);
      if (entry.key == "Viewer") {
        expect(_paintName(find.byKey(const ValueKey("log-painted")), "Viewer"), findsOneWidget);
      }
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
    final hold = await tester.startGesture(tester.getCenter(_paintName(row, "Viewer")));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_highlight(tester, "painted").color?.a ?? 0, 0);
    await tester.pump(kLongPressTimeout - const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_highlight(tester, "painted").color?.a ?? 0, inExclusiveRange(0, 0.18));
    await tester.pump(const Duration(milliseconds: 150));
    final preview = find.byKey(const ValueKey("chat_message_preview"));
    expect(preview, findsOneWidget);
    expect(_paintName(preview, "Viewer"), findsOneWidget);
    expect(find.text("Copy message"), findsOneWidget);
    await hold.up();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(_highlight(tester, "painted").color?.a ?? 0, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("7TV paint settings and moderation restore ordinary name spans", (tester) async {
    final client = _Client();
    final controller = _Controller(client);
    final assets = _PaintAssets(client);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(
        sevenTvBadges: false,
        sevenTvEmotes: false,
        showDeletedMessages: true,
      ),
    );
    const message = TwitchChatMessage(
      id: "paint-settings",
      login: "viewer",
      displayName: "Viewer",
      color: "#00FF00",
      text: "@Hivise hivise",
    );
    controller.items.add(message);
    controller.history.addAll([
      message,
      const TwitchChatMessage(
        id: "known",
        login: "hivise",
        displayName: "Hivise",
        text: "Hi",
        color: "#00FF00",
      ),
    ]);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets, settingsStore: settings));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey("paint-settings"));
    final names = find.descendant(of: row, matching: find.byType(ChatUsername));
    expect(names, findsNWidgets(3));
    expect(tester.widgetList<ChatUsername>(names).every((name) => name.animated), isTrue);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(animatedPaints: false));
    await tester.pumpAndSettle();
    expect(names, findsNWidgets(3));
    expect(tester.widgetList<ChatUsername>(names).every((name) => !name.animated), isTrue);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(sevenTvPaints: false));
    await tester.pumpAndSettle();
    expect(names, findsNothing);
    for (final label in ["Viewer: ", "@Hivise", "hivise"]) {
      final span = _span(tester, row, label);
      expect(span.style!.color, const Color(0xFF00FF00));
      expect(span.recognizer, isA<TapGestureRecognizer>());
    }
    await settings.setChatPreferences(settings.chatPreferences.copyWith(sevenTvPaints: true));
    await tester.pumpAndSettle();
    expect(names, findsNWidgets(3));
    controller.items[0] = message.copyWith(isDeleted: true);
    controller.history[0] = controller.items[0];
    controller.update();
    await tester.pumpAndSettle();
    expect(names, findsNothing);
    final moderatedColor = buildFlowTheme(Brightness.dark).colorScheme.onSurfaceVariant;
    for (final label in ["Viewer: ", "@Hivise", "hivise"]) {
      expect(_span(tester, row, label).style!.color, moderatedColor);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("pinned sender and pinner paints keep their own profile targets", (tester) async {
    await _cacheImages(tester);
    final client = _Client();
    final controller = _Controller(client);
    final assets = _PaintAssets(client);
    controller.pin = TwitchPinnedChat(
      id: "painted-pin",
      pinnedBy: (id: "99", login: "pinner", displayName: "Pinner"),
      message: TwitchChatMessage(
        id: "pin-name",
        userId: "1234",
        login: "viewer",
        displayName: "Viewer",
        text: "Pinned body",
        timestamp: DateTime(2026, 5, 12, 10, 1),
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final pin = find.byKey(const ValueKey("chat_pinned_message"));
    expect(_paintName(pin, "Pinner"), findsOneWidget);
    expect(_paintName(pin, "Viewer"), findsOneWidget);
    expect(_span(tester, pin, "Pinned by ").style, isNull);
    for (final entry in {
      "Pinner": (userId: "99", login: "pinner"),
      "Viewer": (userId: "1234", login: "viewer"),
    }.entries) {
      final tap = await tester.startGesture(tester.getCenter(_paintName(pin, entry.key)));
      await tester.pump(const Duration(milliseconds: 40));
      controller.update();
      await tester.pump(const Duration(milliseconds: 40));
      await tap.up();
      await tester.pumpAndSettle();
      expect(client.lookups.last, entry.value);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "exact known bare names use profile colors across chat views without stealing emotes or links",
    (tester) async {
      await _cacheImages(tester);
      final client = _Client();
      final controller = _Controller(client);
      final assets = _Assets(client);
      const message = TwitchChatMessage(
        id: "bare-name",
        login: "viewer",
        displayName: "Viewer",
        text: "HiViSe, I love you! hivse Party https://example.com/hivise hivise@example.com",
        parentMessageId: "root",
        parentLogin: "parent",
        parentText: "Original question",
      );
      controller.items.addAll([
        message,
        const TwitchChatMessage(
          id: "standalone",
          login: "viewer",
          displayName: "Viewer",
          text: "hivise",
        ),
      ]);
      controller.history.addAll([
        ...controller.items,
        const TwitchChatMessage(
          id: "known",
          login: "hivise",
          userId: "567",
          displayName: "Hivise",
          text: "Hello",
          color: "#00FF00",
        ),
        const TwitchChatMessage(
          id: "emote-name",
          login: "party",
          displayName: "Party",
          text: "Hello",
          color: "#FF0000",
        ),
      ]);
      addTearDown(controller.dispose);
      addTearDown(assets.dispose);
      await tester.pumpWidget(_panel(controller, assets: assets));
      await tester.pumpAndSettle();
      void checkName(Finder row, String name) {
        final span = _span(tester, row, name);
        expect(span.style!.color, const Color(0xFF00FF00));
        expect(span.recognizer, isA<TapGestureRecognizer>());
      }

      final feed = find.byKey(const ValueKey("bare-name"));
      checkName(feed, "HiViSe");
      checkName(find.byKey(const ValueKey("standalone")), "hivise");
      expect(_span(tester, feed, "hivse").recognizer, isNull);
      expect(_span(tester, feed, "hivise@example.com").recognizer, isNull);
      final link = _span(tester, feed, "https://example.com/hivise");
      expect(link.style!.decoration, TextDecoration.underline);
      expect(link.recognizer, isA<TapGestureRecognizer>());
      expect(
        find.descendant(
          of: feed,
          matching: find.byWidgetPredicate(
            (widget) => widget is Image && widget.semanticLabel == "Party",
          ),
        ),
        findsOneWidget,
      );
      final tap = await tester.startGesture(
        _textPoint(tester, feed, "HiViSe") + const Offset(1, 0),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(_highlight(tester, "bare-name").color?.a ?? 0, 0);
      await tap.up();
      await tester.pumpAndSettle();
      expect(client.lookups.last, (userId: "567", login: "hivise"));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tapAt(_textPoint(tester, feed, "Viewer: ") + const Offset(1, 0));
      await tester.pumpAndSettle();
      checkName(find.byKey(const ValueKey("log-bare-name")), "HiViSe");
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("reply-context-bare-name")));
      await tester.pumpAndSettle();
      checkName(find.byKey(const ValueKey("thread-bare-name")), "HiViSe");
      await tester.tap(find.byTooltip("Close thread"));
      await tester.pumpAndSettle();
      await tester.longPressAt(_textPoint(tester, feed, "love"));
      await tester.pumpAndSettle();
      checkName(find.byKey(const ValueKey("chat_message_preview")), "HiViSe");
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("thread moderation survives a stale response, eviction, and repeated message holds", (
    tester,
  ) async {
    final client = _Client();
    final pending = Completer<List<TwitchChatMessage>>();
    client.pendingThread = pending.future;
    final controller = _Controller(client);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    await settings.setChatPreferences(settings.chatPreferences.copyWith(showDeletedMessages: true));
    const original = TwitchChatMessage(
      id: "reply",
      login: "viewer",
      displayName: "Viewer",
      text: "Retained text",
      color: "#123456",
      parentMessageId: "root",
      parentLogin: "parent",
      threadRootId: "root",
    );
    final moderated = original.copyWith(
      isDeleted: true,
      moderation: TwitchChatModeration.timeout,
      timeoutSeconds: 60,
      moderatedAt: DateTime(2026, 5, 12),
    );
    controller.items.add(moderated);
    controller.history.add(moderated);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, settingsStore: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("reply-context-reply")));
    await tester.pump(const Duration(milliseconds: 350));
    final thread = find.byKey(const ValueKey("chat_reply_thread"));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_log(thread, "was timed out for 60s"), findsOneWidget);
    controller.history.clear();
    controller.update();
    pending.complete([
      const TwitchChatMessage(id: "root", login: "parent", displayName: "Parent", text: "Question"),
      original,
    ]);
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      await tester.longPress(find.byKey(const ValueKey("thread-reply")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Copy message"));
      await tester.pumpAndSettle();
      expect(_log(thread, "was timed out for 60s"), findsOneWidget);
      expect(_log(thread, "(deleted)"), findsNothing);
    }
    final row = find.byKey(const ValueKey("thread-reply"));
    final rich = tester.widget<RichText>(_log(row, "Retained text"));
    rich.text.visitChildren((span) {
      if (span is TextSpan) {
        expect(span.style?.decoration, isNot(TextDecoration.lineThrough));
      }
      return true;
    });
    expect(
      _span(tester, row, "Viewer: ").style!.color,
      buildFlowTheme(Brightness.dark).colorScheme.onSurfaceVariant,
    );
    await tester.tap(find.byTooltip("Close thread"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("reply-context-reply")));
    await tester.pumpAndSettle();
    expect(_log(thread, "was timed out for 60s"), findsOneWidget);
    await tester.tap(find.byTooltip("Close thread"));
    await tester.pumpAndSettle();
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(showModerationNotices: false),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("was timed out"), findsNothing);
    expect(find.textContaining("Retained text", findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("gift icons distinguish anonymous gifts and system notices stay quiet", (
    tester,
  ) async {
    final controller = _Controller(_Client());
    controller.items.addAll([
      const TwitchChatMessage(
        id: "gift",
        login: "viewer",
        displayName: "Viewer",
        text: "",
        noticeType: "subgift",
        noticeText: "Viewer gifted a subscription",
      ),
      const TwitchChatMessage(
        id: "anon",
        login: "",
        displayName: "Anonymous",
        text: "",
        noticeType: "anonsubgift",
        noticeText: "An anonymous user gifted a subscription",
      ),
      const TwitchChatMessage(
        id: "system",
        login: "",
        displayName: "",
        text: "",
        noticeType: "system",
        noticeText: "Welcome to channel Chat!",
      ),
    ]);
    controller.history.addAll(controller.items);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.redeem), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SvgPicture && widget.semanticsLabel == "Anonymous gift",
      ),
      findsOneWidget,
    );
    final system = _highlight(tester, "system");
    expect(system.color, isNull);
    expect(system.border, isNull);
    expect(find.text("Welcome to channel Chat!"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("special message icons stay beside the first line of wrapped notices", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(220, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _Controller(_Client());
    final icons = {
      "announcement": find.byIcon(Icons.campaign),
      "sub": find.byIcon(Icons.star_rounded),
      "subgift": find.byIcon(Icons.redeem),
      "anonsubgift": find.byWidgetPredicate(
        (widget) => widget is SvgPicture && widget.semanticsLabel == "Anonymous gift",
      ),
      "watch-streak": find.byWidgetPredicate(
        (widget) => widget is SvgPicture && widget.semanticsLabel == "Watch streak",
      ),
      "prime": find.byWidgetPredicate(
        (widget) => widget is SvgPicture && widget.semanticsLabel == "Prime subscription",
      ),
      "first": find.byIcon(Icons.auto_awesome),
    };
    for (final type in icons.keys) {
      controller.items.add(
        TwitchChatMessage(
          id: type,
          login: "viewer",
          displayName: "Viewer",
          text: type == "first" ? "Hello" : "",
          isFirstMessage: type == "first",
          isPrimeSubscription: type == "prime",
          noticeType: type == "first"
              ? null
              : type == "prime"
              ? "resub"
              : type,
          noticeText: type == "first" ? null : "$type has a special message on several lines",
        ),
      );
    }
    controller.history.addAll(controller.items);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    for (final entry in icons.entries) {
      final notice = find.text(
        entry.key == "first"
            ? "First-time chatter"
            : "${entry.key} has a special message on several lines",
      );
      expect(entry.value, findsOneWidget);
      expect(tester.getSize(notice).height, greaterThan(tester.getSize(entry.value).height));
      expect(tester.getTopLeft(entry.value).dy, closeTo(tester.getTopLeft(notice).dy, 0.1));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("private points and moderation notices show their text once with private headers", (
    tester,
  ) async {
    final controller = _Controller(_Client());
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    const notices = [
      ("points", "channel-points", "Claimed 50 channel points.", true),
      ("private-mod", "moderation", "Your message was blocked by the channel moderator.", true),
      ("public-streak", "watch-streak", "Viewer reached a seven-stream watch streak.", false),
      ("public-sub", "sub", "Viewer subscribed for three months.", false),
    ];
    for (final notice in notices) {
      controller.items.add(
        TwitchChatMessage(
          id: notice.$1,
          login: notice.$4 ? "" : "viewer",
          displayName: notice.$4 ? "" : "Viewer",
          text: "",
          noticeType: notice.$2,
          noticeText: notice.$3,
          isPrivate: notice.$4,
        ),
      );
    }
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, settingsStore: settings));
    await tester.pumpAndSettle();
    for (final notice in notices) {
      final row = find.byKey(ValueKey(notice.$1));
      expect(find.text(notice.$3), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text("Only visible to you")),
        notice.$4 ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.lock_rounded)),
        notice.$4 ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.star_rounded)),
        notice.$1 == "public-sub" ? findsOneWidget : findsNothing,
      );
    }
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SvgPicture && widget.semanticsLabel == "Channel points",
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SvgPicture && widget.semanticsLabel == "Watch streak",
      ),
      findsOneWidget,
    );
    await settings.setChatPreferences(
      settings.chatPreferences.copyWith(
        showSubscriptionNotices: false,
        showModerationNotices: false,
      ),
    );
    await tester.pumpAndSettle();
    for (final notice in notices) {
      expect(find.text(notice.$3), notice.$4 ? findsOneWidget : findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

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
    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.hintText, "@viewer");
    await tester.enterText(find.byType(TextField), "My answer");
    await tester.pump();
    await tester.tap(find.byTooltip("Send message"));
    await tester.pumpAndSettle();
    expect(controller.sent, [(text: "My answer", replyTo: reply)]);
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
      expect(input.controller!.text, "");
      expect(input.decoration!.hintText, "@parent");
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(controller.sent, isEmpty);
      expect(controller.listening, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("opening an unseen user's profile retains their actual mention color", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client()
      ..profile = const TwitchUser(
        id: "1234",
        login: "viewer",
        displayName: "Viewer",
        chatColor: "#000000",
      );
    final controller = _Controller(client)
      ..items.add(
        const TwitchChatMessage(
          id: "unseen-mention",
          login: "other",
          displayName: "Other",
          text: "Hello @viewer",
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, brightness: Brightness.light));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey("unseen-mention"));
    await tester.tapAt(_textPoint(tester, row, "@viewer"));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const ValueKey("chat_user_history")))).pop();
    await tester.pumpAndSettle();
    expect(_span(tester, row, "@viewer").style!.color, Colors.black);
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(_span(tester, row, "@viewer").style!.color, Colors.black);
  });

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

  testWidgets("pin countdown reaches zero without dismissing Twitch's pin", (tester) async {
    final client = _Client();
    final controller = _Controller(client);
    addTearDown(controller.dispose);
    final now = DateTime.now();
    final message = _message("timed-pin", "Timed pinned message", minute: 0);
    controller.pin = TwitchPinnedChat(
      id: "timed",
      message: message,
      startsAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.add(const Duration(minutes: 5)),
    );
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    final timer = find.byKey(const ValueKey("chat_pin_timer"));
    expect(tester.widget<LinearProgressIndicator>(timer).value, closeTo(0.5, 0.02));
    controller.pin = TwitchPinnedChat(
      id: "timed",
      message: message,
      startsAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.subtract(const Duration(seconds: 1)),
    );
    controller.update();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<LinearProgressIndicator>(timer).value, 0);
    expect(find.byKey(const ValueKey("chat_pinned_message")), findsOneWidget);
    controller.pin = TwitchPinnedChat(id: "timed", message: message);
    controller.update();
    await tester.pumpAndSettle();
    expect(timer, findsNothing);
    expect(find.byKey(const ValueKey("chat_pinned_message")), findsOneWidget);
    controller.pin = null;
    controller.update();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("chat_pinned_message")), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "pin uses separate pinner metadata, rich sender details, and local collapse and close",
    (tester) async {
      await _cacheImages(tester);
      final client = _Client();
      final controller = _Controller(client);
      final assets = _PinnedAssets(client);
      final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
      await settings.load();
      await settings.setChatPreferences(settings.chatPreferences.copyWith(messageSpacing: 20));
      controller.items.add(_message("spacing-feed", "An ordinary feed row", minute: 0));
      controller.history.addAll(controller.items);
      addTearDown(assets.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_panel(controller, assets: assets, settingsStore: settings));
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
      final header = find.textContaining("Pinned by", findRichText: true);
      final body = find.textContaining("A pinned message", findRichText: true);
      final sender = find.textContaining("Viewer sent at", findRichText: true);
      final bodyGap = tester.getTopLeft(sender).dy - tester.getBottomLeft(body).dy;
      expect(bodyGap, closeTo(4, 0.1));
      expect(tester.getTopLeft(body).dy - tester.getBottomLeft(header).dy, closeTo(1, 0.1));
      final feed = find.byKey(const ValueKey("spacing-feed"));
      final feedText = find.textContaining("An ordinary feed row", findRichText: true);
      expect(tester.getSize(feed).height - tester.getSize(feedText).height, closeTo(20, 0.1));
      final tap = await tester.startGesture(_textPoint(tester, box, "Pinner"));
      await tester.pump(const Duration(milliseconds: 40));
      controller.update();
      await tester.pump(const Duration(milliseconds: 40));
      await tap.up();
      await tester.pumpAndSettle();
      expect(client.lookups.single, (userId: "99", login: "pinner"));
      expect(find.text("@pinner"), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Minimize pinned message"));
      await tester.pumpAndSettle();
      expect(find.textContaining("sent at", findRichText: true), findsNothing);
      expect(find.byTooltip("Expand pinned message"), findsOneWidget);
      await tester.tap(find.byTooltip("Expand pinned message"));
      await tester.pumpAndSettle();
      final bodyTap = await tester.startGesture(_textPoint(tester, box, "A pinned message"));
      await tester.pump();
      expect(_highlight(tester, "pin").color?.a ?? 0, 0);
      await tester.pump(const Duration(milliseconds: 80));
      expect(_highlight(tester, "pin").color?.a ?? 0, 0);
      await bodyTap.up();
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

  testWidgets("a pinned reply shows its parent context and opens the thread", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _Client();
    final controller = _Controller(client);
    const parent = TwitchChatMessage(
      id: "pin-parent",
      login: "chilligolf",
      displayName: "Chilligolf",
      text:
          "so 26mil is the starting point chat, what will the total be when this is all finished?",
    );
    const reply = TwitchChatMessage(
      id: "pin-reply",
      login: "jay_xxi",
      displayName: "Jay_XXI",
      text: r"@Chilligolf $26,235,610 pin it up",
      parentMessageId: "pin-parent",
      parentLogin: "chilligolf",
      parentDisplayName: "Chilligolf",
      parentText:
          "so 26mil is the starting point chat, what will the total be when this is all finished?",
      threadRootId: "pin-parent",
    );
    controller.pin = const TwitchPinnedChat(id: "reply-pin", message: reply);
    client.thread.addAll([parent, reply]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    final pin = find.byKey(const ValueKey("chat_pinned_message"));
    final context = find.descendant(
      of: pin,
      matching: find.byKey(const ValueKey("reply-context-pin-reply")),
    );
    final replyText = find.text("Chilligolf: ${parent.text}");
    expect(replyText, findsOneWidget);
    expect(tester.widget<Text>(replyText).maxLines, 2);
    final quote = find.descendant(of: context, matching: find.byIcon(Icons.format_quote_rounded));
    expect(quote, findsOneWidget);
    final transform = tester
        .widget<Transform>(find.ancestor(of: quote, matching: find.byType(Transform)).first)
        .transform;
    expect(transform.entry(0, 0), -1);
    expect(transform.entry(1, 1), -1);
    expect(_log(pin, r"$26,235,610 pin it up"), findsOneWidget);
    expect(_log(pin, r"@Chilligolf $26"), findsNothing);
    await tester.tap(context);
    await tester.pumpAndSettle();
    expect(_log(find.byKey(const ValueKey("chat_reply_thread")), parent.text), findsOneWidget);
    await tester.tap(find.byTooltip("Close thread"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(context, findsNothing);
    expect(find.text(r"$26,235,610 pin it up"), findsOneWidget);
    await tester.tap(find.byTooltip("Expand pinned message"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(context, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "user drawer shows profile color, paint, every badge, account date and subscription",
    (tester) async {
      await _cacheImages(tester);
      tester.view.physicalSize = const Size(392, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _Client()
        ..profile = TwitchUser(
          id: "1234",
          login: "viewer",
          displayName: "Viewer Profile",
          profileImageUrl: _avatar,
          createdAt: DateTime.utc(2018, 10, 12, 18),
          chatColor: "#00FF7F",
          badges: [
            const TwitchUserBadge(id: "moderator/1", title: "Moderator", imageUrl: _badgeUrl),
            for (var index = 0; index < 16; index++)
              TwitchUserBadge(
                id: "earned$index/1",
                title: "Earned badge $index",
                imageUrl: _badgeUrl,
              ),
          ],
          isSubscribed: true,
          subscriptionTier: "2000",
          subscriptionMonths: 14,
          subscriptionIsPrime: false,
        );
      final controller = _Controller(client)
        ..items.add(
          const TwitchChatMessage(
            id: "profile-metadata",
            login: "ViEwEr",
            displayName: "Viewer",
            text: "Hello",
            color: "#0000FF",
            badges: ["moderator/1"],
          ),
        );
      final assets = _ProfileAssets(client);
      final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
      await settings.load();
      addTearDown(controller.dispose);
      addTearDown(assets.dispose);
      await tester.pumpWidget(_panel(controller, assets: assets, settingsStore: settings));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey("chat_user_name"));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey("profile-metadata")),
          matching: find.byType(Image),
        ),
        findsNWidgets(3),
      );
      await tester.tapAt(
        _textPoint(tester, find.byKey(const ValueKey("profile-metadata")), "Viewer"),
      );
      await tester.pumpAndSettle();
      expect(client.profileChannels.single, (id: "1", login: "channel"));
      expect(tester.widget<ChatUsername>(name).name, "Viewer Profile");
      expect(tester.widget<ChatUsername>(name).style.color, const Color(0xFF00FF7F));
      expect(find.text("Account created · Oct 12, 2018"), findsOneWidget);
      expect(find.text("Subscriber · Tier 2 · 14 months total"), findsOneWidget);
      final badges = find.byKey(const ValueKey("chat_user_badges"));
      expect(tester.widget<Wrap>(badges).children, hasLength(19));
      expect(find.descendant(of: badges, matching: find.byType(Image)), findsNWidgets(19));
      for (final width in [392.0, 240.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        expect(tester.widget<Wrap>(badges).children, hasLength(19));
        expect(tester.getSize(badges).width, lessThanOrEqualTo(width - 32));
        expect(tester.takeException(), isNull);
      }
      await settings.setChatPreferences(
        settings.chatPreferences.copyWith(
          sevenTvPaints: false,
          twitchBadges: false,
          sevenTvBadges: false,
        ),
      );
      controller.update();
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(name).style!.color, const Color(0xFF00FF7F));
      expect(tester.widget<Wrap>(badges).children, hasLength(19));
      final finalBadge = find.descendant(of: badges, matching: find.byTooltip("FFZ supporter"));
      await tester.ensureVisible(finalBadge);
      await tester.tap(finalBadge);
      await tester.pumpAndSettle();
      expect(find.text("FFZ supporter"), findsOneWidget);
      expect(find.text("Copy image URL"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("user drawer does not infer subscription tier or tenure from an earned badge", (
    tester,
  ) async {
    await _cacheImages(tester);
    final client = _Client()
      ..profile = const TwitchUser(
        id: "1234",
        login: "viewer",
        displayName: "Viewer Profile",
        badges: [
          TwitchUserBadge(id: "subscriber/12", title: "12-month subscriber", imageUrl: _badgeUrl),
        ],
      );
    final controller = _Controller(client)
      ..items.add(_message("unknown-profile", "Hello", minute: 1));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    await _tapName(tester, "unknown-profile");
    expect(find.text("Subscription details unavailable"), findsOneWidget);
    expect(find.text("Account creation date unavailable"), findsOneWidget);
    expect(find.textContaining("months total"), findsNothing);
    expect(find.textContaining("Tier 1"), findsNothing);
    expect(find.byTooltip("12-month subscriber"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    final draft = tester.widget<TextField>(find.byType(TextField)).controller!;
    draft.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
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
      "existing draft",
    );
    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.hintText, "@viewer");
    expect(draft.selection, const TextSelection(baseOffset: 1, extentOffset: 4));
    await tester.tap(find.byTooltip("Cancel reply"));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.hintText, "Send a message");
    expect(draft.text, "existing draft");
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

  for (final changeCredentials in [false, true]) {
    testWidgets("block confirmation aborts a changed session (credentials: $changeCredentials)", (
      tester,
    ) async {
      await _cacheImages(tester);
      final original = _Client();
      final replacement = _Client(token: "another-account");
      var client = original;
      final controller = _Controller(original, clientLoader: () async => client);
      final message = _message("visible", "latest message", minute: 32);
      controller.items.add(message);
      controller.history.add(message);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      await _tapName(tester, "visible");
      await _openBlockConfirmation(tester);
      if (changeCredentials) {
        client = replacement;
      } else {
        controller.viewerId = "another-account";
        controller.update();
      }
      await tester.tap(find.widgetWithText(FilledButton, "Block"));
      await tester.pumpAndSettle();
      expect(original.blocked, isEmpty);
      expect(replacement.blocked, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

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
  AppSettingsStore? settingsStore,
  Brightness brightness = Brightness.dark,
  bool chatOnly = true,
}) => MaterialApp(
  theme: buildFlowTheme(brightness),
  home: Scaffold(
    body: TwitchChatPanel(
      controller: controller,
      assets: assets,
      onReportUser: onReportUser,
      preferences: MemoryFlowPreferences(),
      settingsStore: settingsStore,
      chatOnly: chatOnly,
      isLive: true,
      onToggleChatOnly: () {},
    ),
  ),
);

Rect _paintedBounds(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

Finder _paintName(Finder row, String name) => find.descendant(
  of: row,
  matching: find.byWidgetPredicate((widget) => widget is ChatUsername && widget.name == name),
);

Finder _log(Finder history, String text) => find.descendant(
  of: history,
  matching: find.textContaining(text, findRichText: true),
);

TextSpan _span(WidgetTester tester, Finder row, String text) {
  TextSpan? result;
  for (final rich in tester.widgetList<RichText>(
    find.descendant(of: row, matching: find.byType(RichText)),
  )) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        result = span;
      }
      return true;
    });
  }
  return result!;
}

Future<void> _tapName(WidgetTester tester, String id) async {
  final text = find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(RichText)).first;
  await tester.tapAt(tester.getTopLeft(text) + const Offset(12, 10));
  await tester.pumpAndSettle();
}

BoxDecoration _highlight(WidgetTester tester, String id) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byKey(ValueKey("chat_message_highlight-$id")),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

Offset _textPoint(WidgetTester tester, Finder row, String label) {
  final rich = find
      .descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText().contains(label),
        ),
      )
      .first;
  final paragraph = tester.renderObject<RenderParagraph>(rich);
  final start = paragraph.text.toPlainText().indexOf(label);
  final box = paragraph
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + label.length))
      .first;
  return paragraph.localToGlobal(box.toRect().center);
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

Future<void> _cacheImages(WidgetTester tester, {Color color = Colors.white}) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(color, ui.BlendMode.src);
    final picture = recorder.endRecording();
    final pixel = await picture.toImage(1, 1);
    picture.dispose();
    for (final url in [
      _avatar,
      _emoteUrl,
      _badgeUrl,
      _twitchEmoteUrl,
      _twitchEmoteUrl.replaceFirst("/dark/", "/light/"),
    ]) {
      PaintingBinding.instance.imageCache.putIfAbsent(
        NetworkImage(url),
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: pixel.clone()))),
      );
    }
    pixel.dispose();
  });
}

Future<Color> _pixelAt(WidgetTester tester, Key frame, Offset point) async =>
    (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(frame));
      final image = await boundary.toImage();
      final bytes = (await image.toByteData())!;
      final local = boundary.globalToLocal(point);
      final offset = (local.dy.floor() * image.width + local.dx.floor()) * 4;
      final color = Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
      image.dispose();
      return color;
    }))!;

class _Client extends TwitchApiClient {
  _Client({String token = "test"})
    : super(clientId: "test", accessToken: token, gqlAccessToken: token);

  final lookups = <({String? userId, String? login})>[];
  final profileChannels = <({String? id, String? login})>[];
  TwitchUser profile = const TwitchUser(
    id: "1234",
    login: "viewer",
    displayName: "Viewer Profile",
    profileImageUrl: _avatar,
  );
  final blocked = <String>[];
  final thread = <TwitchChatMessage>[];
  Future<List<TwitchChatMessage>>? pendingThread;

  @override
  Future<List<TwitchChatMessage>> fetchChatReplyThread(String messageId) async =>
      pendingThread ?? thread;

  @override
  Future<TwitchUser?> fetchChatUser({
    String? userId,
    String? login,
    String? channelId,
    String? channelLogin,
  }) async {
    lookups.add((userId: userId, login: login));
    profileChannels.add((id: channelId, login: channelLogin));
    return profile;
  }

  @override
  Future<void> blockUser(String userId) async => blocked.add(userId);
}

class _Controller extends TwitchChatController {
  _Controller(
    _Client client, {
    super.channel = "channel",
    Future<TwitchApiClient> Function()? clientLoader,
  }) : super(clientLoader: clientLoader ?? () async => client, autoConnect: false);

  final items = <TwitchChatMessage>[];
  final history = <TwitchChatMessage>[];
  final sent = <({String text, TwitchChatMessage? replyTo})>[];
  TwitchPinnedChat? pin;
  String? viewerId;
  String? viewerLogin;

  @override
  String? get currentUserId => viewerId;

  @override
  String? get currentUserLogin => viewerLogin;

  @override
  TwitchChatMessage? get pinnedMessage => pin?.message;

  @override
  TwitchPinnedChat? get pinnedChat => pin;

  bool get listening => hasListeners;

  @override
  List<TwitchChatMessage> get messages => items;

  @override
  List<TwitchChatMessage> get recentHistory {
    final retained = {for (final message in history) message.id: message};
    for (final message in items) {
      retained.putIfAbsent(message.id, () => message);
    }
    return retained.values.toList();
  }

  @override
  TwitchChatStatus get status => TwitchChatStatus.connected;

  @override
  bool get isSignedIn => true;

  @override
  bool get canSend => true;

  @override
  TwitchChatAccess get chatAccess => const TwitchChatAccess(
    channelId: "1",
    channelDisplayName: "channel",
    rules: [],
  );

  @override
  Future<bool> send(String text, {TwitchChatMessage? replyTo}) async {
    sent.add((text: text, replyTo: replyTo));
    return true;
  }

  void update() => notifyListeners();
}

class _FailingProfileClient extends _Client {
  @override
  Future<TwitchUser?> fetchChatUser({
    String? userId,
    String? login,
    String? channelId,
    String? channelLogin,
  }) async => throw TwitchApiException("Offline");
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

class _PaintAssets extends _Assets {
  _PaintAssets(super.client);

  static const _paint = ChatAssetPaint(
    id: "test-paint",
    name: "Magenta",
    layers: [
      ChatPaintLayer(id: "color", type: ChatPaintLayerType.color, color: Color(0xFFFF00FF)),
    ],
  );

  @override
  Map<String, ChatAssetPaint> get userPaintsByLogin => const {
    "viewer": _paint,
    "hivise": _paint,
    "pinner": _paint,
  };
}

class _ProfileAssets extends _PaintAssets {
  _ProfileAssets(super.client);

  @override
  Map<String, List<ChatAssetBadge>> get userBadgesByLogin => const {
    "viewer": [
      ChatAssetBadge(
        id: "supporter",
        title: "7TV supporter",
        url: _emoteUrl,
        provider: ChatEmoteProvider.sevenTv,
      ),
      ChatAssetBadge(
        id: "supporter",
        title: "FFZ supporter",
        url: _emoteUrl,
        provider: ChatEmoteProvider.ffz,
      ),
    ],
  };
}

class _ArtAssets extends _Assets {
  _ArtAssets(super.client);

  @override
  Map<String, ChatAssetEmote> get emotesByName => {
    ...super.emotesByName,
    "Kappa": const ChatAssetEmote(
      name: "Kappa",
      id: "25",
      url: _twitchEmoteUrl,
      provider: ChatEmoteProvider.twitch,
    ),
    for (final name in ["sadE", "dancer"])
      name: ChatAssetEmote(
        name: name,
        id: name,
        url: _emoteUrl,
        provider: ChatEmoteProvider.sevenTv,
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
