import "dart:async";

import "package:flow/app/app_settings_store.dart";
import "package:flow/app/tabs_screen.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/player_navigation.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_mobx/flutter_mobx.dart";
import "package:mobx/mobx.dart";

class FlowApp extends StatefulWidget {
  const FlowApp({
    super.key,
    this.openExternalUrl,
    this.preferences,
    this.settingsStore,
  });

  final ExternalUrlOpener? openExternalUrl;
  final FlowPreferences? preferences;
  final AppSettingsStore? settingsStore;

  @override
  State<FlowApp> createState() => _FlowAppState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<ExternalUrlOpener?>.has(
        "openExternalUrl",
        openExternalUrl,
      ),
    );
    properties.add(DiagnosticsProperty<FlowPreferences?>("preferences", preferences));
    properties.add(DiagnosticsProperty<AppSettingsStore?>("settingsStore", settingsStore));
  }
}

class _FlowAppState extends State<FlowApp> {
  final _playbackHost = PlaybackHost();
  late final FlowPreferences _preferences;
  late final AppSettingsStore _settingsStore;
  late final ReactionDisposer _playbackSettingsReaction;

  @override
  void initState() {
    super.initState();
    _preferences =
        widget.preferences ??
        widget.settingsStore?.preferences ??
        SharedPreferencesFlowPreferences();
    _settingsStore = widget.settingsStore ?? AppSettingsStore(preferences: _preferences);
    _playbackSettingsReaction = reaction<bool>(
      (_) => _settingsStore.miniPlayerEnabled,
      (enabled) => _playbackHost.setMiniPlayerEnabled(enabled: enabled),
      fireImmediately: true,
    );
    if (!_settingsStore.isLoaded) {
      unawaited(
        _settingsStore.load().catchError((Object error) {
          debugPrint("Couldn't load settings: $error");
        }),
      );
    }
  }

  @override
  void dispose() {
    _playbackSettingsReaction();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) => AppSettingsScope(
      settingsStore: _settingsStore,
      child: MaterialApp(
        navigatorObservers: [_playbackHost],
        title: "Flow",
        debugShowCheckedModeBanner: false,
        theme: buildFlowTheme(Brightness.light),
        darkTheme: buildFlowTheme(Brightness.dark),
        themeMode: _settingsStore.themeMode,
        home: FlowTabsScreen(
          preferences: _preferences,
          settingsStore: _settingsStore,
          openExternalUrl: widget.openExternalUrl,
        ),
      ),
    ),
  );
}
