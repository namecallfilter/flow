import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/tabs_store.dart";
import "package:flow/features/browse/browse_screen.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/following/following_store.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_mobx/flutter_mobx.dart";

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
    this.preferences,
    this.settingsStore,
    this.tabsStore,
    this.browseStore,
    this.followingStore,
  });

  final String initialRoute;
  final TwitchAuthController? authController;
  final TwitchLoginOpener? openTwitchLogin;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ExternalUrlOpener? openExternalUrl;
  final List<NavigatorObserver> navigatorObservers;
  final FlowPreferences? preferences;
  final AppSettingsStore? settingsStore;
  final TabsStore? tabsStore;
  final BrowseStore? browseStore;
  final FollowingStore? followingStore;

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
    properties.add(DiagnosticsProperty<FlowPreferences?>("preferences", preferences));
    properties.add(DiagnosticsProperty<AppSettingsStore?>("settingsStore", settingsStore));
    properties.add(DiagnosticsProperty<TabsStore?>("tabsStore", tabsStore));
    properties.add(DiagnosticsProperty<BrowseStore?>("browseStore", browseStore));
    properties.add(DiagnosticsProperty<FollowingStore?>("followingStore", followingStore));
  }
}

class _FlowTabsScreenState extends State<FlowTabsScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final FlowPreferences _preferences;
  late final AppSettingsStore _settingsStore;
  late final TwitchAuthController _authController;
  late final TwitchApiCache _apiCache;
  late final TabsStore _tabsStore;
  late final BrowseStore _browseStore;
  late final FollowingStore _followingStore;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? _MemoryFlowPreferences(themeMode: widget.currentThemeMode);
    _settingsStore = widget.settingsStore ?? AppSettingsStore(preferences: _preferences);
    _authController = widget.authController ?? _buildDefaultAuthController();
    _apiCache = TwitchApiCache(clientLoader: () => _loadApiClient(_authController));
    _tabsStore = widget.tabsStore ?? TabsStore(initialRoute: widget.initialRoute);
    _browseStore = widget.browseStore ?? BrowseStore(apiCache: _apiCache);
    _followingStore =
        widget.followingStore ??
        FollowingStore(
          authController: _authController,
          apiCache: _apiCache,
        );
    if (!_settingsStore.isLoaded) {
      unawaited(_settingsStore.load());
    }
    if (_tabsStore.currentRoute != FlowRoutes.following) {
      final initialRoute = _tabsStore.currentRoute;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openSecondaryRoute(initialRoute);
        }
      });
    }
  }

  TwitchAuthController _buildDefaultAuthController() {
    const config = TwitchAuthConfig.fromEnvironment();
    return TwitchAuthController(
      config: config,
      secureStore: const SecureTwitchStore(),
      cookieExtractor: const MethodChannelTwitchCookieExtractor(),
      apiClientFactory: (accessToken) => TwitchApiClient(
        clientId: config.clientId,
        accessToken: accessToken,
      ),
    );
  }

  void _selectRoute(String routeName) {
    final nextRoute = normalizeFlowRoute(routeName);
    if (nextRoute == _tabsStore.currentRoute) {
      return;
    }

    if (nextRoute == FlowRoutes.following) {
      _returnToFollowingRoute();
    } else {
      _openSecondaryRoute(
        nextRoute,
        replaceCurrent: _tabsStore.currentRoute != FlowRoutes.following,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) => Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PopScope<void>(
        canPop: _tabsStore.currentRoute == FlowRoutes.following,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _tabsStore.currentRoute == FlowRoutes.following) {
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
              authController: _authController,
              followingStore: _followingStore,
              openTwitchLogin: widget.openTwitchLogin,
              bottomNavigationBar: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentRoute: _tabsStore.currentRoute,
        onRouteSelected: _selectRoute,
      ),
    ),
  );

  void _openSecondaryRoute(String routeName, {bool replaceCurrent = false}) {
    final nextRoute = normalizeFlowRoute(routeName);
    if (nextRoute == FlowRoutes.following || nextRoute == _tabsStore.activeSecondaryRoute) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    if (replaceCurrent) {
      _tabsStore.setActiveSecondaryRoute(null);
      _popToFollowingRoute(navigator);
    }

    _tabsStore.setActiveSecondaryRoute(nextRoute);
    _tabsStore.setCurrentRoute(nextRoute);
    final route = _secondaryRoute(nextRoute);
    final routeCompletion = navigator.push<void>(route);

    unawaited(
      routeCompletion.whenComplete(() {
        if (!mounted || _tabsStore.activeSecondaryRoute != nextRoute) {
          return;
        }
        _tabsStore.returnToFollowing();
      }),
    );
  }

  void _returnToFollowingRoute() {
    if (_tabsStore.currentRoute == FlowRoutes.following) {
      return;
    }

    _tabsStore.returnToFollowing();
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
        authController: _authController,
        apiCache: _apiCache,
        browseStore: _browseStore,
        preferences: _preferences,
        bottomNavigationBar: const SizedBox.shrink(),
      ),
    ),
    FlowRoutes.settings => MaterialPageRoute<void>(
      settings: const RouteSettings(name: FlowRoutes.settings),
      builder: (_) => SettingsScreen(
        settingsStore: _settingsStore,
        openExternalUrl: widget.openExternalUrl,
        bottomNavigationBar: const SizedBox.shrink(),
      ),
    ),
    _ => throw StateError("Unsupported secondary route: $routeName"),
  };
}

Future<TwitchApiClient> _loadApiClient(TwitchAuthController authController) async {
  if (!authController.config.isConfigured) {
    throw TwitchAuthException(
      "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to browse Twitch.",
    );
  }

  final accessToken = await authController.secureStore.readAccessToken();
  if (accessToken == null || accessToken.isEmpty) {
    throw TwitchAuthException("Connect Twitch from Following to browse live data.");
  }

  return authController.apiClientFactory(accessToken);
}

class _MemoryFlowPreferences implements FlowPreferences {
  _MemoryFlowPreferences({required this.themeMode});

  ThemeMode themeMode;
  List<String> searchHistory = const <String>[];

  @override
  Future<void> clearBrowseSearchHistory() async {
    searchHistory = const <String>[];
  }

  @override
  Future<List<String>> readBrowseSearchHistory() async => searchHistory;

  @override
  Future<ThemeMode> readThemeMode() async => themeMode;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    searchHistory = List<String>.of(history);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeMode = mode;
  }
}
