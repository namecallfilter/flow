import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

abstract interface class FlowPreferences {
  Future<ThemeMode> readThemeMode();
  Future<void> saveThemeMode(ThemeMode mode);
  Future<List<String>> readBrowseSearchHistory();
  Future<void> saveBrowseSearchHistory(List<String> history);
  Future<void> clearBrowseSearchHistory();
}

abstract interface class FlowPreferencesStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

class SharedPreferencesFlowPreferences implements FlowPreferences {
  SharedPreferencesFlowPreferences({
    FlowPreferencesStore? store,
  }) : _store = store ?? SharedPreferencesAsyncFlowPreferencesStore();

  static const themeModeKey = "flow_theme_mode";
  static const browseSearchHistoryKey = "browse_search_history";

  final FlowPreferencesStore _store;

  @override
  Future<void> clearBrowseSearchHistory() => _store.remove(browseSearchHistoryKey);

  @override
  Future<List<String>> readBrowseSearchHistory() async {
    final history = await _store.getStringList(browseSearchHistoryKey);
    return normalizeBrowseSearchHistory(history ?? const <String>[]);
  }

  @override
  Future<ThemeMode> readThemeMode() async {
    final value = await _store.getString(themeModeKey);
    return themeModeFromPreference(value);
  }

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    final normalizedHistory = normalizeBrowseSearchHistory(history);
    if (normalizedHistory.isEmpty) {
      await clearBrowseSearchHistory();
      return;
    }

    await _store.setStringList(browseSearchHistoryKey, normalizedHistory);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) =>
      _store.setString(themeModeKey, themeModePreferenceValue(mode));
}

class SharedPreferencesAsyncFlowPreferencesStore implements FlowPreferencesStore {
  SharedPreferencesAsyncFlowPreferencesStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<List<String>?> getStringList(String key) => _preferences.getStringList(key);

  @override
  Future<void> remove(String key) => _preferences.remove(key);

  @override
  Future<void> setString(String key, String value) => _preferences.setString(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _preferences.setStringList(key, value);
}

ThemeMode themeModeFromPreference(String? value) => switch (value) {
  "light" => ThemeMode.light,
  "dark" => ThemeMode.dark,
  _ => ThemeMode.system,
};

String themeModePreferenceValue(ThemeMode mode) => switch (mode) {
  ThemeMode.light => "light",
  ThemeMode.dark => "dark",
  ThemeMode.system => "system",
};

List<String> normalizeBrowseSearchHistory(Iterable<String> values) {
  final seen = <String>{};
  final history = <String>[];
  for (final rawValue in values) {
    final value = rawValue.trim();
    if (value.isEmpty || !seen.add(value.toLowerCase())) {
      continue;
    }
    history.add(value);
    if (history.length == 8) {
      break;
    }
  }
  return history;
}
