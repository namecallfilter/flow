import "package:flow/shared/twitch/stream_sort.dart";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

abstract interface class FlowPreferences {
  Future<ThemeMode> readThemeMode();
  Future<void> saveThemeMode(ThemeMode mode);
  Future<bool> readPictureInPictureEnabled();
  Future<void> savePictureInPictureEnabled({required bool enabled});
  Future<bool> readMiniPlayerEnabled();
  Future<void> saveMiniPlayerEnabled({required bool enabled});
  Future<bool> readAdProxyEnabled();
  Future<void> saveAdProxyEnabled({required bool enabled});
  Future<List<String>> readAdProxyUrls();
  Future<void> saveAdProxyUrls(List<String> urls);
  Future<List<String>> readAdProxyWhitelistedChannels();
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels);
  Future<List<String>> readAdProxySubscriptionChannels();
  Future<void> saveAdProxySubscriptionChannels(List<String> channels);
  Future<List<String>> readBrowseSearchHistory();
  Future<void> saveBrowseSearchHistory(List<String> history);
  Future<void> clearBrowseSearchHistory();
  Future<bool> readLoginOfferDismissed();
  Future<void> saveLoginOfferDismissed({required bool dismissed});
  Future<StreamSort> readStreamSort(String section);
  Future<void> saveStreamSort(String section, StreamSort sort);
  Future<CategorySort> readCategorySort();
  Future<void> saveCategorySort(CategorySort sort);
  Future<ChatPreferences> readChatPreferences();
  Future<void> saveChatPreferences(ChatPreferences preferences);
  Future<List<String>> readRecentChatEmotes();
  Future<void> saveRecentChatEmotes(List<String> emotes);
  Future<List<String>> readAcceptedChatRules(String key);
  Future<void> saveAcceptedChatRules(String key, List<String> rules);
}

class ChatPreferences {
  const ChatPreferences({
    this.fontSize = 14,
    this.emoteScale = 1,
    this.emoteAutocomplete = true,
    this.badgeScale = 1,
    this.messageScale = 1,
    this.messageSpacing = 6,
    this.showTimestamps = false,
    this.showDeletedMessages = false,
    this.autoSyncChat = true,
    this.autoClaimChannelPoints = false,
    this.showWatchStreakPopups = true,
    this.manualChatDelaySeconds = 0,
    this.highlightFirstMessages = true,
    this.showSubscriptionNotices = true,
    this.showAnnouncements = true,
    this.showRaidNotices = true,
    this.showModerationNotices = true,
    this.showBadges = true,
    this.showEmotes = true,
    this.twitchBadges = true,
    this.sevenTvBadges = true,
    this.sevenTvPaints = true,
    this.animatedPaints = true,
    this.bttvBadges = true,
    this.ffzBadges = true,
    this.twitchEmotes = true,
    this.sevenTvEmotes = true,
    this.bttvEmotes = true,
    this.ffzEmotes = true,
  });

  final double fontSize;
  final double emoteScale;
  final bool emoteAutocomplete;
  final double badgeScale;
  final double messageScale;
  final double messageSpacing;
  final bool showTimestamps;
  final bool showDeletedMessages;
  final bool autoSyncChat;
  final bool autoClaimChannelPoints;
  final bool showWatchStreakPopups;
  final double manualChatDelaySeconds;
  final bool highlightFirstMessages;
  final bool showSubscriptionNotices;
  final bool showAnnouncements;
  final bool showRaidNotices;
  final bool showModerationNotices;
  final bool showBadges;
  final bool showEmotes;
  final bool twitchBadges;
  final bool sevenTvBadges;
  final bool sevenTvPaints;
  final bool animatedPaints;
  final bool bttvBadges;
  final bool ffzBadges;
  final bool twitchEmotes;
  final bool sevenTvEmotes;
  final bool bttvEmotes;
  final bool ffzEmotes;

