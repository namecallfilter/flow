import "dart:async";
import "dart:ui";

import "package:flow/app/app_settings_store.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
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

  Future<String?> _promptForValue({
    required String title,
    required String hint,
    required String? Function(String value) validator,
  }) {
    var inputValue = "";
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: hint, errorText: errorText),
            onChanged: (value) {
              inputValue = value;
              if (errorText != null) {
                setDialogState(() => errorText = null);
              }
            },
            onSubmitted: (value) {
              final error = validator(value);
              if (error == null) {
                Navigator.of(context).pop(value);
              } else {
                setDialogState(() => errorText = error);
              }
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                final error = validator(inputValue);
                if (error == null) {
                  Navigator.of(context).pop(inputValue);
                } else {
                  setDialogState(() => errorText = error);
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProxyUrl() async {
    final value = await _promptForValue(
      title: "Add HTTP proxy",
      hint: "http://host:port",
      validator: (value) {
        final normalized = normalizeAdProxyUrl(value);
        if (normalized == null) {
          return "Enter an HTTP proxy URL without a path.";
        }
        if (_settingsStore.adProxyUrls.contains(normalized)) {
          return "That proxy is already in the list.";
        }
        return null;
      },
    );
    final normalized = value == null ? null : normalizeAdProxyUrl(value);
    if (normalized != null) {
      await _settingsStore.setAdProxyUrls([..._settingsStore.adProxyUrls, normalized]);
    }
  }

  Future<void> _addWhitelistedChannel() async {
    final value = await _promptForValue(
      title: "Whitelist channel",
      hint: "channel_login",
      validator: (value) {
        final normalized = normalizeChannelLogins([value]);
        if (normalized.isEmpty) {
          return "Enter a valid Twitch channel login.";
        }
        if (_settingsStore.adProxyEffectiveWhitelistedChannels.contains(normalized.single)) {
          return "That channel is already whitelisted.";
        }
        return null;
      },
    );
    final normalized = value == null ? const <String>[] : normalizeChannelLogins([value]);
    if (normalized.isNotEmpty) {
      await _settingsStore.setAdProxyWhitelistedChannels([
        ..._settingsStore.adProxyWhitelistedChannels,
        normalized.single,
      ]);
    }
  }

  Future<void> _moveProxy(int index, int offset) async {
    final urls = _settingsStore.adProxyUrls.toList();
    final target = index + offset;
    if (target < 0 || target >= urls.length) {
      return;
    }
    final value = urls.removeAt(index);
    urls.insert(target, value);
    await _settingsStore.setAdProxyUrls(urls);
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
      const bottomScrollPadding = PageHeaderLayout.bottomNavigationScrollPadding;

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
                padding: PageHeaderLayout.scrollPadding(
                  top: PageHeaderLayout.settingsContentTopPadding,
                  bottom: bottomScrollPadding,
                ),
                children: [
                  _SettingsGroup(
                    key: const ValueKey("settings_theme_group"),
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
                    key: const ValueKey("settings_ad_proxy_group"),
                    children: [
                      _AdProxySettings(
                        enabled: _settingsStore.adProxyEnabled,
                        proxyUrls: _settingsStore.adProxyUrls,
                        whitelistedChannels: _settingsStore.adProxyEffectiveWhitelistedChannels,
                        subscriptionChannels: _settingsStore.adProxySubscriptionChannels,
                        onEnabledChanged: (enabled) {
                          unawaited(_settingsStore.setAdProxyEnabled(enabled: enabled));
                        },
                        onAddProxy: () => unawaited(_addProxyUrl()),
                        onRemoveProxy: (index) {
                          final urls = _settingsStore.adProxyUrls.toList()..removeAt(index);
                          unawaited(_settingsStore.setAdProxyUrls(urls));
                        },
                        onMoveProxy: (index, offset) => unawaited(_moveProxy(index, offset)),
                        onAddChannel: () => unawaited(_addWhitelistedChannel()),
                        onRemoveChannel: (channel) {
                          final channels = _settingsStore.adProxyWhitelistedChannels.toList()
                            ..remove(channel);
                          unawaited(_settingsStore.setAdProxyWhitelistedChannels(channels));
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

class _AdProxySettings extends StatelessWidget {
  const _AdProxySettings({
    required this.enabled,
    required this.proxyUrls,
    required this.whitelistedChannels,
    required this.subscriptionChannels,
    required this.onEnabledChanged,
    required this.onAddProxy,
    required this.onRemoveProxy,
    required this.onMoveProxy,
    required this.onAddChannel,
    required this.onRemoveChannel,
  });

  final bool enabled;
  final List<String> proxyUrls;
  final List<String> whitelistedChannels;
  final List<String> subscriptionChannels;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onAddProxy;
  final ValueChanged<int> onRemoveProxy;
  final void Function(int index, int offset) onMoveProxy;
  final VoidCallback onAddChannel;
  final ValueChanged<String> onRemoveChannel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          icon: Icons.shield_outlined,
          title: "Ad proxying",
          subtitle: "Use HTTP proxies only when Twitch returns an ad-bearing playlist.",
          trailing: Switch(
            key: const ValueKey("settings_ad_proxy_toggle"),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
        ),
        const Divider(height: 1),
        _SettingsListHeader(title: "Proxies", onAdd: onAddProxy),
        if (proxyUrls.isEmpty)
          const _SettingsEmptyList(message: "Add at least one HTTP proxy.")
        else
          for (final (index, url) in proxyUrls.indexed)
            ListTile(
              key: ValueKey("settings_proxy_$index"),
              dense: true,
              title: Text(index == 0 ? "Main" : "Fallback $index"),
              subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "Move up",
                    onPressed: index == 0 ? null : () => onMoveProxy(index, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: "Move down",
                    onPressed: index == proxyUrls.length - 1 ? null : () => onMoveProxy(index, 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: "Remove proxy",
                    onPressed: () => onRemoveProxy(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        Divider(height: 1, color: theme.dividerColor),
        _SettingsListHeader(title: "Whitelisted channels", onAdd: onAddChannel),
        if (whitelistedChannels.isEmpty)
          const _SettingsEmptyList(message: "Subscribed channels are added automatically.")
        else
          for (final channel in whitelistedChannels)
            ListTile(
              key: ValueKey("settings_whitelisted_$channel"),
              dense: true,
              title: Text(channel),
              subtitle: subscriptionChannels.contains(channel)
                  ? const Text("Subscribed channel")
                  : null,
              trailing: subscriptionChannels.contains(channel)
                  ? const Tooltip(
                      message: "Managed automatically",
                      child: Icon(Icons.lock_outline),
                    )
                  : IconButton(
                      tooltip: "Remove channel",
                      onPressed: () => onRemoveChannel(channel),
                      icon: const Icon(Icons.delete_outline),
                    ),
            ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty("enabled", value: enabled, ifTrue: "enabled"));
    properties.add(IterableProperty<String>("proxyUrls", proxyUrls));
    properties.add(IterableProperty<String>("whitelistedChannels", whitelistedChannels));
    properties.add(IterableProperty<String>("subscriptionChannels", subscriptionChannels));
    properties.add(
      ObjectFlagProperty<ValueChanged<bool>>.has("onEnabledChanged", onEnabledChanged),
    );
    properties.add(ObjectFlagProperty<VoidCallback>.has("onAddProxy", onAddProxy));
    properties.add(ObjectFlagProperty<ValueChanged<int>>.has("onRemoveProxy", onRemoveProxy));
    properties.add(ObjectFlagProperty<void Function(int, int)>.has("onMoveProxy", onMoveProxy));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onAddChannel", onAddChannel));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>>.has("onRemoveChannel", onRemoveChannel),
    );
  }
}

class _SettingsListHeader extends StatelessWidget {
  const _SettingsListHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm, top: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        IconButton(tooltip: "Add $title", onPressed: onAdd, icon: const Icon(Icons.add)),
      ],
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("title", title));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onAdd", onAdd));
  }
}

class _SettingsEmptyList extends StatelessWidget {
  const _SettingsEmptyList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("message", message));
  }
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
          padding: PageHeaderLayout.settingsTopBarPadding,
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
  const _SettingsGroup({
    required this.children,
    super.key,
  });

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
  bool adProxyEnabled = false;
  List<String> adProxyUrls = const [];
  List<String> adProxyWhitelistedChannels = const [];

  @override
  Future<bool> readAdProxyEnabled() async => adProxyEnabled;

  @override
  Future<List<String>> readAdProxyUrls() async => adProxyUrls;

  @override
  Future<List<String>> readAdProxyWhitelistedChannels() async => adProxyWhitelistedChannels;

  @override
  Future<List<String>> readAdProxySubscriptionChannels() async => const [];

  @override
  Future<void> saveAdProxyEnabled({required bool enabled}) async => adProxyEnabled = enabled;

  @override
  Future<void> saveAdProxyUrls(List<String> urls) async => adProxyUrls = List.of(urls);

  @override
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels) async =>
      adProxyWhitelistedChannels = List.of(channels);

  @override
  Future<void> saveAdProxySubscriptionChannels(List<String> channels) async {}

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
