import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/browse/browse_screen.dart";
import "package:flow/features/browse/browse_search_store.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flow/features/browse/category_streams_store.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  testWidgets("vibrates when changing the browse section", (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == "HapticFeedback.vibrate") {
        haptics.add(call.arguments);
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(authController: _authController(), periodicRefreshInterval: null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();
    expect(haptics, ["HapticFeedbackType.selectionClick"]);
    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();
    expect(haptics, ["HapticFeedbackType.selectionClick"]);
    await tester.tap(find.byKey(const ValueKey("browse_segment_categories")));
    await tester.pumpAndSettle();
    expect(haptics, List.filled(2, "HapticFeedbackType.selectionClick"));
  });

  testWidgets("recommendation paging stops after an error and resumes after refresh", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final requests = <http.Request>[];
    var rejectContinuation = true;
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        gqlAccessToken: "web-token-123",
        httpClient: MockClient((request) async {
          requests.add(request);
          final isFirstPage = _graphQlVariables(request)["after"] == null;
          if (!isFirstPage && rejectContinuation) {
            return _jsonResponse({
              "errors": [
                {"message": "Connection lost"},
              ],
            });
          }
          return _streamConnectionResponse(
            [
              for (var index = isFirstPage ? 0 : 4; index < (isFirstPage ? 8 : 28); index++)
                {
                  "id": "stream-$index",
                  "broadcaster": {
                    "id": "creator-$index",
                    "login": "streamer$index",
                    "displayName": "Streamer $index",
                    "profileImageURL": "",
                  },
                  "viewersCount": 100,
                },
            ],
            cursor: isFirstPage ? "personal-next-page" : null,
          );
        }),
      ),
    );
    final store = BrowseStore(apiCache: apiCache)
      ..categoriesLoaded = true
      ..selectedSection = BrowseSection.liveChannels
      ..streamSort = StreamSort.recommendedForYou;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(apiCache: apiCache, browseStore: store, periodicRefreshInterval: null),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.liveChannels, hasLength(8));
    expect(requests, hasLength(2));
    expect(store.liveChannelsError, isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(requests, hasLength(3));
    expect(store.liveChannelsError, contains("Connection lost"));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(requests, hasLength(3));

    rejectContinuation = false;
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!.jumpTo(0);
    await tester.widget<FlowPullToRefresh>(find.byType(FlowPullToRefresh)).onRefresh();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(requests, hasLength(5));
    expect(_graphQlVariables(requests.last)["after"], "personal-next-page");
    expect(_graphQlVariables(requests.last)["first"], 24);
    expect(store.liveChannels, hasLength(28));
    expect(store.liveChannelsError, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets("live sort picker saves Recently Started and sends its server order", (tester) async {
    final requests = <http.Request>[];
    final preferences = MemoryFlowPreferences();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(onRequest: requests.add),
          preferences: preferences,
          periodicRefreshInterval: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Live channels have already been fetched while the Categories section is visible.
    expect(
      requests.where((request) => _isGraphQlOperation(request, "FlowTopStreams")),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Viewers: High to Low"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<StreamSort>, "Recently Started"));
    await tester.pumpAndSettle();
    final request = requests.lastWhere((request) => _isGraphQlOperation(request, "FlowTopStreams"));
    expect(_graphQlVariables(request)["options"], containsPair("sort", "RECENT"));
    expect(_graphQlVariables(request)["after"], isNull);
    expect(await preferences.readStreamSort("browse"), StreamSort.recentlyStarted);
    expect(tester.takeException(), isNull);
  });

  testWidgets("keeps loaded category streams visible after refresh errors", (tester) async {
    final apiCache = TwitchApiCache(
      clientLoader: () async => throw StateError("Unexpected request"),
    );
    const category = BrowseCategory(
      id: "category",
      name: "Just Chatting",
      viewerCount: 1,
      viewers: "1",
      imageUrl: null,
      colors: [Colors.purple, Colors.pink],
    );
    final store = CategoryStreamsStore(apiCache: apiCache, category: category)
      ..loaded = true
      ..errorMessage = "Connection lost. Try again."
      ..channels = List.generate(
        1,
        (index) => StreamChannel(
          login: "streamer$index",
          name: "Streamer $index",
          initials: "S",
          title: "Live now",
          category: category.name,
          viewers: "1",
          avatarColors: const [Colors.purple, Colors.pink],
          thumbnailColors: const [Colors.black, Colors.grey],
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: CategoryStreamsScreen(
          apiCache: apiCache,
          category: category,
          categoryStreamsStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Connection lost. Try again."), findsOneWidget);
    expect(find.byKey(const ValueKey("stream_thumbnail_Streamer 0")), findsOneWidget);
  });

  testWidgets("browse categories and navigation fit larger system text", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final apiCache = TwitchApiCache(
      clientLoader: () async => throw StateError("Unexpected request"),
    );
    final store = BrowseStore(apiCache: apiCache)
      ..categoriesLoaded = true
      ..categories = const [
        BrowseCategory(
          id: "category",
          name: "Just Chatting",
          viewerCount: 1,
          viewers: "1",
          imageUrl: null,
          colors: [Colors.purple, Colors.pink],
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: BrowseScreen(apiCache: apiCache, browseStore: store, periodicRefreshInterval: null),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey("browse_category_card_Just Chatting")), findsOneWidget);
  });

  testWidgets("hides the duplicate Live Channels section for guests", (tester) async {
    final apiCache = TwitchApiCache(
      clientLoader: () async => throw StateError("Unexpected API request."),
    );
    final store = BrowseStore(apiCache: apiCache)
      ..selectedSection = BrowseSection.liveChannels
      ..categories = const [
        BrowseCategory(
          id: "category-1",
          name: "Just Chatting",
          viewerCount: 1,
          viewers: "1",
          imageUrl: null,
          colors: [Colors.purple, Colors.pink],
        ),
      ]
      ..categoriesLoaded = true
      ..liveChannelsLoaded = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          apiCache: apiCache,
          browseStore: store,
          showLiveChannelsSection: false,
        ),
      ),
    );
    await tester.pump();

    expect(store.selectedSection, BrowseSection.categories);
    expect(find.byKey(const ValueKey("browse_segmented_control")), findsNothing);
    expect(find.byKey(const ValueKey("browse_segment_live_channels")), findsNothing);
    expect(find.byKey(const ValueKey("browse_live_channels")), findsNothing);
    expect(find.byKey(const ValueKey("browse_categories_grid")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_category_card_Just Chatting")), findsOneWidget);
    expect(find.byKey(const ValueKey("bottom_nav_item_Live Channels")), findsOneWidget);
  });

  testWidgets("shows search skeleton immediately during debounce", (tester) async {
    final requestedRequests = <http.Request>[];
    final response = Completer<http.Response>();
    final preferences = _MemorySearchHistoryStore();
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((request) {
          requestedRequests.add(request);
          return response.future;
        }),
      ),
    );
    final searchStore =
        BrowseSearchStore(
            apiCache: apiCache,
            preferences: preferences,
          )
          ..query = "old"
          ..channels = const [
            TwitchSearchChannel(
              id: "old-1",
              broadcasterLogin: "oldcreator",
              displayName: "OldCreator",
              gameName: "",
              title: "",
              isLive: false,
            ),
          ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseSearchScreen(
          authController: _authController(),
          apiCache: apiCache,
          preferences: preferences,
          searchStore: searchStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_search_channel_OldCreator")), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey("browse_search_page_field")),
      "new",
    );
    await tester.pump();

    expect(find.byKey(const ValueKey("browse_search_skeleton")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_search_channel_OldCreator")), findsNothing);
    expect(requestedRequests, isEmpty);

    await tester.pump(const Duration(milliseconds: 299));
    expect(requestedRequests, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(requestedRequests, isNotEmpty);

    response.complete(http.Response("{}", 500));
    await tester.pumpAndSettle();
  });

  testWidgets("opens live channels for a tapped category", (tester) async {
    final requestedRequests = <http.Request>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(onRequest: requestedRequests.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    requestedRequests.clear();
    await tester.tap(find.byKey(const ValueKey("browse_category_card_Just Chatting")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    expect(find.byKey(const ValueKey("category_streams_title_Just Chatting")), findsOneWidget);
    expect(find.byType(StreamCard), findsWidgets);
    expect(find.text("AussieAntics"), findsOneWidget);
    expect(find.text("NovaSkye"), findsOneWidget);
    expect(find.byKey(const ValueKey("stream_category_AussieAntics")), findsNothing);
    expect(find.byKey(const ValueKey("stream_category_NovaSkye")), findsNothing);
    expect(
      requestedRequests.any(
        (request) =>
            _isGraphQlOperation(request, "FlowGameStreams") &&
            _graphQlVariables(request)["id"] == "509658",
      ),
      isTrue,
    );
    final categoryRequestsAfterFirstOpen = requestedRequests
        .where(
          (request) =>
              _isGraphQlOperation(request, "FlowGameStreams") &&
              _graphQlVariables(request)["id"] == "509658",
        )
        .length;

    await tester.tap(find.byKey(const ValueKey("stream_channel_identity_AussieAntics")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsOneWidget);

    Navigator.of(
      tester.element(find.byKey(const ValueKey("channel_page_aussieantics"))),
    ).pop();
    await tester.pumpAndSettle();

    Navigator.of(
      tester.element(find.byKey(const ValueKey("category_streams_page_Just Chatting"))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_category_card_Just Chatting")));
    await tester.pumpAndSettle();

    final categoryRequestsAfterReopen = requestedRequests
        .where(
          (request) =>
              _isGraphQlOperation(request, "FlowGameStreams") &&
              _graphQlVariables(request)["id"] == "509658",
        )
        .length;
    expect(categoryRequestsAfterReopen, categoryRequestsAfterFirstOpen);
  });

  testWidgets("does not open players for missing browse or category logins", (tester) async {
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
      ),
    );
    const channel = StreamChannel(
      login: "",
      name: "MissingLogin",
      initials: "ML",
      title: "Live now",
      category: "Just Chatting",
      viewers: "1",
      avatarColors: [Colors.purple, Colors.pink],
      thumbnailColors: [Colors.black, Colors.grey],
    );
    final browseStore = BrowseStore(apiCache: apiCache)
      ..categoriesLoaded = true
      ..liveChannelsLoaded = true
      ..selectedSection = BrowseSection.liveChannels
      ..liveChannels = const [channel];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          apiCache: apiCache,
          browseStore: browseStore,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("stream_thumbnail_MissingLogin")));
    await tester.pumpAndSettle();
    expect(find.byType(StreamPlayerScreen), findsNothing);

    const category = BrowseCategory(
      id: "category-1",
      name: "Just Chatting",
      viewerCount: 1,
      viewers: "1",
      imageUrl: null,
      colors: [Colors.purple, Colors.pink],
    );
    final categoryStore = CategoryStreamsStore(apiCache: apiCache, category: category)
      ..loaded = true
      ..channels = const [channel];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: CategoryStreamsScreen(
          apiCache: apiCache,
          category: category,
          categoryStreamsStore: categoryStore,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("stream_thumbnail_MissingLogin")));
    await tester.pumpAndSettle();
    expect(find.byType(StreamPlayerScreen), findsNothing);
  });

  testWidgets("does not paginate when switching between Browse sections", (
    tester,
  ) async {
    final requestedRequests = <http.Request>[];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(onRequest: requestedRequests.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    requestedRequests.clear();
    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_segment_categories")));
    await tester.pumpAndSettle();

    expect(
      requestedRequests.where(
        (request) =>
            _isGraphQlOperation(request, "FlowTopGames") &&
            _graphQlVariables(request)["after"] == "cat-page-2",
      ),
      isEmpty,
    );
  });

  testWidgets("shows recent search history and clears it", (tester) async {
    final searchHistoryStore = _MemorySearchHistoryStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(),
          preferences: searchHistoryStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_search_empty_history_icon")), findsOneWidget);
    expect(find.text("No recent searches"), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey("browse_search_page_field")),
      "mine",
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_search_clear_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_search_history_header")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_search_history_mine")), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(),
          preferences: searchHistoryStore,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_search_history_mine")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("browse_search_clear_history_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_search_history_mine")), findsNothing);
    expect(find.text("No recent searches"), findsOneWidget);
    expect(searchHistoryStore.history, isEmpty);
  });

  testWidgets("shows partner badges and preserves search result navigation", (
    tester,
  ) async {
    final settings = AppSettingsStore(preferences: MemoryFlowPreferences());
    final rootNavigator = GlobalKey<NavigatorState>();
    final tabNavigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigator,
        builder: (_, child) => AppSettingsScope(settingsStore: settings, child: child!),
        theme: buildFlowTheme(Brightness.dark),
        home: Navigator(
          key: tabNavigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => BrowseScreen(authController: _authController()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("browse_search_page_field")),
      "mine",
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final searchPage = tester.element(find.byKey(const ValueKey("browse_search_page")));
    expect(Navigator.of(searchPage), same(tabNavigator.currentState));
    for (final name in ["HighCreator", "MinecraftCreator", "LowCreator", "BannedCreator"]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey("browse_search_channel_$name")),
          matching: find.byIcon(Icons.verified),
        ),
        name == "HighCreator" || name == "MinecraftCreator" ? findsOneWidget : findsNothing,
      );
    }

    await tester.tap(find.byKey(const ValueKey("browse_search_channel_category_HighCreator")));
    await tester.pumpAndSettle();
    final categoryPage = tester.element(
      find.byKey(const ValueKey("category_streams_page_Minecraft")),
    );
    expect(Navigator.of(categoryPage), same(tabNavigator.currentState));
    expect(
      tester.widget<CategoryStreamsScreen>(find.byType(CategoryStreamsScreen)).category.id,
      "game-Minecraft",
    );
    expect(find.byType(StreamPlayerScreen), findsNothing);
    Navigator.of(categoryPage).pop();
    await tester.pumpAndSettle();
    expect(tester.element(find.byKey(const ValueKey("browse_search_page"))), same(searchPage));

    await tester.tap(find.byKey(const ValueKey("browse_search_channel_category_MinecraftCreator")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_minecraftcreator")), findsOneWidget);

    Navigator.of(
      tester.element(find.byKey(const ValueKey("channel_page_minecraftcreator"))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_search_channel_HighCreator")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("player_page_highcreator")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_page_highcreator")), findsNothing);
    final player = tester.widget<StreamPlayerScreen>(find.byType(StreamPlayerScreen));
    expect(player.channel.login, "highcreator");
    expect(player.channel.name, "HighCreator");
    expect(player.channel.category, "Minecraft");
    expect(player.channel.categoryId, "game-Minecraft");

    Navigator.of(
      tester.element(find.byKey(const ValueKey("player_page_highcreator"))),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();

    expect(tester.element(find.byKey(const ValueKey("browse_search_page"))), same(searchPage));
    expect(find.text("mine"), findsOneWidget);
    expect(rootNavigator.currentState!.canPop(), isFalse);
    expect(tabNavigator.currentState!.canPop(), isTrue);
    await tester.tap(find.byKey(const ValueKey("browse_search_channel_avatar_HighCreator")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_highcreator")), findsOneWidget);
    expect(rootNavigator.currentState!.canPop(), isFalse);
  });
}

TwitchAuthController _authController({_RequestObserver? onRequest}) {
  final store = _MemoryTwitchStore()..accessToken = "token-123";
  return TwitchAuthController(
    config: const TwitchAuthConfig(clientId: "client-123"),
    secureStore: store,
    apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
      clientId: "client-123",
      accessToken: accessToken,
      gqlAccessToken: gqlAccessToken,
      httpClient: _browseHttpClient(onRequest: onRequest),
    ),
    cookieExtractor: const _StaticCookieExtractor(),
  );
}

MockClient _browseHttpClient({_RequestObserver? onRequest}) => MockClient((request) async {
  onRequest?.call(request);

  if (request.url.host == "gql.twitch.tv") {
    final query = _graphQlQuery(request);
    final variables = _graphQlVariables(request);

    if (query.contains("FlowUsers")) {
      final ids = (variables["ids"] as List<Object?>?)?.cast<String>();
      final logins = (variables["logins"] as List<Object?>?)?.cast<String>();
      return _jsonResponse({
        "data": {
          "users": [
            if (ids != null)
              for (final id in ids)
                if (id != "banned-1") _userJson(id),
            if (logins != null)
              for (final login in logins)
                _userJson(_userIdForLogin(login), stream: _searchStreamForLogin(login)),
          ],
        },
      });
    }

    if (query.contains("FlowTopGames")) {
      if (variables["after"] == "cat-page-2") {
        return _categoryConnectionResponse(
          [
            _categoryJson(id: "516575", name: "VALORANT"),
            _categoryJson(id: "27471", name: "Minecraft"),
            _categoryJson(id: "33214", name: "Fortnite"),
          ],
          fieldName: "games",
        );
      }

      return _categoryConnectionResponse(
        [
          _categoryJson(id: "509658", name: "Just Chatting", viewerCount: 31000),
          _categoryJson(id: "21779", name: "League of Legends"),
          _categoryJson(id: "32399", name: "Counter-Strike"),
          _categoryJson(id: "29595", name: "Dota 2"),
          _categoryJson(id: "511224", name: "Apex Legends"),
          _categoryJson(id: "32982", name: "Grand Theft Auto V"),
          _categoryJson(id: "18122", name: "World of Warcraft"),
          _categoryJson(id: "493057", name: "PUBG"),
          _categoryJson(id: "488552", name: "Overwatch 2"),
          _categoryJson(id: "491487", name: "Dead by Daylight"),
          _categoryJson(id: "515025", name: "Teamfight Tactics"),
          _categoryJson(id: "509663", name: "Special Events"),
        ],
        fieldName: "games",
        cursor: "cat-page-2",
      );
    }

    if (query.contains("FlowSearchChannels")) {
      return _jsonResponse({
        "data": {
          "searchSuggestions": {
            "edges": [
              _searchChannelEdge(
                id: "creator-low",
                login: "lowcreator",
                displayName: "LowCreator",
                isLive: true,
              ),
              _searchChannelEdge(
                id: "creator-4",
                login: "minecraftcreator",
                displayName: "MinecraftCreator",
                isPartner: true,
              ),
              _searchChannelEdge(
                id: "creator-high",
                login: "highcreator",
                displayName: "HighCreator",
                isLive: true,
                isPartner: true,
              ),
              _searchChannelEdge(
                id: "banned-1",
                login: "bannedcreator",
                displayName: "BannedCreator",
              ),
            ],
            "tracking": null,
          },
        },
      });
    }

    if (query.contains("FlowChannelDetails")) {
      final login = variables["login"]!.toString();
      return _channelDetailsResponse(
        login: login,
        displayName: _displayNameForUserId(_userIdForLogin(login)),
      );
    }

    if (query.contains("FlowSearchCategories")) {
      return _categoryConnectionResponse(
        [
          _categoryJson(
            id: "zero-viewer",
            name: "Valiant Hearts",
            boxArtUrl: "https://static-cdn.jtvnw.net/ttv-boxart/zero-viewer-52x72.jpg",
          ),
          _categoryJson(
            id: "27471",
            name: "Minecraft",
            boxArtUrl: "https://static-cdn.jtvnw.net/ttv-boxart/27471-52x72.jpg",
            viewerCount: 4200,
          ),
        ],
        fieldName: "searchCategories",
      );
    }

    if (query.contains("FlowGameStreams")) {
      final gameId = variables["id"];
      if (gameId == "509658") {
        return _gameStreamsResponse([
          _streamJson(
            id: "category-stream-1",
            userId: "creator-1",
            userLogin: "aussieantics",
            userName: "AussieAntics",
            gameName: "Just Chatting",
            viewerCount: 20000,
          ),
          _streamJson(
            id: "category-stream-2",
            userId: "creator-2",
            userLogin: "novaskye",
            userName: "NovaSkye",
            gameName: "Just Chatting",
            viewerCount: 11000,
          ),
        ]);
      }
      if (gameId == "27471") {
        return _gameStreamsResponse([
          _streamJson(
            id: "minecraft-category-stream",
            userId: "creator-4",
            userLogin: "minecraftcreator",
            userName: "MinecraftCreator",
            gameName: "Minecraft",
            viewerCount: 4200,
          ),
        ]);
      }
      return _gameStreamsResponse(const <Map<String, Object?>>[]);
    }

    if (query.contains("FlowTopStreams")) {
      if (variables["after"] == "stream-page-2") {
        return _streamConnectionResponse([
          _streamJson(
            id: "stream-124",
            userId: "creator-5",
            userLogin: "nextstreamer",
            userName: "NextStreamer",
            gameName: "VALORANT",
            viewerCount: 1900,
          ),
        ]);
      }

      return _streamConnectionResponse(
        [
          for (var index = 0; index < 20; index++)
            _streamJson(
              id: "stream-$index",
              userId: index == 0 ? "creator-1" : "creator-top-$index",
              userLogin: index == 0 ? "aussieantics" : "topstreamer$index",
              userName: index == 0 ? "AussieAntics" : "TopStreamer$index",
              gameName: index.isEven ? "Fortnite" : "Just Chatting",
              viewerCount: index == 0 ? 10706 : 9000 - index,
            ),
        ],
        cursor: "stream-page-2",
      );
    }
  }

  return http.Response("not found", 404);
});

bool _isGraphQlOperation(http.Request request, String operationName) =>
    request.url.host == "gql.twitch.tv" && request.body.contains(operationName);

String _graphQlQuery(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return body["query"]! as String;
}

Map<String, Object?> _graphQlVariables(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
}

Map<String, Object?> _userJson(
  String id, {
  Map<String, Object?>? stream,
}) => {
  "id": id,
  "login": _loginForUserId(id),
  "displayName": _displayNameForUserId(id),
  "profileImageURL": "https://static-cdn.jtvnw.net/$id.png",
  "broadcastSettings": null,
  "stream": stream,
};

String _userIdForLogin(String login) => switch (login) {
  "lowcreator" => "creator-low",
  "highcreator" => "creator-high",
  "minecraftcreator" => "creator-4",
  "nextstreamer" => "creator-5",
  "aussieantics" => "creator-1",
  _ => login,
};

String _loginForUserId(String id) {
  if (id.startsWith("creator-top-")) {
    return "topstreamer${id.substring("creator-top-".length)}";
  }
  return switch (id) {
    "creator-1" => "aussieantics",
    "creator-2" => "novaskye",
    "creator-4" => "minecraftcreator",
    "creator-5" => "nextstreamer",
    "creator-low" => "lowcreator",
    "creator-high" => "highcreator",
    "banned-1" => "bannedcreator",
    _ => id,
  };
}

String _displayNameForUserId(String id) {
  if (id.startsWith("creator-top-")) {
    return "TopStreamer${id.substring("creator-top-".length)}";
  }
  return switch (id) {
    "creator-1" => "AussieAntics",
    "creator-2" => "NovaSkye",
    "creator-4" => "MinecraftCreator",
    "creator-5" => "NextStreamer",
    "creator-low" => "LowCreator",
    "creator-high" => "HighCreator",
    "banned-1" => "BannedCreator",
    _ => id,
  };
}

Map<String, Object?>? _searchStreamForLogin(String login) => switch (login) {
  "lowcreator" => _streamJson(
    id: "low-search-stream",
    userId: "creator-low",
    userLogin: "lowcreator",
    userName: "LowCreator",
    gameName: "Minecraft",
    viewerCount: 10,
  ),
  "highcreator" => _streamJson(
    id: "high-search-stream",
    userId: "creator-high",
    userLogin: "highcreator",
    userName: "HighCreator",
    gameName: "Minecraft",
    viewerCount: 900,
  ),
  _ => null,
};

Map<String, Object?> _categoryJson({
  required String id,
  required String name,
  String? boxArtUrl,
  int viewerCount = 0,
}) => {
  "id": id,
  "displayName": name,
  "boxArtURL": boxArtUrl ?? "https://static-cdn.jtvnw.net/ttv-boxart/$id-{width}x{height}.jpg",
  "viewersCount": viewerCount,
};

Map<String, Object?> _streamJson({
  required String id,
  required String userId,
  required String userLogin,
  required String userName,
  required String gameName,
  required int viewerCount,
}) => {
  "id": id,
  "broadcaster": {
    "id": userId,
    "login": userLogin,
    "displayName": userName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$userId.png",
    "broadcastSettings": {"title": "Live from GraphQL"},
  },
  "createdAt": "2026-07-01T00:00:00Z",
  "freeformTags": const <Object?>[],
  "game": {"id": "game-$gameName", "displayName": gameName},
  "previewImageURL":
      "https://static-cdn.jtvnw.net/previews-ttv/live_user_$userLogin-{width}x{height}.jpg",
  "viewersCount": viewerCount,
};

Map<String, Object?> _searchChannelEdge({
  required String id,
  required String login,
  required String displayName,
  bool isLive = false,
  bool isPartner = false,
}) => {
  "node": {
    "id": "$id-suggestion",
    "text": displayName,
    "content": {
      "__typename": "SearchSuggestionChannel",
      "id": id,
      "isLive": isLive,
      "isVerified": false,
      "login": login,
      "profileImageURL": "https://static-cdn.jtvnw.net/$id.png",
      "user": {
        "id": id,
        "isPartner": isPartner,
        "roles": const <Object?>[],
        "stream": isLive ? _searchStreamForLogin(login) : null,
      },
    },
  },
};

http.Response _categoryConnectionResponse(
  List<Map<String, Object?>> categories, {
  required String fieldName,
  String? cursor,
}) => _jsonResponse({
  "data": {
    fieldName: {
      "edges": [
        for (final category in categories) {"cursor": cursor, "node": category},
      ],
      "pageInfo": {"hasNextPage": cursor != null},
    },
  },
});

http.Response _streamConnectionResponse(
  List<Map<String, Object?>> streams, {
  String? cursor,
}) => _jsonResponse({
  "data": {
    "streams": {
      "edges": [
        for (final stream in streams) {"cursor": cursor, "node": stream},
      ],
      "pageInfo": {"hasNextPage": cursor != null},
    },
  },
});

http.Response _gameStreamsResponse(
  List<Map<String, Object?>> streams, {
  String? cursor,
}) => _jsonResponse({
  "data": {
    "game": {
      "streams": {
        "edges": [
          for (final stream in streams) {"cursor": cursor, "node": stream},
        ],
        "pageInfo": {"hasNextPage": cursor != null},
      },
    },
  },
});

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

http.Response _channelDetailsResponse({
  required String login,
  required String displayName,
}) => _jsonResponse({
  "data": {
    "user": {
      "id": _userIdForLogin(login),
      "login": login,
      "displayName": displayName,
      "description": "",
      "profileImageURL": "https://static-cdn.jtvnw.net/$login.png",
      "followers": {"totalCount": 0},
      "stream": null,
      "videos": {
        "edges": const <Object?>[],
        "pageInfo": {"hasNextPage": false},
      },
    },
  },
});

class _MemoryTwitchStore implements TwitchSecureStore {
  String? accessToken;
  String? pendingState;
  String? webSessionToken;

  @override
  Future<void> clearSession() async {
    accessToken = null;
    pendingState = null;
    webSessionToken = null;
  }

  @override
  Future<void> clearPendingState() async {
    pendingState = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readPendingState() async => pendingState;

  @override
  Future<String?> readWebSessionToken() async => webSessionToken;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> savePendingState(String state) async {
    pendingState = state;
  }

  @override
  Future<void> saveWebSessionToken(String token) async {
    webSessionToken = token;
  }
}

class _StaticCookieExtractor extends TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}

class _MemorySearchHistoryStore extends MemoryFlowPreferences {
  @override
  Future<bool> readAdProxyEnabled() async => false;

  @override
  Future<List<String>> readAdProxyUrls() async => const [];

  @override
  Future<List<String>> readAdProxyWhitelistedChannels() async => const [];

  @override
  Future<List<String>> readAdProxySubscriptionChannels() async => const [];

  @override
  Future<void> saveAdProxyEnabled({required bool enabled}) async {}

  @override
  Future<void> saveAdProxyUrls(List<String> urls) async {}

  @override
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels) async {}

  @override
  Future<void> saveAdProxySubscriptionChannels(List<String> channels) async {}

  List<String> history = const <String>[];

  @override
  Future<void> clearBrowseSearchHistory() async {
    history = const <String>[];
  }

  @override
  Future<List<String>> readBrowseSearchHistory() async => history;

  @override
  Future<bool> readLoginOfferDismissed() async => false;

  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.system;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    this.history = List<String>.of(history);
  }

  @override
  Future<void> saveLoginOfferDismissed({required bool dismissed}) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
