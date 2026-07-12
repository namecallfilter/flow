import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:mobx/mobx.dart";

part "app_settings_store.g.dart";

class AppSettingsStore = AppSettingsStoreBase with _$AppSettingsStore;

abstract class AppSettingsStoreBase with Store {
  AppSettingsStoreBase({required this.preferences});

  final FlowPreferences preferences;

  @observable
  ThemeMode themeMode = ThemeMode.system;

  @observable
  bool adProxyEnabled = false;

  @observable
  ObservableList<String> adProxyUrls = ObservableList<String>();

  @observable
  ObservableList<String> adProxyWhitelistedChannels = ObservableList<String>();

  @observable
  ObservableList<String> adProxySubscriptionChannels = ObservableList<String>();

  @computed
  List<String> get adProxyEffectiveWhitelistedChannels => normalizeChannelLogins([
    ...adProxyWhitelistedChannels,
    ...adProxySubscriptionChannels,
  ]);

  @observable
  bool isLoaded = false;

  @action
  Future<void> load() async {
    final values = await Future.wait<Object>([
      preferences.readThemeMode(),
      preferences.readAdProxyEnabled(),
      preferences.readAdProxyUrls(),
      preferences.readAdProxyWhitelistedChannels(),
      preferences.readAdProxySubscriptionChannels(),
    ]);
    themeMode = values[0] as ThemeMode;
    adProxyEnabled = values[1] as bool;
    adProxyUrls = ObservableList.of(values[2] as List<String>);
    adProxyWhitelistedChannels = ObservableList.of(values[3] as List<String>);
    adProxySubscriptionChannels = ObservableList.of(values[4] as List<String>);
    isLoaded = true;
  }

  @action
  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) {
      return;
    }

    themeMode = mode;
    await preferences.saveThemeMode(mode);
  }

  @action
  Future<void> setAdProxyEnabled({required bool enabled}) async {
    adProxyEnabled = enabled;
    await preferences.saveAdProxyEnabled(enabled: enabled);
  }

  @action
  Future<void> setAdProxyUrls(List<String> urls) async {
    adProxyUrls = ObservableList.of(normalizeAdProxyUrls(urls));
    await preferences.saveAdProxyUrls(adProxyUrls);
  }

  @action
  Future<void> setAdProxyWhitelistedChannels(List<String> channels) async {
    adProxyWhitelistedChannels = ObservableList.of(normalizeChannelLogins(channels));
    await preferences.saveAdProxyWhitelistedChannels(adProxyWhitelistedChannels);
  }
}
