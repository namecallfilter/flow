import "package:flow/app/theme.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  for (final brightness in Brightness.values) {
    test("uses visible snackbar foregrounds in ${brightness.name} mode", () {
      final theme = buildFlowTheme(brightness);

      expect(theme.snackBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
      expect(
        theme.snackBarTheme.contentTextStyle?.color,
        theme.colorScheme.onSurface,
      );
      expect(theme.snackBarTheme.closeIconColor, theme.colorScheme.onSurface);
    });
  }
}
