import "dart:async";
import "dart:ui" as ui;

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_vod_chat.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/chat_username.dart";
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

  testWidgets(
    "watch streak popup uses the app theme for a private event without a footer counter",
    (
      tester,
    ) async {
      final controller = _ChatController()
        ..items.add(
          const TwitchChatMessage(
            id: "public-streak",
            login: "viewer",
            displayName: "Viewer",
            text: "",
            noticeType: "watch-streak",
            noticeText: "Viewer reached a watch streak.",
          ),
        );
      addTearDown(controller.dispose);
      await tester.pumpWidget(panel(controller));
      await tester.pump();
      final footer = find.byKey(const ValueKey("chat_watch_streak"));
      final callout = find.byKey(const ValueKey("chat_watch_streak_callout"));
      final input = find.byKey(const ValueKey("chat_message_input"));
      expect(footer, findsNothing);
      expect(callout, findsNothing);
      controller.items.add(
        TwitchChatMessage(
          id: "watch-streak:milestone-7",
          login: "",
          displayName: "",
          text: "",
          noticeType: "watch-streak",
          noticeText: "You reached a 7-stream watch streak!",
          isPrivate: true,
          timestamp: DateTime.now(),
        ),
      );
      controller.update();
      await tester.pump();
      expect(callout, findsOneWidget);
      expect(find.text("You reached a 7-stream watch streak!"), findsOneWidget);
      expect(
        tester.widget<Material>(callout).color,
        Theme.of(tester.element(callout)).colorScheme.primaryContainer,
      );
      expect(tester.widget<Material>(callout).borderRadius, BorderRadius.circular(12));
      expect(tester.getBottomLeft(callout).dy, lessThan(tester.getTopLeft(input).dy));
      await tester.enterText(input, "keep this draft");
      await tester.tap(find.byTooltip("Dismiss watch streak"));
      await tester.pump();
      expect(callout, findsNothing);
      final notice = controller.items.last;
      controller.items.clear();
      controller.update();
      await tester.pump();
      controller.items.add(notice);
      controller.items.add(_message(1));
      controller.update();
      await tester.pump();
      expect(callout, findsNothing);
      expect(tester.widget<TextField>(input).controller!.text, "keep this draft");
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets("watch streak dismissal expires without restarting on chat updates", (tester) async {
    final controller = _ChatController()
      ..items.add(
        TwitchChatMessage(
          id: "watch-streak:milestone-7",
          login: "",
          displayName: "",
          text: "",
          noticeType: "watch-streak",
          noticeText: "You reached a 7-stream watch streak!",
          isPrivate: true,
          timestamp: DateTime.now(),
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pump();
    final callout = find.byKey(const ValueKey("chat_watch_streak_callout"));
    final timer = find.byKey(const ValueKey("chat_watch_streak_dismissal"));
    expect(callout, findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    expect(tester.widget<LinearProgressIndicator>(timer).value, closeTo(0.5, 0.01));
    controller.items.add(_message(1));
    controller.update();
    await tester.pump();
    expect(tester.widget<LinearProgressIndicator>(timer).value, closeTo(0.5, 0.01));
    await tester.pump(const Duration(seconds: 16));
    expect(callout, findsNothing);
    controller.update();
    await tester.pump();
    expect(callout, findsNothing);
    expect(find.text("7/7"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("watch streak popup hides expired events and is absent outside live signed-in chat", (
    tester,
  ) async {
    final controller = _ChatController()
      ..items.add(
        TwitchChatMessage(
          id: "watch-streak:milestone-7",
          login: "",
          displayName: "",
          text: "",
          noticeType: "watch-streak",
          noticeText: "You reached a 7-stream watch streak!",
          isPrivate: true,
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    expect(find.byKey(const ValueKey("chat_watch_streak")), findsNothing);
    expect(find.byKey(const ValueKey("chat_watch_streak_callout")), findsNothing);
    controller.items.add(
      TwitchChatMessage(
        id: "new-watch-event",
        login: "",
        displayName: "",
        text: "",
        noticeType: "watch-streak",
        noticeText: "A new watch streak was reached.",
        isPrivate: true,
        timestamp: DateTime.now(),
      ),
    );
    await tester.pumpWidget(panel(controller, isLive: false));
    expect(find.byKey(const ValueKey("chat_watch_streak")), findsNothing);
    expect(find.byKey(const ValueKey("chat_watch_streak_callout")), findsNothing);
    controller.signedIn = false;
    await tester.pumpWidget(panel(controller));
    expect(find.byKey(const ValueKey("chat_watch_streak")), findsNothing);
    expect(find.byKey(const ValueKey("chat_watch_streak_callout")), findsNothing);
    final replay = _ReplayController();
    addTearDown(replay.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchChatPanel(
            replayController: replay,
            chatOnly: false,
            isLive: false,
            preferences: MemoryFlowPreferences(),
            onToggleChatOnly: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey("chat_watch_streak")), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    expect(find.text("Chat disconnected"), findsOneWidget);
    expect(find.textContaining("message 1", findRichText: true), findsOneWidget);
    controller.connectionStatus = TwitchChatStatus.connected;
    controller.update();
    await tester.pump();
    expect(find.text("Reconnecting to chat…"), findsNothing);
    expect(find.text("Connected"), findsNothing);
  });

  testWidgets("followers-only chat explains its read-only composer and Follow unlocks it", (
    tester,
  ) async {
    final controller = _ChatController()
      ..room["followers-only"] = "0"
      ..followerEligible = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    expect(tester.widget<TextField>(input).readOnly, isTrue);
    expect(tester.widget<TextField>(input).decoration!.hintText, "Send a message");
    expect(controller.followCalls, 0);
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(find.text("You need to be a follower of Test Channel to chat."), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(controller.followCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, "Follow"));
    await tester.pumpAndSettle();
    expect(controller.followCalls, 1);
    expect(find.text("You need to be a follower of Test Channel to chat."), findsNothing);
    expect(tester.widget<TextField>(input).readOnly, isFalse);
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    await tester.enterText(input, "Now following");
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("chat_send")));
    await tester.pumpAndSettle();
    expect(controller.sent, ["Now following"]);
    expect(tester.takeException(), isNull);
  });

  testWidgets("followed chat gate counts down by the second and can unfollow", (tester) async {
    final controller = _ChatController()
      ..room["followers-only"] = "10"
      ..followerEligible = false
      ..waitRemaining = const Duration(seconds: 61)
      ..access = const TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Test Channel",
        rules: [],
        isFollowing: true,
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("chat_message_input")));
    await tester.pumpAndSettle();
    expect(
      find.text("You need to be a follower for 10m to chat, and you have 1m 01s left."),
      findsOneWidget,
    );
    expect(find.text("Check access"), findsNothing);
    expect(find.widgetWithText(FilledButton, "Unfollow"), findsOneWidget);
    controller.waitRemaining = const Duration(seconds: 60);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining("you have 1m left."), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, "Unfollow"));
    await tester.pumpAndSettle();
    expect(controller.unfollowCalls, 1);
    expect(controller.followCalls, 0);
    expect(find.widgetWithText(FilledButton, "Follow"), findsOneWidget);
    expect(find.textContaining("you have"), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, "Follow"));
    await tester.pumpAndSettle();
    expect(controller.followCalls, 1);
    expect(find.text("Followers-Only Chat"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("followers-only composer counts down without opening its drawer", (tester) async {
    final controller = _ChatController()
      ..room["followers-only"] = "10"
      ..followerEligible = false
      ..waitRemaining = const Duration(seconds: 61)
      ..access = const TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Test Channel",
        rules: [],
        isFollowing: true,
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    expect(tester.widget<TextField>(input).decoration!.hintText, "You can chat in 1m 01s");
    expect(tester.widget<TextField>(input).readOnly, isTrue);
    controller.waitRemaining = const Duration(seconds: 60);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<TextField>(input).decoration!.hintText, "You can chat in 1m");
    controller.waitRemaining = Duration.zero;
    controller.followerEligible = true;
    controller.update();
    await tester.pump();
    expect(tester.widget<TextField>(input).decoration!.hintText, "Send a message");
    expect(tester.widget<TextField>(input).readOnly, isFalse);
    expect(find.text("Followers-Only Chat"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("watch streak popup preference hides callouts without discarding notices", (
    tester,
  ) async {
    final store = AppSettingsStore(preferences: MemoryFlowPreferences());
    await store.load();
    final controller = _ChatController()
      ..items.add(
        TwitchChatMessage(
          id: "watch-streak:setting",
          login: "",
          displayName: "",
          text: "",
          noticeType: "watch-streak",
          noticeText: "You reached a 7-stream watch streak!",
          isPrivate: true,
          timestamp: DateTime.now(),
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, settingsStore: store));
    await tester.pump();
    final callout = find.byKey(const ValueKey("chat_watch_streak_callout"));
    expect(callout, findsOneWidget);
    await store.setChatPreferences(store.chatPreferences.copyWith(showWatchStreakPopups: false));
    await tester.pump();
    expect(callout, findsNothing);
    expect(controller.items.single.noticeType, "watch-streak");
    await store.setChatPreferences(store.chatPreferences.copyWith(showWatchStreakPopups: true));
    await tester.pump();
    expect(callout, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("slow-mode countdown blocks both send controls until Twitch allows chat", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    final send = find.byKey(const ValueKey("chat_send"));
    await tester.enterText(input, "first message");
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    controller.slowWaitRemaining = const Duration(seconds: 2);
    controller.update();
    await tester.pump();
    expect(tester.widget<TextField>(input).decoration!.hintText, "You can chat in 2s");
    tester.widget<TextField>(input).controller!.text = "next message";
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    tester.widget<TextField>(input).onSubmitted!("next message");
    await tester.pump();
    expect(controller.sent, ["first message"]);
    controller.slowWaitRemaining = const Duration(seconds: 1);
    controller.update();
    await tester.pump();
    expect(tester.widget<TextField>(input).decoration!.hintText, "You can chat in 1s");
    controller.slowWaitRemaining = Duration.zero;
    controller.update();
    await tester.pump();
    expect(tester.widget<TextField>(input).decoration!.hintText, "Send a message");
    await tester.tap(send);
    await tester.pump();
    expect(controller.sent, ["first message", "next message"]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("rules require acknowledgement once per channel and persist across reopening", (
    tester,
  ) async {
    final controller = _ChatController()
      ..access = const TwitchChatAccess(
        channelId: "1",
        channelDisplayName: "Test Channel",
        rules: ["Be kind", "No spoilers"],
      );
    final preferences = MemoryFlowPreferences();
    addTearDown(controller.dispose);
    final input = find.byKey(const ValueKey("chat_message_input"));
    await tester.pumpWidget(panel(controller, preferences: preferences));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).readOnly, isTrue);
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(find.text("Chat Rules"), findsOneWidget);
    expect(find.text("Test Channel"), findsNothing);
    expect(find.text("1. Be kind"), findsOneWidget);
    expect(find.text("2. No spoilers"), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byTooltip("Close rules"));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).readOnly, isTrue);
    expect(await preferences.readAcceptedChatRules("viewer-id:1"), isEmpty);
    await tester.tap(input);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Okay, Got It!"));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).readOnly, isFalse);
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    expect(await preferences.readAcceptedChatRules("viewer-id:1"), ["Be kind", "No spoilers"]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(panel(controller, preferences: preferences));
    await tester.pumpAndSettle();
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(find.text("Chat Rules"), findsNothing);
    expect(tester.widget<TextField>(input).readOnly, isFalse);
    controller.access = const TwitchChatAccess(
      channelId: "1",
      channelDisplayName: "Test Channel",
      rules: ["Be kind", "Keep links relevant"],
    );
    controller.update();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).readOnly, isFalse);
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(find.text("Chat Rules"), findsNothing);
    controller.access = const TwitchChatAccess(
      channelId: "2",
      channelDisplayName: "Another Channel",
      rules: ["Be kind", "Keep links relevant"],
    );
    controller.update();
    await tester.pumpAndSettle();
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(find.text("Chat Rules"), findsOneWidget);
    await tester.tap(find.text("Okay, Got It!"));
    await tester.pumpAndSettle();
    expect(await preferences.readAcceptedChatRules("viewer-id:2"), [
      "Be kind",
      "Keep links relevant",
    ]);
    expect(controller.sent, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets("long pins collapse after five seconds and respect a manual expansion", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _ChatController()
      ..pin = TwitchPinnedChat(
        id: "long",
        message: TwitchChatMessage(
          id: "long-message",
          login: "viewer",
          displayName: "Viewer",
          text: List.filled(35, "A longer pinned message").join(" "),
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byTooltip("Minimize pinned message"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.byTooltip("Expand pinned message"), findsOneWidget);
    await tester.tap(find.byTooltip("Expand pinned message"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(find.byTooltip("Minimize pinned message"), findsOneWidget);
    controller.pin = const TwitchPinnedChat(
      id: "short",
      message: TwitchChatMessage(
        id: "short-message",
        login: "viewer",
        displayName: "Viewer",
        text: "Short pin",
      ),
    );
    controller.update();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(find.byTooltip("Minimize pinned message"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("pin collapse uses rendered emote lines and cancels when the body becomes short", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const emoteUrl = "https://static-cdn.jtvnw.net/emoticons/v2/25/default/light/2.0";
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      picture.dispose();
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(emoteUrl),
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
      );
    });
    addTearDown(PaintingBinding.instance.imageCache.clear);
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    await settings.setChatPreferences(settings.chatPreferences.copyWith(emoteScale: 2));
    final controller = _ChatController()
      ..pin = TwitchPinnedChat(
        id: "emotes",
        message: TwitchChatMessage(
          id: "emote-message",
          login: "viewer",
          displayName: "Viewer",
          text: List.filled(16, "E").join(" "),
          emotes: [
            for (var index = 0; index < 16; index++)
              TwitchChatEmote(id: "25", start: index * 2, end: index * 2 + 1),
          ],
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, settingsStore: settings));
    await tester.pumpAndSettle();
    final images = find.descendant(
      of: find.byKey(const ValueKey("chat_pinned_message")),
      matching: find.byType(Image),
    );
    expect(images, findsNWidgets(16));
    final tops = {
      for (var index = 0; index < 16; index++) tester.getTopLeft(images.at(index)).dy,
    };
    expect(tops.length, greaterThan(2));
    await tester.pump(const Duration(seconds: 4));
    await settings.setChatPreferences(settings.chatPreferences.copyWith(emoteScale: 0.5));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byTooltip("Minimize pinned message"), findsOneWidget);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(emoteScale: 2));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pumpAndSettle();
    expect(find.byTooltip("Expand pinned message"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the emote picker pushes chat up, inserts into the draft, and Back closes it", (
    tester,
  ) async {
    final originalSize = tester.view.physicalSize;
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _ChatController();
    final assets = _Assets();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final chat = find.byKey(const ValueKey("chat_messages"));
    final input = find.byKey(const ValueKey("chat_message_input"));
    await tester.enterText(input, "Hello");
    await tester.pumpAndSettle();
    final fullHeight = tester.getSize(chat).height;
    await tester.tap(find.byTooltip("Show emotes"));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, "Recent"), findsOneWidget);
    expect(tester.getSize(chat).height, lessThan(fullHeight));
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.widgetWithText(ChoiceChip, "Twitch"));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, "Unlocked"), findsOneWidget);
    await tester.tap(find.text("HeyGuys"));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, "Hello HeyGuys ");
    expect(controller.sent, isEmpty);
    for (final height in [100.0, 80.0]) {
      tester.view.physicalSize = Size(originalSize.width, height * tester.view.devicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: "Picker at $height logical pixels");
      expect(tester.widget<TextField>(input).controller!.text, "Hello HeyGuys ");
    }
    tester.view.physicalSize = originalSize;
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, "Recent"), findsNothing);
    expect(tester.getSize(chat).height, fullHeight);
    expect(tester.widget<TextField>(input).controller!.text, "Hello HeyGuys ");
    expect(tester.takeException(), isNull);
  });

  testWidgets("emote autocomplete replaces the cursor word and preserves draft and keyboard", (
    tester,
  ) async {
    final controller = _ChatController();
    final assets = _Assets();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    final suggestions = find.byKey(const ValueKey("chat_emote_autocomplete"));
    await tester.enterText(input, "Hello :ka");
    await tester.pumpAndSettle();
    expect(suggestions, findsOneWidget);
    expect(assets.unlockedLoads, 1);
    expect(tester.getSize(suggestions).height, 48);
    expect(find.descendant(of: suggestions, matching: find.byType(ActionChip)), findsNothing);
    expect(find.descendant(of: suggestions, matching: find.text("Kappa")), findsOneWidget);
    final image = find.descendant(of: suggestions, matching: find.byType(Image));
    final emote = tester.widget<Image>(
      image,
    );
    expect(emote.width, 80);
    expect(emote.height, 40);
    expect(
      tester.getTopLeft(find.descendant(of: suggestions, matching: find.text("Kappa"))).dx,
      greaterThan(tester.getTopRight(image).dx),
    );
    await tester.tap(find.byTooltip("Kappa"));
    await tester.pumpAndSettle();
    final draft = tester.widget<TextField>(input).controller!;
    expect(draft.text, "Hello Kappa ");
    expect(draft.selection.baseOffset, draft.text.length);
    expect(suggestions, findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    expect(controller.sent, isEmpty);

    await tester.enterText(input, "Hello kappa friend");
    draft.selection = const TextSelection.collapsed(offset: 8);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Kappa"));
    await tester.pumpAndSettle();
    expect(draft.text, "Hello Kappa friend");
    expect(draft.selection.baseOffset, 12);
    expect(assets.unlockedLoads, 1);

    final fullDraft = "${List.filled(496, "x").join()} Ka";
    await tester.enterText(input, fullDraft);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Kappa"));
    await tester.pumpAndSettle();
    expect(draft.text, fullDraft);
    expect(controller.sent, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets("emote autocomplete ranks exact and prefix matches before substring matches", (
    tester,
  ) async {
    final controller = _ChatController();
    final assets = _AutocompleteAssets();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    final suggestions = find.byKey(const ValueKey("chat_emote_autocomplete"));
    await tester.enterText(input, "before :lOl after");
    final field = tester.widget<TextField>(input);
    field.controller!.selection = const TextSelection.collapsed(offset: "before :lOl".length);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Text>(
            find.descendant(of: suggestions, matching: find.byType(Text)),
          )
          .map((text) => text.data),
      ["LOL", "lolcat", "LOLW", "ALOL", "MaxLOL"],
    );
    final tiles = find.descendant(of: suggestions, matching: find.byType(ListTile));
    for (var index = 1; index < 5; index++) {
      expect(tester.getTopLeft(tiles.at(index)).dx, tester.getTopLeft(tiles.first).dx);
      expect(tester.getTopLeft(tiles.at(index)).dy - tester.getTopLeft(tiles.at(index - 1)).dy, 48);
    }
    await tester.tap(find.byTooltip("MaxLOL"));
    await tester.pumpAndSettle();
    expect(field.controller!.text, "before MaxLOL after");
    expect(field.controller!.selection.baseOffset, "before MaxLOL ".length);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(controller.sent, isEmpty);
    await tester.enterText(input, "@lol");
    await tester.pumpAndSettle();
    expect(suggestions, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "username autocomplete works without emote settings or assets and preserves draft selection",
    (tester) async {
      final controller = _ChatController();
      for (final entry in {
        "hivise": "Hivise",
        "hivise_fan": "Hivise_Fan",
        "somehivise": "SomeHivise",
        "actual_login": "昵称",
      }.entries) {
        controller.items.add(
          TwitchChatMessage(
            id: entry.key,
            login: entry.key,
            displayName: entry.value,
            text: "Hello",
            color: switch (entry.key) {
              "hivise" => "#FF0000",
              "hivise_fan" => "#00FF00",
              _ => "#0000FF",
            },
          ),
        );
      }
      controller.items.add(
        const TwitchChatMessage(
          id: "duplicate-user",
          login: "hivise",
          displayName: "Hivise",
          text: "Another message",
        ),
      );
      final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
      await settings.load();
      await settings.setChatPreferences(
        settings.chatPreferences.copyWith(emoteAutocomplete: false),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(panel(controller, settingsStore: settings));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey("chat_message_input"));
      final suggestions = find.byKey(const ValueKey("chat_username_autocomplete"));
      await tester.enterText(input, "@");
      await tester.pumpAndSettle();
      expect(find.descendant(of: suggestions, matching: find.byType(ListTile)), findsNWidgets(4));
      await tester.enterText(input, "Before @HiOLD after");
      final field = tester.widget<TextField>(input);
      field.controller!.selection = const TextSelection.collapsed(offset: "Before @Hi".length);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Text>(find.descendant(of: suggestions, matching: find.byType(Text)))
            .map((text) => text.data),
        ["Hivise", "Hivise_Fan", "SomeHivise"],
      );
      final labels = tester
          .widgetList<Text>(
            find.descendant(of: suggestions, matching: find.byType(Text)),
          )
          .toList();
      expect(labels.map((text) => text.style!.color), [
        const Color(0xFFDC0000),
        const Color(0xFF007B00),
        const Color(0xFF0000FF),
      ]);
      final tiles = find.descendant(of: suggestions, matching: find.byType(ListTile));
      expect(tester.getTopLeft(tiles.at(1)).dy - tester.getTopLeft(tiles.first).dy, 32);
      final tap = await tester.startGesture(
        tester.getCenter(find.widgetWithText(ListTile, "Hivise")),
      );
      await tester.pump(const Duration(milliseconds: 80));
      await tap.up();
      await tester.pumpAndSettle();
      expect(field.controller!.text, "Before @hivise after");
      expect(field.controller!.selection.baseOffset, "Before @hivise ".length);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(suggestions, findsNothing);
      expect(controller.sent, isEmpty);
      await tester.enterText(input, "@昵");
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, "昵称"));
      await tester.pumpAndSettle();
      expect(field.controller!.text, "@actual_login ");
      for (final text in ["Hivise", "email@hi", "@hi "]) {
        await tester.enterText(input, text);
        await tester.pumpAndSettle();
        expect(suggestions, findsNothing, reason: text);
      }
      final fullDraft = "${List.filled(495, "x").join()} @hi";
      await tester.enterText(input, fullDraft);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, "Hivise"));
      await tester.pumpAndSettle();
      expect(field.controller!.text, fullDraft);
      await tester.enterText(input, "@hi");
      await tester.pumpAndSettle();
      field.controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      await tester.pumpAndSettle();
      expect(suggestions, findsNothing);
      field.controller!.selection = const TextSelection.collapsed(offset: 3);
      await tester.pumpAndSettle();
      expect(suggestions, findsOneWidget);
      field.focusNode!.unfocus();
      await tester.pumpAndSettle();
      expect(suggestions, findsNothing);
      expect(controller.sent, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("vertical autocomplete stays above the keyboard, scrolls, and uses username paints", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(392, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final controller = _ChatController();
    for (var index = 0; index < 30; index++) {
      final suffix = index.toString().padLeft(2, "0");
      controller.items.add(
        TwitchChatMessage(
          id: suffix,
          login: "user$suffix",
          displayName: "User$suffix",
          color: "#FFFFFF",
          text: "Hello",
        ),
      );
    }
    final assets = _LargeCompletionAssets();
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets, settingsStore: settings));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    final field = tester.widget<TextField>(input);
    for (final mention in [false, true]) {
      await tester.enterText(input, mention ? "@user" : "Emote");
      await tester.pumpAndSettle();
      final suggestions = find.byKey(
        ValueKey(mention ? "chat_username_autocomplete" : "chat_emote_autocomplete"),
      );
      final list = find.descendant(of: suggestions, matching: find.byType(ListView));
      final view = tester.widget<ListView>(list);
      expect(view.scrollDirection, Axis.vertical);
      expect((view.childrenDelegate as SliverChildBuilderDelegate).childCount, 20);
      expect(tester.getSize(suggestions).height, lessThanOrEqualTo(200));
      expect(tester.getTopLeft(suggestions).dy, greaterThanOrEqualTo(0));
      expect(tester.getBottomRight(suggestions).dy, lessThanOrEqualTo(tester.getTopLeft(input).dy));
      if (mention) {
        final painted = find.descendant(of: suggestions, matching: find.byType(ChatUsername));
        expect(painted, findsOneWidget);
        expect(tester.widget<ChatUsername>(painted).name, "User00");
        expect(tester.widget<ChatUsername>(painted).style.color, const Color(0xFF717171));
        await settings.setChatPreferences(settings.chatPreferences.copyWith(animatedPaints: false));
        await tester.pumpAndSettle();
        expect(tester.widget<ChatUsername>(painted).animated, isFalse);
        await settings.setChatPreferences(settings.chatPreferences.copyWith(sevenTvPaints: false));
        await tester.pumpAndSettle();
        expect(painted, findsNothing);
        final label = find.descendant(of: suggestions, matching: find.text("User00"));
        expect(tester.widget<Text>(label).style!.color, const Color(0xFF717171));
      }
      final last = find.descendant(
        of: suggestions,
        matching: find.text(mention ? "User19" : "Emote19"),
      );
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      final tap = await tester.startGesture(tester.getCenter(last));
      await tester.pump(const Duration(milliseconds: 80));
      await tap.up();
      await tester.pumpAndSettle();
      expect(field.controller!.text, mention ? "@user19 " : "Emote19 ");
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    }
    expect(controller.sent, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets("connection notices scroll away as history and live chat arrive", (tester) async {
    final now = DateTime.now();
    final controller = _ChatController()
      ..items.addAll([
        TwitchChatMessage(
          id: "connecting",
          login: "",
          displayName: "",
          text: "",
          noticeType: "system",
          noticeText: "Connecting to chat...",
          timestamp: now,
        ),
        TwitchChatMessage(
          id: "welcome",
          login: "",
          displayName: "",
          text: "",
          noticeType: "system",
          noticeText: "Welcome to channel's Chat!",
          timestamp: now,
        ),
      ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, chatOnly: true));
    await tester.pumpAndSettle();
    final welcome = find.text("Welcome to channel's Chat!");
    final initialTop = tester.getTopLeft(welcome).dy;
    controller.items.insert(
      0,
      _message(1, timestamp: now.subtract(const Duration(minutes: 1))).copyWith(isHistorical: true),
    );
    controller.items.add(
      _message(2, timestamp: now.subtract(const Duration(milliseconds: 200))),
    );
    controller.update();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(welcome).dy, lessThan(initialTop));
    expect(
      tester.getTopLeft(welcome).dy,
      lessThan(tester.getTopLeft(find.textContaining("message 1", findRichText: true)).dy),
    );
    expect(
      tester.getTopLeft(find.textContaining("message 1", findRichText: true)).dy,
      lessThan(tester.getTopLeft(find.textContaining("message 2", findRichText: true)).dy),
    );
    expect(controller.items.firstWhere((item) => item.id == "welcome").timestamp, now);
  });

  testWidgets("local echoes and notices keep their position when server timestamps lag", (
    tester,
  ) async {
    final now = DateTime.now();
    final controller = _ChatController()
      ..items.add(_message(0, timestamp: now.subtract(const Duration(seconds: 20))));
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, chatOnly: true));
    await tester.pumpAndSettle();
    final sentAt = now.add(const Duration(minutes: 1));
    controller.items.add(_message(1, timestamp: sentAt, isOwn: true));
    controller.update();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("1")), findsOneWidget);
    controller.items.add(_message(2, timestamp: now.subtract(const Duration(seconds: 19))));
    controller.update();
    await tester.pumpAndSettle();
    double top(String id) => tester.getTopLeft(find.byKey(ValueKey(id))).dy;
    expect(top("0"), lessThan(top("1")));
    expect(top("1"), lessThan(top("2")));
    controller.items[1] = _message(3, timestamp: sentAt, isOwn: true);
    controller.items.add(
      TwitchChatMessage(
        id: "notice",
        login: "",
        displayName: "",
        text: "",
        isPrivate: true,
        noticeType: "notice",
        noticeText: "Local notice",
        timestamp: sentAt,
      ),
    );
    controller.update();
    await tester.pumpAndSettle();
    expect(top("3"), lessThan(top("2")));
    expect(top("2"), lessThan(top("notice")));
    controller.items.add(_message(4, timestamp: now.subtract(const Duration(seconds: 18))));
    controller.update();
    await tester.pumpAndSettle();
    expect(top("notice"), lessThan(top("4")));
    expect(tester.takeException(), isNull);
  });

  testWidgets("historical chat bypasses sync delay while new messages wait", (tester) async {
    final now = DateTime.now();
    final controller = _ChatController()
      ..items.addAll([
        _message(1, timestamp: now).copyWith(isHistorical: true),
        _message(2, timestamp: now),
      ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, latencyMs: 30000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("1")), findsOneWidget);
    expect(find.byKey(const ValueKey("2")), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("autocomplete retries a failed emote load on refocus without retrying while typing", (
    tester,
  ) async {
    final controller = _ChatController();
    final assets = _Assets(failUnlockedOnce: true);
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    await tester.enterText(input, "Ka");
    await tester.pumpAndSettle();
    expect(assets.unlockedLoads, 1);
    expect(assets.unlockedError, isNotNull);
    await tester.enterText(input, "Kapp");
    await tester.pumpAndSettle();
    expect(assets.unlockedLoads, 1);
    final field = tester.widget<TextField>(input);
    for (var refocus = 0; refocus < 2; refocus++) {
      field.focusNode!.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(assets.unlockedLoads, 2);
      expect(assets.unlockedError, isNull);
      expect(field.controller!.text, "Kapp");
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("autocomplete follows its setting, enabled providers, selection, and focus", (
    tester,
  ) async {
    final controller = _ChatController();
    final assets = _Assets();
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    addTearDown(controller.dispose);
    addTearDown(assets.dispose);
    await tester.pumpWidget(panel(controller, assets: assets, settingsStore: settings));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey("chat_message_input"));
    final suggestions = find.byKey(const ValueKey("chat_emote_autocomplete"));
    for (final text in ["K", "no-match", "@Ka", "https://Ka", "Ka "]) {
      await tester.enterText(input, text);
      await tester.pumpAndSettle();
      expect(suggestions, findsNothing, reason: text);
    }
    await tester.enterText(input, "Ka");
    await tester.pumpAndSettle();
    expect(find.byTooltip("Kappa"), findsOneWidget);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(sevenTvEmotes: false));
    await tester.pumpAndSettle();
    expect(suggestions, findsNothing);
    await tester.enterText(input, "he");
    await tester.pumpAndSettle();
    expect(find.byTooltip("HeyGuys"), findsOneWidget);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(emoteAutocomplete: false));
    await tester.pumpAndSettle();
    expect(suggestions, findsNothing);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(emoteAutocomplete: true));
    await tester.pumpAndSettle();
    expect(suggestions, findsOneWidget);
    final field = tester.widget<TextField>(input);
    field.controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    await tester.pumpAndSettle();
    expect(suggestions, findsNothing);
    field.controller!.selection = const TextSelection.collapsed(offset: 2);
    await tester.pumpAndSettle();
    expect(suggestions, findsOneWidget);
    field.focusNode!.unfocus();
    await tester.pumpAndSettle();
    expect(suggestions, findsNothing);
    expect(field.controller!.text, "he");
    expect(tester.takeException(), isNull);
  });

  testWidgets("sent messages flow upward as delayed chat arrives through acknowledgement", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    final sentAt = DateTime.now();
    controller.items.addAll([
      _message(0, timestamp: sentAt.subtract(const Duration(seconds: 2))),
      _message(1, timestamp: sentAt.subtract(const Duration(milliseconds: 400))),
      _message(2, timestamp: sentAt, isOwn: true),
      _message(3, timestamp: sentAt),
    ]);
    await tester.pumpWidget(panel(controller, latencyMs: 1000));
    expect(find.byKey(const ValueKey("2")), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("0"))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("2"))).dy),
    );
    expect(find.byKey(const ValueKey("1")), findsNothing);
    expect(find.byKey(const ValueKey("3")), findsNothing);

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("2"))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("1"))).dy),
    );
    controller.items.add(
      _message(4, timestamp: DateTime.now(), isOwn: true).copyWith(isHistorical: true),
    );
    controller.update();
    await tester.pump();
    controller.items.removeLast();
    controller.items[2] = _message(4, timestamp: sentAt, isOwn: true);
    controller.update();
    await tester.pump();
    expect(find.byKey(const ValueKey("2")), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("4"))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("1"))).dy),
    );

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("1"))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("3"))).dy),
    );
    controller.items.add(_message(5, timestamp: sentAt));
    controller.update();
    await tester.pumpWidget(panel(controller, chatOnly: true));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("3"))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("5"))).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets("sync countdown keeps one row through jitter and stays finished", (
    tester,
  ) async {
    final controller = _ChatController();
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    await settings.load();
    addTearDown(controller.dispose);
    controller.items.add(_message(1, timestamp: DateTime.now()));
    await tester.pumpWidget(panel(controller, settingsStore: settings, latencyMs: 1500));
    await tester.pumpAndSettle();
    final sync = controller.items.singleWhere((message) => message.noticeType == "system");
    final position = controller.items.indexOf(sync);
    final syncElement = tester.element(find.byKey(ValueKey(sync.id)));
    expect(find.text("Chat will sync in 2s..."), findsOneWidget);
    controller.update();
    await tester.pumpAndSettle();
    for (final latency in [1510, 2000, 3500, null, 6000]) {
      await tester.pumpWidget(panel(controller, settingsStore: settings, latencyMs: latency));
      await tester.pump();
    }
    controller.items.add(_message(2, isOwn: true));
    controller.update();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text("Chat will sync in 1s..."), findsOneWidget);
    expect(controller.items[position].id, sync.id);
    expect(controller.items[position].timestamp, sync.timestamp);
    expect(tester.element(find.byKey(ValueKey(sync.id))), same(syncElement));
    expect(controller.systemMessages, ["Chat will sync in 2s...", "Chat will sync in 1s..."]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining("Chat will sync"), findsNothing);
    expect(find.byKey(const ValueKey("1")), findsOneWidget);
    controller.items.add(_message(3, timestamp: DateTime.now()));
    controller.update();
    await tester.pumpWidget(panel(controller, settingsStore: settings, latencyMs: 10000));
    await tester.pump();
    expect(find.textContaining("Chat will sync"), findsNothing);
    expect(controller.items.where((message) => message.noticeType == "system"), hasLength(1));
    expect(controller.systemMessages, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets("auto delay tracks gradual latency changes without hiding released messages", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    final latencies = [6500, 4200, 2300, 1650];
    for (var index = 0; index < latencies.length; index++) {
      controller.items.add(
        _message(
          index,
          timestamp: DateTime.now().subtract(
            Duration(milliseconds: latencies[index] + 250),
          ),
        ),
      );
      await tester.pumpWidget(panel(controller, latencyMs: latencies[index]));
      for (var visible = 0; visible <= index; visible++) {
        expect(find.byKey(ValueKey("$visible")), findsOneWidget);
      }
      if (index > 0) {
        expect(
          tester.getTopLeft(find.byKey(ValueKey("${index - 1}"))).dy,
          lessThan(tester.getTopLeft(find.byKey(ValueKey("$index"))).dy),
        );
      }
    }
    controller.items.add(_message(4, timestamp: DateTime.now()));
    await tester.pumpWidget(panel(controller, latencyMs: 5000));
    await tester.pump();
    expect(find.byKey(const ValueKey("1")), findsOneWidget);
    expect(find.byKey(const ValueKey("2")), findsOneWidget);
    expect(find.byKey(const ValueKey("3")), findsOneWidget);
    expect(find.byKey(const ValueKey("4")), findsNothing);
    await tester.pumpWidget(panel(controller));
    expect(find.byKey(const ValueKey("4")), findsNothing);
    await tester.pumpWidget(panel(controller, chatOnly: true));
    expect(find.byKey(const ValueKey("4")), findsOneWidget);
    expect(find.textContaining("Chat will sync"), findsNothing);
    await tester.pumpWidget(panel(controller, latencyMs: 10000));
    expect(find.byKey(const ValueKey("4")), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets("chat-only flushes an eight-second delay and video delays only new arrivals", (
    tester,
  ) async {
    final controller = _ChatController()..items.add(_message(1, timestamp: DateTime.now()));
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, latencyMs: 8000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("1")), findsNothing);
    expect(find.text("Chat will sync in 8s..."), findsOneWidget);

    await tester.pumpWidget(panel(controller, chatOnly: true, latencyMs: 8000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("1")), findsOneWidget);
    expect(find.textContaining("Chat will sync"), findsNothing);
    controller.items.add(_message(2, timestamp: DateTime.now()));
    controller.update();
    await tester.pump();
    expect(find.byKey(const ValueKey("2")), findsOneWidget);
    final countdownUpdates = controller.systemMessages.length;
    await tester.pump(const Duration(seconds: 8));
    expect(controller.systemMessages, hasLength(countdownUpdates));
    expect(find.textContaining("Chat will sync"), findsNothing);

    await tester.pumpWidget(panel(controller, latencyMs: 8000));
    await tester.pump();
    expect(find.byKey(const ValueKey("1")), findsOneWidget);
    expect(find.byKey(const ValueKey("2")), findsOneWidget);
    controller.items.add(_message(3, timestamp: DateTime.now()));
    controller.update();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey("3")), findsNothing);
    expect(find.text("Chat will sync in 8s..."), findsOneWidget);
    expect(controller.items.where((message) => message.noticeType == "system"), hasLength(1));

    await tester.pumpWidget(panel(controller, chatOnly: true, latencyMs: 8000));
    expect(find.byKey(const ValueKey("3")), findsOneWidget);
    expect(find.textContaining("Chat will sync"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets("a lower auto delay cannot release newer messages ahead of pending chat", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    controller.items.add(
      _message(1, timestamp: DateTime.now().subtract(const Duration(seconds: 5))),
    );
    await tester.pumpWidget(panel(controller, latencyMs: 6500));
    controller.items.add(_message(2, timestamp: DateTime.now()));
    controller.items.add(
      _message(3, timestamp: DateTime.now().subtract(const Duration(minutes: 1))),
    );
    await tester.pumpWidget(panel(controller, latencyMs: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey("1")), findsNothing);
    expect(find.byKey(const ValueKey("2")), findsNothing);
    expect(find.byKey(const ValueKey("3")), findsNothing);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1300)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey("1")), findsOneWidget);
    expect(find.byKey(const ValueKey("2")), findsOneWidget);
    expect(find.byKey(const ValueKey("3")), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("1"))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("2"))).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets("switching sources and disposing cancel the old sync countdown", (tester) async {
    final first = _ChatController()..items.add(_message(1, timestamp: DateTime.now()));
    final second = _ChatController(channel: "second")
      ..items.add(_message(1, timestamp: DateTime.now()));
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(panel(first, latencyMs: 30000));
    await tester.pump();
    expect(find.text("Chat will sync in 30s..."), findsOneWidget);
    final firstUpdates = first.systemMessages.length;
    await tester.pumpWidget(panel(second, latencyMs: 1500));
    await tester.pump();
    expect(find.text("Chat will sync in 2s..."), findsOneWidget);
    expect(find.byKey(const ValueKey("1")), findsNothing);
    expect(first.listening, isFalse);
    final secondUpdates = second.systemMessages.length;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
    expect(first.systemMessages, hasLength(firstUpdates));
    expect(second.systemMessages, hasLength(secondUpdates));
    expect(tester.takeException(), isNull);
  });

  testWidgets("matches Twitch's readable name colors in light and dark themes", (
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
        "White": brightness == Brightness.light ? const Color(0xFF717171) : Colors.white,
        "NearWhite": brightness == Brightness.light
            ? const Color(0xFF727171)
            : const Color(0xFFFFFEFE),
        "Snow": brightness == Brightness.light ? const Color(0xFF736F6F) : const Color(0xFFFFFAFA),
        "Black": brightness == Brightness.dark ? const Color(0xFF7A7A7A) : Colors.black,
        "NearBlack": brightness == Brightness.dark
            ? const Color(0xFF7A7A7A)
            : const Color(0xFF010101),
        "Green": brightness == Brightness.light ? const Color(0xFF007B00) : const Color(0xFF00FF00),
        "LightYellow": brightness == Brightness.light
            ? const Color(0xFF727258)
            : const Color(0xFFFFFFE0),
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

  testWidgets("clears sent drafts immediately, restores failures and supports keyboard send", (
    tester,
  ) async {
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
    expect(send, findsNothing);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
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
      "Chat disconnected",
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

  testWidgets("VOD replay retains a disabled composer and a watch action", (
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
    final input = tester.widget<TextField>(find.byKey(const ValueKey("chat_message_input")));
    expect(input.enabled, isFalse);
    expect(input.readOnly, isTrue);
    expect(input.decoration!.hintText, "Chat replay");
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byTooltip("Send message"), findsNothing);
    await _openMenu(tester);
    await tester.tap(find.text("Show video"));
    await tester.pumpAndSettle();
    expect(watching, isTrue);
  });

  testWidgets("scrolled replay applies timed deletions after feed eviction and resets on seek", (
    tester,
  ) async {
    final client = _VodPageClient([
      TwitchChatMessage(
        id: "original",
        login: "viewer",
        displayName: "Viewer",
        text: "original recorded message",
        offsetSeconds: 0,
        timestamp: DateTime.utc(2026),
        moderatedAt: DateTime.utc(2026).add(const Duration(seconds: 3)),
      ),
      for (var index = 1; index < 400; index++)
        TwitchChatMessage(
          id: "$index",
          login: "viewer",
          displayName: "Viewer",
          text: "recorded message $index",
          offsetSeconds: index < 100 ? 0 : 2,
        ),
    ]);
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    addTearDown(replay.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchChatPanel(
            replayController: replay,
            chatOnly: false,
            isLive: false,
            preferences: MemoryFlowPreferences(),
            onToggleChatOnly: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(find.byKey(const ValueKey("chat_messages"))).controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final original = find.textContaining("original recorded message", findRichText: true);
    expect(original, findsOneWidget);
    replay.updatePosition(const Duration(milliseconds: 2999));
    await tester.pumpAndSettle();
    expect(replay.messages.any((message) => message.id == "original"), isFalse);
    expect(original, findsOneWidget);
    replay.updatePosition(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(original, findsNothing);
    replay.updatePosition(Duration.zero, seek: true);
    await tester.pumpAndSettle();
    expect(find.text("Jump to latest"), findsNothing);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(original, findsOneWidget);
  });

  testWidgets("replay threads hide future replies and defer current deletion flags", (
    tester,
  ) async {
    final start = DateTime.utc(2026);
    final client = _VodPageClient(
      [
        TwitchChatMessage(
          id: "reply",
          login: "viewer",
          displayName: "Viewer",
          text: "recorded reply",
          parentMessageId: "root",
          parentLogin: "parent",
          parentText: "parent preview",
          offsetSeconds: 1,
          timestamp: start.add(const Duration(seconds: 1)),
        ),
      ],
      thread: [
        TwitchChatMessage(
          id: "root",
          login: "parent",
          displayName: "Parent",
          text: "original thread body",
          timestamp: start,
          isDeleted: true,
          moderation: TwitchChatModeration.deleted,
          moderatedAt: start.add(const Duration(seconds: 3)),
        ),
        TwitchChatMessage(
          id: "future-reply",
          login: "future",
          displayName: "Future",
          text: "future thread body",
          parentMessageId: "root",
          timestamp: start.add(const Duration(seconds: 8)),
        ),
      ],
    );
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    addTearDown(replay.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchChatPanel(
            replayController: replay,
            chatOnly: false,
            isLive: false,
            preferences: MemoryFlowPreferences(),
            onToggleChatOnly: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    replay.updatePosition(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("reply-context-reply")));
    await tester.pumpAndSettle();
    expect(find.text("REPLIES"), findsOneWidget);
    expect(find.textContaining("original thread body", findRichText: true), findsOneWidget);
    expect(find.textContaining("future thread body", findRichText: true), findsNothing);
    replay.updatePosition(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining("original thread body", findRichText: true), findsNothing);
    replay.updatePosition(Duration.zero, seek: true);
    await tester.pumpAndSettle();
    expect(find.text("REPLIES"), findsNothing);
  });

  testWidgets("timestamps switch between 24-hour and 12-hour clocks", (tester) async {
    final controller = _ChatController()
      ..items.addAll([
        _message(1, timestamp: DateTime(2026, 1, 1, 0, 5)),
        _message(2, timestamp: DateTime(2026, 1, 1, 12, 5)),
        _message(3, timestamp: DateTime(2026, 1, 1, 23, 5)),
      ]);
    addTearDown(controller.dispose);
    final store = AppSettingsStore(preferences: MemoryFlowPreferences());
    await store.load();
    await store.setChatPreferences(const ChatPreferences(showTimestamps: true));
    await tester.pumpWidget(panel(controller, settingsStore: store));
    for (final time in ["00:05", "12:05", "23:05"]) {
      expect(find.textContaining("$time ", findRichText: true), findsOneWidget);
    }
    await store.setChatPreferences(
      store.chatPreferences.copyWith(timestampFormat: ChatTimestampFormat.twelveHour),
    );
    await tester.pump();
    for (final time in ["12:05 AM", "12:05 PM", "11:05 PM"]) {
      expect(find.textContaining("$time ", findRichText: true), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("composer shows the applied chat delay and clears it in offline and chat-only mode", (
    tester,
  ) async {
    final controller = _ChatController();
    addTearDown(controller.dispose);
    final store = AppSettingsStore(preferences: MemoryFlowPreferences());
    await store.load();
    String? hint() => tester.widget<TextField>(find.byType(TextField)).decoration!.hintText;
    await tester.pumpWidget(panel(controller, settingsStore: store, latencyMs: 1540));
    expect(hint(), "Send a message · 1.5s");
    await store.setChatPreferences(
      const ChatPreferences(autoSyncChat: false, manualChatDelaySeconds: 3),
    );
    await tester.pump();
    expect(hint(), "Send a message · 3.0s");
    await tester.pumpWidget(panel(controller, settingsStore: store, chatOnly: true));
    expect(hint(), "Send a message");
    await tester.pumpWidget(panel(controller, settingsStore: store, isLive: false));
    expect(hint(), "Send a message");
    expect(tester.takeException(), isNull);
  });

  testWidgets("keyboard dismissal keeps chat following and preserves an intentional pause", (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    final controller = _ChatController()..items.addAll(List.generate(100, _message));
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, chatOnly: true));
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey("chat_messages"));
    final scroll = tester.widget<ListView>(list).controller!;
    final input = find.byKey(const ValueKey("chat_message_input"));
    await tester.tap(input);
    for (final bottom in [300.0, 240.0, 120.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: bottom * tester.view.devicePixelRatio);
      await tester.pump();
      controller.items.add(_message(controller.items.length));
      controller.update();
      await tester.pump();
    }
    expect(scroll.position.extentBefore, 0);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    scroll.jumpTo(200);
    await tester.pump();
    for (final bottom in [300.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: bottom * tester.view.devicePixelRatio);
      await tester.pump();
    }
    expect(scroll.offset, 200);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });

  testWidgets("a canceled system gesture does not leave live chat paused", (tester) async {
    final controller = _ChatController()..items.addAll(List.generate(100, _message));
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, chatOnly: true));
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey("chat_messages"));
    final scroll = tester.widget<ListView>(list).controller!;
    final gesture = await tester.startGesture(tester.getTopLeft(list) + const Offset(1, 150));
    await gesture.moveBy(const Offset(5, 40));
    await tester.pump();
    await gesture.moveBy(const Offset(15, 40));
    await tester.pump();
    expect(scroll.position.extentBefore, greaterThan(0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    controller.items.add(_message(100));
    controller.update();
    await tester.pump();
    expect(scroll.position.extentBefore, 0);
    expect(find.textContaining("message 100", findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    scroll.jumpTo(200);
    await tester.pump();
    final pausedGesture = await tester.startGesture(tester.getCenter(list));
    await pausedGesture.moveBy(const Offset(5, 40));
    await pausedGesture.moveBy(const Offset(15, 40));
    await pausedGesture.cancel();
    await tester.pumpAndSettle();
    controller.items.add(_message(101));
    controller.update();
    await tester.pump();
    expect(scroll.position.extentBefore, greaterThan(0));
    expect(find.text("1 new message"), findsOneWidget);
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

  testWidgets(
    "a paused feed removes cleared private notices and pending sends while retaining public messages",
    (
      tester,
    ) async {
      final controller = _ChatController()
        ..received = 101
        ..items.addAll([
          const TwitchChatMessage(
            id: "private-notice",
            login: "",
            displayName: "",
            text: "",
            noticeType: "channel-points",
            noticeText: "Claimed 50 points",
            isPrivate: true,
          ),
          const TwitchChatMessage(
            id: "pending:123",
            login: "me",
            displayName: "Me",
            text: "Waiting for confirmation",
            isOwn: true,
          ),
          ...List.generate(100, _message),
        ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(panel(controller));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<ListView>(find.byKey(const ValueKey("chat_messages")))
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text("Jump to latest"), findsOneWidget);
      expect(find.text("Claimed 50 points"), findsOneWidget);
      expect(find.byKey(const ValueKey("pending:123")), findsOneWidget);
      expect(find.byKey(const ValueKey("0")), findsOneWidget);
      controller.items.removeWhere(
        (message) => message.isPrivate || message.id.startsWith("pending:") || message.id == "0",
      );
      controller.update();
      await tester.pumpAndSettle();
      expect(find.text("Claimed 50 points"), findsNothing);
      expect(find.text("Only visible to you"), findsNothing);
      expect(find.byKey(const ValueKey("pending:123")), findsNothing);
      expect(find.byKey(const ValueKey("0")), findsOneWidget);
      expect(find.byKey(const ValueKey("1")), findsOneWidget);
      expect(find.text("Jump to latest"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("a newer delayed timeout does not remove the visible moderation label", (
    tester,
  ) async {
    final controller = _ChatController();
    final now = DateTime.now();
    final moderationTime = now.subtract(const Duration(seconds: 1));
    controller.items.addAll([
      TwitchChatMessage(
        id: "visible",
        login: "viewer",
        displayName: "Viewer",
        text: "Visible message",
        timestamp: now.subtract(const Duration(minutes: 1)),
        isDeleted: true,
        moderation: TwitchChatModeration.timeout,
        timeoutSeconds: 60,
        moderatedAt: moderationTime,
      ),
      TwitchChatMessage(
        id: "delayed",
        login: "viewer",
        displayName: "Viewer",
        text: "Delayed message",
        timestamp: now.add(const Duration(minutes: 1)),
        isDeleted: true,
        moderation: TwitchChatModeration.timeout,
        timeoutSeconds: 60,
        moderatedAt: moderationTime,
      ),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, latencyMs: 30000));
    await tester.pumpAndSettle();
    expect(find.textContaining("was timed out for 60s"), findsOneWidget);
    final row = find.byKey(const ValueKey("visible"));
    for (var index = 0; index < 2; index++) {
      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Copy message"));
      await tester.pumpAndSettle();
      expect(find.textContaining("was timed out for 60s"), findsOneWidget);
    }
    expect(find.byKey(const ValueKey("delayed")), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a paused feed keeps its timeout label when a newer matching message arrives", (
    tester,
  ) async {
    final controller = _ChatController();
    final moderatedAt = DateTime(2026, 5, 12);
    controller.items.addAll([
      _message(0).copyWith(
        isDeleted: true,
        moderation: TwitchChatModeration.timeout,
        timeoutSeconds: 60,
        moderatedAt: moderatedAt,
      ),
      ...List.generate(99, (index) => _message(index + 1)),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(find.byKey(const ValueKey("chat_messages"))).controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.textContaining("was timed out for 60s"), findsOneWidget);
    controller.items.add(
      _message(100).copyWith(
        isDeleted: true,
        moderation: TwitchChatModeration.timeout,
        timeoutSeconds: 60,
        moderatedAt: moderatedAt,
      ),
    );
    controller.update();
    await tester.pumpAndSettle();
    expect(find.text("1 new message"), findsOneWidget);
    expect(find.byKey(const ValueKey("100")), findsNothing);
    expect(find.textContaining("was timed out for 60s"), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.textContaining("timed message", findRichText: true), findsOneWidget);
    controller.items.add(
      _message(2, timestamp: DateTime.now().subtract(const Duration(seconds: 2))),
    );
    controller.update();
    await tester.pump();
    expect(find.byKey(const ValueKey("2")), findsNothing);
    await settings.setChatPreferences(settings.chatPreferences.copyWith(manualChatDelaySeconds: 1));
    await tester.pump();
    expect(find.byKey(const ValueKey("2")), findsOneWidget);
    expect(find.textContaining("timed message", findRichText: true), findsOneWidget);
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
    expect(find.textContaining("removed words", findRichText: true), findsOneWidget);
    expect(find.textContaining("(deleted)", findRichText: true), findsNothing);
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
      const Color(0xFF007B00),
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

  testWidgets("username autocomplete shares all returned chatters with the searchable drawer", (
    tester,
  ) async {
    final client = _ChattersClient()
      ..result = TwitchChatters(
        count: 44000,
        groups: {
          "chatbots": ["helperbot"],
          "viewers": [for (var index = 0; index < 1200; index++) "lurker$index"],
        },
      );
    final controller = _ChatController(client: client);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pump();
    final input = find.byKey(const ValueKey("chat_message_input"));
    final suggestions = find.byKey(const ValueKey("chat_username_autocomplete"));
    await tester.enterText(input, "@lurker1199");
    await tester.pumpAndSettle();
    expect(find.descendant(of: suggestions, matching: find.text("lurker1199")), findsOneWidget);
    expect(client.calls, 1);
    await tester.tap(find.descendant(of: suggestions, matching: find.text("lurker1199")));
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, "@lurker1199 ");
    await tester.enterText(input, "");
    tester.widget<TextField>(input).focusNode!.unfocus();
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(find.text("Chatters"));
    await tester.pumpAndSettle();
    expect(client.calls, 1);
    expect(find.text("Chatters · 44000"), findsOneWidget);
    expect(find.text("Showing 1201 names returned by Twitch"), findsOneWidget);
    expect(find.text("Chatbots"), findsOneWidget);
    expect(find.text("helperbot"), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey("chatters_search")), "lurker1199");
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byType(CustomScrollView)).dy, lessThanOrEqualTo(300));
    expect(
      find.descendant(of: find.byType(CustomScrollView), matching: find.text("lurker1199")),
      findsOneWidget,
    );
    expect(find.text("helperbot"), findsNothing);
    client.result = const TwitchChatters(
      count: 1,
      groups: {
        "viewers": ["newlurker1199"],
      },
    );
    await tester.tap(find.byTooltip("Refresh chatters"));
    await tester.pumpAndSettle();
    expect(client.calls, 2);
    expect(find.text("newlurker1199"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("a previous channel roster cannot appear in username autocomplete", (tester) async {
    final pending = Completer<TwitchChatters>();
    final oldClient = _ChattersClient()..response = pending.future;
    final oldController = _ChatController(client: oldClient);
    final newClient = _ChattersClient()
      ..result = const TwitchChatters(
        count: 1,
        groups: {
          "viewers": ["newlurker"],
        },
      );
    final newController = _ChatController(channel: "newchannel", client: newClient);
    addTearDown(oldController.dispose);
    addTearDown(newController.dispose);
    await tester.pumpWidget(panel(oldController));
    await tester.pump();
    final input = find.byKey(const ValueKey("chat_message_input"));
    await tester.enterText(input, "@lurker");
    await tester.pump();
    expect(oldClient.calls, 1);
    await tester.pumpWidget(panel(newController));
    await tester.pump();
    await tester.enterText(input, "@lurker");
    await tester.pumpAndSettle();
    pending.complete(
      const TwitchChatters(
        count: 1,
        groups: {
          "viewers": ["oldlurker"],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("newlurker"), findsOneWidget);
    expect(find.text("oldlurker"), findsNothing);
    expect(newClient.calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("username autocomplete retries a failed roster request on the next query", (
    tester,
  ) async {
    final client = _ChattersClient()..fail = true;
    final controller = _ChatController(client: client);
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller));
    await tester.pump();
    final input = find.byKey(const ValueKey("chat_message_input"));
    await tester.enterText(input, "@some");
    await tester.pumpAndSettle();
    expect(client.calls, 1);
    expect(tester.takeException(), isNull);
    client.fail = false;
    await tester.enterText(input, "@someone");
    await tester.pumpAndSettle();
    expect(client.calls, 2);
    expect(find.text("someone"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("roster duplicates retain the observed username and chat color", (tester) async {
    final client = _ChattersClient()
      ..result = const TwitchChatters(
        count: 1,
        groups: {
          "viewers": ["viewer"],
        },
      );
    final controller = _ChatController(client: client)..items.add(_message(1));
    addTearDown(controller.dispose);
    await tester.pumpWidget(panel(controller, brightness: Brightness.dark));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey("chat_message_input")), "@viewer");
    await tester.pumpAndSettle();
    final name = find.descendant(
      of: find.byKey(const ValueKey("chat_username_autocomplete")),
      matching: find.text("Viewer"),
    );
    expect(name, findsOneWidget);
    final username = tester.widget<Text>(name);
    expect(username.style!.color, const Color(0xFF00FF00));
    await tester.pumpWidget(const SizedBox.shrink());
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

TwitchChatMessage _message(int index, {DateTime? timestamp, bool isOwn = false}) =>
    TwitchChatMessage(
      id: "$index",
      login: "viewer",
      displayName: "Viewer",
      text: "message $index",
      color: "#00FF00",
      timestamp: timestamp,
      isOwn: isOwn,
    );

class _ChatController extends TwitchChatController {
  _ChatController({super.channel = "testchannel", TwitchApiClient? client})
    : super(
        clientLoader: () async => client ?? (throw StateError("Unused in widget tests")),
        autoConnect: false,
      );

  final items = <TwitchChatMessage>[];
  final sent = <String>[];
  final systemMessages = <String>[];
  final room = <String, String>{};
  TwitchChatStatus connectionStatus = TwitchChatStatus.connected;
  String? notice;
  bool signedIn = true;
  bool followerEligible = true;
  Duration waitRemaining = Duration.zero;
  Duration slowWaitRemaining = Duration.zero;
  int followCalls = 0;
  int unfollowCalls = 0;
  TwitchChatAccess access = const TwitchChatAccess(
    channelId: "1",
    channelDisplayName: "Test Channel",
    rules: [],
  );
  TwitchPinnedChat? pin;
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
  bool get canSend =>
      signedIn &&
      status == TwitchChatStatus.connected &&
      followerChatEligible &&
      slowModeWaitRemaining == Duration.zero;

  @override
  Duration get slowModeWaitRemaining => slowWaitRemaining;

  @override
  TwitchChatAccess get chatAccess => access;

  @override
  String get currentUserId => "viewer-id";

  @override
  int get followersOnlyMinutes => int.tryParse(room["followers-only"] ?? "") ?? -1;

  @override
  bool get followerChatEligible => followerEligible;

  @override
  Duration get followingWaitRemaining => waitRemaining;

  @override
  TwitchPinnedChat? get pinnedChat => pin;

  @override
  TwitchChatMessage? get pinnedMessage => pin?.message;

  @override
  Future<bool> followChannel() async {
    followCalls++;
    followerEligible = true;
    access = TwitchChatAccess(
      channelId: access.channelId,
      channelDisplayName: access.channelDisplayName,
      rules: access.rules,
      isFollowing: true,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> unfollowChannel() async {
    unfollowCalls++;
    followerEligible = false;
    access = TwitchChatAccess(
      channelId: access.channelId,
      channelDisplayName: access.channelDisplayName,
      rules: access.rules,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> send(String text, {TwitchChatMessage? replyTo}) {
    sent.add(text);
    return sendResult ?? Future.value(true);
  }

  @override
  void reconnect() => retries++;

  @override
  void addSystemMessage(String text) => systemMessages.add(text);

  @override
  void upsertSystemMessage(String id, String text) {
    final index = items.indexWhere((message) => message.id == id);
    if (index >= 0) {
      if (items[index].noticeText == text) {
        return;
      }
      items[index] = items[index].copyWith(noticeText: text);
    } else {
      items.add(
        TwitchChatMessage(
          id: id,
          login: "",
          displayName: "",
          text: "",
          noticeType: "system",
          noticeText: text,
          timestamp: DateTime.now(),
        ),
      );
    }
    systemMessages.add(text);
    notifyListeners();
  }

  void update() => notifyListeners();
}

class _ChattersClient extends TwitchApiClient {
  _ChattersClient() : super(clientId: "test", accessToken: "");

  String? channel;
  int calls = 0;
  bool fail = false;
  Future<TwitchChatters>? response;
  TwitchChatters result = const TwitchChatters(
    count: 200,
    groups: {
      "moderators": ["channelmod"],
      "viewers": ["someone"],
    },
  );

  @override
  Future<TwitchChatters> fetchChatters(String login) async {
    channel = login;
    calls++;
    if (fail) {
      throw TwitchApiException("Offline");
    }
    return response ?? result;
  }
}

class _VodPageClient extends TwitchApiClient {
  _VodPageClient(this.messages, {this.thread = const []})
    : super(clientId: "test", accessToken: "");

  final List<TwitchChatMessage> messages;
  final List<TwitchChatMessage> thread;

  @override
  Future<List<TwitchChatMessage>> fetchChatReplyThread(String messageId) async => thread;

  @override
  Future<TwitchVodChatPage> fetchVodChatPage(
    String videoId, {
    int? offsetSeconds,
    String? cursor,
  }) async => TwitchVodChatPage(messages: messages, cursor: null, hasNextPage: false);
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

class _AutocompleteAssets extends _Assets {
  @override
  Map<String, ChatAssetEmote> get emotesByName => {
    ...super.emotesByName,
    for (final name in ["MaxLOL", "ALOL", "LOLW", "LOL", "lolcat"])
      name: ChatAssetEmote(
        name: name,
        id: name,
        url: "https://example.com/$name.png",
        provider: ChatEmoteProvider.sevenTv,
      ),
  };
}

class _LargeCompletionAssets extends _Assets {
  @override
  Map<String, ChatAssetEmote> get emotesByName => {
    for (var index = 0; index < 30; index++)
      "Emote${index.toString().padLeft(2, "0")}": ChatAssetEmote(
        name: "Emote${index.toString().padLeft(2, "0")}",
        id: "$index",
        url: "https://example.com/emote-$index.png",
        provider: ChatEmoteProvider.sevenTv,
      ),
  };

  @override
  Map<String, ChatAssetPaint> get userPaintsByLogin => const {
    "user00": ChatAssetPaint(
      id: "paint",
      name: "Magenta",
      layers: [
        ChatPaintLayer(id: "color", type: ChatPaintLayerType.color, color: Colors.purple),
      ],
    ),
  };
}

class _Assets extends TwitchChatAssets {
  _Assets({this.failUnlockedOnce = false})
    : super(
        clientLoader: () async => throw StateError("Unused"),
        channelLogin: "testchannel",
        autoLoad: false,
      );

  int refreshes = 0;
  int unlockedLoads = 0;
  final bool failUnlockedOnce;

  @override
  String? get unlockedError =>
      failUnlockedOnce && unlockedLoads == 1 ? "Could not load emotes" : null;

  @override
  Future<void> loadUnlockedEmotes() async => unlockedLoads++;

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

  @override
  List<ChatAssetEmote> emotesFor(ChatEmoteProvider provider, ChatEmoteScope scope) =>
      emotesByName.values.where((emote) => emote.provider == provider).toList();
}
