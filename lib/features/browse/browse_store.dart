import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:mobx/mobx.dart";

part "browse_store.g.dart";

enum BrowseSection { categories, liveChannels }

class BrowseStore = BrowseStoreBase with _$BrowseStore;

abstract class BrowseStoreBase with Store {
  BrowseStoreBase({required this.apiCache, this.preferences});

  final TwitchApiCache apiCache;
  final FlowPreferences? preferences;
  Future<void>? _sortRestore;
  Future<void>? _categorySortRestore;
  int _categoriesRevision = 0;
  int _liveChannelsRevision = 0;
  int _categoriesFirstPageLength = 0;
  Set<String> _liveChannelsFirstPageIds = {};
  Future<void>? _categoriesLoad;
  bool _categoriesRefreshQueued = false;
  bool _categoriesQueuedPreserveTail = true;
  Future<void>? _liveChannelsLoad;
  bool _liveChannelsRefreshQueued = false;
  bool _liveChannelsQueuedPreserveTail = true;

  @observable
  List<BrowseCategory> categories = const <BrowseCategory>[];

  @observable
  List<StreamChannel> liveChannels = const <StreamChannel>[];

  @observable
  BrowseSection selectedSection = BrowseSection.categories;

  @observable
  StreamSort streamSort = StreamSort.viewersHighToLow;

  @observable
  CategorySort categorySort = CategorySort.viewersHighToLow;

  Future<void> restoreCategorySort() => _categorySortRestore ??= _restoreCategorySort();

  Future<void> _restoreCategorySort() async {
    final revision = _categoriesRevision;
    try {
      final saved = await preferences?.readCategorySort();
      if (saved != null && revision == _categoriesRevision) {
        runInAction(() => categorySort = saved);
      }
    } on Object {
      // An unavailable preference store must not block browsing.
    }
  }

  @action
  Future<void> selectCategorySort(CategorySort sort) async {
    if (sort == categorySort) {
      return;
    }
    _categoriesRevision++;
    _categorySortRestore = Future<void>.value();
    categorySort = sort;
    _categoriesLoad = null;
    _categoriesRefreshQueued = false;
    isLoadingCategories = false;
    categoriesLoaded = false;
    categories = const [];
    categoriesCursor = null;
    categoriesScrollOffset = 0;
    _categoriesFirstPageLength = 0;
    final load = loadCategories(reset: true);
    try {
      await preferences?.saveCategorySort(sort);
    } on Object {
      // Keep the selected order for this session if saving fails.
    }
    await load;
  }

  Future<void> restoreStreamSort() => _sortRestore ??= _restoreStreamSort();

  Future<void> _restoreStreamSort() async {
    final revision = _liveChannelsRevision;
    try {
      final saved = await preferences?.readStreamSort("browse");
      if (saved != null && revision == _liveChannelsRevision) {
        runInAction(() => streamSort = saved);
      }
    } on Object {
      // An unavailable preference store must not block browsing.
    }
  }

  @action
  Future<void> selectStreamSort(StreamSort sort) async {
    if (sort == streamSort) {
      return;
    }
    _liveChannelsRevision++;
    _sortRestore = Future<void>.value();
    streamSort = sort;
    _liveChannelsLoad = null;
    _liveChannelsRefreshQueued = false;
    isLoadingLiveChannels = false;
    liveChannelsLoaded = false;
    liveChannels = const [];
    liveChannelsCursor = null;
    liveChannelsScrollOffset = 0;
    _liveChannelsFirstPageIds = {};
    final load = loadLiveChannels(reset: true);
    try {
      await preferences?.saveStreamSort("browse", sort);
    } on Object {
      // Keep the selected order for this session if saving fails.
    }
    await load;
  }

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
    if (preferences != null) {
      await restoreCategorySort();
    }
    final activeLoad = _categoriesLoad;
    if (activeLoad != null) {
      if (refresh) {
        _queueCategoriesRefresh(preserveTail: preserveTail);
      }
      await activeLoad;
      return;
    }
    if (isLoadingCategories || (!reset && categoriesLoaded && categoriesCursor == null)) {
      return;
    }

    final operation = Completer<void>();
    final operationFuture = operation.future;
    _categoriesLoad = operationFuture;
    final revision = _categoriesRevision;
    var nextReset = reset;
    var nextRefresh = refresh;
    var nextPreserveTail = preserveTail;

