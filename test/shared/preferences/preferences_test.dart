import "package:flow/shared/preferences/preferences.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
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

  test("stores only ordered HTTP proxy URLs and valid channel logins", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);

    await preferences.saveAdProxyEnabled(enabled: true);
    await preferences.saveAdProxyUrls([
      " http://main.example:8080 ",
      "https://not-http.example",
      "http://fallback.example:3128/",
      "HTTP://MAIN.EXAMPLE:8080",
      "http://proxy.example/path",
      "http://proxy.example:99999",
      "http://:password@proxy.example:8080",
    ]);
    await preferences.saveAdProxyWhitelistedChannels([
      " Creator ",
      "creator",
      "other_channel",
      "invalid-channel",
    ]);

    expect(await preferences.readAdProxyEnabled(), isTrue);
    expect(await preferences.readAdProxyUrls(), [
      "http://main.example:8080",
      "http://fallback.example:3128",
    ]);
    expect(await preferences.readAdProxyWhitelistedChannels(), ["creator", "other_channel"]);
  });

  test("persists dismissal of the startup login offer", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);

    expect(await preferences.readLoginOfferDismissed(), isFalse);

    await preferences.saveLoginOfferDismissed(dismissed: true);

    expect(
      await SharedPreferencesFlowPreferences(store: store).readLoginOfferDismissed(),
      isTrue,
    );
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
