import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:mobx/mobx.dart";

part "player_store.g.dart";

class PlayerStore = PlayerStoreBase with _$PlayerStore;

abstract class PlayerStoreBase with Store {
  PlayerStoreBase({
    required this.apiCache,
    required this.login,
  });

  final TwitchApiCache apiCache;
  final String login;
  int _generation = 0;

  @observable
  TwitchLivePlayback? playback;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @computed
  bool get isInitialLoading => isLoading && playback == null;

  @action
  Future<TwitchLivePlayback?> load({bool refresh = false}) async {
    final generation = ++_generation;
    isLoading = true;
    errorMessage = null;

    try {
      final nextPlayback = await apiCache.fetchLivePlayback(
        login,
        refresh: refresh,
      );
      if (generation != _generation) {
        return null;
      }
      playback = nextPlayback;
      errorMessage = null;
      return nextPlayback;
    } on Object catch (error) {
      if (generation != _generation) {
        return null;
      }
      errorMessage = browseErrorMessage(error);
      return null;
    } finally {
      if (generation == _generation) {
        isLoading = false;
      }
    }
  }
}
