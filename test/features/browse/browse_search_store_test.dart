import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/browse/browse_search_store.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("ignores stale search results from an earlier query", () async {
    final slowSearch = Completer<http.Response>();
    final cache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((request) async {
          if (request.url.host == "gql.twitch.tv") {
            final query = _graphQlQuery(request);
            final variables = _graphQlVariables(request);
            if (query.contains("FlowSearchChannels")) {
              if (variables["queryFragment"] == "slow") {
                return slowSearch.future;
              }
              return _jsonResponse({
                "data": {
                  "searchSuggestions": {
                    "edges": [
                      _searchChannelEdge(id: "fast-1", displayName: "FastCreator"),
                    ],
                    "tracking": null,
                  },
                },
              });
            }
            if (query.contains("FlowSearchCategories")) {
              return _searchCategoriesResponse(const <Map<String, Object?>>[]);
            }
            if (query.contains("FlowUsers")) {
              final ids = (variables["ids"] as List<Object?>?)?.cast<String>() ?? const <String>[];
              return _jsonResponse({
                "data": {
                  "users": [
                    for (final id in ids) _userJson(id),
                  ],
                },
              });
            }
            if (query.contains("FlowTopStreams") || query.contains("FlowGameStreams")) {
              return _topStreamsResponse(const <Map<String, Object?>>[]);
            }
          }

          return http.Response("not found", 404);
        }),
      ),
    );
    final store = BrowseSearchStore(
      apiCache: cache,
      preferences: _MemoryFlowPreferences(),
    );

    final slowFuture = store.search("slow");
    await Future<void>.delayed(Duration.zero);
    await store.search("fast");

    expect(store.channels.single.displayName, "FastCreator");

    slowSearch.complete(
      _jsonResponse({
        "data": {
          "searchSuggestions": {
            "edges": [
              _searchChannelEdge(id: "slow-1", displayName: "SlowCreator"),
            ],
            "tracking": null,
          },
        },
      }),
    );
    await slowFuture;

    expect(store.channels.single.displayName, "FastCreator");
  });
}

String _graphQlQuery(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return body["query"]! as String;
}

Map<String, Object?> _graphQlVariables(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
}

Map<String, Object?> _searchChannelEdge({
  required String id,
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
      "login": displayName.toLowerCase(),
      "profileImageURL": "https://static-cdn.jtvnw.net/$id.png",
      "user": {
        "id": id,
        "roles": const <Object?>[],
        "stream": null,
      },
    },
  },
};

Map<String, Object?> _userJson(String id) => {
  "id": id,
  "login": id == "fast-1" ? "fastcreator" : "slowcreator",
  "displayName": id == "fast-1" ? "FastCreator" : "SlowCreator",
  "profileImageURL": "https://static-cdn.jtvnw.net/$id.png",
  "broadcastSettings": null,
  "stream": null,
};

http.Response _searchCategoriesResponse(
  List<Map<String, Object?>> categories,
) => _jsonResponse({
  "data": {
    "searchCategories": {
      "edges": [
        for (final category in categories) {"cursor": null, "node": category},
      ],
      "pageInfo": {"hasNextPage": false},
    },
  },
});

http.Response _topStreamsResponse(
  List<Map<String, Object?>> streams,
) => _jsonResponse({
  "data": {
    "streams": {
      "edges": [
        for (final stream in streams) {"cursor": null, "node": stream},
      ],
      "pageInfo": {"hasNextPage": false},
    },
  },
});

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

class _MemoryFlowPreferences implements FlowPreferences {
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

  List<String> searchHistory = const <String>[];

  @override
  Future<void> clearBrowseSearchHistory() async {
    searchHistory = const <String>[];
  }

  @override
  Future<List<String>> readBrowseSearchHistory() async => searchHistory;

  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.system;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    searchHistory = List<String>.of(history);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
