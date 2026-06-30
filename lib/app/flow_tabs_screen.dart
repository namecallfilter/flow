import "dart:async";

import "package:flow/api/twitch_auth.dart";
import "package:flow/app/routes.dart";
import "package:flow/features/browse/browse_screen.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class FlowTabsScreen extends StatefulWidget {
  const FlowTabsScreen({
    super.key,
    this.initialRoute = FlowRoutes.following,
    this.authController,
    this.openTwitchLogin,
    this.currentThemeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.openExternalUrl,
    this.navigatorObservers = const <NavigatorObserver>[],
  });

  final String initialRoute;
  final TwitchAuthController? authController;
  final TwitchLoginOpener? openTwitchLogin;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ExternalUrlOpener? openExternalUrl;
  final List<NavigatorObserver> navigatorObservers;

  @override
  State<FlowTabsScreen> createState() => _FlowTabsScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("initialRoute", initialRoute));
    properties.add(DiagnosticsProperty<TwitchAuthController?>("authController", authController));
    properties.add(ObjectFlagProperty<TwitchLoginOpener?>.has("openTwitchLogin", openTwitchLogin));
    properties.add(EnumProperty<ThemeMode>("currentThemeMode", currentThemeMode));
    properties.add(
      ObjectFlagProperty<ValueChanged<ThemeMode>?>.has(
        "onThemeModeChanged",
        onThemeModeChanged,
      ),
    );
    properties.add(
      ObjectFlagProperty<ExternalUrlOpener?>.has(
        "openExternalUrl",
        openExternalUrl,
      ),
    );
    properties.add(
      IterableProperty<NavigatorObserver>(
        "navigatorObservers",
        navigatorObservers,
      ),
    );
  }
}

class _FlowTabsScreenState extends State<FlowTabsScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _browseStateStore = BrowseScreenStateStore();
  String? _activeSecondaryRoute;
  late String _currentRoute;

  @override
  void initState() {
    super.initState();
    _currentRoute = _normalizeRoute(widget.initialRoute);
    if (_currentRoute != FlowRoutes.following) {
      final initialRoute = _currentRoute;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openSecondaryRoute(initialRoute);
        }
      });
    }
  }

  void _selectRoute(String routeName) {
    final nextRoute = _normalizeRoute(routeName);
    if (nextRoute == _currentRoute) {
      return;
    }

    if (nextRoute == FlowRoutes.following) {
      _returnToFollowingRoute();
    } else {
      _openSecondaryRoute(
        nextRoute,
        replaceCurrent: _currentRoute != FlowRoutes.following,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: PopScope<void>(
      canPop: _currentRoute == FlowRoutes.following,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _currentRoute == FlowRoutes.following) {
          return;
        }
        _returnToFollowingRoute();
      },
      child: Navigator(
        key: _navigatorKey,
        initialRoute: FlowRoutes.following,
        observers: widget.navigatorObservers,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => FollowingScreen(
            authController: widget.authController,
            openTwitchLogin: widget.openTwitchLogin,
            bottomNavigationBar: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
    bottomNavigationBar: AppBottomNav(
      currentRoute: _currentRoute,
      onRouteSelected: _selectRoute,
    ),
  );

  void _openSecondaryRoute(String routeName, {bool replaceCurrent = false}) {
    final nextRoute = _normalizeRoute(routeName);
    if (nextRoute == FlowRoutes.following || nextRoute == _activeSecondaryRoute) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    if (replaceCurrent) {
      _activeSecondaryRoute = null;
      _popToFollowingRoute(navigator);
    }

    _activeSecondaryRoute = nextRoute;
    _setCurrentRoute(nextRoute);
    final route = _secondaryRoute(nextRoute);
    final routeCompletion = navigator.push<void>(route);

    unawaited(
      routeCompletion.whenComplete(() {
        if (!mounted || _activeSecondaryRoute != nextRoute) {
          return;
        }
        _activeSecondaryRoute = null;
        _setCurrentRoute(FlowRoutes.following);
      }),
    );
  }

  void _returnToFollowingRoute() {
    if (_currentRoute == FlowRoutes.following) {
      return;
    }

    _activeSecondaryRoute = null;
    _setCurrentRoute(FlowRoutes.following);
    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      _popToFollowingRoute(navigator);
    }
  }

  void _popToFollowingRoute(NavigatorState navigator) {
    navigator.popUntil(
      (route) => route.isFirst || route.settings.name == FlowRoutes.following,
    );
  }

  MaterialPageRoute<void> _secondaryRoute(String routeName) => switch (routeName) {
    FlowRoutes.browse => MaterialPageRoute<void>(
      settings: const RouteSettings(name: FlowRoutes.browse),
      builder: (_) => BrowseScreen(
        authController: widget.authController,
        bottomNavigationBar: const SizedBox.shrink(),
        stateStore: _browseStateStore,
      ),
    ),
    FlowRoutes.settings => MaterialPageRoute<void>(
      settings: const RouteSettings(name: FlowRoutes.settings),
      builder: (_) => SettingsScreen(
        currentThemeMode: widget.currentThemeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        openExternalUrl: widget.openExternalUrl,
        bottomNavigationBar: const SizedBox.shrink(),
      ),
    ),
    _ => throw StateError("Unsupported secondary route: $routeName"),
  };

  void _setCurrentRoute(String routeName) {
    if (_currentRoute == routeName) {
      return;
    }

    setState(() {
      _currentRoute = routeName;
    });
  }
}

String _normalizeRoute(String routeName) => switch (routeName) {
  FlowRoutes.browse => FlowRoutes.browse,
  FlowRoutes.settings => FlowRoutes.settings,
  _ => FlowRoutes.following,
};
