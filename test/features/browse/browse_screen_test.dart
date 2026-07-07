import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/browse/browse_screen.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/player/player_controller.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

import "../../helpers/fake_flow_video_controller.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  setUp(() {
    debugSetFlowVideoControllerFactory(FakeFlowVideoController.new);
  });

  tearDown(debugResetFlowVideoControllerFactory);

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

    await tester.tap(find.byKey(const ValueKey("stream_thumbnail_AussieAntics")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("player_page_aussieantics")), findsOneWidget);
    expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const ValueKey("player_page_aussieantics"))),
    ).pop();
    await tester.pumpAndSettle();

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

    await tester.tap(find.byKey(const ValueKey("stream_channel_identity_AussieAntics")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsOneWidget);
  });

  testWidgets("does not paginate when switching between Browse sections", (
    tester,
  ) async {
    final requestedRequests = <http.Request>[];
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

  testWidgets("opens search channels with live results limited to the avatar", (
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
    expect(find.byKey(const ValueKey("channel_page_highcreator")), findsNothing);

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
          _categoryJson(id: "509658", name: "Just Chatting"),
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

    if (query.contains("FlowPlaybackAccessToken")) {
      return _livePlaybackResponse();
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
}) => {
  "id": id,
  "displayName": name,
  "boxArtURL": boxArtUrl ?? "https://static-cdn.jtvnw.net/ttv-boxart/$id-{width}x{height}.jpg",
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

http.Response _livePlaybackResponse() => _jsonResponse({
  "data": {
    "streamPlaybackAccessToken": {
      "value": "token-value",
      "signature": "sig-value",
      "authorization": {"isForbidden": false},
    },
  },
});

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
  List<String> history = const <String>[];

  @override
  Future<void> clearBrowseSearchHistory() async {
    history = const <String>[];
  }

  @override
  Future<List<String>> readBrowseSearchHistory() async => history;

  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.system;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    this.history = List<String>.of(history);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
