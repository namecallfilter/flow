import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("fetches top categories with a pagination cursor", () async {
    late Uri requestedUri;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return _jsonResponse({
          "data": [
            {
              "id": "516575",
              "name": "VALORANT",
              "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/516575-{width}x{height}.jpg",
            },
          ],
          "pagination": {"cursor": "cat-page-3"},
        });
      }),
    );

    final page = await client.fetchTopCategoriesPage(
      first: 20,
      cursor: "cat-page-2",
    );

    expect(requestedUri.path, "/helix/games/top");
    expect(requestedUri.queryParameters["first"], "20");
    expect(requestedUri.queryParameters["after"], "cat-page-2");
    expect(page.cursor, "cat-page-3");
    expect(page.data.single.name, "VALORANT");
  });

  test("fetches live streams with a pagination cursor", () async {
    late Uri requestedUri;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return _jsonResponse({
          "data": [
            {
              "id": "stream-2",
              "user_id": "creator-2",
              "user_login": "nextcreator",
              "user_name": "NextCreator",
              "game_id": "21779",
              "game_name": "League of Legends",
              "title": "Next page stream",
              "viewer_count": 1900,
              "thumbnail_url":
                  "https://static-cdn.jtvnw.net/previews-ttv/live_user_nextcreator-{width}x{height}.jpg",
            },
          ],
          "pagination": {"cursor": "stream-page-3"},
        });
      }),
    );

    final page = await client.fetchLiveStreamsPage(
      gameIds: const ["21779"],
      userLogins: const ["nextcreator"],
      cursor: "stream-page-2",
    );

    expect(requestedUri.path, "/helix/streams");
    expect(requestedUri.queryParametersAll["game_id"], ["21779"]);
    expect(requestedUri.queryParametersAll["user_login"], ["nextcreator"]);
    expect(requestedUri.queryParameters["after"], "stream-page-2");
    expect(page.cursor, "stream-page-3");
    expect(page.data.single.userName, "NextCreator");
  });

  test("searches channels as a paginated typeahead query", () async {
    late Uri requestedUri;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return _jsonResponse({
          "data": [
            {
              "id": "creator-2",
              "broadcaster_login": "minecraftcreator",
              "display_name": "MinecraftCreator",
              "game_name": "Minecraft",
              "title": "Building",
              "thumbnail_url": "https://static-cdn.jtvnw.net/creator-2.png",
              "is_live": false,
            },
          ],
          "pagination": {"cursor": "channel-page-2"},
        });
      }),
    );

    final page = await client.searchChannelsPage(
      "mine",
      first: 8,
      cursor: "channel-page-1",
    );

    expect(requestedUri.path, "/helix/search/channels");
    expect(requestedUri.queryParameters["query"], "mine");
    expect(requestedUri.queryParameters["first"], "8");
    expect(requestedUri.queryParameters["after"], "channel-page-1");
    expect(requestedUri.queryParameters.containsKey("live_only"), isFalse);
    expect(page.cursor, "channel-page-2");
    expect(page.data.single.displayName, "MinecraftCreator");
  });
}

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);
