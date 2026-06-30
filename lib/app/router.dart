import "package:flow/app/flow_tabs_screen.dart";
import "package:flow/app/routes.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flutter/material.dart";

abstract final class FlowRouter {
  static Route<void> onGenerateRoute(
    RouteSettings settings, {
    ThemeMode currentThemeMode = ThemeMode.system,
    ValueChanged<ThemeMode>? onThemeModeChanged,
    ExternalUrlOpener? openExternalUrl,
  }) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => FlowTabsScreen(
      initialRoute: settings.name ?? FlowRoutes.following,
      currentThemeMode: currentThemeMode,
      onThemeModeChanged: onThemeModeChanged,
      openExternalUrl: openExternalUrl,
    ),
  );
}
