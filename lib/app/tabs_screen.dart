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
  final _followingNavigatorKey = GlobalKey<NavigatorState>();
  final _browseNavigatorKey = GlobalKey<NavigatorState>();
  final _settingsNavigatorKey = GlobalKey<NavigatorState>();
  final _visitedRoutes = <String>{};
  late final FlowPreferences _preferences;
  late final AppSettingsStore _settingsStore;
  late final TwitchAuthController _authController;
  late final TwitchApiCache _apiCache;
  late final TabsStore _tabsStore;
  late final BrowseStore _browseStore;
  late final FollowingStore _followingStore;
  late final _TabNavigatorObserver _followingNavigatorObserver;
  late final _TabNavigatorObserver _browseNavigatorObserver;
  late final _TabNavigatorObserver _settingsNavigatorObserver;
  LocalHistoryEntry? _tabHistoryEntry;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? _MemoryFlowPreferences(themeMode: widget.currentThemeMode);
    _settingsStore = widget.settingsStore ?? AppSettingsStore(preferences: _preferences);
    _authController = widget.authController ?? _buildDefaultAuthController();
    _apiCache = TwitchApiCache(clientLoader: () => _loadApiClient(_authController));
    _tabsStore = widget.tabsStore ?? TabsStore(initialRoute: widget.initialRoute);
    _visitedRoutes.add(_tabsStore.currentRoute);
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
    _followingNavigatorObserver = _TabNavigatorObserver(_handleTabNavigatorChanged);
    _browseNavigatorObserver = _TabNavigatorObserver(_handleTabNavigatorChanged);
    _settingsNavigatorObserver = _TabNavigatorObserver(_handleTabNavigatorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabHistory());
  }

  TwitchAuthController _buildDefaultAuthController() {
    const config = TwitchAuthConfig.fromEnvironment();
    return TwitchAuthController(
      config: config,
      secureStore: const SecureTwitchStore(),
      cookieExtractor: const MethodChannelTwitchCookieExtractor(),
      apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
        clientId: config.clientId,
        graphQlClientId: config.graphQlClientId,
        accessToken: accessToken,
        gqlAccessToken: gqlAccessToken,
      ),
    );
  }

  void _selectRoute(String routeName) {
    final nextRoute = normalizeFlowRoute(routeName);
    if (nextRoute == _tabsStore.currentRoute) {
      return;
    }

    setState(() {
      _visitedRoutes.add(nextRoute);
    });
    _tabsStore.setCurrentRoute(nextRoute);
    if (nextRoute == FlowRoutes.settings) {
      unawaited(_settingsStore.load());
    }
    _syncTabHistory();
  }

  void _syncTabHistory() {
    if (!mounted || _isDisposing) {
      return;
    }

    if (_tabsStore.currentRoute == FlowRoutes.following) {
      final entry = _tabHistoryEntry;
      _tabHistoryEntry = null;
      entry?.remove();
      return;
    }
    if (_tabHistoryEntry != null) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null) {
      return;
    }

    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(
      onRemove: () {
        if (identical(_tabHistoryEntry, entry)) {
          _tabHistoryEntry = null;
        }
        if (mounted && !_isDisposing && _tabsStore.currentRoute != FlowRoutes.following) {
          _selectRoute(FlowRoutes.following);
        }
      },
    );
    _tabHistoryEntry = entry;
    route.addLocalHistoryEntry(entry);
  }

  @override
  void dispose() {
    _isDisposing = true;
    _tabHistoryEntry?.remove();
    _tabHistoryEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) => Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PopScope<void>(
        canPop: !_activeNavigatorCanPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            return;
          }
          unawaited(_handleBackNavigation());
        },
        child: IndexedStack(
          index: _routeIndex(_tabsStore.currentRoute),
          children: [
            _buildTabNavigator(
              routeName: FlowRoutes.following,
              navigatorKey: _followingNavigatorKey,
              observers: [
                ...widget.navigatorObservers,
                _followingNavigatorObserver,
              ],
              rootBuilder: (_) => FollowingScreen(
                authController: _authController,
                apiCache: _apiCache,
                followingStore: _followingStore,
                openTwitchLogin: widget.openTwitchLogin,
                bottomNavigationBar: const SizedBox.shrink(),
              ),
            ),
            _buildTabNavigator(
              routeName: FlowRoutes.browse,
              navigatorKey: _browseNavigatorKey,
              observers: [_browseNavigatorObserver],
              rootBuilder: (_) => BrowseScreen(
                authController: _authController,
                apiCache: _apiCache,
                browseStore: _browseStore,
                preferences: _preferences,
                bottomNavigationBar: const SizedBox.shrink(),
              ),
            ),
            _buildTabNavigator(
              routeName: FlowRoutes.settings,
              navigatorKey: _settingsNavigatorKey,
              observers: [_settingsNavigatorObserver],
              rootBuilder: (_) => SettingsScreen(
                settingsStore: _settingsStore,
                openExternalUrl: widget.openExternalUrl,
                bottomNavigationBar: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentRoute: _tabsStore.currentRoute,
        onRouteSelected: _selectRoute,
      ),
    ),
  );

  Widget _buildTabNavigator({
    required String routeName,
    required GlobalKey<NavigatorState> navigatorKey,
    required WidgetBuilder rootBuilder,
    required List<NavigatorObserver> observers,
  }) {
    if (!_visitedRoutes.contains(routeName)) {
      return const SizedBox.shrink();
    }

    return Navigator(
      key: navigatorKey,
      observers: observers,
      onGenerateInitialRoutes: (_, _) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: routeName),
          builder: rootBuilder,
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: rootBuilder,
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    final activeNavigator = _navigatorKeyFor(_tabsStore.currentRoute).currentState;
    if (activeNavigator != null && await activeNavigator.maybePop()) {
      return;
    }
    if (_tabsStore.currentRoute != FlowRoutes.following) {
      _selectRoute(FlowRoutes.following);
    }
  }

  bool _activeNavigatorCanPop() =>
      _navigatorKeyFor(_tabsStore.currentRoute).currentState?.canPop() ?? false;

  GlobalKey<NavigatorState> _navigatorKeyFor(String routeName) => switch (routeName) {
    FlowRoutes.browse => _browseNavigatorKey,
    FlowRoutes.settings => _settingsNavigatorKey,
    _ => _followingNavigatorKey,
  };

  int _routeIndex(String routeName) => switch (routeName) {
    FlowRoutes.browse => 1,
    FlowRoutes.settings => 2,
    _ => 0,
  };

  void _handleTabNavigatorChanged() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }
}

