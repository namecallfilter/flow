import "dart:async";
import "dart:math" as math;

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
import "package:flow/features/following/twitch_login_offer_screen.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
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
    this.showLoginOnLaunch = true,
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
  final bool showLoginOnLaunch;

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
    properties.add(DiagnosticsProperty<bool>("showLoginOnLaunch", showLoginOnLaunch));
  }
}

class _FlowTabsScreenState extends State<FlowTabsScreen> with WidgetsBindingObserver {
  static const _topLevelRefreshInterval = Duration(seconds: 30);

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
  late final ValueNotifier<double> _tabBackProgress;
  Timer? _topLevelRefreshTimer;
  Future<void>? _topLevelRefresh;
  bool _topLevelRefreshQueued = false;
  Future<void>? _queuedFollowingRefresh;
  bool _appIsResumed = false;
  late final Future<void> _initialSessionRestore;
  bool _isStartupResolved = false;
  bool _showStartupLoginOffer = false;
  bool _isHandlingMe = false;
  String? _startupLoginMessage;
  String? _predictiveBackTab;
  SwipeEdge _predictiveBackSwipeEdge = SwipeEdge.left;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? _MemoryFlowPreferences(themeMode: widget.currentThemeMode);
    _settingsStore = widget.settingsStore ?? AppSettingsStore(preferences: _preferences);
    _authController =
        widget.followingStore?.authController ??
        widget.authController ??
        _buildDefaultAuthController();
    _apiCache = TwitchApiCache(clientLoader: () => _loadApiClient(_authController));
    _tabsStore = widget.tabsStore ?? TabsStore(initialRoute: widget.initialRoute);
    _visitedRoutes
      ..add(FlowRoutes.following)
      ..add(FlowRoutes.browse)
      ..add(_tabsStore.currentRoute);
    _browseStore = widget.browseStore ?? BrowseStore(apiCache: _apiCache);
    _followingStore =
        widget.followingStore ??
        FollowingStore(
          authController: _authController,
          apiCache: _apiCache,
        );
    if (widget.showLoginOnLaunch) {
      _initialSessionRestore = _restoreInitialSession();
    } else {
      _isStartupResolved = true;
      _initialSessionRestore = Future<void>.value();
    }
    unawaited(_initialSessionRestore);
    if (!_settingsStore.isLoaded) {
      unawaited(_settingsStore.load());
    }
    _followingNavigatorObserver = _TabNavigatorObserver(_handleTabNavigatorChanged);
    _browseNavigatorObserver = _TabNavigatorObserver(_handleTabNavigatorChanged);
    _settingsNavigatorObserver = _TabNavigatorObserver(_handleTabNavigatorChanged);
    _tabBackProgress = ValueNotifier(0);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appIsResumed = lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _topLevelRefreshTimer = Timer.periodic(_topLevelRefreshInterval, (_) {
      if (_appIsResumed) {
        unawaited(_refreshTopLevelData(refresh: true));
      }
    });
    if (_appIsResumed) {
      unawaited(_refreshTopLevelData(refresh: false));
    }
  }

  Future<void> _restoreInitialSession() async {
    final sessionRestore = _followingStore.loadSavedConnection();
    if (_authController.config.isConfigured) {
      try {
        final tokens = await _authController.readSavedTokens();
        if (mounted &&
            (tokens.accessToken?.isNotEmpty ?? false) &&
            (tokens.webSessionToken?.trim().isNotEmpty ?? false)) {
          setState(() {
            _isStartupResolved = true;
          });
        }
      } on Object catch (error) {
        debugPrint("Couldn't inspect the saved Twitch session: $error");
      }
    }

    var isLoginOfferDismissed = false;
    try {
      isLoginOfferDismissed = await _preferences.readLoginOfferDismissed();
    } on Object catch (error) {
      debugPrint("Couldn't read the login offer preference: $error");
    }

    await sessionRestore;
    if (!mounted) {
      return;
    }
    setState(() {
      _showStartupLoginOffer = !isLoginOfferDismissed && !_followingStore.isLoggedIn;
      _isStartupResolved = true;
    });
  }

  void _completeInitialLogin(TwitchAuthConnection connection) {
    _followingStore.applyConnection(connection);
    setState(() {
      _showStartupLoginOffer = false;
      _startupLoginMessage = null;
    });
  }

  Future<void> _signOutAndContinue() async {
    try {
      await _followingStore.signOut();
    } on Object catch (error) {
      debugPrint("Couldn't clear the Twitch session: $error");
      if (mounted) {
        setState(() {
          _startupLoginMessage = "We couldn't clear your Twitch session. Try again.";
        });
      }
      return;
    }
    try {
      await _preferences.saveLoginOfferDismissed(dismissed: true);
    } on Object catch (error) {
      debugPrint("Couldn't save the login offer preference: $error");
      if (mounted) {
        setState(() {
          _startupLoginMessage = "We couldn't save your choice. Try again.";
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _showStartupLoginOffer = false;
        _startupLoginMessage = null;
      });
    }
  }

  Future<void> _handleMeRequested() async {
    if (_isHandlingMe) {
      return;
    }
    _isHandlingMe = true;
    try {
      await _initialSessionRestore;
      await _followingStore.loadSavedConnection();
      if (!mounted || _showStartupLoginOffer) {
        return;
      }
      if (_followingStore.isLoggedIn) {
        _selectRoute(FlowRoutes.settings);
        return;
      }

      await _connectTwitchAccount();
    } finally {
      _isHandlingMe = false;
    }
  }

  Future<void> _switchTwitchAccount() async {
    if (_isHandlingMe) {
      return;
    }
    _isHandlingMe = true;
    try {
      await _connectTwitchAccount();
    } finally {
      _isHandlingMe = false;
    }
  }

  Future<void> _connectTwitchAccount() async {
    final connection = await openTwitchLoginOfferScreen(
      context,
      _authController,
      openTwitchLogin: widget.openTwitchLogin,
    );
    if (!mounted || connection == null) {
      return;
    }
    _followingStore.applyConnection(connection);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Connected as ${connection.user.displayName}")),
    );
  }

  Future<void> _signOutFromSettings() async {
    if (_isHandlingMe) {
      return;
    }
    _isHandlingMe = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _followingStore.signOut();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Signed out of Twitch")),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      _isHandlingMe = false;
    }
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
    if (_predictiveBackTab != null ||
        (_navigatorKeyFor(_tabsStore.currentRoute).currentState?.userGestureInProgress ?? false)) {
      return;
    }

    final nextRoute = normalizeFlowRoute(routeName);
    if (nextRoute == _tabsStore.currentRoute) {
      return;
    }

    setState(() {
      _visitedRoutes.add(nextRoute);
    });
    _tabsStore.setCurrentRoute(nextRoute);
    if (nextRoute == FlowRoutes.browse &&
        (!_browseStore.categoriesLoaded || !_browseStore.liveChannelsLoaded)) {
      unawaited(_refreshTopLevelData(refresh: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _topLevelRefreshTimer?.cancel();
    _tabBackProgress.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _appIsResumed;
    _appIsResumed = state == AppLifecycleState.resumed;
    if (_appIsResumed && !wasResumed) {
      unawaited(_refreshTopLevelData(refresh: true));
    }
  }

  Future<void> _refreshTopLevelData({required bool refresh}) async {
    final activeRefresh = _topLevelRefresh;
    if (activeRefresh != null) {
      if (refresh) {
        _topLevelRefreshQueued = true;
        _queuedFollowingRefresh ??= _refreshSavedConnection(refresh: true);
      }
      await activeRefresh;
      return;
    }

    final operation = Completer<void>();
    final operationFuture = operation.future;
    _topLevelRefresh = operationFuture;
    var nextRefresh = refresh;
    Future<void>? nextFollowingRefresh;

    try {
      while (true) {
        await Future.wait([
          nextFollowingRefresh ?? _refreshSavedConnection(refresh: nextRefresh),
          if (nextRefresh || !_browseStore.categoriesLoaded)
            nextRefresh && _browseStore.categoriesLoaded
                ? _browseStore.refreshCategoriesFirstPage()
                : _browseStore.loadCategories(reset: true, refresh: nextRefresh),
          if (nextRefresh || !_browseStore.liveChannelsLoaded)
            nextRefresh && _browseStore.liveChannelsLoaded
                ? _browseStore.refreshLiveChannelsFirstPage()
                : _browseStore.loadLiveChannels(reset: true, refresh: nextRefresh),
        ]);
        if (!_topLevelRefreshQueued || !mounted) {
          break;
        }

        nextRefresh = true;
        nextFollowingRefresh = _queuedFollowingRefresh;
        _topLevelRefreshQueued = false;
        _queuedFollowingRefresh = null;
      }
    } finally {
      if (identical(_topLevelRefresh, operationFuture)) {
        _topLevelRefresh = null;
      }
      _topLevelRefreshQueued = false;
      _queuedFollowingRefresh = null;
      operation.complete();
    }
  }

  Future<void> _refreshSavedConnection({required bool refresh}) async {
    await _followingStore.loadSavedConnection(refresh: refresh);
    if (!mounted ||
        !_showStartupLoginOffer ||
        _startupLoginMessage != null ||
        !_followingStore.isLoggedIn) {
      return;
    }
    setState(() {
      _showStartupLoginOffer = false;
      _startupLoginMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStartupResolved) {
      return ColoredBox(
        key: const ValueKey("startup_gate"),
        color: Theme.of(context).scaffoldBackgroundColor,
      );
    }
    if (_showStartupLoginOffer) {
      return TwitchLoginOfferScreen(
        authController: _authController,
        openTwitchLogin: widget.openTwitchLogin,
        statusMessage:
            _startupLoginMessage ??
            (_followingStore.sessionStatus == TwitchSessionStatus.restoreFailed
                ? "We couldn't restore your Twitch session. Log in again or continue without an "
                      "account."
                : null),
        onConnected: _completeInitialLogin,
        onContinue: _signOutAndContinue,
      );
    }

    return _buildTabs(context);
  }

  Widget _buildTabs(BuildContext context) => Scaffold(
    extendBody: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: PopScope<void>(
      canPop: _tabsStore.currentRoute == FlowRoutes.following && !_activeNavigatorCanPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleBackNavigation());
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildTabSlot(
            routeName: FlowRoutes.following,
            child: _buildTabNavigator(
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
                browseStore: _browseStore,
                openTwitchLogin: widget.openTwitchLogin,
                onMeRequested: _handleMeRequested,
                bottomNavigationBar: const SizedBox.shrink(),
                periodicRefreshInterval: null,
              ),
            ),
          ),
          _buildTabSlot(
            routeName: FlowRoutes.browse,
            child: _buildTabNavigator(
              routeName: FlowRoutes.browse,
              navigatorKey: _browseNavigatorKey,
              observers: [_browseNavigatorObserver],
              rootBuilder: (_) => Observer(
                builder: (_) => BrowseScreen(
                  authController: _authController,
                  apiCache: _apiCache,
                  browseStore: _browseStore,
                  preferences: _preferences,
                  showLiveChannelsSection:
                      _followingStore.isLoggedIn ||
                      _followingStore.sessionStatus == TwitchSessionStatus.restoring,
                  bottomNavigationBar: const SizedBox.shrink(),
                  periodicRefreshInterval: null,
                ),
              ),
            ),
          ),
          _buildTabSlot(
            routeName: FlowRoutes.settings,
            child: _buildTabNavigator(
              routeName: FlowRoutes.settings,
              navigatorKey: _settingsNavigatorKey,
              observers: [_settingsNavigatorObserver],
              rootBuilder: (_) => Observer(
                builder: (_) => SettingsScreen(
                  settingsStore: _settingsStore,
                  openExternalUrl: widget.openExternalUrl,
                  twitchAccount: _followingStore.profileUser,
                  onSwitchTwitchAccount: _switchTwitchAccount,
                  onSignOutTwitch: _signOutFromSettings,
                  bottomNavigationBar: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: Observer(
      builder: (_) => AppBottomNav(
        currentRoute: _tabsStore.currentRoute,
        onRouteSelected: _selectRoute,
        showLiveChannels:
            !_followingStore.isLoggedIn &&
            _followingStore.sessionStatus != TwitchSessionStatus.restoring,
      ),
    ),
  );

  Widget _buildTabSlot({
    required String routeName,
    required Widget child,
  }) {
    final isPredictiveBackTab = routeName == _predictiveBackTab;
    final isVisible =
        routeName == _tabsStore.currentRoute ||
        (routeName == FlowRoutes.following && _predictiveBackTab != null);
    final routeTransitionsEnabled =
        routeName == _tabsStore.currentRoute && (ModalRoute.isCurrentOf(context) ?? false);
    final theme = Theme.of(context);
    final tabChild = Theme(
      data: routeTransitionsEnabled
          ? theme
          : theme.copyWith(
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: _InstantPageTransitionsBuilder(),
                },
              ),
            ),
      child: child,
    );
    final tab = isPredictiveBackTab
        ? _PredictiveTabBackTransition(
            progress: _tabBackProgress,
            swipeEdge: _predictiveBackSwipeEdge,
            child: tabChild,
          )
        : tabChild;

    return Offstage(
      offstage: !isVisible,
      child: TickerMode(enabled: isVisible, child: tab),
    );
  }

  Widget _buildTabNavigator({
    required String routeName,
    required GlobalKey<NavigatorState> navigatorKey,
    required WidgetBuilder rootBuilder,
    required List<NavigatorObserver> observers,
  }) {
    if (!_visitedRoutes.contains(routeName)) {
      return const SizedBox.shrink();
    }

    return NotificationListener<NavigationNotification>(
      onNotification: (_) => true,
      child: Navigator(
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
      ),
    );
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return false;
    }

    final activeNavigator = _navigatorKeyFor(_tabsStore.currentRoute).currentState;
    if (activeNavigator?.canPop() ?? false) {
      return false;
    }

    final activeRoute = _navigatorObserverFor(_tabsStore.currentRoute).currentRoute;
    if (_tabsStore.currentRoute == FlowRoutes.following ||
        !(activeRoute?.isFirst ?? false) ||
        activeRoute?.popDisposition != RoutePopDisposition.bubble) {
      return false;
    }

    setState(() {
      _predictiveBackTab = _tabsStore.currentRoute;
      _predictiveBackSwipeEdge = backEvent.swipeEdge;
      _tabBackProgress.value = backEvent.progress;
    });
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_predictiveBackTab != null) {
      _tabBackProgress.value = backEvent.progress;
    }
  }

  @override
  void handleCancelBackGesture() {
    if (_predictiveBackTab != null) {
      _finishTabBackGesture(commit: false);
    }
  }

  @override
  void handleCommitBackGesture() {
    if (_predictiveBackTab != null) {
      _finishTabBackGesture(commit: true);
    }
  }

  void _finishTabBackGesture({required bool commit}) {
    if (_predictiveBackTab == null) {
      return;
    }

    setState(() {
      _predictiveBackTab = null;
      _tabBackProgress.value = 0;
    });
    if (commit) {
      _selectRoute(FlowRoutes.following);
    }
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
      (_navigatorKeyFor(_tabsStore.currentRoute).currentState?.canPop() ?? false) ||
      _navigatorObserverFor(_tabsStore.currentRoute).currentRoute?.popDisposition ==
          RoutePopDisposition.doNotPop;

  GlobalKey<NavigatorState> _navigatorKeyFor(String routeName) => switch (routeName) {
    FlowRoutes.browse => _browseNavigatorKey,
    FlowRoutes.settings => _settingsNavigatorKey,
    _ => _followingNavigatorKey,
  };

  _TabNavigatorObserver _navigatorObserverFor(String routeName) => switch (routeName) {
    FlowRoutes.browse => _browseNavigatorObserver,
    FlowRoutes.settings => _settingsNavigatorObserver,
    _ => _followingNavigatorObserver,
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
  Route<dynamic>? currentRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    currentRoute = route;
    onRouteStackChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    currentRoute = previousRoute;
    onRouteStackChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (identical(currentRoute, route)) {
      currentRoute = previousRoute;
    }
    onRouteStackChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (identical(currentRoute, oldRoute)) {
      currentRoute = newRoute;
    }
    onRouteStackChanged();
  }
}

class _PredictiveTabBackTransition extends StatelessWidget {
  const _PredictiveTabBackTransition({
    required this.progress,
    required this.swipeEdge,
    required this.child,
  });

  final ValueListenable<double> progress;
  final SwipeEdge swipeEdge;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxHorizontalShift = math.max(0, constraints.maxWidth / 20 - 8);
      return AnimatedBuilder(
        key: const ValueKey("predictive_tab_back_transition"),
        animation: progress,
        child: child,
        builder: (context, child) {
          final gestureProgress = progress.value;
          final horizontalShift =
              maxHorizontalShift * gestureProgress * (swipeEdge == SwipeEdge.right ? -1 : 1);
          return Transform.scale(
            scale: 1 - 0.1 * gestureProgress,
            child: Transform.translate(
              offset: Offset(horizontalShift, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32 * gestureProgress),
                child: child,
              ),
            ),
          );
        },
      );
    },
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ValueListenable<double>>("progress", progress));
    properties.add(EnumProperty<SwipeEdge>("swipeEdge", swipeEdge));
    properties.add(DiagnosticsProperty<Widget>("child", child));
  }
}

class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

Future<TwitchApiClient> _loadApiClient(TwitchAuthController authController) async {
  final savedTokens = await authController.readSavedTokens();
  return authController.apiClientFactory(
    savedTokens.accessToken ?? "",
    gqlAccessToken: savedTokens.webSessionToken,
  );
}

class _MemoryFlowPreferences implements FlowPreferences {
  _MemoryFlowPreferences({required this.themeMode});

  ThemeMode themeMode;
  List<String> searchHistory = const <String>[];
  bool adProxyEnabled = false;
  bool loginOfferDismissed = false;
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
  Future<bool> readLoginOfferDismissed() async => loginOfferDismissed;

  @override
  Future<ThemeMode> readThemeMode() async => themeMode;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    searchHistory = List<String>.of(history);
  }

  @override
  Future<void> saveLoginOfferDismissed({required bool dismissed}) async {
    loginOfferDismissed = dismissed;
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeMode = mode;
  }
}
