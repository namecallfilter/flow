// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browse_search_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$BrowseSearchStore on BrowseSearchStoreBase, Store {
  late final _$channelsAtom = Atom(
    name: 'BrowseSearchStoreBase.channels',
    context: context,
  );

  @override
  List<TwitchSearchChannel> get channels {
    _$channelsAtom.reportRead();
    return super.channels;
  }

  @override
  set channels(List<TwitchSearchChannel> value) {
    _$channelsAtom.reportWrite(value, super.channels, () {
      super.channels = value;
    });
  }

  late final _$categoriesAtom = Atom(
    name: 'BrowseSearchStoreBase.categories',
    context: context,
  );

  @override
  List<BrowseCategory> get categories {
    _$categoriesAtom.reportRead();
    return super.categories;
  }

  @override
  set categories(List<BrowseCategory> value) {
    _$categoriesAtom.reportWrite(value, super.categories, () {
      super.categories = value;
    });
  }

  late final _$searchHistoryAtom = Atom(
    name: 'BrowseSearchStoreBase.searchHistory',
    context: context,
  );

  @override
  List<String> get searchHistory {
    _$searchHistoryAtom.reportRead();
    return super.searchHistory;
  }

  @override
  set searchHistory(List<String> value) {
    _$searchHistoryAtom.reportWrite(value, super.searchHistory, () {
      super.searchHistory = value;
    });
  }

  late final _$isSearchingAtom = Atom(
    name: 'BrowseSearchStoreBase.isSearching',
    context: context,
  );

  @override
  bool get isSearching {
    _$isSearchingAtom.reportRead();
    return super.isSearching;
  }

  @override
  set isSearching(bool value) {
    _$isSearchingAtom.reportWrite(value, super.isSearching, () {
      super.isSearching = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: 'BrowseSearchStoreBase.errorMessage',
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

  late final _$loadSearchHistoryAsyncAction = AsyncAction(
    'BrowseSearchStoreBase.loadSearchHistory',
    context: context,
  );

  @override
  Future<void> loadSearchHistory() {
    return _$loadSearchHistoryAsyncAction.run(() => super.loadSearchHistory());
  }

  late final _$clearSearchHistoryAsyncAction = AsyncAction(
    'BrowseSearchStoreBase.clearSearchHistory',
    context: context,
  );

  @override
  Future<void> clearSearchHistory() {
    return _$clearSearchHistoryAsyncAction.run(
      () => super.clearSearchHistory(),
    );
  }

  late final _$saveQueryToHistoryAsyncAction = AsyncAction(
    'BrowseSearchStoreBase.saveQueryToHistory',
    context: context,
  );

  @override
  Future<void> saveQueryToHistory(String query) {
    return _$saveQueryToHistoryAsyncAction.run(
      () => super.saveQueryToHistory(query),
    );
  }

  late final _$searchAsyncAction = AsyncAction(
    'BrowseSearchStoreBase.search',
    context: context,
  );

  @override
  Future<void> search(String query) {
    return _$searchAsyncAction.run(() => super.search(query));
  }

  late final _$BrowseSearchStoreBaseActionController = ActionController(
    name: 'BrowseSearchStoreBase',
    context: context,
  );

  @override
  void clearSearch() {
    final _$actionInfo = _$BrowseSearchStoreBaseActionController.startAction(
      name: 'BrowseSearchStoreBase.clearSearch',
    );
    try {
      return super.clearSearch();
    } finally {
      _$BrowseSearchStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
channels: ${channels},
categories: ${categories},
searchHistory: ${searchHistory},
isSearching: ${isSearching},
errorMessage: ${errorMessage}
    ''';
  }
}