class _TabNavigatorObserver extends NavigatorObserver {
  _TabNavigatorObserver(this.onRouteStackChanged);

  final VoidCallback onRouteStackChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteStackChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteStackChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onRouteStackChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onRouteStackChanged();
  }
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

  final gqlAccessToken = await authController.secureStore.readWebSessionToken();
  return authController.apiClientFactory(
    accessToken,
    gqlAccessToken: gqlAccessToken,
  );
}

class _MemoryFlowPreferences implements FlowPreferences {
  _MemoryFlowPreferences({required this.themeMode});

  ThemeMode themeMode;
  List<String> searchHistory = const <String>[];
  bool adProxyEnabled = false;
  List<String> adProxyUrls = const [];
  List<String> adProxyWhitelistedChannels = const [];

  @override
  Future<bool> readAdProxyEnabled() async => adProxyEnabled;

  @override
  Future<List<String>> readAdProxyUrls() async => adProxyUrls;

  @override
  Future<List<String>> readAdProxyWhitelistedChannels() async => adProxyWhitelistedChannels;

  @override
  Future<List<String>> readAdProxySubscriptionChannels() async => const [];

  @override
  Future<void> saveAdProxyEnabled({required bool enabled}) async => adProxyEnabled = enabled;

  @override
  Future<void> saveAdProxyUrls(List<String> urls) async => adProxyUrls = List.of(urls);

  @override
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels) async =>
      adProxyWhitelistedChannels = List.of(channels);

  @override
  Future<void> saveAdProxySubscriptionChannels(List<String> channels) async {}

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
