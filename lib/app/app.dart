import "dart:async";

import "package:flow/app/app_settings_store.dart";
import "package:flow/app/tabs_screen.dart";
import "package:flow/app/theme.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_mobx/flutter_mobx.dart";

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
  late final FlowPreferences _preferences;
  late final AppSettingsStore _settingsStore;

  @override
  void initState() {
    super.initState();
    _preferences =
        widget.preferences ??
        widget.settingsStore?.preferences ??
        SharedPreferencesFlowPreferences();
    _settingsStore = widget.settingsStore ?? AppSettingsStore(preferences: _preferences);
    if (!_settingsStore.isLoaded) {
      unawaited(_settingsStore.load());
    }
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) => MaterialApp(
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
  );
}
