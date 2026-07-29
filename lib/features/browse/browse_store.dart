import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:mobx/mobx.dart";

part "browse_store.g.dart";

enum BrowseSection { categories, liveChannels }

class BrowseStore = BrowseStoreBase with _$BrowseStore;

abstract class BrowseStoreBase with Store {
  BrowseStoreBase({required this.apiCache});

  final TwitchApiCache apiCache;
  int _categoriesFirstPageLength = 0;
  int _liveChannelsFirstPageLength = 0;

  @observable
  List<BrowseCategory> categories = const <BrowseCategory>[];

  @observable
  List<StreamChannel> liveChannels = const <StreamChannel>[];

  @observable
  BrowseSection selectedSection = BrowseSection.categories;

  @observable
  bool categoriesLoaded = false;

  @observable
  bool liveChannelsLoaded = false;

  @observable
  bool isLoadingCategories = false;

  @observable
  bool isLoadingLiveChannels = false;

  @observable
  String? categoriesCursor;

  @observable
  String? liveChannelsCursor;

  @observable
  String? categoriesError;

  @observable
  String? liveChannelsError;

  @observable
  double categoriesScrollOffset = 0;

  @observable
  double liveChannelsScrollOffset = 0;

  @computed
  bool get activeLoading =>
      selectedSection == BrowseSection.categories ? isLoadingCategories : isLoadingLiveChannels;

  @computed
  bool get activeItemsEmpty =>
      selectedSection == BrowseSection.categories ? categories.isEmpty : liveChannels.isEmpty;

  @computed
  String? get activeError =>
      selectedSection == BrowseSection.categories ? categoriesError : liveChannelsError;

  double scrollOffsetFor(BrowseSection section) => switch (section) {
    BrowseSection.categories => categoriesScrollOffset,
    BrowseSection.liveChannels => liveChannelsScrollOffset,
  };

  @action
  void setScrollOffsetFor(BrowseSection section, double offset) {
    switch (section) {
      case BrowseSection.categories:
        categoriesScrollOffset = offset;
      case BrowseSection.liveChannels:
        liveChannelsScrollOffset = offset;
    }
  }

  @action
  void selectSection(BrowseSection? section) {
    if (section == null || section == selectedSection) {
      return;
    }
    selectedSection = section;
  }

  @action
  Future<void> loadCategories({
    bool reset = false,
    bool refresh = false,
    bool preserveTail = false,
  }) async {
    if (isLoadingCategories || (!reset && categoriesLoaded && categoriesCursor == null)) {
      return;
    }

    isLoadingCategories = true;
    categoriesError = null;
    final preservedCursor = categoriesCursor;
    final tailStart = _categoriesFirstPageLength > categories.length
        ? categories.length
        : _categoriesFirstPageLength;
    final preservedTail = preserveTail
        ? categories.skip(tailStart).toList(growable: false)
        : const <BrowseCategory>[];
    if (reset && !preserveTail) {
      categoriesCursor = null;
    }

    try {
      final page = await apiCache.fetchTopCategoriesPage(
        cursor: reset ? null : categoriesCursor,
        refresh: refresh,
      );
      final nextCategories = [
        for (final category in page.data) browseCategoryFromApi(category),
      ];

      if (reset) {
        final firstPageCategories = _mergeCategories(
          const <BrowseCategory>[],
          nextCategories,
        );
        categories = preserveTail
            ? _prependUniqueCategories(firstPageCategories, preservedTail)
            : firstPageCategories;
        _categoriesFirstPageLength = firstPageCategories.length;
      } else {
        categories = _mergeCategories(categories, nextCategories);
      }
      categoriesCursor = preserveTail && preservedTail.isNotEmpty
          ? preservedCursor
          : page.cursor;
      categoriesLoaded = true;
    } on Object catch (error) {
      categoriesError = browseErrorMessage(error);
    } finally {
      isLoadingCategories = false;
    }
  }

