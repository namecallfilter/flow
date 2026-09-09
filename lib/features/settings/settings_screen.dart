import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flow/shared/widgets/page_header_title.dart";
import "package:flow/shared/widgets/scroll_reactive_chrome.dart";
import "package:flow/shared/widgets/section_header.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_mobx/flutter_mobx.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.bottomNavigationBar,
    this.showBackButton = false,
    this.currentThemeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.openExternalUrl,
    this.settingsStore,
    this.twitchAccount,
    this.onSwitchTwitchAccount,
    this.onSignOutTwitch,
  });

  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ExternalUrlOpener? openExternalUrl;
  final AppSettingsStore? settingsStore;
  final TwitchUser? twitchAccount;
  final AsyncCallback? onSwitchTwitchAccount;
  final AsyncCallback? onSignOutTwitch;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Widget?>("bottomNavigationBar", bottomNavigationBar));
    properties.add(FlagProperty("showBackButton", value: showBackButton, ifTrue: "show back"));
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
    properties.add(DiagnosticsProperty<TwitchUser?>("twitchAccount", twitchAccount));
    properties.add(
      ObjectFlagProperty<AsyncCallback?>.has(
        "onSwitchTwitchAccount",
        onSwitchTwitchAccount,
      ),
    );
    properties.add(
      ObjectFlagProperty<AsyncCallback?>.has("onSignOutTwitch", onSignOutTwitch),
    );
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final AppSettingsStore _settingsStore;
  bool _settingsLoadFailed = false;
  bool _isSaving = false;
  final _chatSliderValues = <String, double>{};

  @override
  void initState() {
    super.initState();
    _settingsStore =
        widget.settingsStore ??
        AppSettingsStore(
          preferences: MemoryFlowPreferences(themeMode: widget.currentThemeMode),
        );
    if (!_settingsStore.isLoaded) {
      unawaited(_loadSettings());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      await _settingsStore.load();
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _settingsLoadFailed = true);
    }
  }

  void _retrySettingsLoad() {
    setState(() => _settingsLoadFailed = false);
    unawaited(_loadSettings());
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    await _settingsStore.setThemeMode(themeMode);
    widget.onThemeModeChanged?.call(themeMode);
  }

  void _changeChatSettings(ChatPreferences settings) {
    unawaited(_saveSettings(() => _settingsStore.setChatPreferences(settings)));
  }

  Widget _chatSection(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    ),
  );

  Widget _chatSlider({
    required String id,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ChatPreferences Function(double) update,
    bool enabled = true,
    String suffix = "",
    double labelMultiplier = 1,
  }) {
    final current = _chatSliderValues[id] ?? value;
    final label = "${(current * labelMultiplier).round()}$suffix";
    return Column(
      children: [
        ListTile(title: Text(title), trailing: Text(label)),
        Slider(
          key: ValueKey(id),
          min: min,
          max: max,
          divisions: divisions,
          value: current,
          label: label,
          onChanged: enabled ? (value) => setState(() => _chatSliderValues[id] = value) : null,
          onChangeEnd: enabled
              ? (value) => unawaited(
                  _saveSettings(() async {
                    try {
                      await _settingsStore.setChatPreferences(update(value));
                    } finally {
                      if (mounted) {
                        setState(() => _chatSliderValues.remove(id));
                      }
                    }
                  }),
                )
              : null,
        ),
      ],
    );
  }

  Future<void> _saveSettings(AsyncCallback change) async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    unawaited(HapticFeedback.selectionClick());
    try {
      await change();
    } on Object catch (error) {
      debugPrint("Couldn't save settings: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save settings. Please try again.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
            autocorrect: false,
            enableSuggestions: false,
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

  Future<void> _reorderProxy(int oldIndex, int newIndex) async {
    final urls = _settingsStore.adProxyUrls.toList();
    final value = urls.removeAt(oldIndex);
    urls.insert(newIndex, value);
    await _settingsStore.setAdProxyUrls(urls);
  }

  Future<void> _openRepository(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opener = widget.openExternalUrl ?? ExternalUrlLauncher.open;

    try {
      await opener(FlowLinks.repository);
    } on Object catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      final bottomScrollPadding = widget.showBackButton
          ? MediaQuery.paddingOf(context).bottom + AppSpacing.lg
          : PageHeaderLayout.bottomNavigationScrollPadding;
      final topSafeAreaInset = ScrollReactiveChrome.safeAreaInsetsOf(context).top;

      return Scaffold(
        extendBody: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar: widget.showBackButton
            ? null
            : widget.bottomNavigationBar ?? const AppBottomNav(currentRoute: FlowRoutes.settings),
        body: ScrollReactiveChrome(
          scrollController: _scrollController,
          header: _SettingsTopBar(showBackButton: widget.showBackButton),
          child: Stack(
            children: [
              AbsorbPointer(
                key: const ValueKey("settings_content_interaction_gate"),
                absorbing: !_settingsStore.isLoaded || _isSaving,
                child: ListView(
                  controller: _scrollController,
                  padding: PageHeaderLayout.scrollPadding(
                    top:
                        PageHeaderLayout.settingsContentTopPadding +
                        topSafeAreaInset +
                        (widget.showBackButton ? 16 : 0),
                    bottom: bottomScrollPadding,
                  ),
                  children: [
                    if (widget.twitchAccount case final account?) ...[
                      _SettingsGroup(
                        key: const ValueKey("settings_twitch_account_group"),
                        children: [
                          _SettingsRow(
                            icon: Icons.person_outline,
                            title: account.displayName,
                            subtitle: "@${account.login}",
                            trailing: const Text("Connected"),
                          ),
                          const Divider(height: 1),
                          _SettingsRow(
                            icon: Icons.sync,
                            title: "Switch Twitch account",
                            subtitle: "Log in with a different Twitch account.",
                            trailing: const Icon(Icons.chevron_right),
                            onTap: widget.onSwitchTwitchAccount == null
                                ? null
                                : () => unawaited(widget.onSwitchTwitchAccount!()),
                          ),
                          const Divider(height: 1),
                          _SettingsRow(
                            icon: Icons.logout,
                            title: "Sign out of Twitch",
                            subtitle: "Continue without an account.",
                            trailing: const Icon(Icons.chevron_right),
                            onTap: widget.onSignOutTwitch == null
                                ? null
                                : () => unawaited(widget.onSignOutTwitch!()),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _SettingsGroup(
                      key: const ValueKey("settings_theme_group"),
                      children: [
                        _ThemeModeRow(
                          currentThemeMode: _settingsStore.themeMode,
                          onThemeModeChanged: (themeMode) {
                            unawaited(_saveSettings(() => _changeThemeMode(themeMode)));
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
                          manualChannels: _settingsStore.adProxyWhitelistedChannels,
                          subscriptionChannels: _settingsStore.adProxySubscriptionChannels,
                          onEnabledChanged: (enabled) {
                            unawaited(
                              _saveSettings(
                                () => _settingsStore.setAdProxyEnabled(enabled: enabled),
                              ),
                            );
                          },
                          onAddProxy: () => unawaited(_saveSettings(_addProxyUrl)),
                          onRemoveProxy: (index) {
                            final urls = _settingsStore.adProxyUrls.toList()..removeAt(index);
                            unawaited(_saveSettings(() => _settingsStore.setAdProxyUrls(urls)));
                          },
                          onReorderProxy: (oldIndex, newIndex) =>
                              unawaited(_saveSettings(() => _reorderProxy(oldIndex, newIndex))),
                          onAddChannel: () => unawaited(_saveSettings(_addWhitelistedChannel)),
                          onRemoveChannel: (channel) {
                            final channels = _settingsStore.adProxyWhitelistedChannels.toList()
                              ..remove(channel);
                            unawaited(
                              _saveSettings(
                                () => _settingsStore.setAdProxyWhitelistedChannels(channels),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const SectionHeader(title: "Playback"),
                    const SizedBox(height: AppSpacing.sm),
                    _SettingsGroup(
                      key: const ValueKey("settings_playback_group"),
                      children: [
                        _SettingsRow(
                          icon: Icons.picture_in_picture_alt_rounded,
                          title: "Picture-in-picture",
                          subtitle: "Keep playing when you leave Flow.",
                          trailing: Switch(
                            key: const ValueKey("settings_picture_in_picture_toggle"),
                            value: _settingsStore.pictureInPictureEnabled,
                            onChanged: (enabled) => unawaited(
                              _saveSettings(
                                () => _settingsStore.setPictureInPictureEnabled(enabled: enabled),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _SettingsRow(
                          icon: Icons.web_asset_rounded,
                          title: "Mini-player",
                          subtitle: "Keep playing while you browse Flow.",
                          trailing: Switch(
                            key: const ValueKey("settings_mini_player_toggle"),
                            value: _settingsStore.miniPlayerEnabled,
                            onChanged: (enabled) => unawaited(
                              _saveSettings(
                                () => _settingsStore.setMiniPlayerEnabled(enabled: enabled),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const SectionHeader(title: "Chat"),
                    const SizedBox(height: AppSpacing.sm),
                    _SettingsGroup(
                      key: const ValueKey("settings_chat_group"),
                      children: [
                        Material(
                          type: MaterialType.transparency,
                          child: Column(
                            children: [
                              _chatSection("Appearance"),
                              _chatSlider(
                                id: "chat_font_size",
                                title: "Font size",
                                value: _settingsStore.chatPreferences.fontSize,
                                min: 10,
                                max: 24,
                                divisions: 14,
                                update: (value) =>
                                    _settingsStore.chatPreferences.copyWith(fontSize: value),
                              ),
                              _chatSlider(
                                id: "chat_message_scale",
                                title: "Message scale",
                                value: _settingsStore.chatPreferences.messageScale,
                                min: 0.5,
                                max: 2,
                                divisions: 15,
                                suffix: "%",
                                labelMultiplier: 100,
                                update: (value) =>
                                    _settingsStore.chatPreferences.copyWith(messageScale: value),
                              ),
                              _chatSlider(
                                id: "chat_message_spacing",
                                title: "Message spacing",
                                value: _settingsStore.chatPreferences.messageSpacing,
                                min: 0,
                                max: 16,
                                divisions: 16,
                                update: (value) =>
                                    _settingsStore.chatPreferences.copyWith(messageSpacing: value),
                              ),
                              SwitchListTile(
                                title: const Text("Timestamps"),
                                value: _settingsStore.chatPreferences.showTimestamps,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(showTimestamps: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Show deleted messages"),
                                value: _settingsStore.chatPreferences.showDeletedMessages,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(
                                    showDeletedMessages: value,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              _chatSection("Badges and paints"),
                              _chatSlider(
                                id: "chat_badge_scale",
                                title: "Badge scale",
                                value: _settingsStore.chatPreferences.badgeScale,
                                min: 0.5,
                                max: 2,
                                divisions: 15,
                                suffix: "%",
                                labelMultiplier: 100,
                                update: (value) =>
                                    _settingsStore.chatPreferences.copyWith(badgeScale: value),
                              ),
                              SwitchListTile(
                                title: const Text("Twitch badges"),
                                value: _settingsStore.chatPreferences.twitchBadges,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(twitchBadges: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("7TV badges"),
                                value: _settingsStore.chatPreferences.sevenTvBadges,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(sevenTvBadges: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("7TV paints"),
                                value: _settingsStore.chatPreferences.sevenTvPaints,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(sevenTvPaints: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Animated paints"),
                                value: _settingsStore.chatPreferences.animatedPaints,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(animatedPaints: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("BetterTTV badges"),
                                value: _settingsStore.chatPreferences.bttvBadges,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(bttvBadges: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("FrankerFaceZ badges"),
                                value: _settingsStore.chatPreferences.ffzBadges,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(ffzBadges: value),
                                ),
                              ),
                              const Divider(height: 1),
                              _chatSection("Emotes"),
                              SwitchListTile(
                                title: const Text("Emote autocomplete"),
                                subtitle: const Text("Suggest emotes while typing."),
                                value: _settingsStore.chatPreferences.emoteAutocomplete,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(emoteAutocomplete: value),
                                ),
                              ),
                              _chatSlider(
                                id: "chat_emote_scale",
                                title: "Emote scale",
                                value: _settingsStore.chatPreferences.emoteScale,
                                min: 0.5,
                                max: 2,
                                divisions: 15,
                                suffix: "%",
                                labelMultiplier: 100,
                                update: (value) =>
                                    _settingsStore.chatPreferences.copyWith(emoteScale: value),
                              ),
                              SwitchListTile(
                                title: const Text("Twitch emotes"),
                                value: _settingsStore.chatPreferences.twitchEmotes,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(twitchEmotes: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("7TV emotes"),
                                value: _settingsStore.chatPreferences.sevenTvEmotes,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(sevenTvEmotes: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("BetterTTV emotes"),
                                value: _settingsStore.chatPreferences.bttvEmotes,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(bttvEmotes: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("FrankerFaceZ emotes"),
                                value: _settingsStore.chatPreferences.ffzEmotes,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(ffzEmotes: value),
                                ),
                              ),
                              const Divider(height: 1),
                              _chatSection("Timing"),
                              SwitchListTile(
                                title: const Text("Auto-sync chat"),
                                subtitle: const Text("Match messages to video playback."),
                                value: _settingsStore.chatPreferences.autoSyncChat,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(autoSyncChat: value),
                                ),
                              ),
                              _chatSlider(
                                id: "chat_manual_delay",
                                title: "Manual chat delay",
                                value: _settingsStore.chatPreferences.manualChatDelaySeconds,
                                min: 0,
                                max: 30,
                                divisions: 30,
                                suffix: "s",
                                enabled: !_settingsStore.chatPreferences.autoSyncChat,
                                update: (value) => _settingsStore.chatPreferences.copyWith(
                                  manualChatDelaySeconds: value,
                                ),
                              ),
                              const Divider(height: 1),
                              _chatSection("Alerts"),
                              SwitchListTile(
                                title: const Text("Auto claim channel points"),
                                value: _settingsStore.chatPreferences.autoClaimChannelPoints,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(
                                    autoClaimChannelPoints: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Watch streak popups"),
                                value: _settingsStore.chatPreferences.showWatchStreakPopups,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(
                                    showWatchStreakPopups: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Highlight first-time chatters"),
                                value: _settingsStore.chatPreferences.highlightFirstMessages,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(
                                    highlightFirstMessages: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Subscription notices"),
                                value: _settingsStore.chatPreferences.showSubscriptionNotices,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(
                                    showSubscriptionNotices: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Announcements"),
                                value: _settingsStore.chatPreferences.showAnnouncements,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(showAnnouncements: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Raid notices"),
                                value: _settingsStore.chatPreferences.showRaidNotices,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(showRaidNotices: value),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text("Timeouts and bans"),
                                value: _settingsStore.chatPreferences.showModerationNotices,
                                onChanged: (value) => _changeChatSettings(
                                  _settingsStore.chatPreferences.copyWith(
                                    showModerationNotices: value,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
              ),
              if (_settingsLoadFailed)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(top: topSafeAreaInset),
                    child: Center(
                      child: FilledButton.icon(
                        key: const ValueKey("settings_load_retry"),
                        onPressed: _retrySettingsLoad,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Couldn't load settings. Retry"),
                      ),
                    ),
                  ),
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
    required this.manualChannels,
    required this.subscriptionChannels,
    required this.onEnabledChanged,
    required this.onAddProxy,
    required this.onRemoveProxy,
    required this.onReorderProxy,
    required this.onAddChannel,
    required this.onRemoveChannel,
  });

  final bool enabled;
  final List<String> proxyUrls;
  final List<String> whitelistedChannels;
  final List<String> manualChannels;
  final List<String> subscriptionChannels;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onAddProxy;
  final ValueChanged<int> onRemoveProxy;
  final ReorderCallback onReorderProxy;
  final VoidCallback onAddChannel;
  final ValueChanged<String> onRemoveChannel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget proxyTile(int index) => ListTile(
      key: ValueKey("settings_proxy_${proxyUrls[index]}"),
      dense: true,
      contentPadding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
      title: Text(index == 0 ? "Main" : "Fallback $index"),
      subtitle: Text(
        _displayProxyUrl(proxyUrls[index]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: "Remove proxy",
            onPressed: () => onRemoveProxy(index),
            icon: const Icon(Icons.delete_outline),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Tooltip(
              message: "Reorder proxy",
              child: SizedBox.square(dimension: 48, child: Icon(Icons.drag_indicator)),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          icon: Icons.shield_outlined,
          title: "Ad proxying",
          subtitle: "Use proxies for ad requests. Stream video directly.",
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
          ReorderableListView(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            buildDefaultDragHandles: false,
            onReorderItem: onReorderProxy,
            // Keep an open tooltip out of the subtree moved between overlays.
            proxyDecorator: (_, index, _) => Material(elevation: 6, child: proxyTile(index)),
            children: [for (var index = 0; index < proxyUrls.length; index++) proxyTile(index)],
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
              contentPadding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
              title: Text(channel),
              subtitle: subscriptionChannels.contains(channel)
                  ? const Text("Subscribed channel")
                  : null,
              trailing: subscriptionChannels.contains(channel) && !manualChannels.contains(channel)
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
    properties.add(IntProperty("proxyUrlCount", proxyUrls.length));
    properties.add(IterableProperty<String>("whitelistedChannels", whitelistedChannels));
    properties.add(IterableProperty<String>("manualChannels", manualChannels));
    properties.add(IterableProperty<String>("subscriptionChannels", subscriptionChannels));
    properties.add(
      ObjectFlagProperty<ValueChanged<bool>>.has("onEnabledChanged", onEnabledChanged),
    );
    properties.add(ObjectFlagProperty<VoidCallback>.has("onAddProxy", onAddProxy));
    properties.add(ObjectFlagProperty<ValueChanged<int>>.has("onRemoveProxy", onRemoveProxy));
    properties.add(ObjectFlagProperty<ReorderCallback>.has("onReorderProxy", onReorderProxy));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onAddChannel", onAddChannel));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>>.has("onRemoveChannel", onRemoveChannel),
    );
  }
}

String _displayProxyUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri == null || uri.userInfo.isEmpty ? value : uri.replace(userInfo: "").toString();
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
  const _SettingsTopBar({required this.showBackButton});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) => Padding(
    padding: PageHeaderLayout.settingsTopBarPadding,
    child: Row(
      children: [
        if (showBackButton) ...[
          const BackButton(key: ValueKey("settings_back")),
          const SizedBox(width: AppSpacing.sm),
        ],
        const PageHeaderTitle(key: ValueKey("settings_title"), title: "Settings"),
      ],
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty("showBackButton", value: showBackButton, ifTrue: "show back"));
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