  ChatPreferences copyWith({
    double? fontSize,
    double? emoteScale,
    bool? emoteAutocomplete,
    double? badgeScale,
    double? messageScale,
    double? messageSpacing,
    bool? showTimestamps,
    bool? showDeletedMessages,
    bool? autoSyncChat,
    bool? autoClaimChannelPoints,
    bool? showWatchStreakPopups,
    double? manualChatDelaySeconds,
    bool? highlightFirstMessages,
    bool? showSubscriptionNotices,
    bool? showAnnouncements,
    bool? showRaidNotices,
    bool? showModerationNotices,
    bool? showBadges,
    bool? showEmotes,
    bool? twitchBadges,
    bool? sevenTvBadges,
    bool? sevenTvPaints,
    bool? animatedPaints,
    bool? bttvBadges,
    bool? ffzBadges,
    bool? twitchEmotes,
    bool? sevenTvEmotes,
    bool? bttvEmotes,
    bool? ffzEmotes,
  }) => ChatPreferences(
    fontSize: fontSize ?? this.fontSize,
    emoteScale: emoteScale ?? this.emoteScale,
    emoteAutocomplete: emoteAutocomplete ?? this.emoteAutocomplete,
    badgeScale: badgeScale ?? this.badgeScale,
    messageScale: messageScale ?? this.messageScale,
    messageSpacing: messageSpacing ?? this.messageSpacing,
    showTimestamps: showTimestamps ?? this.showTimestamps,
    showDeletedMessages: showDeletedMessages ?? this.showDeletedMessages,
    autoSyncChat: autoSyncChat ?? this.autoSyncChat,
    autoClaimChannelPoints: autoClaimChannelPoints ?? this.autoClaimChannelPoints,
    showWatchStreakPopups: showWatchStreakPopups ?? this.showWatchStreakPopups,
    manualChatDelaySeconds: manualChatDelaySeconds ?? this.manualChatDelaySeconds,
    highlightFirstMessages: highlightFirstMessages ?? this.highlightFirstMessages,
    showSubscriptionNotices: showSubscriptionNotices ?? this.showSubscriptionNotices,
    showAnnouncements: showAnnouncements ?? this.showAnnouncements,
    showRaidNotices: showRaidNotices ?? this.showRaidNotices,
    showModerationNotices: showModerationNotices ?? this.showModerationNotices,
    showBadges: showBadges ?? this.showBadges,
    showEmotes: showEmotes ?? this.showEmotes,
    twitchBadges: twitchBadges ?? this.twitchBadges,
    sevenTvBadges: sevenTvBadges ?? this.sevenTvBadges,
    sevenTvPaints: sevenTvPaints ?? this.sevenTvPaints,
    animatedPaints: animatedPaints ?? this.animatedPaints,
    bttvBadges: bttvBadges ?? this.bttvBadges,
    ffzBadges: ffzBadges ?? this.ffzBadges,
    twitchEmotes: twitchEmotes ?? this.twitchEmotes,
    sevenTvEmotes: sevenTvEmotes ?? this.sevenTvEmotes,
    bttvEmotes: bttvEmotes ?? this.bttvEmotes,
    ffzEmotes: ffzEmotes ?? this.ffzEmotes,
  );
}

abstract interface class FlowPreferencesStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

class MemoryFlowPreferences extends SharedPreferencesFlowPreferences {
  MemoryFlowPreferences({ThemeMode themeMode = ThemeMode.system})
    : super(store: _MemoryPreferencesStore(themeMode));
}

class _MemoryPreferencesStore implements FlowPreferencesStore {
  _MemoryPreferencesStore(ThemeMode themeMode)
    : _values = {
        SharedPreferencesFlowPreferences.themeModeKey: themeModePreferenceValue(themeMode),
      };

  final Map<String, Object> _values;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async {
    final values = _values[key] as List<String>?;
    return values == null ? null : List.of(values);
  }

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async => _values[key] = List.of(value);

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

class SharedPreferencesFlowPreferences implements FlowPreferences {
  SharedPreferencesFlowPreferences({
    FlowPreferencesStore? store,
  }) : _store = store ?? SharedPreferencesAsyncFlowPreferencesStore();

