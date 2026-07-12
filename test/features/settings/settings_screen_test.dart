import "package:flow/app/app_settings_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
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
