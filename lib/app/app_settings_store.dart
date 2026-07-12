import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mobx/mobx.dart";

part "app_settings_store.g.dart";

class AppSettingsStore = AppSettingsStoreBase with _$AppSettingsStore;

class AppSettingsScope extends InheritedWidget {
  const AppSettingsScope({required this.settingsStore, required super.child, super.key});

  final AppSettingsStore settingsStore;

  static AppSettingsStore? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppSettingsScope>()?.settingsStore;

  @override
  bool updateShouldNotify(AppSettingsScope oldWidget) => settingsStore != oldWidget.settingsStore;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AppSettingsStore>("settingsStore", settingsStore));
  }
}

abstract class AppSettingsStoreBase with Store {
  AppSettingsStoreBase({required this.preferences});

  final FlowPreferences preferences;
  Future<void> _adProxySubscriptionUpdateTail = Future<void>.value();

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
    final subscriptionLoad = _enqueueAdProxySubscriptionUpdate(() async {
      final channels = await preferences.readAdProxySubscriptionChannels();
      runInAction(
        () => adProxySubscriptionChannels = ObservableList.of(channels),
      );
    });
    final values = await Future.wait<Object>([
      preferences.readThemeMode(),
      preferences.readAdProxyEnabled(),
      preferences.readAdProxyUrls(),
      preferences.readAdProxyWhitelistedChannels(),
    ]);
    themeMode = values[0] as ThemeMode;
    adProxyEnabled = values[1] as bool;
    adProxyUrls = ObservableList.of(values[2] as List<String>);
    adProxyWhitelistedChannels = ObservableList.of(values[3] as List<String>);
    await subscriptionLoad;
    isLoaded = true;
  }

  Future<void> syncAdProxySubscriptionChannel({
    required String login,
    required bool isSubscribed,
  }) {
    final normalized = normalizeChannelLogins([login]);
    if (normalized.isEmpty) {
      return Future<void>.value();
    }
    final normalizedLogin = normalized.single;
    return _enqueueAdProxySubscriptionUpdate(() async {
      final channels = adProxySubscriptionChannels.toList();
      final containsChannel = channels.contains(normalizedLogin);
      if (isSubscribed == containsChannel) {
        runInAction(
          () => adProxySubscriptionChannels = ObservableList.of(channels),
        );
        return;
      }
      final nextChannels = isSubscribed
          ? [...channels, normalizedLogin]
          : (channels..remove(normalizedLogin));
      final normalizedChannels = normalizeChannelLogins(nextChannels);
      await preferences.saveAdProxySubscriptionChannels(normalizedChannels);
      runInAction(
        () => adProxySubscriptionChannels = ObservableList.of(normalizedChannels),
      );
    });
  }

  Future<void> _enqueueAdProxySubscriptionUpdate(Future<void> Function() update) {
    final result = _adProxySubscriptionUpdateTail.then((_) => update());
    _adProxySubscriptionUpdateTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
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