  @action
  Future<void> loadLiveChannels({
    bool reset = false,
    bool refresh = false,
    bool preserveTail = false,
  }) async {
    if (isLoadingLiveChannels || (!reset && liveChannelsLoaded && liveChannelsCursor == null)) {
      return;
    }

    isLoadingLiveChannels = true;
    liveChannelsError = null;
    final preservedCursor = liveChannelsCursor;
    final tailStart = _liveChannelsFirstPageLength > liveChannels.length
        ? liveChannels.length
        : _liveChannelsFirstPageLength;
    final preservedTail = preserveTail
        ? liveChannels.skip(tailStart).toList(growable: false)
        : const <StreamChannel>[];
    if (reset && !preserveTail) {
      liveChannelsCursor = null;
    }

    try {
      final page = await apiCache.fetchLiveStreamsPage(
        cursor: reset ? null : liveChannelsCursor,
        refresh: refresh,
      );
      final usersById = await apiCache.fetchUsersByIds([
        for (final stream in page.data) stream.userId,
      ], refresh: refresh);
      final nextChannels = [
        for (final stream in page.data)
          if (usersById.containsKey(stream.userId))
            streamChannelFromStream(
              stream,
              avatarImageUrl: usersById[stream.userId]?.profileImageUrl,
            ),
      ];

      if (reset) {
        final firstPageChannels = _mergeLiveChannels(
          const <StreamChannel>[],
          nextChannels,
        );
        liveChannels = preserveTail
            ? _prependUniqueLiveChannels(firstPageChannels, preservedTail)
            : firstPageChannels;
        _liveChannelsFirstPageLength = firstPageChannels.length;
      } else {
        liveChannels = _mergeLiveChannels(liveChannels, nextChannels);
      }
      liveChannelsCursor = preserveTail && preservedTail.isNotEmpty
          ? preservedCursor
          : page.cursor;
      liveChannelsLoaded = true;
    } on Object catch (error) {
      liveChannelsError = browseErrorMessage(error);
    } finally {
      isLoadingLiveChannels = false;
    }
  }

  Future<void> refreshActiveSection() {
    if (selectedSection == BrowseSection.categories) {
      return loadCategories(reset: true, refresh: true);
    }
    return loadLiveChannels(reset: true, refresh: true);
  }

  Future<void> refreshCategoriesFirstPage() =>
      loadCategories(reset: true, refresh: true, preserveTail: true);

  Future<void> refreshLiveChannelsFirstPage() =>
      loadLiveChannels(reset: true, refresh: true, preserveTail: true);
}

List<BrowseCategory> _prependUniqueCategories(
  List<BrowseCategory> firstPage,
  List<BrowseCategory> tail,
) {
  final seen = <String>{};
  return [
    for (final category in firstPage.followedBy(tail))
      if (seen.add(category.id)) category,
  ];
}

List<BrowseCategory> _mergeCategories(
  List<BrowseCategory> current,
  List<BrowseCategory> next,
) {
  final merged = <BrowseCategory>[];
  final indicesById = <String, int>{};

  for (final category in current.followedBy(next)) {
    final existingIndex = indicesById[category.id];
    if (existingIndex == null) {
      indicesById[category.id] = merged.length;
      merged.add(category);
    } else {
      merged[existingIndex] = category;
    }
  }

  return merged;
}

List<StreamChannel> _prependUniqueLiveChannels(
  List<StreamChannel> firstPage,
  List<StreamChannel> tail,
) {
  final seen = <String>{};
  return [
    for (final channel in firstPage.followedBy(tail))
      if (seen.add(_liveChannelIdentity(channel))) channel,
  ];
}

List<StreamChannel> _mergeLiveChannels(
  List<StreamChannel> current,
  List<StreamChannel> next,
) {
  final merged = <StreamChannel>[];
  final indicesByIdentity = <String, int>{};

  for (final channel in current.followedBy(next)) {
    final identity = _liveChannelIdentity(channel);
    final existingIndex = indicesByIdentity[identity];
    if (existingIndex == null) {
      indicesByIdentity[identity] = merged.length;
      merged.add(channel);
    } else {
      merged[existingIndex] = channel;
    }
  }

  return merged;
}

String _liveChannelIdentity(StreamChannel channel) {
  final id = channel.id.trim();
  if (id.isNotEmpty) {
    return "id:$id";
  }
  final login = channel.login.trim().toLowerCase();
  if (login.isNotEmpty) {
    return "login:$login";
  }
  return "name:${channel.name.trim().toLowerCase()}";
}
