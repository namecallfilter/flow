import "dart:async";

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
        if (!_categoriesRefreshQueued) {
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
    } on Object catch (error) {
      categoriesError = browseErrorMessage(error);
    } finally {
      isLoadingCategories = false;
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
        if (!_liveChannelsRefreshQueued) {
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
        _liveChannelsFirstPageLength = firstPageChannels.length;
      } else {
        liveChannels = _mergeLiveChannels(liveChannels, nextChannels);
      }
      liveChannelsCursor = hasPreservedTail ? preservedCursor : page.cursor;
      liveChannelsLoaded = true;
    } on Object catch (error) {
      liveChannelsError = browseErrorMessage(error);
    } finally {
      isLoadingLiveChannels = false;
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
