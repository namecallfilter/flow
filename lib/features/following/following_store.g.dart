// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'following_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FollowingStore on FollowingStoreBase, Store {
  Computed<List<StreamChannel>>? _$liveChannelsComputed;

  @override
  List<StreamChannel> get liveChannels =>
      (_$liveChannelsComputed ??= Computed<List<StreamChannel>>(
        () => super.liveChannels,
        name: 'FollowingStoreBase.liveChannels',
      )).value;
  Computed<List<OfflineChannel>>? _$offlineChannelsComputed;

  @override
  List<OfflineChannel> get offlineChannels =>
      (_$offlineChannelsComputed ??= Computed<List<OfflineChannel>>(
        () => super.offlineChannels,
        name: 'FollowingStoreBase.offlineChannels',
      )).value;
  Computed<TwitchUser?>? _$profileUserComputed;

  @override
  TwitchUser? get profileUser =>
      (_$profileUserComputed ??= Computed<TwitchUser?>(
        () => super.profileUser,
        name: 'FollowingStoreBase.profileUser',
      )).value;
  Computed<bool>? _$offlineExpandedComputed;

  @override
  bool get offlineExpanded => (_$offlineExpandedComputed ??= Computed<bool>(
    () => super.offlineExpanded,
    name: 'FollowingStoreBase.offlineExpanded',
  )).value;
  Computed<bool>? _$showLiveEmptyStateComputed;

  @override
  bool get showLiveEmptyState =>
      (_$showLiveEmptyStateComputed ??= Computed<bool>(
        () => super.showLiveEmptyState,
        name: 'FollowingStoreBase.showLiveEmptyState',
      )).value;

  late final _$connectionAtom = Atom(
    name: 'FollowingStoreBase.connection',
    context: context,
  );

  @override
  TwitchAuthConnection? get connection {
    _$connectionAtom.reportRead();
    return super.connection;
  }

  @override
  set connection(TwitchAuthConnection? value) {
    _$connectionAtom.reportWrite(value, super.connection, () {
      super.connection = value;
    });
  }

  late final _$isLoadingFollowingAtom = Atom(
    name: 'FollowingStoreBase.isLoadingFollowing',
    context: context,
  );

  @override
  bool get isLoadingFollowing {
    _$isLoadingFollowingAtom.reportRead();
    return super.isLoadingFollowing;
  }

  @override
  set isLoadingFollowing(bool value) {
    _$isLoadingFollowingAtom.reportWrite(value, super.isLoadingFollowing, () {
      super.isLoadingFollowing = value;
    });
  }

  late final _$followingErrorAtom = Atom(
    name: 'FollowingStoreBase.followingError',
    context: context,
  );

  @override
  String? get followingError {
    _$followingErrorAtom.reportRead();
    return super.followingError;
  }

  @override
  set followingError(String? value) {
    _$followingErrorAtom.reportWrite(value, super.followingError, () {
      super.followingError = value;
    });
  }

  late final _$offlineExpandedOverrideAtom = Atom(
    name: 'FollowingStoreBase.offlineExpandedOverride',
    context: context,
  );

  @override
  bool? get offlineExpandedOverride {
    _$offlineExpandedOverrideAtom.reportRead();
    return super.offlineExpandedOverride;
  }

  @override
  set offlineExpandedOverride(bool? value) {
    _$offlineExpandedOverrideAtom.reportWrite(
      value,
      super.offlineExpandedOverride,
      () {
        super.offlineExpandedOverride = value;
      },
    );
  }

  late final _$loadSavedConnectionAsyncAction = AsyncAction(
    'FollowingStoreBase.loadSavedConnection',
    context: context,
  );

  @override
  Future<void> loadSavedConnection({bool refresh = false}) {
    return _$loadSavedConnectionAsyncAction.run(
      () => super.loadSavedConnection(refresh: refresh),
    );
  }

  late final _$FollowingStoreBaseActionController = ActionController(
    name: 'FollowingStoreBase',
    context: context,
  );

  @override
  void applyConnection(TwitchAuthConnection nextConnection) {
    final _$actionInfo = _$FollowingStoreBaseActionController.startAction(
      name: 'FollowingStoreBase.applyConnection',
    );
    try {
      return super.applyConnection(nextConnection);
    } finally {
      _$FollowingStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleOfflineExpanded() {
    final _$actionInfo = _$FollowingStoreBaseActionController.startAction(
      name: 'FollowingStoreBase.toggleOfflineExpanded',
    );
    try {
      return super.toggleOfflineExpanded();
    } finally {
      _$FollowingStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
connection: ${connection},
isLoadingFollowing: ${isLoadingFollowing},
followingError: ${followingError},
offlineExpandedOverride: ${offlineExpandedOverride},
liveChannels: ${liveChannels},
offlineChannels: ${offlineChannels},
profileUser: ${profileUser},
offlineExpanded: ${offlineExpanded},
showLiveEmptyState: ${showLiveEmptyState}
    ''';
  }
}
