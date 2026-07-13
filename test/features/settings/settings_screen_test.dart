import "dart:async";

import "package:flow/app/app_settings_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("shares preference reads between concurrent settings loads", () async {
    final preferencesStore = _DelayedPreferencesStore();
    final settingsStore = AppSettingsStore(
      preferences: SharedPreferencesFlowPreferences(store: preferencesStore),
    );

    final firstLoad = settingsStore.load();
    final secondLoad = settingsStore.load();
    await Future<void>.delayed(Duration.zero);

    expect(preferencesStore.readCount, 5);
    preferencesStore.completeReads();
    await Future.wait([firstLoad, secondLoad]);

    expect(settingsStore.isLoaded, isTrue);
    expect(preferencesStore.readCount, 5);
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

  testWidgets("uses the Settings header spacing", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    _expectVisibleHeaderGap(
      tester,
      header: find.ancestor(
        of: find.byKey(const ValueKey("settings_title")),
        matching: find.byType(ClipRect),
      ),
      content: find.byKey(const ValueKey("settings_theme_group")),
    );
  });

  testWidgets("persists the ad proxy toggle", (tester) async {
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    final settingsStore = AppSettingsStore(preferences: preferences);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("settings_ad_proxy_toggle")));
    await tester.pumpAndSettle();

    expect(settingsStore.adProxyEnabled, isTrue);
    expect(await preferences.readAdProxyEnabled(), isTrue);
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

  testWidgets("shows subscription whitelist updates without reloading settings", (tester) async {
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    final settingsStore = AppSettingsStore(preferences: preferences);
    await settingsStore.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: SettingsScreen(settingsStore: settingsStore),
      ),
    );
    await tester.pumpAndSettle();

    await settingsStore.syncAdProxySubscriptionChannel(
      login: "Creator",
      isSubscribed: true,
    );
    await tester.pump();

    expect(find.text("creator"), findsOneWidget);
    expect(find.text("Subscribed channel"), findsOneWidget);
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

void _expectVisibleHeaderGap(
  WidgetTester tester, {
  required Finder header,
  required Finder content,
}) {
  final headerBottom = tester.getBottomLeft(header).dy;
  final contentTop = tester.getTopLeft(content).dy;

  expect(contentTop - headerBottom, closeTo(PageHeaderLayout.headerContentGap, 0.1));
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

class _DelayedPreferencesStore extends _MemoryPreferencesStore {
  final _readsCompleted = Completer<void>();
  int readCount = 0;

  void completeReads() => _readsCompleted.complete();

  @override
  Future<String?> getString(String key) async {
    readCount++;
    await _readsCompleted.future;
    return super.getString(key);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    readCount++;
    await _readsCompleted.future;
    return super.getStringList(key);
  }
}
