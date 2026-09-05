import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:mobx/mobx.dart";

part "category_streams_store.g.dart";

class CategoryStreamsStore = CategoryStreamsStoreBase with _$CategoryStreamsStore;

abstract class CategoryStreamsStoreBase with Store {
  CategoryStreamsStoreBase({
    required this.apiCache,
    required this.category,
    this.preferences,
  });

  final TwitchApiCache apiCache;
  final BrowseCategory category;
  final FlowPreferences? preferences;
  Future<void>? _sortRestore;
  int _revision = 0;

  @observable
  StreamSort streamSort = StreamSort.viewersHighToLow;

  Future<void> restoreStreamSort() => _sortRestore ??= _restoreStreamSort();

  Future<void> _restoreStreamSort() async {
    final revision = _revision;
    try {
      final saved = await preferences?.readStreamSort("category");
      if (saved != null && revision == _revision) {
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
    _revision++;
    _sortRestore = Future<void>.value();
    streamSort = sort;
    isLoading = false;
    loaded = false;
    channels = const [];
    cursor = null;
    final load = loadStreams(reset: true);
    try {
      await preferences?.saveStreamSort("category", sort);
    } on Object {
      // Keep the selected order for this session if saving fails.
    }
    await load;
  }

  @observable
  List<StreamChannel> channels = const <StreamChannel>[];

  @observable
  bool isLoading = false;

  @observable
  bool loaded = false;

  @observable
  String? cursor;

  @observable
  String? errorMessage;

  @action
  Future<void> loadStreams({
    bool reset = false,
    bool refresh = false,
  }) async {
    if (preferences != null) {
      await restoreStreamSort();
    }
    if (isLoading && reset && refresh) {
      _revision++;
      isLoading = false;
    }
    if (isLoading || (!reset && loaded && cursor == null)) {
      return;
    }

    isLoading = true;
    final revision = _revision;
    errorMessage = null;
    try {
      final page = await apiCache.fetchLiveStreamsPage(
        sort: streamSort,
        gameIds: [category.id],
        cursor: reset ? null : cursor,
        refresh: refresh,
      );
      final missingAvatars = [
        for (final stream in page.data)
          if (stream.profileImageUrl == null) stream.userId,
      ];
      final usersById = missingAvatars.isEmpty
          ? const <String, TwitchUser>{}
          : await apiCache.fetchUsersByIds(missingAvatars, refresh: refresh);
      if (revision != _revision) {
        return;
      }
      final nextChannels = [
        for (final stream in page.data)
          streamChannelFromStream(
            stream,
            avatarImageUrl: usersById[stream.userId]?.profileImageUrl,
          ),
      ];

      channels = {
        if (!reset)
          for (final channel in channels) channel.id: channel,
        for (final channel in nextChannels) channel.id: channel,
      }.values.toList();
      cursor = page.cursor;
      loaded = true;
    } on Object catch (error) {
      if (revision == _revision) {
        errorMessage = browseErrorMessage(error);
      }
    } finally {
      if (revision == _revision) {
        isLoading = false;
      }
    }
  }
}
