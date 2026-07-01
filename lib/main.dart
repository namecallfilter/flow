import "package:flow/app/app.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = SharedPreferencesFlowPreferences();
  final settingsStore = AppSettingsStore(preferences: preferences);
  await settingsStore.load();
  runApp(
    FlowApp(
      preferences: preferences,
      settingsStore: settingsStore,
    ),
  );
}
