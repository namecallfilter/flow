import "dart:async";

import "package:flow/api/twitch_auth.dart";
import "package:flow/app/routes.dart";
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
  bool _settingsRouteActive = false;
  late String _currentRoute;

  @override
  void initState() {
    super.initState();
    _currentRoute = _normalizeRoute(widget.initialRoute);
    if (_normalizeRoute(widget.initialRoute) == FlowRoutes.settings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openSettingsRoute();
        }
      });
    }
  }

  void _selectRoute(String routeName) {
    final nextRoute = _normalizeRoute(routeName);
    if (nextRoute == FlowRoutes.settings) {
      _openSettingsRoute();
    } else if (nextRoute == FlowRoutes.following) {
      _returnToFollowingRoute();
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

  void _openSettingsRoute() {
    if (_settingsRouteActive) {
      return;
    }

    _settingsRouteActive = true;
    _setCurrentRoute(FlowRoutes.settings);
    unawaited(
      _navigatorKey.currentState!
          .push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: FlowRoutes.settings),
              builder: (_) => SettingsScreen(
                currentThemeMode: widget.currentThemeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
                openExternalUrl: widget.openExternalUrl,
                bottomNavigationBar: const SizedBox.shrink(),
              ),
            ),
          )
          .whenComplete(() {
            if (!mounted) {
              return;
            }
            _settingsRouteActive = false;
            _setCurrentRoute(FlowRoutes.following);
          }),
    );
  }

  void _returnToFollowingRoute() {
    if (_currentRoute == FlowRoutes.following) {
      return;
    }

    _setCurrentRoute(FlowRoutes.following);
    unawaited(_navigatorKey.currentState?.maybePop());
  }

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
  FlowRoutes.settings => FlowRoutes.settings,
  _ => FlowRoutes.following,
};
