import "dart:async";

import "package:flow/app/app_settings_store.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/tabs_screen.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("chat settings load existing values and save appearance and every provider", (
    tester,
  ) async {
    final saved = _MemoryPreferencesStore()..stringLists["chat_settings"] = ["18"];
    final preferences = SharedPreferencesFlowPreferences(store: saved);
    final settingsStore = AppSettingsStore(preferences: preferences);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey("chat_font_size"));
    await tester.scrollUntilVisible(slider, 300);
    await Scrollable.ensureVisible(tester.element(slider), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 18);
    await tester.drag(slider, const Offset(100, 0));
    await tester.pumpAndSettle();
    final size = settingsStore.chatPreferences.fontSize;
    expect(size, greaterThan(18));
    for (final title in [
      "Timestamps",
      "Show deleted messages",
      "Twitch badges",
      "7TV badges",
      "7TV paints",
      "Animated paints",
      "BetterTTV badges",
      "FrankerFaceZ badges",
      "Emote autocomplete",
      "Twitch emotes",
      "7TV emotes",
      "BetterTTV emotes",
      "FrankerFaceZ emotes",
      "Auto claim channel points",
      "Watch streak popups",
      "Highlight first-time chatters",
      "Subscription notices",
      "Announcements",
      "Raid notices",
      "Timeouts and bans",
    ]) {
      final toggle = find.widgetWithText(SwitchListTile, title);
      await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    final reloaded = AppSettingsStore(preferences: preferences);
    await reloaded.load();
    expect(reloaded.chatPreferences.fontSize, size);
    expect(reloaded.chatPreferences.showTimestamps, isTrue);
    expect(reloaded.chatPreferences.showDeletedMessages, isTrue);
    expect(reloaded.chatPreferences.twitchBadges, isFalse);
    expect(reloaded.chatPreferences.sevenTvBadges, isFalse);
    expect(reloaded.chatPreferences.sevenTvPaints, isFalse);
    expect(reloaded.chatPreferences.animatedPaints, isFalse);
    expect(reloaded.chatPreferences.bttvBadges, isFalse);
    expect(reloaded.chatPreferences.ffzBadges, isFalse);
    expect(reloaded.chatPreferences.emoteAutocomplete, isFalse);
    expect(reloaded.chatPreferences.twitchEmotes, isFalse);
    expect(reloaded.chatPreferences.sevenTvEmotes, isFalse);
    expect(reloaded.chatPreferences.bttvEmotes, isFalse);
    expect(reloaded.chatPreferences.ffzEmotes, isFalse);
    expect(reloaded.chatPreferences.autoClaimChannelPoints, isTrue);
    expect(reloaded.chatPreferences.showWatchStreakPopups, isFalse);
    expect(reloaded.chatPreferences.highlightFirstMessages, isFalse);
    expect(reloaded.chatPreferences.showSubscriptionNotices, isFalse);
    expect(reloaded.chatPreferences.showAnnouncements, isFalse);
    expect(reloaded.chatPreferences.showRaidNotices, isFalse);
    expect(reloaded.chatPreferences.showModerationNotices, isFalse);
    expect(find.widgetWithText(SwitchListTile, "Badges"), findsNothing);
    expect(find.widgetWithText(SwitchListTile, "Emotes"), findsNothing);
    expect(find.text("Highlight first messages"), findsNothing);
    final autocomplete = find.widgetWithText(SwitchListTile, "Emote autocomplete");
    await Scrollable.ensureVisible(tester.element(autocomplete), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(autocomplete);
    await tester.pumpAndSettle();
    expect((await preferences.readChatPreferences()).emoteAutocomplete, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets("chat scale and spacing ranges persist and manual delay requires auto-sync off", (
    tester,
  ) async {
    final preferences = MemoryFlowPreferences();
    final store = AppSettingsStore(preferences: preferences);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: store),
      ),
    );
    await tester.pumpAndSettle();
    for (final setting in [
      ("chat_message_scale", 0.5, 2.0, 1.5),
      ("chat_badge_scale", 0.5, 2.0, 0.7),
      ("chat_emote_scale", 0.5, 2.0, 1.8),
      ("chat_message_spacing", 0.0, 16.0, 12.0),
    ]) {
      final finder = find.byKey(ValueKey(setting.$1));
      await tester.scrollUntilVisible(finder, 300);
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(finder);
      expect(slider.min, setting.$2);
      expect(slider.max, setting.$3);
      slider.onChanged!(setting.$4);
      slider.onChangeEnd!(setting.$4);
      await tester.pumpAndSettle();
    }
    final delay = find.byKey(const ValueKey("chat_manual_delay"));
    await tester.scrollUntilVisible(delay, 300);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(delay).onChanged, isNull);
    final automatic = find.widgetWithText(SwitchListTile, "Auto-sync chat");
    await Scrollable.ensureVisible(tester.element(automatic), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(automatic);
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(delay);
    expect(slider.min, 0);
    expect(slider.max, 30);
    slider.onChanged!(17);
    slider.onChangeEnd!(17);
    await tester.pumpAndSettle();
    final restored = await preferences.readChatPreferences();
    expect(restored.messageScale, 1.5);
    expect(restored.badgeScale, 0.7);
    expect(restored.emoteScale, 1.8);
    expect(restored.messageSpacing, 12);
    expect(restored.autoSyncChat, isFalse);
    expect(restored.manualChatDelaySeconds, 17);
    await tester.tap(automatic);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(delay).onChanged, isNull);
    expect((await preferences.readChatPreferences()).manualChatDelaySeconds, 17);
    expect(tester.takeException(), isNull);
  });

  testWidgets("pushed settings shows Back without bottom navigation and returns to its route", (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final store = AppSettingsStore(preferences: MemoryFlowPreferences());
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: SettingsScreen(settingsStore: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.byKey(const ValueKey("settings_back")), findsNothing);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => SettingsScreen(settingsStore: store, showBackButton: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsNothing);
    await tester.tap(find.byKey(const ValueKey("settings_back")));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.byKey(const ValueKey("settings_back")), findsNothing);
  });

  test("failed chat settings writes retain the saved appearance", () async {
    final store = AppSettingsStore(
      preferences: SharedPreferencesFlowPreferences(store: _FailingWritesPreferencesStore()),
    );
    await store.load();
    final previous = store.chatPreferences;
    await expectLater(
      store.setChatPreferences(previous.copyWith(fontSize: 20)),
      throwsStateError,
    );
    expect(store.chatPreferences, same(previous));
  });

  for (final holdThroughDrag in [false, true]) {
    testWidgets("keeps proxy dragging usable after a held tooltip: $holdThroughDrag", (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = MemoryFlowPreferences();
      final settingsStore = AppSettingsStore(preferences: preferences);
      const urls = ["http://first:8080", "http://second:8080", "http://third:8080"];
      await settingsStore.setAdProxyUrls(urls);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.dark),
          home: FlowTabsScreen(
            initialRoute: FlowRoutes.settings,
            showLoginOnLaunch: false,
            settingsStore: settingsStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final handles = find.byIcon(Icons.drag_indicator);
      final start = tester.getCenter(handles.first);
      final end = tester.getCenter(handles.last);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text("Reorder proxy"), findsOneWidget);
      if (holdThroughDrag) {
        await gesture.moveTo(end);
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(settingsStore.adProxyUrls, urls);
        expect(tester.takeException(), isNull);
        await tester.timedDrag(handles.first, end - start, const Duration(milliseconds: 300));
      } else {
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.timedDrag(handles.first, end - start, const Duration(milliseconds: 300));
      }
      await tester.pumpAndSettle();
      expect(settingsStore.adProxyUrls, [urls[1], urls[2], urls[0]]);
      expect(await preferences.readAdProxyUrls(), settingsStore.adProxyUrls);
      expect(tester.takeException(), isNull);

      await tester.longPress(handles.last);
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text("Reorder proxy"), findsOneWidget);
      await tester.timedDrag(handles.last, start - end, const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(settingsStore.adProxyUrls, urls);
      expect(await preferences.readAdProxyUrls(), urls);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("Playback switches save independently and reload their values", (tester) async {
    final preferences = MemoryFlowPreferences();
    final settingsStore = AppSettingsStore(preferences: preferences);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();
    for (final key in ["settings_picture_in_picture_toggle", "settings_mini_player_toggle"]) {
      final toggle = find.byKey(ValueKey(key));
      await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
    }
    final reloaded = AppSettingsStore(preferences: preferences);
    await reloaded.load();
    expect(reloaded.pictureInPictureEnabled, isFalse);
    expect(reloaded.miniPlayerEnabled, isFalse);

    for (final key in ["settings_picture_in_picture_toggle", "settings_mini_player_toggle"]) {
      final toggle = find.byKey(ValueKey(key));
      await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);
    }
    expect(await preferences.readPictureInPictureEnabled(), isTrue);
    expect(await preferences.readMiniPlayerEnabled(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets("blocks overlapping settings edits while saving", (tester) async {
    final preferencesStore = _DelayedWritesPreferencesStore();
    final settingsStore = AppSettingsStore(
      preferences: SharedPreferencesFlowPreferences(store: preferencesStore),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = tester.widget<Switch>(find.byKey(const ValueKey("settings_ad_proxy_toggle")));
    toggle.onChanged!(true);
    toggle.onChanged!(false);
    await tester.pump();

    expect(preferencesStore.writes, 1);
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(
              const ValueKey("settings_content_interaction_gate"),
            ),
          )
          .absorbing,
      isTrue,
    );
    preferencesStore.saved.complete();
    await tester.pumpAndSettle();
    expect(settingsStore.adProxyEnabled, isTrue);
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(
              const ValueKey("settings_content_interaction_gate"),
            ),
          )
          .absorbing,
      isFalse,
    );
  });

  testWidgets("failed saves keep the saved setting and offer useful feedback", (tester) async {
    final settingsStore = AppSettingsStore(
      preferences: SharedPreferencesFlowPreferences(store: _FailingWritesPreferencesStore()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("settings_ad_proxy_toggle")));
    await tester.pumpAndSettle();

    expect(settingsStore.adProxyEnabled, isFalse);
    expect(find.text("Couldn't save settings. Please try again."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test("serializes subscription whitelist updates", () async {
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    await preferences.saveAdProxyWhitelistedChannels(["manual"]);
    final settingsStore = AppSettingsStore(preferences: preferences);
    await settingsStore.load();

    await Future.wait([
      settingsStore.syncAdProxySubscriptionChannel(login: "Alpha", isSubscribed: true),
      settingsStore.syncAdProxySubscriptionChannel(login: "Beta", isSubscribed: true),
    ]);

    expect(settingsStore.adProxySubscriptionChannels, ["alpha", "beta"]);
    expect(settingsStore.adProxyEffectiveWhitelistedChannels, ["manual", "alpha", "beta"]);
    expect(await preferences.readAdProxySubscriptionChannels(), ["alpha", "beta"]);
    expect(await preferences.readAdProxyWhitelistedChannels(), ["manual"]);
  });

  testWidgets("blocks settings interactions until preferences finish loading", (tester) async {
    final preferencesStore = _DelayedPreferencesStore();
    final settingsStore = AppSettingsStore(
      preferences: SharedPreferencesFlowPreferences(store: preferencesStore),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pump();

    final interactionGate = find.byKey(const ValueKey("settings_content_interaction_gate"));
    expect(tester.widget<AbsorbPointer>(interactionGate).absorbing, isTrue);
    await tester.tap(
      find.byKey(const ValueKey("settings_ad_proxy_toggle")),
      warnIfMissed: false,
    );
    expect(settingsStore.adProxyEnabled, isFalse);

    preferencesStore.completeReads();
    await tester.pumpAndSettle();
    expect(tester.widget<AbsorbPointer>(interactionGate).absorbing, isFalse);

    await tester.tap(find.byKey(const ValueKey("settings_ad_proxy_toggle")));
    await tester.pumpAndSettle();
    expect(settingsStore.adProxyEnabled, isTrue);
    expect(await settingsStore.preferences.readAdProxyEnabled(), isTrue);
  });

  testWidgets("offers a retry when settings fail to load", (tester) async {
    final settingsStore = AppSettingsStore(
      preferences: SharedPreferencesFlowPreferences(store: _FailingOncePreferencesStore()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();

    final interactionGate = find.byKey(const ValueKey("settings_content_interaction_gate"));
    expect(tester.widget<AbsorbPointer>(interactionGate).absorbing, isTrue);
    expect(find.byKey(const ValueKey("settings_load_retry")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("settings_load_retry")));
    await tester.pumpAndSettle();

    expect(settingsStore.isLoaded, isTrue);
    expect(tester.widget<AbsorbPointer>(interactionGate).absorbing, isFalse);
  });

  testWidgets("masks proxy credentials while retaining the host and port", (tester) async {
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    final settingsStore = AppSettingsStore(preferences: preferences);
    await settingsStore.setAdProxyUrls(["http://user:password@host:8080"]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("http://host:8080"), findsOneWidget);
    expect(find.textContaining("user"), findsNothing);
    expect(find.textContaining("password"), findsNothing);
  });

  testWidgets("drags proxies in both directions and persists their priority", (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    final settingsStore = AppSettingsStore(preferences: preferences);
    const urls = ["http://first:8080", "http://second:8080", "http://third:8080"];
    await settingsStore.setAdProxyUrls(urls);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_indicator);
    expect(handles, findsNWidgets(3));
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(tester.getCenter(handles.first).dx, tester.getCenter(find.byTooltip("Add Proxies")).dx);
    expect(
      tester.getCenter(handles.first).dx,
      greaterThan(tester.getCenter(find.byTooltip("Remove proxy").first).dx),
    );

    final firstPosition = tester.getCenter(handles.first);
    final lastPosition = tester.getCenter(handles.last);
    await tester.timedDrag(
      handles.first,
      lastPosition - firstPosition,
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(settingsStore.adProxyUrls, [urls[1], urls[2], urls[0]]);
    expect(await preferences.readAdProxyUrls(), [urls[1], urls[2], urls[0]]);
    expect(
      find.descendant(
        of: find.byKey(ValueKey("settings_proxy_${urls[1]}")),
        matching: find.text("Main"),
      ),
      findsOneWidget,
    );

    await tester.timedDrag(
      handles.last,
      firstPosition - lastPosition,
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(settingsStore.adProxyUrls, urls);
    expect(await preferences.readAdProxyUrls(), urls);
    expect(tester.takeException(), isNull);
  });

  testWidgets("allows removing a manual channel that is also subscription-managed", (tester) async {
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    final settingsStore = AppSettingsStore(preferences: preferences);
    await settingsStore.setAdProxyWhitelistedChannels(["Creator"]);
    await settingsStore.syncAdProxySubscriptionChannel(login: "Creator", isSubscribed: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();

    final removeChannel = find.byTooltip("Remove channel");
    await tester.ensureVisible(removeChannel);
    expect(removeChannel, findsOneWidget);

    await tester.tap(removeChannel);
    await tester.pumpAndSettle();

    expect(settingsStore.adProxyWhitelistedChannels, isEmpty);
    expect(settingsStore.adProxyEffectiveWhitelistedChannels, ["creator"]);
    expect(find.byTooltip("Managed automatically"), findsOneWidget);
  });

  testWidgets("adds and cancels proxy and whitelist dialogs without errors", (tester) async {
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    final settingsStore = AppSettingsStore(preferences: preferences);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Add Proxies"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, "Cancel"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip("Add Proxies"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "http://proxy.example:8080");
    await tester.tap(find.widgetWithText(FilledButton, "Add"));
    await tester.pumpAndSettle();
    expect(settingsStore.adProxyUrls, ["http://proxy.example:8080"]);
    expect(tester.takeException(), isNull);

    final addChannel = find.byTooltip("Add Whitelisted channels");
    await tester.ensureVisible(addChannel);
    await tester.tap(addChannel);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, "Cancel"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(addChannel);
    await tester.tap(addChannel);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "creator");
    await tester.tap(find.widgetWithText(FilledButton, "Add"));
    await tester.pumpAndSettle();
    expect(settingsStore.adProxyWhitelistedChannels, ["creator"]);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryPreferencesStore implements FlowPreferencesStore {
  final strings = <String, String>{};
  final stringLists = <String, List<String>>{};

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<List<String>?> getStringList(String key) async => stringLists[key];

  @override
  Future<void> remove(String key) async {
    strings.remove(key);
    stringLists.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async => strings[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      stringLists[key] = List.of(value);
}

class _FailingWritesPreferencesStore extends _MemoryPreferencesStore {
  @override
  Future<void> setString(String key, String value) async => throw StateError("write failed");

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      throw StateError("write failed");
}

class _DelayedWritesPreferencesStore extends _MemoryPreferencesStore {
  final saved = Completer<void>();
  int writes = 0;

  @override
  Future<void> setString(String key, String value) async {
    writes++;
    await saved.future;
    await super.setString(key, value);
  }
}

class _DelayedPreferencesStore extends _MemoryPreferencesStore {
  final _readsCompleted = Completer<void>();

  void completeReads() => _readsCompleted.complete();

  @override
  Future<String?> getString(String key) async {
    await _readsCompleted.future;
    return super.getString(key);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    await _readsCompleted.future;
    return super.getStringList(key);
  }
}

class _FailingOncePreferencesStore extends _MemoryPreferencesStore {
  bool _hasFailed = false;

  @override
  Future<String?> getString(String key) {
    if (!_hasFailed && key == SharedPreferencesFlowPreferences.adProxyEnabledKey) {
      _hasFailed = true;
      return Future<String?>.error(StateError("read failed"));
    }
    return super.getString(key);
  }
}
