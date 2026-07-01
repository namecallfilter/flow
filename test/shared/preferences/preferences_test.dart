import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("stores theme mode as a non-sensitive preference", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);

    expect(await preferences.readThemeMode(), ThemeMode.system);

    await preferences.saveThemeMode(ThemeMode.dark);

    expect(store.strings["flow_theme_mode"], "dark");
    expect(await preferences.readThemeMode(), ThemeMode.dark);
  });

  test("normalizes browse search history in shared preferences", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);

    await preferences.saveBrowseSearchHistory([
      " mine ",
      "Mine",
      "",
      "VALORANT",
      "just chatting",
      "apex",
      "Dota",
      "counter-strike",
      "retro",
      "music",
    ]);

    expect(await preferences.readBrowseSearchHistory(), [
      "mine",
      "VALORANT",
      "just chatting",
      "apex",
      "Dota",
      "counter-strike",
      "retro",
      "music",
    ]);

    await preferences.clearBrowseSearchHistory();

    expect(await preferences.readBrowseSearchHistory(), isEmpty);
  });
}

class _MemoryPreferencesStore implements FlowPreferencesStore {
  final strings = <String, String>{};
  final stringLists = <String, List<String>>{};

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<List<String>?> getStringList(String key) async {
    final value = stringLists[key];
    return value == null ? null : List<String>.of(value);
  }

  @override
  Future<void> remove(String key) async {
    strings.remove(key);
    stringLists.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    strings[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    stringLists[key] = List<String>.of(value);
  }
}
