import "package:flow/app/spacing.dart";
import "package:flutter/material.dart";

abstract final class PageHeaderLayout {
  static const headerContentGap = 11.5;
  static const largeTitleContentTopPadding = 92.0;
  static const largeTitleRefreshIndicatorStartTop = 64.0;
  static const backButtonContentTopPadding = 76.0;
  static const backButtonRefreshIndicatorStartTop = 52.0;
  static const searchFieldHeight = 48.0;
  static const searchContentTopPadding = 75.5;
  static const settingsContentTopPadding = 80.0;
  static const bottomNavigationScrollPadding = 114.0;

  static const largeTitleTopBarPadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg + 0.5,
  );

  static const backButtonTopBarPadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg + 0.5,
  );

  static const settingsTopBarPadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.xl + 0.5,
  );

  static EdgeInsets scrollPadding({
    required double top,
    double horizontal = AppSpacing.lg,
    double bottom = 0,
  }) => EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}
