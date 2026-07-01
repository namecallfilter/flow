import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:mobx/mobx.dart";

part "following_store.g.dart";

class FollowingStore = FollowingStoreBase with _$FollowingStore;

abstract class FollowingStoreBase with Store {
  FollowingStoreBase({
    required this.authController,
    this.apiCache,
  });

  final TwitchAuthController authController;
  final TwitchApiCache? apiCache;

  @observable
  TwitchAuthConnection? connection;

  @observable
  bool isLoadingFollowing = false;

  @observable
  String? followingError;

  @observable
  bool? offlineExpandedOverride;

  @computed
  List<StreamChannel> get liveChannels {
    final currentConnection = connection;
    return currentConnection == null
        ? const <StreamChannel>[]
        : liveChannelsFromConnection(currentConnection);
  }

  @computed
  List<OfflineChannel> get offlineChannels {
    final currentConnection = connection;
    return currentConnection == null
        ? const <OfflineChannel>[]
        : offlineChannelsFromConnection(currentConnection);
  }

  @computed
  TwitchUser? get profileUser {
    final currentConnection = connection;
    if (currentConnection == null) {
      return null;
    }
    return currentConnection.usersById[currentConnection.user.id] ?? currentConnection.user;
  }

  @computed
  bool get offlineExpanded => offlineExpandedOverride ?? liveChannels.isEmpty;

  @computed
  bool get showLiveEmptyState => liveChannels.isEmpty && offlineChannels.isEmpty;

  @action
  Future<void> loadSavedConnection({bool refresh = false}) async {
    if (!authController.config.isConfigured) {
      return;
    }
    if (!refresh && connection != null) {
      return;
    }

    if (refresh) {
      apiCache?.clear();
    }

    isLoadingFollowing = true;
    followingError = null;

    try {
      final savedConnection = await authController.loadSavedConnection();
      if (savedConnection != null) {
        connection = savedConnection;
      }
      followingError = null;
    } on Object catch (error) {
      followingError = error.toString();
    } finally {
      isLoadingFollowing = false;
    }
  }

  @action
  void applyConnection(TwitchAuthConnection nextConnection) {
    apiCache?.clear();
    connection = nextConnection;
    followingError = null;
  }

  @action
  void toggleOfflineExpanded() {
    offlineExpandedOverride = !offlineExpanded;
  }
}
