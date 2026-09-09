import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test(
    "accepted rules survive preferences recreation separately for each viewer and channel",
    () async {
      final store = _MemoryPreferencesStore();
      final preferences = SharedPreferencesFlowPreferences(store: store);
      expect(await preferences.readAcceptedChatRules("viewer:channel"), isEmpty);
      await preferences.saveAcceptedChatRules("viewer:channel", ["Be kind", "No spoilers"]);
      final restored = SharedPreferencesFlowPreferences(store: store);
      expect(await restored.readAcceptedChatRules("viewer:channel"), ["Be kind", "No spoilers"]);
      expect(await restored.readAcceptedChatRules("another:channel"), isEmpty);
      expect(await restored.readAcceptedChatRules("viewer:another"), isEmpty);
    },
  );

  test("recent emotes preserve serialized provider data and keep the latest forty", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);
    expect(await preferences.readRecentChatEmotes(), isEmpty);
    final emotes = List.generate(45, (index) => '{"provider":"twitch","id":"$index"}');
    await preferences.saveRecentChatEmotes(["", ...emotes]);
    final restored = await SharedPreferencesFlowPreferences(store: store).readRecentChatEmotes();
    expect(restored, emotes.take(40));
  });

  test("chat appearance and emote providers persist with safe font defaults", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);
    final defaults = await preferences.readChatPreferences();
    expect(defaults.fontSize, 14);
    expect(defaults.showTimestamps, isFalse);
    expect(defaults.showBadges, isTrue);
    expect(defaults.emoteScale, 1);
    expect(defaults.emoteAutocomplete, isTrue);
    expect(defaults.sevenTvPaints, isTrue);
    expect(defaults.animatedPaints, isTrue);
    expect(defaults.badgeScale, 1);
    expect(defaults.messageScale, 1);
    expect(defaults.messageSpacing, 6);
    expect(defaults.showDeletedMessages, isFalse);
    expect(defaults.autoSyncChat, isTrue);
    expect(defaults.autoClaimChannelPoints, isFalse);
    expect(defaults.showWatchStreakPopups, isTrue);
    expect(defaults.manualChatDelaySeconds, 0);
    expect(defaults.highlightFirstMessages, isTrue);
    expect(defaults.showSubscriptionNotices, isTrue);
    expect(defaults.showAnnouncements, isTrue);
    expect(defaults.showRaidNotices, isTrue);
    expect(defaults.showModerationNotices, isTrue);
    await preferences.saveChatPreferences(
      const ChatPreferences(
        fontSize: 19,
        emoteScale: 1.5,
        emoteAutocomplete: false,
        badgeScale: 0.8,
        messageScale: 1.7,
        messageSpacing: 12,
        showTimestamps: true,
        showDeletedMessages: true,
        autoSyncChat: false,
        autoClaimChannelPoints: true,
        showWatchStreakPopups: false,
        manualChatDelaySeconds: 23,
        highlightFirstMessages: false,
        showSubscriptionNotices: false,
        showAnnouncements: false,
        showRaidNotices: false,
        showModerationNotices: false,
        showBadges: false,
        showEmotes: false,
        twitchBadges: false,
        sevenTvBadges: false,
        sevenTvPaints: false,
        animatedPaints: false,
        bttvBadges: false,
        ffzBadges: false,
        twitchEmotes: false,
        sevenTvEmotes: false,
        bttvEmotes: false,
        ffzEmotes: false,
      ),
    );
    final restored = await SharedPreferencesFlowPreferences(store: store).readChatPreferences();
    expect(restored.fontSize, 19);
    expect(restored.emoteScale, 1.5);
    expect(restored.emoteAutocomplete, isFalse);
    expect(restored.badgeScale, 0.8);
    expect(restored.messageScale, 1.7);
    expect(restored.messageSpacing, 12);
    expect(restored.showTimestamps, isTrue);
    expect(restored.showDeletedMessages, isTrue);
    expect(restored.autoSyncChat, isFalse);
    expect(restored.autoClaimChannelPoints, isTrue);
    expect(restored.showWatchStreakPopups, isFalse);
    expect(restored.manualChatDelaySeconds, 23);
    expect(restored.highlightFirstMessages, isFalse);
    expect(restored.showSubscriptionNotices, isFalse);
    expect(restored.showAnnouncements, isFalse);
    expect(restored.showRaidNotices, isFalse);
    expect(restored.showModerationNotices, isFalse);
    expect(restored.showBadges, isFalse);
    expect(restored.showEmotes, isFalse);
    expect(restored.twitchBadges, isFalse);
    expect(restored.sevenTvBadges, isFalse);
    expect(restored.sevenTvPaints, isFalse);
    expect(restored.animatedPaints, isFalse);
    expect(restored.bttvBadges, isFalse);
    expect(restored.ffzBadges, isFalse);
    expect(restored.twitchEmotes, isFalse);
    expect(restored.sevenTvEmotes, isFalse);
    expect(restored.bttvEmotes, isFalse);
    expect(restored.ffzEmotes, isFalse);
    await preferences.saveChatPreferences(restored.copyWith(fontSize: 20));
    expect((await preferences.readChatPreferences()).emoteAutocomplete, isFalse);
    expect((await preferences.readChatPreferences()).sevenTvPaints, isFalse);
    expect((await preferences.readChatPreferences()).animatedPaints, isFalse);
    expect((await preferences.readChatPreferences()).autoClaimChannelPoints, isTrue);
    expect((await preferences.readChatPreferences()).showWatchStreakPopups, isFalse);
    await preferences.saveChatPreferences(const ChatPreferences());
    expect((await preferences.readChatPreferences()).emoteAutocomplete, isTrue);
    expect((await preferences.readChatPreferences()).sevenTvPaints, isTrue);
    expect((await preferences.readChatPreferences()).animatedPaints, isTrue);
    expect((await preferences.readChatPreferences()).autoClaimChannelPoints, isFalse);
    expect((await preferences.readChatPreferences()).showWatchStreakPopups, isTrue);
    store.stringLists["chat_settings"] = ["NaN"];
    expect((await preferences.readChatPreferences()).fontSize, 14);
    store.stringLists["chat_settings"] = ["900"];
    expect((await preferences.readChatPreferences()).fontSize, 24);
  });

  test(
    "chat numeric settings clamp invalid stored ranges and migrate old master switches",
    () async {
      final store = _MemoryPreferencesStore()
        ..stringLists["chat_settings"] = [
          "14",
          "emote_scale=99",
          "badge_scale=-1",
          "message_scale=NaN",
          "message_spacing=-1",
          "manual_delay=200",
          "hide_badges",
          "hide_emotes",
        ];
      final preferences = SharedPreferencesFlowPreferences(store: store);
      final migrated = await preferences.readChatPreferences();
      expect(migrated.emoteScale, 2);
      expect(migrated.badgeScale, 0.5);
      expect(migrated.messageScale, 1);
      expect(migrated.messageSpacing, 0);
      expect(migrated.manualChatDelaySeconds, 30);
      expect(migrated.twitchBadges, isFalse);
      expect(migrated.sevenTvBadges, isFalse);
      expect(migrated.bttvBadges, isFalse);
      expect(migrated.ffzBadges, isFalse);
      expect(migrated.twitchEmotes, isFalse);
      expect(migrated.sevenTvEmotes, isFalse);
      expect(migrated.bttvEmotes, isFalse);
      expect(migrated.ffzEmotes, isFalse);
      await preferences.saveChatPreferences(
        migrated.copyWith(twitchBadges: true, sevenTvEmotes: true),
      );
      final overridden = await preferences.readChatPreferences();
      expect(overridden.twitchBadges, isTrue);
      expect(overridden.sevenTvEmotes, isTrue);
      expect(overridden.ffzBadges, isFalse);
      expect(overridden.bttvEmotes, isFalse);
    },
  );

  test("playback modes default on and persist independent selections", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);
    expect(await preferences.readPictureInPictureEnabled(), isTrue);
    expect(await preferences.readMiniPlayerEnabled(), isTrue);

    await preferences.savePictureInPictureEnabled(enabled: false);
    final reloaded = SharedPreferencesFlowPreferences(store: store);
    expect(await reloaded.readPictureInPictureEnabled(), isFalse);
    expect(await reloaded.readMiniPlayerEnabled(), isTrue);

    await reloaded.saveMiniPlayerEnabled(enabled: false);
    await reloaded.savePictureInPictureEnabled(enabled: true);
    expect(await preferences.readPictureInPictureEnabled(), isTrue);
    expect(await preferences.readMiniPlayerEnabled(), isFalse);
    await reloaded.saveMiniPlayerEnabled(enabled: true);
    expect(await preferences.readMiniPlayerEnabled(), isTrue);
  });

  test("migrates saved sort names without changing their selected order", () async {
    final store = _MemoryPreferencesStore()
      ..strings["category_sort"] = "viewers"
      ..strings["stream_sort_following"] = "recommended";
    final preferences = SharedPreferencesFlowPreferences(store: store);

    final sort = await preferences.readCategorySort();
    expect(sort, CategorySort.viewersHighToLow);
    await preferences.saveCategorySort(sort);
    expect(store.strings["category_sort"], "viewersHighToLow");
    final streamSort = await preferences.readStreamSort("following");
    expect(streamSort, StreamSort.recommendedForYou);
    await preferences.saveStreamSort("following", streamSort);
    expect(store.strings["stream_sort_following"], "recommendedForYou");
  });
  test("proxy credentials remain case sensitive during deduplication", () {
    expect(
      normalizeAdProxyUrls([
        "http://User:Secret@PROXY.EXAMPLE:8080/",
        "http://User:Secret@proxy.example:8080",
        "http://user:secret@proxy.example:8080",
      ]),
      [
        "http://User:Secret@proxy.example:8080",
        "http://user:secret@proxy.example:8080",
      ],
    );
  });

  test("normalizes browse search history in shared preferences", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);

    await preferences.saveBrowseSearchHistory([
      " mine ",
      "Mine",
      "",
      "VALORANT",
      "just chatting",
      "apex",
      "Dota",
      "counter-strike",
      "retro",
      "music",
    ]);

    expect(await preferences.readBrowseSearchHistory(), [
      "mine",
      "VALORANT",
      "just chatting",
      "apex",
      "Dota",
      "counter-strike",
      "retro",
      "music",
    ]);

    await preferences.clearBrowseSearchHistory();

    expect(await preferences.readBrowseSearchHistory(), isEmpty);
  });

  test("stores only ordered HTTP proxy URLs and valid channel logins", () async {
    final store = _MemoryPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: store);

    await preferences.saveAdProxyEnabled(enabled: true);
    await preferences.saveAdProxyUrls([
      " http://main.example:8080 ",
      "https://not-http.example",
      "http://fallback.example:3128/",
      "HTTP://MAIN.EXAMPLE:8080",
      "http://proxy.example/path",
      "http://proxy.example:99999",
      "http://:password@proxy.example:8080",
    ]);
    await preferences.saveAdProxyWhitelistedChannels([
      " Creator ",
      "creator",
      "other_channel",
      "invalid-channel",
    ]);

    expect(await preferences.readAdProxyEnabled(), isTrue);
    expect(await preferences.readAdProxyUrls(), [
      "http://main.example:8080",
      "http://fallback.example:3128",
    ]);
    expect(await preferences.readAdProxyWhitelistedChannels(), ["creator", "other_channel"]);
  });
}

class _MemoryPreferencesStore implements FlowPreferencesStore {
  final strings = <String, String>{};
  final stringLists = <String, List<String>>{};

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<List<String>?> getStringList(String key) async {
    final value = stringLists[key];
    return value == null ? null : List<String>.of(value);
  }

  @override
  Future<void> remove(String key) async {
    strings.remove(key);
    stringLists.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    strings[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    stringLists[key] = List<String>.of(value);
  }
}
