import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/browse/browse_screen.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  testWidgets("shows categories with viewer counts, pagination, and refresh", (
    tester,
  ) async {
    final requestedUris = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(
            onRequest: (request) {
              requestedUris.add(request.url);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_title")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_category_card_Just Chatting")), findsOneWidget);
    expect(find.text("31K"), findsOneWidget);
    expect(find.byType(StreamCard), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(
      requestedUris.any((uri) => uri.queryParameters["after"] == "cat-page-2"),
      isTrue,
    );
    expect(find.byKey(const ValueKey("browse_category_card_VALORANT")), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    requestedUris.clear();
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      requestedUris.any(
        (uri) => uri.path == "/helix/games/top" && !uri.queryParameters.containsKey("after"),
      ),
      isTrue,
    );
  });

  testWidgets("shows live channels with pagination and refresh", (tester) async {
    final requestedUris = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(
            onRequest: (request) {
              requestedUris.add(request.url);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_categories_grid")), findsNothing);
    expect(find.byType(StreamCard), findsWidgets);
    expect(find.text("AussieAntics"), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(
      requestedUris.any((uri) => uri.queryParameters["after"] == "stream-page-2"),
      isTrue,
    );
    expect(find.text("NextStreamer"), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    requestedUris.clear();
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      requestedUris.any(
        (uri) => uri.path == "/helix/streams" && !uri.queryParameters.containsKey("after"),
      ),
      isTrue,
    );
  });

  testWidgets("opens live channels for a tapped category", (tester) async {
    final requestedUris = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(
            onRequest: (request) {
              requestedUris.add(request.url);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    requestedUris.clear();
    await tester.tap(find.byKey(const ValueKey("browse_category_card_Just Chatting")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    expect(find.byKey(const ValueKey("category_streams_title_Just Chatting")), findsOneWidget);
    expect(find.byType(StreamCard), findsWidgets);
    expect(find.text("AussieAntics"), findsOneWidget);
    expect(find.text("NovaSkye"), findsOneWidget);
    expect(
      requestedUris.any(
        (uri) =>
            uri.path == "/helix/streams" &&
            (uri.queryParametersAll["game_id"] ?? const <String>[]).contains("509658"),
      ),
      isTrue,
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

    expect(
      find.descendant(
        of: find.byKey(const ValueKey("browse_search_top_bar")),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    expect(find.text("Search channels or categories"), findsOneWidget);
    expect(find.text("Search channels"), findsNothing);
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

  testWidgets("searches channels before categories and filters unavailable channels", (
    tester,
  ) async {
    final requestedUris = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.dark),
        home: BrowseScreen(
          authController: _authController(
            onRequest: (request) {
              requestedUris.add(request.url);
            },
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
      requestedUris.any((uri) => uri.path == "/helix/search/categories"),
      isTrue,
    );
    expect(
      requestedUris.any(
        (uri) =>
            uri.path == "/helix/streams" &&
            (uri.queryParametersAll["user_login"] ?? const <String>[]).contains("highcreator"),
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
    final categoryThumbnailImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey("browse_search_category_thumbnail_Minecraft")),
        matching: find.byType(Image),
      ),
    );

    expect(highChannelTop.dy, lessThan(lowChannelTop.dy));
    expect(categoryTop.dy, lessThan(lowViewerCategoryTop.dy));
    expect(
      (categoryThumbnailImage.image as NetworkImage).url,
      contains("1200x1600"),
    );

    await tester.tap(find.byKey(const ValueKey("browse_search_category_Minecraft")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Minecraft")), findsOneWidget);
  });
}

TwitchAuthController _authController({_RequestObserver? onRequest}) {
  final store = _MemoryTwitchStore()..accessToken = "token-123";
  return TwitchAuthController(
    config: const TwitchAuthConfig(clientId: "client-123"),
    secureStore: store,
    apiClientFactory: (accessToken) => TwitchApiClient(
      clientId: "client-123",
      accessToken: accessToken,
      httpClient: _browseHttpClient(onRequest: onRequest),
    ),
    cookieExtractor: const _StaticCookieExtractor(),
  );
}

MockClient _browseHttpClient({_RequestObserver? onRequest}) => MockClient((request) async {
  onRequest?.call(request);

  if (request.url.path == "/helix/users") {
    final ids = request.url.queryParametersAll["id"] ?? const <String>[];
    return _jsonResponse({
      "data": [
        for (final id in ids)
          if (id != "banned-1")
            {
              "id": id,
              "login": _loginForUserId(id),
              "display_name": _displayNameForUserId(id),
              "profile_image_url": "https://static-cdn.jtvnw.net/$id.png",
            },
      ],
    });
  }

  if (request.url.path == "/helix/games/top") {
    if (request.url.queryParameters["after"] == "cat-page-2") {
      return _jsonResponse({
        "data": [
          _categoryJson(id: "516575", name: "VALORANT"),
          _categoryJson(id: "27471", name: "Minecraft"),
          _categoryJson(id: "33214", name: "Fortnite"),
        ],
      });
    }

    return _jsonResponse({
      "data": [
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
      "pagination": {"cursor": "cat-page-2"},
    });
  }

  if (request.url.path == "/helix/search/channels") {
    return _jsonResponse({
      "data": [
        {
          "id": "creator-low",
          "broadcaster_login": "lowcreator",
          "display_name": "LowCreator",
          "game_name": "Minecraft",
          "title": "Low live search result",
          "thumbnail_url": "https://static-cdn.jtvnw.net/creator-low.png",
          "is_live": true,
        },
        {
          "id": "creator-4",
          "broadcaster_login": "minecraftcreator",
          "display_name": "MinecraftCreator",
          "game_name": "Minecraft",
          "title": "Building from search",
          "thumbnail_url": "https://static-cdn.jtvnw.net/creator-4.png",
          "is_live": false,
        },
        {
          "id": "creator-high",
          "broadcaster_login": "highcreator",
          "display_name": "HighCreator",
          "game_name": "Minecraft",
          "title": "High live search result",
          "thumbnail_url": "https://static-cdn.jtvnw.net/creator-high.png",
          "is_live": true,
        },
        {
          "id": "banned-1",
          "broadcaster_login": "bannedcreator",
          "display_name": "BannedCreator",
          "game_name": "Minecraft",
          "title": "Unavailable account",
          "thumbnail_url": "https://static-cdn.jtvnw.net/banned-1.png",
          "is_live": false,
        },
      ],
    });
  }

  if (request.url.path == "/helix/search/categories") {
    return _jsonResponse({
      "data": [
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
    });
  }

  if (request.url.path == "/helix/streams") {
    final gameIds = request.url.queryParametersAll["game_id"] ?? const <String>[];
    final userLogins = request.url.queryParametersAll["user_login"] ?? const <String>[];
    if (userLogins.isNotEmpty) {
      return _jsonResponse({
        "data": [
          _streamJson(
            id: "low-search-stream",
            userId: "creator-low",
            userLogin: "lowcreator",
            userName: "LowCreator",
            gameName: "Minecraft",
            viewerCount: 10,
          ),
          _streamJson(
            id: "high-search-stream",
            userId: "creator-high",
            userLogin: "highcreator",
            userName: "HighCreator",
            gameName: "Minecraft",
            viewerCount: 900,
          ),
        ],
      });
    }
    if (gameIds.contains("509658")) {
      return _jsonResponse({
        "data": [
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
        ],
      });
    }
    if (gameIds.contains("27471")) {
      return _jsonResponse({
        "data": [
          _streamJson(
            id: "minecraft-category-stream",
            userId: "creator-4",
            userLogin: "minecraftcreator",
            userName: "MinecraftCreator",
            gameName: "Minecraft",
            viewerCount: 4200,
          ),
        ],
      });
    }
    if (gameIds.isNotEmpty) {
      return _jsonResponse({"data": <Object?>[]});
    }
    if (request.url.queryParameters["after"] == "stream-page-2") {
      return _jsonResponse({
        "data": [
          _streamJson(
            id: "stream-124",
            userId: "creator-5",
            userLogin: "nextstreamer",
            userName: "NextStreamer",
            gameName: "VALORANT",
            viewerCount: 1900,
          ),
        ],
      });
    }

    return _jsonResponse({
      "data": [
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
      "pagination": {"cursor": "stream-page-2"},
    });
  }

  return http.Response("not found", 404);
});

String _loginForUserId(String id) => switch (id) {
  "creator-1" => "aussieantics",
  "creator-4" => "minecraftcreator",
  "creator-5" => "nextstreamer",
  _ => "novaskye",
};

String _displayNameForUserId(String id) => switch (id) {
  "creator-1" => "AussieAntics",
  "creator-4" => "MinecraftCreator",
  "creator-5" => "NextStreamer",
  _ => "NovaSkye",
};

Map<String, Object?> _categoryJson({
  required String id,
  required String name,
  String? boxArtUrl,
}) => {
  "id": id,
  "name": name,
  "box_art_url": boxArtUrl ?? "https://static-cdn.jtvnw.net/ttv-boxart/$id-{width}x{height}.jpg",
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
  "user_id": userId,
  "user_login": userLogin,
  "user_name": userName,
  "game_name": gameName,
  "title": "Live from Helix",
  "viewer_count": viewerCount,
  "thumbnail_url":
      "https://static-cdn.jtvnw.net/previews-ttv/live_user_$userLogin-{width}x{height}.jpg",
};

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

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
