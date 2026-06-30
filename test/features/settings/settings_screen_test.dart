import "package:flow/app/app.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("changes the app theme from settings", (tester) async {
    await tester.pumpWidget(const FlowApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.system);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("settings_theme_dark")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.dark);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(_settingsBrightness(tester), Brightness.dark);

    await tester.tap(find.byKey(const ValueKey("settings_theme_light")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.light);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(_settingsBrightness(tester), Brightness.light);

    await tester.tap(find.byKey(const ValueKey("settings_theme_system")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.system);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets("system theme icon follows the platform brightness", (tester) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    await tester.pumpWidget(const FlowApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.system);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
  });

  testWidgets("opens the Flow repository from about", (tester) async {
    Uri? openedUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          onThemeModeChanged: (_) {},
          openExternalUrl: (uri) async {
            openedUrl = uri;
          },
        ),
      ),
    );

    await tester.tap(find.text("About Flow"));
    await tester.pump();

    expect(openedUrl, Uri.parse("https://github.com/namecallfilter/flow"));
  });
}

CupertinoSlidingSegmentedControl<ThemeMode> _themeControl(WidgetTester tester) =>
    tester.widget<CupertinoSlidingSegmentedControl<ThemeMode>>(
      find.byKey(const ValueKey("settings_theme_control")),
    );

Brightness _settingsBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(const ValueKey("settings_title")))).brightness;
