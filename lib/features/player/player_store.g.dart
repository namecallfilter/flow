// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerStore on PlayerStoreBase, Store {
  Computed<bool>? _$isInitialLoadingComputed;

  @override
  bool get isInitialLoading => (_$isInitialLoadingComputed ??= Computed<bool>(
    () => super.isInitialLoading,
    name: 'PlayerStoreBase.isInitialLoading',
  )).value;

  late final _$playbackAtom = Atom(
    name: 'PlayerStoreBase.playback',
    context: context,
  );

  @override
  TwitchLivePlayback? get playback {
    _$playbackAtom.reportRead();
    return super.playback;
  }

  @override
  set playback(TwitchLivePlayback? value) {
    _$playbackAtom.reportWrite(value, super.playback, () {
      super.playback = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: 'PlayerStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: 'PlayerStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    'PlayerStoreBase.load',
    context: context,
  );

  @override
  Future<TwitchLivePlayback?> load({bool refresh = false}) {
    return _$loadAsyncAction.run(() => super.load(refresh: refresh));
  }

  @override
  String toString() {
    return '''
playback: ${playback},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
isInitialLoading: ${isInitialLoading}
    ''';
  }
}
