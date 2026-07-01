import "package:flow/app/routes.dart";
import "package:mobx/mobx.dart";

part "tabs_store.g.dart";

class TabsStore = TabsStoreBase with _$TabsStore;

abstract class TabsStoreBase with Store {
  TabsStoreBase({String initialRoute = FlowRoutes.following})
    : currentRoute = normalizeFlowRoute(initialRoute);

  @observable
  String currentRoute;

  @observable
  String? activeSecondaryRoute;

  @action
  void setCurrentRoute(String routeName) {
    final nextRoute = normalizeFlowRoute(routeName);
    if (currentRoute == nextRoute) {
      return;
    }

    currentRoute = nextRoute;
  }

  @action
  void setActiveSecondaryRoute(String? routeName) {
    activeSecondaryRoute = routeName == null ? null : normalizeFlowRoute(routeName);
  }

  @action
  void returnToFollowing() {
    activeSecondaryRoute = null;
    currentRoute = FlowRoutes.following;
  }
}

String normalizeFlowRoute(String routeName) => switch (routeName) {
  FlowRoutes.browse => FlowRoutes.browse,
  FlowRoutes.settings => FlowRoutes.settings,
  _ => FlowRoutes.following,
};
