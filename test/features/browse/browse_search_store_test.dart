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
          if (request.url.path == "/helix/search/channels") {
            if (request.url.queryParameters["query"] == "slow") {
              return slowSearch.future;
            }
            return _jsonResponse({
              "data": [
                _searchChannelJson(id: "fast-1", displayName: "FastCreator"),
              ],
            });
          }
          if (request.url.path == "/helix/search/categories") {
            return _jsonResponse({"data": <Object?>[]});
          }
          if (request.url.path == "/helix/users") {
            final ids = request.url.queryParametersAll["id"] ?? const <String>[];
            return _jsonResponse({
              "data": [
                for (final id in ids)
                  {
                    "id": id,
                    "login": "fastcreator",
                    "display_name": "FastCreator",
                  },
              ],
            });
          }
          if (request.url.path == "/helix/streams") {
            return _jsonResponse({"data": <Object?>[]});
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
        "data": [
          _searchChannelJson(id: "slow-1", displayName: "SlowCreator"),
        ],
      }),
    );
    await slowFuture;

    expect(store.channels.single.displayName, "FastCreator");
  });
}

Map<String, Object?> _searchChannelJson({
  required String id,
  required String displayName,
}) => {
  "id": id,
  "broadcaster_login": displayName.toLowerCase(),
  "display_name": displayName,
  "game_name": "Minecraft",
  "title": "Building",
  "thumbnail_url": "https://static-cdn.jtvnw.net/$id.png",
  "is_live": false,
};

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

class _MemoryFlowPreferences implements FlowPreferences {
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
