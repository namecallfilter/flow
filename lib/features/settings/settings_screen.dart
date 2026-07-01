import "dart:async";
import "dart:ui";

import "package:flow/app/app_settings_store.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/page_header_title.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_mobx/flutter_mobx.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.bottomNavigationBar,
    this.currentThemeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.openExternalUrl,
    this.settingsStore,
  });

  final Widget? bottomNavigationBar;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ExternalUrlOpener? openExternalUrl;
  final AppSettingsStore? settingsStore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Widget?>("bottomNavigationBar", bottomNavigationBar));
    properties.add(EnumProperty<ThemeMode>("currentThemeMode", currentThemeMode));
    properties.add(
      ObjectFlagProperty<ValueChanged<ThemeMode>?>.has(
        "onThemeModeChanged",
        onThemeModeChanged,
      ),
    );
    properties.add(
      ObjectFlagProperty<ExternalUrlOpener?>.has(
        "openExternalUrl",
        openExternalUrl,
      ),
    );
    properties.add(DiagnosticsProperty<AppSettingsStore?>("settingsStore", settingsStore));
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppSettingsStore _settingsStore;

  @override
  void initState() {
    super.initState();
    _settingsStore =
        widget.settingsStore ??
        AppSettingsStore(
          preferences: _MemoryFlowPreferences(themeMode: widget.currentThemeMode),
        );
    if (!_settingsStore.isLoaded) {
      unawaited(_settingsStore.load());
    }
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    await _settingsStore.setThemeMode(themeMode);
    widget.onThemeModeChanged?.call(themeMode);
  }

  Future<void> _openRepository(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opener = widget.openExternalUrl ?? ExternalUrlLauncher.open;

    try {
      await opener(FlowLinks.repository);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      const topScrollPadding = 80.0;
      const bottomScrollPadding = 114.0;

      return Scaffold(
        extendBody: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar:
            widget.bottomNavigationBar ?? const AppBottomNav(currentRoute: FlowRoutes.settings),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  topScrollPadding,
                  AppSpacing.lg,
                  0,
                ).copyWith(bottom: bottomScrollPadding),
                children: [
                  _SettingsGroup(
                    children: [
                      _ThemeModeRow(
                        currentThemeMode: _settingsStore.themeMode,
                        onThemeModeChanged: (themeMode) {
                          unawaited(_changeThemeMode(themeMode));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.info_outline,
                        title: "About Flow",
                        subtitle: "Mobile Twitch client.",
                        trailing: const Text("1.0.0"),
                        onTap: () {
                          unawaited(_openRepository(context));
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SettingsTopBar(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerSurface = theme.scaffoldBackgroundColor;
    final topAlpha = theme.brightness == Brightness.dark ? 0.92 : 0.94;
    final bottomAlpha = theme.brightness == Brightness.dark ? 0.30 : 0.42;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                headerSurface.withValues(alpha: topAlpha),
                headerSurface.withValues(alpha: bottomAlpha),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: const PageHeaderTitle(
            key: ValueKey("settings_title"),
            title: "Settings",
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.14 : 0.42,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<Widget>("children", children));
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _SettingsIcon(icon: icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              DefaultTextStyle(
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
                child: IconTheme(
                  data: IconThemeData(color: mutedColor, size: 22),
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>("icon", icon));
    properties.add(StringProperty("title", title));
    properties.add(StringProperty("subtitle", subtitle));
    properties.add(DiagnosticsProperty<Widget?>("trailing", trailing));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onTap", onTap));
  }
}

class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );
    final themeIcon = _themeModeIcon(
      currentThemeMode,
      theme.brightness,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SettingsIcon(icon: themeIcon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Theme",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Choose how Flow looks.",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<ThemeMode>(
              key: const ValueKey("settings_theme_control"),
              groupValue: currentThemeMode,
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
              thumbColor: theme.colorScheme.primary.withValues(alpha: 0.34),
              onValueChanged: (themeMode) {
                if (themeMode != null) {
                  onThemeModeChanged?.call(themeMode);
                }
              },
              children: <ThemeMode, Widget>{
                ThemeMode.light: Padding(
                  key: const ValueKey("settings_theme_light"),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("Light", style: labelStyle),
                ),
                ThemeMode.dark: Padding(
                  key: const ValueKey("settings_theme_dark"),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("Dark", style: labelStyle),
                ),
                ThemeMode.system: Padding(
                  key: const ValueKey("settings_theme_system"),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("System", style: labelStyle),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ThemeMode>("currentThemeMode", currentThemeMode));
    properties.add(
      ObjectFlagProperty<ValueChanged<ThemeMode>?>.has(
        "onThemeModeChanged",
        onThemeModeChanged,
      ),
    );
  }
}

IconData _themeModeIcon(
  ThemeMode themeMode,
  Brightness effectiveBrightness,
) => switch (themeMode) {
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
  ThemeMode.system =>
    effectiveBrightness == Brightness.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
};

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        icon,
        color: theme.colorScheme.primary.withValues(alpha: 0.9),
        size: 20,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>("icon", icon));
  }
}

class _MemoryFlowPreferences implements FlowPreferences {
  _MemoryFlowPreferences({required this.themeMode});

  ThemeMode themeMode;
  List<String> searchHistory = const <String>[];

  @override
  Future<void> clearBrowseSearchHistory() async {
    searchHistory = const <String>[];
  }

  @override
  Future<List<String>> readBrowseSearchHistory() async => searchHistory;

  @override
  Future<ThemeMode> readThemeMode() async => themeMode;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    searchHistory = List<String>.of(history);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeMode = mode;
  }
}
