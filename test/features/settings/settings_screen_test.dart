import "package:flow/app/app.dart";
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

    await tester.tap(find.byKey(const ValueKey("settings_theme_dark")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.dark);
    expect(_settingsBrightness(tester), Brightness.dark);

    await tester.tap(find.byKey(const ValueKey("settings_theme_light")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.light);
    expect(_settingsBrightness(tester), Brightness.light);

    await tester.tap(find.byKey(const ValueKey("settings_theme_system")));
    await tester.pumpAndSettle();

    expect(_themeControl(tester).groupValue, ThemeMode.system);
  });
}

CupertinoSlidingSegmentedControl<ThemeMode> _themeControl(WidgetTester tester) =>
    tester.widget<CupertinoSlidingSegmentedControl<ThemeMode>>(
      find.byKey(const ValueKey("settings_theme_control")),
    );

Brightness _settingsBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(const ValueKey("settings_title")))).brightness;
