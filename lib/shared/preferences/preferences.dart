import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

abstract interface class FlowPreferences {
  Future<ThemeMode> readThemeMode();
  Future<void> saveThemeMode(ThemeMode mode);
  Future<bool> readAdProxyEnabled();
  Future<void> saveAdProxyEnabled({required bool enabled});
  Future<List<String>> readAdProxyUrls();
  Future<void> saveAdProxyUrls(List<String> urls);
  Future<List<String>> readAdProxyWhitelistedChannels();
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels);
  Future<List<String>> readAdProxySubscriptionChannels();
  Future<void> saveAdProxySubscriptionChannels(List<String> channels);
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
  static const adProxyEnabledKey = "ad_proxy_enabled";
  static const adProxyUrlsKey = "ad_proxy_urls";
  static const adProxyWhitelistedChannelsKey = "ad_proxy_whitelisted_channels";
  static const adProxySubscriptionChannelsKey = "ad_proxy_subscription_channels";
  static const browseSearchHistoryKey = "browse_search_history";

  final FlowPreferencesStore _store;

  @override
  Future<bool> readAdProxyEnabled() async => await _store.getString(adProxyEnabledKey) == "true";

  @override
  Future<List<String>> readAdProxyUrls() async =>
      normalizeAdProxyUrls(await _store.getStringList(adProxyUrlsKey) ?? const []);

  @override
  Future<List<String>> readAdProxyWhitelistedChannels() async => normalizeChannelLogins(
    await _store.getStringList(adProxyWhitelistedChannelsKey) ?? const [],
  );

  @override
  Future<List<String>> readAdProxySubscriptionChannels() async => normalizeChannelLogins(
    await _store.getStringList(adProxySubscriptionChannelsKey) ?? const [],
  );

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
  Future<void> saveAdProxyEnabled({required bool enabled}) =>
      _store.setString(adProxyEnabledKey, enabled.toString());

  @override
  Future<void> saveAdProxyUrls(List<String> urls) =>
      _store.setStringList(adProxyUrlsKey, normalizeAdProxyUrls(urls));

  @override
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels) => _store.setStringList(
    adProxyWhitelistedChannelsKey,
    normalizeChannelLogins(channels),
  );

  @override
  Future<void> saveAdProxySubscriptionChannels(List<String> channels) => _store.setStringList(
    adProxySubscriptionChannelsKey,
    normalizeChannelLogins(channels),
  );

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

List<String> normalizeAdProxyUrls(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final rawValue in values)
      if (normalizeAdProxyUrl(rawValue) case final value?)
        if (seen.add(value.toLowerCase())) value,
  ];
}

String? normalizeAdProxyUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  final hasEmptyUsername =
      uri != null &&
      uri.authority.contains("@") &&
      (uri.userInfo.isEmpty || uri.userInfo.split(":").first.isEmpty);
  if (uri == null ||
      uri.scheme.toLowerCase() != "http" ||
      uri.host.isEmpty ||
      hasEmptyUsername ||
      uri.path.isNotEmpty && uri.path != "/" ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final port = uri.hasPort ? uri.port : 80;
  if (port < 1 || port > 65535) {
    return null;
  }
  return uri.replace(scheme: "http", path: "").toString();
}

List<String> normalizeChannelLogins(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final rawValue in values)
      if (rawValue.trim().toLowerCase() case final value)
        if (RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(value) && seen.add(value)) value,
  ];
}
