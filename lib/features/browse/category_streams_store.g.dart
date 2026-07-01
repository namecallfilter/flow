// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_streams_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CategoryStreamsStore on CategoryStreamsStoreBase, Store {
  late final _$channelsAtom = Atom(
    name: 'CategoryStreamsStoreBase.channels',
    context: context,
  );

  @override
  List<StreamChannel> get channels {
    _$channelsAtom.reportRead();
    return super.channels;
  }

  @override
  set channels(List<StreamChannel> value) {
    _$channelsAtom.reportWrite(value, super.channels, () {
      super.channels = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: 'CategoryStreamsStoreBase.isLoading',
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

  late final _$loadedAtom = Atom(
    name: 'CategoryStreamsStoreBase.loaded',
    context: context,
  );

  @override
  bool get loaded {
    _$loadedAtom.reportRead();
    return super.loaded;
  }

  @override
  set loaded(bool value) {
    _$loadedAtom.reportWrite(value, super.loaded, () {
      super.loaded = value;
    });
  }

  late final _$cursorAtom = Atom(
    name: 'CategoryStreamsStoreBase.cursor',
    context: context,
  );

  @override
  String? get cursor {
    _$cursorAtom.reportRead();
    return super.cursor;
  }

  @override
  set cursor(String? value) {
    _$cursorAtom.reportWrite(value, super.cursor, () {
      super.cursor = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: 'CategoryStreamsStoreBase.errorMessage',
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

  late final _$loadStreamsAsyncAction = AsyncAction(
    'CategoryStreamsStoreBase.loadStreams',
    context: context,
  );

  @override
  Future<void> loadStreams({bool reset = false, bool refresh = false}) {
    return _$loadStreamsAsyncAction.run(
      () => super.loadStreams(reset: reset, refresh: refresh),
    );
  }

  @override
  String toString() {
    return '''
channels: ${channels},
isLoading: ${isLoading},
loaded: ${loaded},
cursor: ${cursor},
errorMessage: ${errorMessage}
    ''';
  }
}
