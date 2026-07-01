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
  bool isLoaded = false;

  @action
  Future<void> load() async {
    themeMode = await preferences.readThemeMode();
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
}
