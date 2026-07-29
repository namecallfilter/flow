import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/spacing.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/browse/browse_screen.dart";
import "package:flow/features/browse/browse_search_store.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flow/features/browse/category_streams_store.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flow/shared/widgets/skeleton.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  testWidgets("shows category skeleton until initial Browse content loads", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
      ),
    );
    final store = BrowseStore(apiCache: apiCache)..isLoadingCategories = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(apiCache: apiCache, browseStore: store),
      ),
    );
    await tester.pump();

    final categorySkeleton = find.byKey(const ValueKey("browse_categories_skeleton"));
    final categorySkeletonBoxes = find.descendant(
      of: categorySkeleton,
      matching: find.byType(SkeletonBox),
    );
    expect(categorySkeleton, findsOneWidget);
    expect(categorySkeletonBoxes, findsNWidgets(54));
    expect(tester.getBottomLeft(categorySkeletonBoxes.at(53)).dy, greaterThanOrEqualTo(1200));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text("No categories found."), findsNothing);

    store
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
      ..isLoadingCategories = false;
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_categories_skeleton")), findsNothing);
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

  testWidgets("matches stream skeleton geometry in Browse Live Channels", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
      ),
    );
    final store = BrowseStore(apiCache: apiCache)
      ..categoriesLoaded = true
      ..selectedSection = BrowseSection.liveChannels
      ..isLoadingLiveChannels = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(apiCache: apiCache, browseStore: store),
      ),
    );
    await tester.pump();

    final liveSkeleton = find.byKey(const ValueKey("browse_live_channels_skeleton"));
    final firstCard = find
        .descendant(
          of: liveSkeleton,
          matching: find.byType(StreamCardSkeleton),
        )
        .first;
    final thumbnail = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey("stream_skeleton_thumbnail")),
    );
    final viewers = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey("stream_skeleton_viewers")),
    );
    final avatar = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey("stream_skeleton_avatar")),
    );
    final verified = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey("stream_skeleton_verified")),
    );
    final title = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey("stream_skeleton_title")),
    );
    final metadata = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey("stream_skeleton_metadata")),
    );
    final secondTitleLine = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey("stream_skeleton_title_second_line")),
    );

    expect(liveSkeleton, findsOneWidget);
    expect(tester.widget<StreamCardSkeleton>(firstCard).showCategory, isTrue);
    expect(tester.getSize(firstCard).height, 93);
    expect(tester.getSize(thumbnail), const Size(116, 65.25));
    expect(tester.getSize(viewers), const Size(49, 17));
    expect(tester.getSize(avatar), const Size(28, 28));
    expect(tester.getSize(verified), const Size(14, 14));
    expect(tester.getSize(title).height, 17);
    expect(tester.getSize(metadata), const Size(104, 15));
    expect(secondTitleLine, findsNothing);
  });

  testWidgets("shows skeletons for category streams and search results", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
      ),
    );
    const category = BrowseCategory(
      id: "category-1",
      name: "Just Chatting",
      viewerCount: 1,
      viewers: "1",
      imageUrl: null,
      colors: [Colors.purple, Colors.pink],
    );
    final categoryStore = CategoryStreamsStore(apiCache: apiCache, category: category)
      ..isLoading = true;

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

    final categorySkeleton = find.byKey(const ValueKey("category_streams_skeleton"));
    final firstCategoryCard = find
        .descendant(
          of: categorySkeleton,
          matching: find.byType(StreamCardSkeleton),
        )
        .first;
    final firstTitleLine = find.descendant(
      of: firstCategoryCard,
      matching: find.byKey(const ValueKey("stream_skeleton_title")),
    );
    final secondTitleLine = find.descendant(
      of: firstCategoryCard,
      matching: find.byKey(const ValueKey("stream_skeleton_title_second_line")),
    );
    final metadata = find.descendant(
      of: firstCategoryCard,
      matching: find.byKey(const ValueKey("stream_skeleton_metadata")),
    );

    expect(categorySkeleton, findsOneWidget);
    expect(find.byType(StreamCardSkeleton), findsNWidgets(13));
    expect(tester.widget<StreamCardSkeleton>(firstCategoryCard).showCategory, isFalse);
    expect(tester.getSize(firstCategoryCard).height, 93);
    expect(tester.getSize(firstTitleLine).height, 17);
    expect(tester.getSize(secondTitleLine).height, 15);
    expect(tester.getSize(secondTitleLine).width, tester.getSize(firstTitleLine).width);
    expect(
      tester.getTopLeft(secondTitleLine).dy - tester.getBottomLeft(firstTitleLine).dy,
      5,
    );
    expect(metadata, findsNothing);
    expect(
      tester.getBottomLeft(find.byType(StreamCardSkeleton).at(12)).dy,
      greaterThanOrEqualTo(1200),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text("No live channels streaming Just Chatting."), findsNothing);

    final searchStore =
        BrowseSearchStore(
            apiCache: apiCache,
            preferences: _MemorySearchHistoryStore(),
          )
          ..query = "flow"
          ..isSearching = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseSearchScreen(
          authController: _authController(),
          apiCache: apiCache,
          preferences: searchStore.preferences,
          searchStore: searchStore,
        ),
      ),
    );
    await tester.pump();

    final channelsHeader = find.byKey(
      const ValueKey("browse_search_channels_skeleton_header"),
    );
    final categoriesHeader = find.byKey(
      const ValueKey("browse_search_categories_skeleton_header"),
    );
    final firstChannelRow = find.byKey(const ValueKey("browse_search_channel_skeleton_0"));
    final secondChannelRow = find.byKey(const ValueKey("browse_search_channel_skeleton_1"));
    final firstCategoryRow = find.byKey(const ValueKey("browse_search_category_skeleton_0"));
    final secondCategoryRow = find.byKey(const ValueKey("browse_search_category_skeleton_1"));
    final channelAvatar = find.descendant(
      of: firstChannelRow,
      matching: find.byWidgetPredicate(
        (widget) => widget is SkeletonBox && widget.width == 42 && widget.height == 42,
      ),
    );
    final channelTitle = find.descendant(
      of: firstChannelRow,
      matching: find.byWidgetPredicate(
        (widget) => widget is SkeletonBox && widget.height == 16,
      ),
    );
    final categoryThumbnail = find.descendant(
      of: firstCategoryRow,
      matching: find.byWidgetPredicate(
        (widget) => widget is SkeletonBox && widget.height == 1,
      ),
    );
    final categoryTitle = find.descendant(
      of: firstCategoryRow,
      matching: find.byWidgetPredicate(
        (widget) => widget is SkeletonBox && widget.height == 16,
      ),
    );

    expect(find.byKey(const ValueKey("browse_search_skeleton")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_search_channel_skeleton_6")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_search_channel_skeleton_7")), findsNothing);
    expect(find.byKey(const ValueKey("browse_search_category_skeleton_3")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_search_category_skeleton_4")), findsNothing);
    expect(tester.getSize(channelsHeader).height, 35);
    expect(tester.getSize(categoriesHeader).height, 35);
    expect(
      tester.getSize(find.descendant(of: channelsHeader, matching: find.byType(SkeletonBox))),
      const Size(68, 14),
    );
    expect(
      tester.getSize(find.descendant(of: categoriesHeader, matching: find.byType(SkeletonBox))),
      const Size(82, 14),
    );
    expect(tester.getSize(firstChannelRow).height, 72);
    expect(tester.getTopLeft(secondChannelRow).dy - tester.getTopLeft(firstChannelRow).dy, 72);
    expect(tester.getSize(channelAvatar), const Size(42, 42));
    expect(
      tester.getTopLeft(channelTitle).dx - tester.getTopRight(channelAvatar).dx,
      closeTo(AppSpacing.lg, 0.1),
    );
    expect(tester.getSize(firstCategoryRow).height, 144);
    expect(tester.getTopLeft(secondCategoryRow).dy - tester.getTopLeft(firstCategoryRow).dy, 144);
    expect(tester.getSize(categoryThumbnail), const Size(96, 128));
    expect(
      tester.getTopLeft(categoryTitle).dx - tester.getTopRight(categoryThumbnail).dx,
      closeTo(AppSpacing.md, 0.1),
    );
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey("browse_search_category_skeleton_3"))).dy,
      greaterThanOrEqualTo(1200),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text("No matching channels."), findsNothing);
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

    _expectVisibleHeaderGap(
      tester,
      header: find.ancestor(
        of: find.byKey(const ValueKey("browse_title")),
        matching: find.byType(ClipRect),
      ),
      content: find.byKey(const ValueKey("browse_segmented_control")),
    );

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
    _expectVisibleHeaderGap(
      tester,
      header: find.ancestor(
        of: find.byKey(const ValueKey("category_streams_title_Just Chatting")),
        matching: find.byType(ClipRect),
      ),
      content: find.byKey(const ValueKey("browse_live_channels")),
    );
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

  testWidgets("opens browse live channel identities from the Live Channels section", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_live_channels")), findsOneWidget);
    expect(find.byKey(const ValueKey("stream_channel_identity_AussieAntics")), findsOneWidget);
    expect(find.byKey(const ValueKey("stream_category_AussieAntics")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("stream_channel_identity_AussieAntics")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsOneWidget);
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

  testWidgets("retains Browse content and images when switching sections", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var topCategoriesRequests = 0;
    var topLiveStreamsRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(
            onRequest: (request) {
              if (_isGraphQlOperation(request, "FlowTopGames") &&
                  _graphQlVariables(request)["after"] == null) {
                topCategoriesRequests++;
              }
              if (_isGraphQlOperation(request, "FlowTopStreams") &&
                  _graphQlVariables(request)["after"] == null) {
                topLiveStreamsRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();

    final categoryImage = find.descendant(
      of: find.byKey(
        const ValueKey("browse_category_card_Just Chatting"),
        skipOffstage: false,
      ),
      matching: find.byType(Image, skipOffstage: false),
      skipOffstage: false,
    );
    final categoryImageElement = tester.element(categoryImage);

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();

    final liveImage = find.descendant(
      of: find.byKey(
        const ValueKey("stream_thumbnail_AussieAntics"),
        skipOffstage: false,
      ),
      matching: find.byType(Image, skipOffstage: false),
      skipOffstage: false,
    );
    final liveImageElement = tester.element(liveImage);
    expect(topCategoriesRequests, 1);
    expect(topLiveStreamsRequests, 1);

    await tester.tap(find.byKey(const ValueKey("browse_segment_categories")));
    await tester.pumpAndSettle();

    expect(tester.element(categoryImage), same(categoryImageElement));
    expect(tester.element(liveImage), same(liveImageElement));
    expect(find.byKey(const ValueKey("stream_thumbnail_AussieAntics")), findsNothing);
    expect(topCategoriesRequests, 1);
    expect(topLiveStreamsRequests, 1);

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();

    expect(tester.element(liveImage), same(liveImageElement));
    expect(topCategoriesRequests, 1);
    expect(topLiveStreamsRequests, 1);
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
    _expectVisibleHeaderGap(
      tester,
      header: find.byKey(const ValueKey("browse_search_top_bar")),
      content: find.descendant(
        of: find.byKey(const ValueKey("browse_search_history_header")),
        matching: find.text("History"),
      ),
    );

    await tester.tap(find.byKey(const ValueKey("browse_search_clear_history_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_search_history_mine")), findsNothing);
    expect(find.text("No recent searches"), findsOneWidget);
    expect(searchHistoryStore.history, isEmpty);
  });

  testWidgets("searches channels before categories and filters unavailable channels", (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("browse_search_page_field")),
      "mine",
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey("browse_search_channel_MinecraftCreator")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("browse_search_channel_HighCreator")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("browse_search_channel_LowCreator")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("browse_search_channel_BannedCreator")),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey("browse_search_category_Minecraft")),
      findsOneWidget,
    );
    expect(
      requestedRequests.any(
        (request) => _isGraphQlOperation(request, "FlowSearchCategories"),
      ),
      isTrue,
    );
    expect(
      requestedRequests.where(
        (request) => _isGraphQlOperation(request, "FlowGameStreams"),
      ),
      isEmpty,
    );
    expect(
      requestedRequests.any(
        (request) =>
            _isGraphQlOperation(request, "FlowUsers") &&
            ((_graphQlVariables(request)["logins"] as List<Object?>?) ?? const <Object?>[])
                .contains("highcreator"),
      ),
      isTrue,
    );

    expect(find.byKey(const ValueKey("browse_search_channels_header")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_search_categories_header")), findsOneWidget);
    final offlineAvatar = tester.widget<AvatarRing>(
      find.descendant(
        of: find.byKey(const ValueKey("browse_search_channel_avatar_MinecraftCreator")),
        matching: find.byType(AvatarRing),
      ),
    );
    expect(offlineAvatar.statusColor, isNull);

    final highChannelTop = tester.getTopLeft(
      find.byKey(const ValueKey("browse_search_channel_HighCreator")),
    );
    final lowChannelTop = tester.getTopLeft(
      find.byKey(const ValueKey("browse_search_channel_LowCreator")),
    );
    final categoryTop = tester.getTopLeft(
      find.byKey(const ValueKey("browse_search_category_Minecraft")),
    );
    final lowViewerCategoryTop = tester.getTopLeft(
      find.byKey(const ValueKey("browse_search_category_Valiant Hearts")),
    );

    expect(highChannelTop.dy, lessThan(lowChannelTop.dy));
    expect(categoryTop.dy, lessThan(lowViewerCategoryTop.dy));

    await tester.tap(find.byKey(const ValueKey("browse_search_category_Minecraft")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Minecraft")), findsOneWidget);
  });

  testWidgets("keeps search results in memory when reopening search", (tester) async {
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

    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("browse_search_page_field")),
      "mine",
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey("browse_search_channel_MinecraftCreator")),
      findsOneWidget,
    );
    _expectVisibleHeaderGap(
      tester,
      header: find.byKey(const ValueKey("browse_search_top_bar")),
      content: find.descendant(
        of: find.byKey(const ValueKey("browse_search_channels_header")),
        matching: find.text("Channels"),
      ),
    );
    final searchRequestsAfterFirstOpen = requestedRequests
        .where((request) => _isGraphQlOperation(request, "FlowSearchChannels"))
        .length;

    Navigator.of(tester.element(find.byKey(const ValueKey("browse_search_page")))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_search_field")));
    await tester.pumpAndSettle();

    expect(find.text("mine"), findsOneWidget);
    expect(
      find.byKey(const ValueKey("browse_search_channel_MinecraftCreator")),
      findsOneWidget,
    );
    final searchRequestsAfterReopen = requestedRequests
        .where((request) => _isGraphQlOperation(request, "FlowSearchChannels"))
        .length;
    expect(searchRequestsAfterReopen, searchRequestsAfterFirstOpen);
  });

  testWidgets("opens live search results in the player and avatars as channels", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(),
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

    await tester.tap(find.byKey(const ValueKey("browse_search_channel_MinecraftCreator")));
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

    Navigator.of(
      tester.element(find.byKey(const ValueKey("player_page_highcreator"))),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_search_channel_avatar_HighCreator")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("channel_page_highcreator")), findsOneWidget);
  });
}

void _expectVisibleHeaderGap(
  WidgetTester tester, {
  required Finder header,
  required Finder content,
}) {
  final headerBottom = tester.getBottomLeft(header).dy;
  final contentTop = tester.getTopLeft(content).dy;

  expect(contentTop - headerBottom, closeTo(PageHeaderLayout.headerContentGap, 0.1));
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
              ),
              _searchChannelEdge(
                id: "creator-high",
                login: "highcreator",
                displayName: "HighCreator",
                isLive: true,
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

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}

class _MemorySearchHistoryStore implements FlowPreferences {
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
