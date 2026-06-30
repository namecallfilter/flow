import "package:flow/app/flow_tabs_screen.dart";
import "package:flow/app/theme.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class FlowApp extends StatefulWidget {
  const FlowApp({super.key, this.openExternalUrl});

  final ExternalUrlOpener? openExternalUrl;

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
  }
}

class _FlowAppState extends State<FlowApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode themeMode) {
    if (themeMode == _themeMode) {
      return;
    }

    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "Flow",
    debugShowCheckedModeBanner: false,
    theme: buildFlowTheme(Brightness.light),
    darkTheme: buildFlowTheme(Brightness.dark),
    themeMode: _themeMode,
    home: FlowTabsScreen(
      currentThemeMode: _themeMode,
      onThemeModeChanged: _setThemeMode,
      openExternalUrl: widget.openExternalUrl,
    ),
  );
}
