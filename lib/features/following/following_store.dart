import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:mobx/mobx.dart";

part "following_store.g.dart";

enum TwitchSessionStatus {
  uninitialized,
  restoring,
  authenticated,
  loggedOut,
  restoreFailed,
}

class FollowingStore = FollowingStoreBase with _$FollowingStore;

abstract class FollowingStoreBase with Store {
  FollowingStoreBase({
    required this.authController,
    this.apiCache,
  });

  final TwitchAuthController authController;
  final TwitchApiCache? apiCache;
  bool _hasAttemptedSavedConnection = false;
  Future<void>? _savedConnectionLoad;
  Future<void>? _savedConnectionRefresh;
  int _sessionRevision = 0;

  @observable
  TwitchAuthConnection? connection;

  @observable
  TwitchSessionStatus sessionStatus = TwitchSessionStatus.uninitialized;

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

  @computed
  bool get isLoggedIn => connection != null;

  @action
  Future<void> loadSavedConnection({bool refresh = false}) async {
    final activeLoad = _savedConnectionLoad;
    if (activeLoad != null) {
      if (!refresh) {
        await activeLoad;
        return;
      }
      final activeRefresh = _savedConnectionRefresh;
      if (activeRefresh != null) {
        await activeRefresh;
        return;
      }

      final operation = Completer<void>();
      final operationFuture = operation.future;
      final revision = _sessionRevision;
      _savedConnectionRefresh = operationFuture;
      try {
        await activeLoad;
        if (revision != _sessionRevision) {
          return;
        }
        await loadSavedConnection(refresh: true);
      } finally {
        if (identical(_savedConnectionRefresh, operationFuture)) {
          _savedConnectionRefresh = null;
        }
        operation.complete();
      }
      return;
    }
    if (!refresh && (_hasAttemptedSavedConnection || connection != null)) {
      if (connection != null) {
        sessionStatus = TwitchSessionStatus.authenticated;
      }
      return;
    }
    final hadAttemptedSavedConnection = _hasAttemptedSavedConnection;
    final previousConnection = connection;
    _hasAttemptedSavedConnection = true;
    final operation = Completer<void>();
    final operationFuture = operation.future;
    final revision = ++_sessionRevision;
    _savedConnectionLoad = operationFuture;
    var didStartLoading = false;

    try {
      if (!authController.config.isConfigured) {
        connection = null;
        sessionStatus = TwitchSessionStatus.loggedOut;
        return;
      }

      if (connection == null && !hadAttemptedSavedConnection) {
        sessionStatus = TwitchSessionStatus.restoring;
      }
      isLoadingFollowing = true;
      didStartLoading = true;
      followingError = null;

      final savedConnection = await authController.loadSavedConnection();
      if (revision != _sessionRevision) {
        return;
      }
      if (hadAttemptedSavedConnection &&
          !_isSameTwitchSession(previousConnection, savedConnection)) {
        apiCache?.clear();
      }
      connection = savedConnection;
      sessionStatus = savedConnection == null
          ? TwitchSessionStatus.loggedOut
          : TwitchSessionStatus.authenticated;
      followingError = null;
    } on Object catch (error) {
      if (revision != _sessionRevision) {
        return;
      }
      followingError = error.toString();
      sessionStatus = connection == null
          ? TwitchSessionStatus.restoreFailed
          : TwitchSessionStatus.authenticated;
    } finally {
      if (didStartLoading && revision == _sessionRevision) {
        isLoadingFollowing = false;
      }
      if (identical(_savedConnectionLoad, operationFuture)) {
        _savedConnectionLoad = null;
      }
      operation.complete();
    }
  }

  @action
  void applyConnection(TwitchAuthConnection nextConnection) {
    _sessionRevision++;
    _savedConnectionRefresh = null;
    apiCache?.clear();
    _hasAttemptedSavedConnection = true;
    connection = nextConnection;
    sessionStatus = TwitchSessionStatus.authenticated;
    isLoadingFollowing = false;
    followingError = null;
  }

  @action
  Future<void> signOut() async {
    final revision = ++_sessionRevision;
    _savedConnectionRefresh = null;
    apiCache?.clear();
    _hasAttemptedSavedConnection = true;
    isLoadingFollowing = false;
    try {
      await authController.signOut();
    } on Object catch (error) {
      if (revision == _sessionRevision) {
        followingError = error.toString();
        sessionStatus = connection == null
            ? TwitchSessionStatus.restoreFailed
            : TwitchSessionStatus.authenticated;
      }
      rethrow;
    }
    if (revision != _sessionRevision) {
      return;
    }
    connection = null;
    sessionStatus = TwitchSessionStatus.loggedOut;
    followingError = null;
  }

  @action
  void toggleOfflineExpanded() {
    offlineExpandedOverride = !offlineExpanded;
  }
}

bool _isSameTwitchSession(
  TwitchAuthConnection? previous,
  TwitchAuthConnection? next,
) => previous?.user.id == next?.user.id;
