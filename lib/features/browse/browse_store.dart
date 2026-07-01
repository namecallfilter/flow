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
  }) async {
    if (isLoadingCategories || (!reset && categoriesLoaded && categoriesCursor == null)) {
      return;
    }

    isLoadingCategories = true;
    categoriesError = null;
    if (reset) {
      categoriesCursor = null;
    }

    try {
      final page = await apiCache.fetchTopCategoriesPage(
        cursor: reset ? null : categoriesCursor,
        refresh: refresh,
      );
      final nextCategories = await Future.wait([
        for (final category in page.data)
          browseCategoryFromApi(apiCache, category, refresh: refresh),
      ]);

      categories = reset ? nextCategories : [...categories, ...nextCategories];
      categoriesCursor = page.cursor;
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
  }) async {
    if (isLoadingLiveChannels || (!reset && liveChannelsLoaded && liveChannelsCursor == null)) {
      return;
    }

    isLoadingLiveChannels = true;
    liveChannelsError = null;
    if (reset) {
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

      liveChannels = reset ? nextChannels : [...liveChannels, ...nextChannels];
      liveChannelsCursor = page.cursor;
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
}
