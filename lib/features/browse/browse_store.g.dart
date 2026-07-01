// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browse_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$BrowseStore on BrowseStoreBase, Store {
  Computed<bool>? _$activeLoadingComputed;

  @override
  bool get activeLoading => (_$activeLoadingComputed ??= Computed<bool>(
    () => super.activeLoading,
    name: 'BrowseStoreBase.activeLoading',
  )).value;
  Computed<bool>? _$activeItemsEmptyComputed;

  @override
  bool get activeItemsEmpty => (_$activeItemsEmptyComputed ??= Computed<bool>(
    () => super.activeItemsEmpty,
    name: 'BrowseStoreBase.activeItemsEmpty',
  )).value;
  Computed<String?>? _$activeErrorComputed;

  @override
  String? get activeError => (_$activeErrorComputed ??= Computed<String?>(
    () => super.activeError,
    name: 'BrowseStoreBase.activeError',
  )).value;

  late final _$categoriesAtom = Atom(
    name: 'BrowseStoreBase.categories',
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

  late final _$liveChannelsAtom = Atom(
    name: 'BrowseStoreBase.liveChannels',
    context: context,
  );

  @override
  List<StreamChannel> get liveChannels {
    _$liveChannelsAtom.reportRead();
    return super.liveChannels;
  }

  @override
  set liveChannels(List<StreamChannel> value) {
    _$liveChannelsAtom.reportWrite(value, super.liveChannels, () {
      super.liveChannels = value;
    });
  }

  late final _$selectedSectionAtom = Atom(
    name: 'BrowseStoreBase.selectedSection',
    context: context,
  );

  @override
  BrowseSection get selectedSection {
    _$selectedSectionAtom.reportRead();
    return super.selectedSection;
  }

  @override
  set selectedSection(BrowseSection value) {
    _$selectedSectionAtom.reportWrite(value, super.selectedSection, () {
      super.selectedSection = value;
    });
  }

  late final _$categoriesLoadedAtom = Atom(
    name: 'BrowseStoreBase.categoriesLoaded',
    context: context,
  );

  @override
  bool get categoriesLoaded {
    _$categoriesLoadedAtom.reportRead();
    return super.categoriesLoaded;
  }

  @override
  set categoriesLoaded(bool value) {
    _$categoriesLoadedAtom.reportWrite(value, super.categoriesLoaded, () {
      super.categoriesLoaded = value;
    });
  }

  late final _$liveChannelsLoadedAtom = Atom(
    name: 'BrowseStoreBase.liveChannelsLoaded',
    context: context,
  );

  @override
  bool get liveChannelsLoaded {
    _$liveChannelsLoadedAtom.reportRead();
    return super.liveChannelsLoaded;
  }

  @override
  set liveChannelsLoaded(bool value) {
    _$liveChannelsLoadedAtom.reportWrite(value, super.liveChannelsLoaded, () {
      super.liveChannelsLoaded = value;
    });
  }

  late final _$isLoadingCategoriesAtom = Atom(
    name: 'BrowseStoreBase.isLoadingCategories',
    context: context,
  );

  @override
  bool get isLoadingCategories {
    _$isLoadingCategoriesAtom.reportRead();
    return super.isLoadingCategories;
  }

  @override
  set isLoadingCategories(bool value) {
    _$isLoadingCategoriesAtom.reportWrite(value, super.isLoadingCategories, () {
      super.isLoadingCategories = value;
    });
  }

  late final _$isLoadingLiveChannelsAtom = Atom(
    name: 'BrowseStoreBase.isLoadingLiveChannels',
    context: context,
  );

  @override
  bool get isLoadingLiveChannels {
    _$isLoadingLiveChannelsAtom.reportRead();
    return super.isLoadingLiveChannels;
  }

  @override
  set isLoadingLiveChannels(bool value) {
    _$isLoadingLiveChannelsAtom.reportWrite(
      value,
      super.isLoadingLiveChannels,
      () {
        super.isLoadingLiveChannels = value;
      },
    );
  }

  late final _$categoriesCursorAtom = Atom(
    name: 'BrowseStoreBase.categoriesCursor',
    context: context,
  );

  @override
  String? get categoriesCursor {
    _$categoriesCursorAtom.reportRead();
    return super.categoriesCursor;
  }

  @override
  set categoriesCursor(String? value) {
    _$categoriesCursorAtom.reportWrite(value, super.categoriesCursor, () {
      super.categoriesCursor = value;
    });
  }

  late final _$liveChannelsCursorAtom = Atom(
    name: 'BrowseStoreBase.liveChannelsCursor',
    context: context,
  );

  @override
  String? get liveChannelsCursor {
    _$liveChannelsCursorAtom.reportRead();
    return super.liveChannelsCursor;
  }

  @override
  set liveChannelsCursor(String? value) {
    _$liveChannelsCursorAtom.reportWrite(value, super.liveChannelsCursor, () {
      super.liveChannelsCursor = value;
    });
  }

  late final _$categoriesErrorAtom = Atom(
    name: 'BrowseStoreBase.categoriesError',
    context: context,
  );

  @override
  String? get categoriesError {
    _$categoriesErrorAtom.reportRead();
    return super.categoriesError;
  }

  @override
  set categoriesError(String? value) {
    _$categoriesErrorAtom.reportWrite(value, super.categoriesError, () {
      super.categoriesError = value;
    });
  }

  late final _$liveChannelsErrorAtom = Atom(
    name: 'BrowseStoreBase.liveChannelsError',
    context: context,
  );

  @override
  String? get liveChannelsError {
    _$liveChannelsErrorAtom.reportRead();
    return super.liveChannelsError;
  }

  @override
  set liveChannelsError(String? value) {
    _$liveChannelsErrorAtom.reportWrite(value, super.liveChannelsError, () {
      super.liveChannelsError = value;
    });
  }

  late final _$categoriesScrollOffsetAtom = Atom(
    name: 'BrowseStoreBase.categoriesScrollOffset',
    context: context,
  );

  @override
  double get categoriesScrollOffset {
    _$categoriesScrollOffsetAtom.reportRead();
    return super.categoriesScrollOffset;
  }

  @override
  set categoriesScrollOffset(double value) {
    _$categoriesScrollOffsetAtom.reportWrite(
      value,
      super.categoriesScrollOffset,
      () {
        super.categoriesScrollOffset = value;
      },
    );
  }

  late final _$liveChannelsScrollOffsetAtom = Atom(
    name: 'BrowseStoreBase.liveChannelsScrollOffset',
    context: context,
  );

  @override
  double get liveChannelsScrollOffset {
    _$liveChannelsScrollOffsetAtom.reportRead();
    return super.liveChannelsScrollOffset;
  }

  @override
  set liveChannelsScrollOffset(double value) {
    _$liveChannelsScrollOffsetAtom.reportWrite(
      value,
      super.liveChannelsScrollOffset,
      () {
        super.liveChannelsScrollOffset = value;
      },
    );
  }

  late final _$loadCategoriesAsyncAction = AsyncAction(
    'BrowseStoreBase.loadCategories',
    context: context,
  );

  @override
  Future<void> loadCategories({bool reset = false, bool refresh = false}) {
    return _$loadCategoriesAsyncAction.run(
      () => super.loadCategories(reset: reset, refresh: refresh),
    );
  }

  late final _$loadLiveChannelsAsyncAction = AsyncAction(
    'BrowseStoreBase.loadLiveChannels',
    context: context,
  );

  @override
  Future<void> loadLiveChannels({bool reset = false, bool refresh = false}) {
    return _$loadLiveChannelsAsyncAction.run(
      () => super.loadLiveChannels(reset: reset, refresh: refresh),
    );
  }

  late final _$BrowseStoreBaseActionController = ActionController(
    name: 'BrowseStoreBase',
    context: context,
  );

  @override
  void setScrollOffsetFor(BrowseSection section, double offset) {
    final _$actionInfo = _$BrowseStoreBaseActionController.startAction(
      name: 'BrowseStoreBase.setScrollOffsetFor',
    );
    try {
      return super.setScrollOffsetFor(section, offset);
    } finally {
      _$BrowseStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectSection(BrowseSection? section) {
    final _$actionInfo = _$BrowseStoreBaseActionController.startAction(
      name: 'BrowseStoreBase.selectSection',
    );
    try {
      return super.selectSection(section);
    } finally {
      _$BrowseStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
categories: ${categories},
liveChannels: ${liveChannels},
selectedSection: ${selectedSection},
categoriesLoaded: ${categoriesLoaded},
liveChannelsLoaded: ${liveChannelsLoaded},
isLoadingCategories: ${isLoadingCategories},
isLoadingLiveChannels: ${isLoadingLiveChannels},
categoriesCursor: ${categoriesCursor},
liveChannelsCursor: ${liveChannelsCursor},
categoriesError: ${categoriesError},
liveChannelsError: ${liveChannelsError},
categoriesScrollOffset: ${categoriesScrollOffset},
liveChannelsScrollOffset: ${liveChannelsScrollOffset},
activeLoading: ${activeLoading},
activeItemsEmpty: ${activeItemsEmpty},
activeError: ${activeError}
    ''';
  }
}
