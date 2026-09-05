import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:mobx/mobx.dart";

part "channel_store.g.dart";

class ChannelStore = ChannelStoreBase with _$ChannelStore;

abstract class ChannelStoreBase with Store {
  ChannelStoreBase({
    required this.apiCache,
    required this.login,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final TwitchApiCache apiCache;
  final String login;
  final DateTime Function() now;
  DateTime? loadedAt;
  int _generation = 0;
  final _loadedPastBroadcastCursors = <String>{};

  @observable
  TwitchChannelDetails? channel;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  bool isLoadingPastBroadcasts = false;

  @observable
  String? pastBroadcastsError;

  @computed
  bool get isInitialLoading => isLoading && channel == null;

  @computed
  bool get canLoadMorePastBroadcasts => channel?.pastBroadcastsCursor != null;

  @action
  Future<void> load({bool refresh = false}) async {
    final generation = ++_generation;
    isLoading = true;
    isLoadingPastBroadcasts = false;
    errorMessage = null;
    pastBroadcastsError = null;
    _loadedPastBroadcastCursors.clear();

    try {
      final nextChannel = await apiCache.fetchChannelDetails(
        login,
        refresh: refresh,
      );
      if (generation != _generation) {
        return;
      }
      loadedAt = now();
      channel = nextChannel;
      errorMessage = null;
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      errorMessage = browseErrorMessage(error);
    } finally {
      if (generation == _generation) {
        isLoading = false;
      }
    }
  }

  @action
  Future<void> loadMorePastBroadcasts() async {
    final currentChannel = channel;
    final cursor = currentChannel?.pastBroadcastsCursor;
    if (currentChannel == null ||
        cursor == null ||
        isLoadingPastBroadcasts ||
        _loadedPastBroadcastCursors.contains(cursor)) {
      return;
    }

    final generation = _generation;
    isLoadingPastBroadcasts = true;
    pastBroadcastsError = null;

    try {
      final nextPage = await apiCache.fetchChannelDetails(
        login,
        videosCursor: cursor,
      );
      if (generation != _generation || !identical(channel, currentChannel)) {
        return;
      }

      _loadedPastBroadcastCursors.add(cursor);
      final seenIds = {
        for (final broadcast in currentChannel.pastBroadcasts) broadcast.id,
      };
      final nextCursor = nextPage.pastBroadcastsCursor;
      channel = currentChannel.withPastBroadcasts(
        pastBroadcasts: [
          ...currentChannel.pastBroadcasts,
          for (final broadcast in nextPage.pastBroadcasts)
            if (seenIds.add(broadcast.id)) broadcast,
        ],
        pastBroadcastsCursor: nextCursor == null || _loadedPastBroadcastCursors.contains(nextCursor)
            ? null
            : nextCursor,
      );
    } on Object catch (error) {
      if (generation != _generation || !identical(channel, currentChannel)) {
        return;
      }
      pastBroadcastsError = browseErrorMessage(error);
    } finally {
      if (generation == _generation) {
        isLoadingPastBroadcasts = false;
      }
    }
  }
}
