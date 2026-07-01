// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tabs_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TabsStore on TabsStoreBase, Store {
  late final _$currentRouteAtom = Atom(
    name: 'TabsStoreBase.currentRoute',
    context: context,
  );

  @override
  String get currentRoute {
    _$currentRouteAtom.reportRead();
    return super.currentRoute;
  }

  @override
  set currentRoute(String value) {
    _$currentRouteAtom.reportWrite(value, super.currentRoute, () {
      super.currentRoute = value;
    });
  }

  late final _$activeSecondaryRouteAtom = Atom(
    name: 'TabsStoreBase.activeSecondaryRoute',
    context: context,
  );

  @override
  String? get activeSecondaryRoute {
    _$activeSecondaryRouteAtom.reportRead();
    return super.activeSecondaryRoute;
  }

  @override
  set activeSecondaryRoute(String? value) {
    _$activeSecondaryRouteAtom.reportWrite(
      value,
      super.activeSecondaryRoute,
      () {
        super.activeSecondaryRoute = value;
      },
    );
  }

  late final _$TabsStoreBaseActionController = ActionController(
    name: 'TabsStoreBase',
    context: context,
  );

  @override
  void setCurrentRoute(String routeName) {
    final _$actionInfo = _$TabsStoreBaseActionController.startAction(
      name: 'TabsStoreBase.setCurrentRoute',
    );
    try {
      return super.setCurrentRoute(routeName);
    } finally {
      _$TabsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setActiveSecondaryRoute(String? routeName) {
    final _$actionInfo = _$TabsStoreBaseActionController.startAction(
      name: 'TabsStoreBase.setActiveSecondaryRoute',
    );
    try {
      return super.setActiveSecondaryRoute(routeName);
    } finally {
      _$TabsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void returnToFollowing() {
    final _$actionInfo = _$TabsStoreBaseActionController.startAction(
      name: 'TabsStoreBase.returnToFollowing',
    );
    try {
      return super.returnToFollowing();
    } finally {
      _$TabsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentRoute: ${currentRoute},
activeSecondaryRoute: ${activeSecondaryRoute}
    ''';
  }
}
