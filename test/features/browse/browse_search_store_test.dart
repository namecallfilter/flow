import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/browse/browse_search_store.dart";
import "package:flow/shared/preferences/preferences.dart";
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
          }

          return http.Response("not found", 404);
        }),
      ),
    );
    final store = BrowseSearchStore(
      apiCache: cache,
      preferences: MemoryFlowPreferences(),
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

  test("invalidates an in-flight search before the next debounce starts", () async {
    final slowSearch = Completer<http.Response>();
    final preferences = MemoryFlowPreferences();
    var followupRequests = 0;
    final cache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((request) async {
          if (request.url.host == "gql.twitch.tv") {
            final query = _graphQlQuery(request);
            if (query.contains("FlowSearchChannels")) {
              return slowSearch.future;
            }
            followupRequests++;
          }

          return http.Response("not found", 404);
        }),
      ),
    );
    final store =
        BrowseSearchStore(
            apiCache: cache,
            preferences: preferences,
          )
          ..channels = const [
            TwitchSearchChannel(
              id: "cached-1",
              broadcasterLogin: "cachedcreator",
              displayName: "CachedCreator",
              gameName: "",
              title: "",
              isLive: false,
            ),
          ];

    final slowFuture = store.search("slow");
    await Future<void>.delayed(Duration.zero);
    store.invalidatePendingSearch();

    expect(store.isSearching, isFalse);

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

    expect(store.channels.single.displayName, "CachedCreator");
    expect(store.errorMessage, isNull);
    expect(await preferences.readBrowseSearchHistory(), isEmpty);
    expect(followupRequests, 0);
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

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);