  static const themeModeKey = "flow_theme_mode";
  static const pictureInPictureEnabledKey = "picture_in_picture_enabled";
  static const miniPlayerEnabledKey = "mini_player_enabled";
  static const adProxyEnabledKey = "ad_proxy_enabled";
  static const adProxyUrlsKey = "ad_proxy_urls";
  static const adProxyWhitelistedChannelsKey = "ad_proxy_whitelisted_channels";
  static const adProxySubscriptionChannelsKey = "ad_proxy_subscription_channels";
  static const browseSearchHistoryKey = "browse_search_history";
  static const loginOfferDismissedKey = "login_offer_dismissed";

  final FlowPreferencesStore _store;

  @override
  Future<ChatPreferences> readChatPreferences() async {
    final values = await _store.getStringList("chat_settings") ?? const [];
    final size = double.tryParse(values.firstOrNull ?? "");
    double number(String key, double fallback, double min, double max) {
      final raw = values.where((value) => value.startsWith("$key=")).firstOrNull;
      final parsed = double.tryParse(raw?.substring(key.length + 1) ?? "");
      return parsed != null && parsed.isFinite ? parsed.clamp(min, max) : fallback;
    }

    final legacyHideBadges =
        !values.contains("per_provider_assets") && values.contains("hide_badges");
    final legacyHideEmotes =
        !values.contains("per_provider_assets") && values.contains("hide_emotes");
    return ChatPreferences(
      fontSize: size != null && size.isFinite ? size.clamp(10, 24) : 14,
      emoteScale: number("emote_scale", 1, 0.5, 2),
      emoteAutocomplete: !values.contains("disable_emote_autocomplete"),
      badgeScale: number("badge_scale", 1, 0.5, 2),
      messageScale: number("message_scale", 1, 0.5, 2),
      messageSpacing: number("message_spacing", 6, 0, 16),
      showTimestamps: values.contains("timestamps"),
      showDeletedMessages: values.contains("deleted_messages"),
      autoSyncChat: !values.contains("manual_sync"),
      autoClaimChannelPoints: values.contains("auto_claim_channel_points"),
      showWatchStreakPopups: !values.contains("hide_watch_streak_popups"),
      manualChatDelaySeconds: number("manual_delay", 0, 0, 30),
      highlightFirstMessages: !values.contains("disable_first_messages"),
      showSubscriptionNotices: !values.contains("hide_subscriptions"),
      showAnnouncements: !values.contains("hide_announcements"),
      showRaidNotices: !values.contains("hide_raids"),
      showModerationNotices: !values.contains("hide_moderation"),
      showBadges: !values.contains("hide_badges"),
      showEmotes: !values.contains("hide_emotes"),
      twitchBadges: !legacyHideBadges && !values.contains("disable_twitch_badges"),
      sevenTvBadges: !legacyHideBadges && !values.contains("disable_7tv_badges"),
      sevenTvPaints: !values.contains("disable_7tv_paints"),
      animatedPaints: !values.contains("disable_animated_paints"),
      bttvBadges: !legacyHideBadges && !values.contains("disable_bttv_badges"),
      ffzBadges: !legacyHideBadges && !values.contains("disable_ffz_badges"),
      twitchEmotes: !legacyHideEmotes && !values.contains("disable_twitch"),
      sevenTvEmotes: !legacyHideEmotes && !values.contains("disable_7tv"),
      bttvEmotes: !legacyHideEmotes && !values.contains("disable_bttv"),
      ffzEmotes: !legacyHideEmotes && !values.contains("disable_ffz"),
    );
  }

