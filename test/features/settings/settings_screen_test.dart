import "dart:async";

import "package:flow/app/app_settings_store.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/tabs_screen.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
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
