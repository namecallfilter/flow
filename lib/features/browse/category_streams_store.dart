import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:mobx/mobx.dart";

part "category_streams_store.g.dart";

class CategoryStreamsStore = CategoryStreamsStoreBase with _$CategoryStreamsStore;

abstract class CategoryStreamsStoreBase with Store {
  CategoryStreamsStoreBase({
    required this.apiCache,
    required this.category,
  });

  final TwitchApiCache apiCache;
  final BrowseCategory category;

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
    if (isLoading || (!reset && loaded && cursor == null)) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    if (reset) {
      cursor = null;
    }

    try {
      final page = await apiCache.fetchLiveStreamsPage(
        gameIds: [category.id],
        cursor: reset ? null : cursor,
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

      channels = reset ? nextChannels : [...channels, ...nextChannels];
      cursor = page.cursor;
      loaded = true;
    } on Object catch (error) {
      errorMessage = browseErrorMessage(error);
    } finally {
      isLoading = false;
    }
  }
}
