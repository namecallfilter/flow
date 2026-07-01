import "package:flow/app/app_settings_store.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("loads saved theme mode and persists changes", () async {
    final preferences = _MemoryFlowPreferences(themeMode: ThemeMode.light);
    final store = AppSettingsStore(preferences: preferences);

    expect(store.themeMode, ThemeMode.system);

    await store.load();

    expect(store.themeMode, ThemeMode.light);

    await store.setThemeMode(ThemeMode.dark);

    expect(store.themeMode, ThemeMode.dark);
    expect(preferences.themeMode, ThemeMode.dark);
  });
}

class _MemoryFlowPreferences implements FlowPreferences {
  _MemoryFlowPreferences({this.themeMode = ThemeMode.system});

  ThemeMode themeMode;

  @override
  Future<void> clearBrowseSearchHistory() async {}

  @override
  Future<List<String>> readBrowseSearchHistory() async => const <String>[];

  @override
  Future<ThemeMode> readThemeMode() async => themeMode;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeMode = mode;
  }
}
