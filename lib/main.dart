import "package:flow/app/app.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = SharedPreferencesFlowPreferences();
  final settingsStore = AppSettingsStore(preferences: preferences);
  try {
    await settingsStore.load();
  } on Object {
    debugPrint("Couldn't load saved settings. Settings can be retried in the app.");
  }
  runApp(
    FlowApp(
      preferences: preferences,
      settingsStore: settingsStore,
    ),
  );
}
