import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:mobx/mobx.dart";

part "browse_search_store.g.dart";

class BrowseSearchStore = BrowseSearchStoreBase with _$BrowseSearchStore;

abstract class BrowseSearchStoreBase with Store {
  BrowseSearchStoreBase({
    required this.apiCache,
    required this.preferences,
  });

  final TwitchApiCache apiCache;
  final FlowPreferences preferences;
  int _searchGeneration = 0;

  @observable
  List<TwitchSearchChannel> channels = const <TwitchSearchChannel>[];

  @observable
  List<BrowseCategory> categories = const <BrowseCategory>[];

  @observable
  List<String> searchHistory = const <String>[];

  @observable
  bool isSearching = false;

  @observable
  String? errorMessage;

  @action
  Future<void> loadSearchHistory() async {
    if (searchHistory.isNotEmpty) {
      return;
    }

    searchHistory = await preferences.readBrowseSearchHistory();
  }

  @action
  void clearSearch() {
    _searchGeneration++;
    channels = const <TwitchSearchChannel>[];
    categories = const <BrowseCategory>[];
    isSearching = false;
    errorMessage = null;
  }

  @action
  Future<void> clearSearchHistory() async {
    searchHistory = const <String>[];
    await preferences.clearBrowseSearchHistory();
  }

  @action
  Future<void> saveQueryToHistory(String query) async {
    final nextHistory = updatedSearchHistory(query);
    searchHistory = nextHistory;
    await preferences.saveBrowseSearchHistory(nextHistory);
  }

  @action
  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    _searchGeneration++;
    final generation = _searchGeneration;
    if (normalizedQuery.isEmpty) {
      clearSearch();
      return;
    }

    isSearching = true;
    errorMessage = null;

    try {
      final channelPage = await apiCache.searchChannelsPage(normalizedQuery, first: 8);
      final categoryPage = await apiCache.searchCategoriesPage(normalizedQuery, first: 8);
      final validUsersById = await apiCache.fetchUsersByIds([
        for (final channel in channelPage.data) channel.id,
      ]);
      final liveSearchStreams = await apiCache.fetchLiveStreamsPage(
        first: 100,
        userLogins: [
          for (final channel in channelPage.data)
            if (channel.isLive && validUsersById.containsKey(channel.id)) channel.broadcasterLogin,
        ],
      );
      final liveViewerCountsByLogin = {
        for (final stream in liveSearchStreams.data)
          stream.userLogin.toLowerCase(): stream.viewerCount,
      };
      final nextChannels =
          [
            for (final channel in channelPage.data)
              if (validUsersById.containsKey(channel.id)) channel,
          ]..sort((left, right) {
            if (left.isLive == right.isLive) {
              final leftViewers = liveViewerCountsByLogin[left.broadcasterLogin.toLowerCase()] ?? 0;
              final rightViewers =
                  liveViewerCountsByLogin[right.broadcasterLogin.toLowerCase()] ?? 0;
              final viewerComparison = rightViewers.compareTo(leftViewers);
              if (viewerComparison != 0) {
                return viewerComparison;
              }
              return left.displayName.toLowerCase().compareTo(
                right.displayName.toLowerCase(),
              );
            }
            return left.isLive ? -1 : 1;
          });
      final nextCategories =
          await Future.wait([
              for (final category in categoryPage.data) browseCategoryFromApi(apiCache, category),
            ])
            ..sort((left, right) {
              final viewerComparison = right.viewerCount.compareTo(left.viewerCount);
              if (viewerComparison != 0) {
                return viewerComparison;
              }
              return left.name.toLowerCase().compareTo(right.name.toLowerCase());
            });

      if (generation != _searchGeneration) {
        return;
      }

      channels = nextChannels;
      categories = nextCategories;
      isSearching = false;
      await saveQueryToHistory(normalizedQuery);
    } on Object catch (error) {
      if (generation != _searchGeneration) {
        return;
      }

      errorMessage = browseErrorMessage(error);
      isSearching = false;
    }
  }

  List<String> updatedSearchHistory(String query) =>
      normalizeBrowseSearchHistory([query, ...searchHistory]);
}
