// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AppSettingsStore on AppSettingsStoreBase, Store {
  late final _$themeModeAtom = Atom(
    name: 'AppSettingsStoreBase.themeMode',
    context: context,
  );

  @override
  ThemeMode get themeMode {
    _$themeModeAtom.reportRead();
    return super.themeMode;
  }

  @override
  set themeMode(ThemeMode value) {
    _$themeModeAtom.reportWrite(value, super.themeMode, () {
      super.themeMode = value;
    });
  }

  late final _$isLoadedAtom = Atom(
    name: 'AppSettingsStoreBase.isLoaded',
    context: context,
  );

  @override
  bool get isLoaded {
    _$isLoadedAtom.reportRead();
    return super.isLoaded;
  }

  @override
  set isLoaded(bool value) {
    _$isLoadedAtom.reportWrite(value, super.isLoaded, () {
      super.isLoaded = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    'AppSettingsStoreBase.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$setThemeModeAsyncAction = AsyncAction(
    'AppSettingsStoreBase.setThemeMode',
    context: context,
  );

  @override
  Future<void> setThemeMode(ThemeMode mode) {
    return _$setThemeModeAsyncAction.run(() => super.setThemeMode(mode));
  }

  @override
  String toString() {
    return '''
themeMode: ${themeMode},
isLoaded: ${isLoaded}
    ''';
  }
}