    try {
      while (true) {
        await _loadCategoriesOnce(
          reset: nextReset,
          refresh: nextRefresh,
          preserveTail: nextPreserveTail,
        );
        if (revision != _categoriesRevision || !_categoriesRefreshQueued) {
          break;
        }

        nextReset = true;
        nextRefresh = true;
        nextPreserveTail = _categoriesQueuedPreserveTail;
        _categoriesRefreshQueued = false;
        _categoriesQueuedPreserveTail = true;
      }
    } finally {
      if (identical(_categoriesLoad, operationFuture)) {
        _categoriesLoad = null;
      }
      operation.complete();
    }
  }

  Future<void> _loadCategoriesOnce({
    required bool reset,
    required bool refresh,
    required bool preserveTail,
  }) async {
    final revision = _categoriesRevision;
    final prefetchNextPage = !categoriesLoaded && categorySort == CategorySort.recommendedForYou;
    isLoadingCategories = true;
    categoriesError = null;
    final preservedCursor = categoriesCursor;
    final tailStart = _categoriesFirstPageLength > categories.length
        ? categories.length
        : _categoriesFirstPageLength;
    final preservedTail = preserveTail
        ? categories.skip(tailStart).toList(growable: false)
        : const <BrowseCategory>[];
    try {
      final page = await apiCache.fetchTopCategoriesPage(
        sort: categorySort,
        cursor: reset ? null : categoriesCursor,
        refresh: refresh,
      );
      if (revision != _categoriesRevision) {
        return;
      }
      final nextCategories = [
        for (final category in page.data) browseCategoryFromApi(category),
      ];
      var hasPreservedTail = false;

      if (reset) {
        final firstPageCategories = _mergeCategories(
          const <BrowseCategory>[],
          nextCategories,
        );
        categories = preserveTail
            ? _prependUniqueCategories(firstPageCategories, preservedTail)
            : firstPageCategories;
        hasPreservedTail = categories.length > firstPageCategories.length;
        _categoriesFirstPageLength = firstPageCategories.length;
      } else {
        categories = _mergeCategories(categories, nextCategories);
      }
      categoriesCursor = hasPreservedTail ? preservedCursor : page.cursor;
      categoriesLoaded = true;
      if (prefetchNextPage && page.cursor != null) {
        apiCache.fetchTopCategoriesPage(sort: categorySort, cursor: page.cursor).ignore();
      }
    } on Object catch (error) {
      if (revision == _categoriesRevision) {
        categoriesError = browseErrorMessage(error);
      }
    } finally {
      if (revision == _categoriesRevision) {
        isLoadingCategories = false;
      }
    }
  }

  void _queueCategoriesRefresh({required bool preserveTail}) {
    _categoriesQueuedPreserveTail = _categoriesRefreshQueued
        ? _categoriesQueuedPreserveTail && preserveTail
        : preserveTail;
    _categoriesRefreshQueued = true;
  }

  @action
  Future<void> loadLiveChannels({
    bool reset = false,
    bool refresh = false,
    bool preserveTail = false,
  }) async {
    if (preferences != null) {
      await restoreStreamSort();
    }
    final activeLoad = _liveChannelsLoad;
    if (activeLoad != null) {
      if (refresh) {
        _queueLiveChannelsRefresh(preserveTail: preserveTail);
      }
      await activeLoad;
      return;
    }
    if (isLoadingLiveChannels || (!reset && liveChannelsLoaded && liveChannelsCursor == null)) {
      return;
    }

    final operation = Completer<void>();
    final operationFuture = operation.future;
    _liveChannelsLoad = operationFuture;
    final revision = _liveChannelsRevision;
    var nextReset = reset;
    var nextRefresh = refresh;
    var nextPreserveTail = preserveTail;

    try {
      while (true) {
        await _loadLiveChannelsOnce(
          reset: nextReset,
          refresh: nextRefresh,
          preserveTail: nextPreserveTail,
        );
        if (revision != _liveChannelsRevision || !_liveChannelsRefreshQueued) {
          break;
        }

        nextReset = true;
        nextRefresh = true;
        nextPreserveTail = _liveChannelsQueuedPreserveTail;
        _liveChannelsRefreshQueued = false;
        _liveChannelsQueuedPreserveTail = true;
      }
    } finally {
      if (identical(_liveChannelsLoad, operationFuture)) {
        _liveChannelsLoad = null;
      }
      operation.complete();
    }
  }

  Future<void> _loadLiveChannelsOnce({
    required bool reset,
    required bool refresh,
    required bool preserveTail,
  }) async {
    final revision = _liveChannelsRevision;
    final prefetchNextPage = !liveChannelsLoaded && streamSort == StreamSort.recommendedForYou;
    isLoadingLiveChannels = true;
    liveChannelsError = null;
    final preservedCursor = liveChannelsCursor;
    final preservedTail = preserveTail
        ? liveChannels
              .where(
                (channel) => !_liveChannelsFirstPageIds.contains(_liveChannelIdentity(channel)),
              )
              .toList(growable: false)
        : const <StreamChannel>[];
    try {
      final page = await apiCache.fetchLiveStreamsPage(
        sort: streamSort,
        cursor: reset ? null : liveChannelsCursor,
        refresh: refresh,
      );
      final missingAvatars = [
        for (final stream in page.data)
          if (stream.profileImageUrl == null) stream.userId,
      ];
      final usersById = missingAvatars.isEmpty
          ? const <String, TwitchUser>{}
          : await apiCache.fetchUsersByIds(missingAvatars, refresh: refresh);
      if (revision != _liveChannelsRevision) {
        return;
      }
      final nextChannels = [
        for (final stream in page.data)
          streamChannelFromStream(
            stream,
            avatarImageUrl: usersById[stream.userId]?.profileImageUrl,
          ),
      ];
      var hasPreservedTail = false;

      if (reset) {
        final firstPageChannels = _mergeLiveChannels(
          const <StreamChannel>[],
          nextChannels,
        );
        liveChannels = preserveTail
            ? _prependUniqueLiveChannels(firstPageChannels, preservedTail)
            : firstPageChannels;
        hasPreservedTail = liveChannels.length > firstPageChannels.length;
        _liveChannelsFirstPageIds = firstPageChannels.map(_liveChannelIdentity).toSet();
      } else {
        liveChannels = _mergeLiveChannels(liveChannels, nextChannels);
      }
      // Twitch's ranking can lag behind the viewer counts returned with each row.
      liveChannels = sortedStreamChannels(liveChannels, streamSort);
      liveChannelsCursor = hasPreservedTail ? preservedCursor : page.cursor;
      liveChannelsLoaded = true;
      if (prefetchNextPage && page.cursor != null) {
        apiCache.fetchLiveStreamsPage(sort: streamSort, cursor: page.cursor).ignore();
      }
    } on Object catch (error) {
      if (revision == _liveChannelsRevision) {
        liveChannelsError = browseErrorMessage(error);
      }
    } finally {
      if (revision == _liveChannelsRevision) {
        isLoadingLiveChannels = false;
      }
    }
  }

  void _queueLiveChannelsRefresh({required bool preserveTail}) {
    _liveChannelsQueuedPreserveTail = _liveChannelsRefreshQueued
        ? _liveChannelsQueuedPreserveTail && preserveTail
        : preserveTail;
    _liveChannelsRefreshQueued = true;
  }

  Future<void> refreshActiveSection() {
    if (selectedSection == BrowseSection.categories) {
      return loadCategories(reset: true, refresh: true);
    }
    return loadLiveChannels(reset: true, refresh: true);
  }

  Future<void> refreshCategoriesFirstPage() {
    if (categorySort == CategorySort.recommendedForYou && categoriesLoaded) {
      return Future<void>.value();
    }
    return loadCategories(reset: true, refresh: true, preserveTail: true);
  }

  Future<void> refreshLiveChannelsFirstPage() {
    // Keep a recommendation feed's continuation snapshot until an explicit refresh.
    if (streamSort == StreamSort.recommendedForYou && liveChannelsLoaded) {
      return Future<void>.value();
    }
    return loadLiveChannels(reset: true, refresh: true, preserveTail: true);
  }
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
) => {
  for (final category in current.followedBy(next)) category.id: category,
}.values.toList();

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
) => {
  for (final channel in current.followedBy(next)) _liveChannelIdentity(channel): channel,
}.values.toList();

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