  @override
  Future<void> saveChatPreferences(ChatPreferences preferences) => _store.setStringList(
    "chat_settings",
    [
      preferences.fontSize.toString(),
      "per_provider_assets",
      "emote_scale=${preferences.emoteScale}",
      "badge_scale=${preferences.badgeScale}",
      "message_scale=${preferences.messageScale}",
      "message_spacing=${preferences.messageSpacing}",
      "manual_delay=${preferences.manualChatDelaySeconds}",
      if (!preferences.emoteAutocomplete) "disable_emote_autocomplete",
      if (preferences.showTimestamps) "timestamps",
      if (preferences.showDeletedMessages) "deleted_messages",
      if (!preferences.autoSyncChat) "manual_sync",
      if (preferences.autoClaimChannelPoints) "auto_claim_channel_points",
      if (!preferences.showWatchStreakPopups) "hide_watch_streak_popups",
      if (!preferences.highlightFirstMessages) "disable_first_messages",
      if (!preferences.showSubscriptionNotices) "hide_subscriptions",
      if (!preferences.showAnnouncements) "hide_announcements",
      if (!preferences.showRaidNotices) "hide_raids",
      if (!preferences.showModerationNotices) "hide_moderation",
      if (!preferences.showBadges) "hide_badges",
      if (!preferences.showEmotes) "hide_emotes",
      if (!preferences.twitchBadges) "disable_twitch_badges",
      if (!preferences.sevenTvBadges) "disable_7tv_badges",
      if (!preferences.sevenTvPaints) "disable_7tv_paints",
      if (!preferences.animatedPaints) "disable_animated_paints",
      if (!preferences.bttvBadges) "disable_bttv_badges",
      if (!preferences.ffzBadges) "disable_ffz_badges",
      if (!preferences.twitchEmotes) "disable_twitch",
      if (!preferences.sevenTvEmotes) "disable_7tv",
      if (!preferences.bttvEmotes) "disable_bttv",
      if (!preferences.ffzEmotes) "disable_ffz",
    ],
  );

  @override
  Future<StreamSort> readStreamSort(String section) async {
    final value = await _store.getString("stream_sort_$section");
    if (value == "recommended") {
      return StreamSort.recommendedForYou;
    }
    return StreamSort.values.where((sort) => sort.name == value).firstOrNull ??
        StreamSort.viewersHighToLow;
  }

  @override
  Future<void> saveStreamSort(String section, StreamSort sort) =>
      _store.setString("stream_sort_$section", sort.name);

  @override
  Future<CategorySort> readCategorySort() async {
    final value = await _store.getString("category_sort");
    if (value == "viewers") {
      return CategorySort.viewersHighToLow;
    }
    return CategorySort.values.where((sort) => sort.name == value).firstOrNull ??
        CategorySort.viewersHighToLow;
  }

  @override
  Future<void> saveCategorySort(CategorySort sort) => _store.setString("category_sort", sort.name);

  @override
  Future<List<String>> readRecentChatEmotes() async =>
      (await _store.getStringList("recent_chat_emotes") ?? const []).take(40).toList();

  @override
  Future<void> saveRecentChatEmotes(List<String> emotes) => _store.setStringList(
    "recent_chat_emotes",
    emotes.where((emote) => emote.isNotEmpty).take(40).toList(),
  );

  @override
  Future<List<String>> readAcceptedChatRules(String key) async =>
      await _store.getStringList("accepted_chat_rules_$key") ?? const [];

  @override
  Future<void> saveAcceptedChatRules(String key, List<String> rules) =>
      _store.setStringList("accepted_chat_rules_$key", rules);

  @override
  Future<bool> readPictureInPictureEnabled() async =>
      await _store.getString(pictureInPictureEnabledKey) != "false";

  @override
  Future<void> savePictureInPictureEnabled({required bool enabled}) =>
      _store.setString(pictureInPictureEnabledKey, enabled.toString());

  @override
  Future<bool> readMiniPlayerEnabled() async =>
      await _store.getString(miniPlayerEnabledKey) != "false";

  @override
  Future<void> saveMiniPlayerEnabled({required bool enabled}) =>
      _store.setString(miniPlayerEnabledKey, enabled.toString());

  @override
  Future<bool> readAdProxyEnabled() async => await _store.getString(adProxyEnabledKey) == "true";

  @override
  Future<List<String>> readAdProxyUrls() async =>
      normalizeAdProxyUrls(await _store.getStringList(adProxyUrlsKey) ?? const []);

  @override
  Future<List<String>> readAdProxyWhitelistedChannels() async => normalizeChannelLogins(
    await _store.getStringList(adProxyWhitelistedChannelsKey) ?? const [],
  );

  @override
  Future<List<String>> readAdProxySubscriptionChannels() async => normalizeChannelLogins(
    await _store.getStringList(adProxySubscriptionChannelsKey) ?? const [],
  );

  @override
  Future<void> clearBrowseSearchHistory() => _store.remove(browseSearchHistoryKey);

  @override
  Future<List<String>> readBrowseSearchHistory() async {
    final history = await _store.getStringList(browseSearchHistoryKey);
    return normalizeBrowseSearchHistory(history ?? const <String>[]);
  }

  @override
  Future<bool> readLoginOfferDismissed() async =>
      await _store.getString(loginOfferDismissedKey) == "true";

  @override
  Future<ThemeMode> readThemeMode() async {
    final value = await _store.getString(themeModeKey);
    return themeModeFromPreference(value);
  }

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    final normalizedHistory = normalizeBrowseSearchHistory(history);
    if (normalizedHistory.isEmpty) {
      await clearBrowseSearchHistory();
      return;
    }

    await _store.setStringList(browseSearchHistoryKey, normalizedHistory);
  }

  @override
  Future<void> saveLoginOfferDismissed({required bool dismissed}) =>
      _store.setString(loginOfferDismissedKey, dismissed.toString());

  @override
  Future<void> saveAdProxyEnabled({required bool enabled}) =>
      _store.setString(adProxyEnabledKey, enabled.toString());

  @override
  Future<void> saveAdProxyUrls(List<String> urls) =>
      _store.setStringList(adProxyUrlsKey, normalizeAdProxyUrls(urls));

  @override
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels) => _store.setStringList(
    adProxyWhitelistedChannelsKey,
    normalizeChannelLogins(channels),
  );

  @override
  Future<void> saveAdProxySubscriptionChannels(List<String> channels) => _store.setStringList(
    adProxySubscriptionChannelsKey,
    normalizeChannelLogins(channels),
  );

  @override
  Future<void> saveThemeMode(ThemeMode mode) =>
      _store.setString(themeModeKey, themeModePreferenceValue(mode));
}

class SharedPreferencesAsyncFlowPreferencesStore implements FlowPreferencesStore {
  SharedPreferencesAsyncFlowPreferencesStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<List<String>?> getStringList(String key) => _preferences.getStringList(key);

  @override
  Future<void> remove(String key) => _preferences.remove(key);

  @override
  Future<void> setString(String key, String value) => _preferences.setString(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _preferences.setStringList(key, value);
}

ThemeMode themeModeFromPreference(String? value) => switch (value) {
  "light" => ThemeMode.light,
  "dark" => ThemeMode.dark,
  _ => ThemeMode.system,
};

String themeModePreferenceValue(ThemeMode mode) => switch (mode) {
  ThemeMode.light => "light",
  ThemeMode.dark => "dark",
  ThemeMode.system => "system",
};

List<String> normalizeBrowseSearchHistory(Iterable<String> values) {
  final seen = <String>{};
  final history = <String>[];
  for (final rawValue in values) {
    final value = rawValue.trim();
    if (value.isEmpty || !seen.add(value.toLowerCase())) {
      continue;
    }
    history.add(value);
    if (history.length == 8) {
      break;
    }
  }
  return history;
}

List<String> normalizeAdProxyUrls(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final rawValue in values)
      if (normalizeAdProxyUrl(rawValue) case final value?)
        if (seen.add(value)) value,
  ];
}

String? normalizeAdProxyUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  final hasEmptyUsername =
      uri != null &&
      uri.authority.contains("@") &&
      (uri.userInfo.isEmpty || uri.userInfo.split(":").first.isEmpty);
  if (uri == null ||
      uri.scheme.toLowerCase() != "http" ||
      uri.host.isEmpty ||
      hasEmptyUsername ||
      uri.path.isNotEmpty && uri.path != "/" ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final port = uri.hasPort ? uri.port : 80;
  if (port < 1 || port > 65535) {
    return null;
  }
  return uri.replace(scheme: "http", path: "").toString();
}

List<String> normalizeChannelLogins(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final rawValue in values)
      if (rawValue.trim().toLowerCase() case final value)
        if (RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(value) && seen.add(value)) value,
  ];
}
