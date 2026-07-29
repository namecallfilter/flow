import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("deduplicates in-flight requests and reuses session cache", () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((_) {
        requests++;
        return response.future;
      }),
    );
    final cache = TwitchApiCache(clientLoader: () async => client);

    final first = cache.fetchTopCategoriesPage();
    final second = cache.fetchTopCategoriesPage();
    await Future<void>.delayed(Duration.zero);

    expect(requests, 1);

    response.complete(
      _topGamesResponse(id: "509658", name: "Just Chatting"),
    );

    expect((await first).data.single.name, "Just Chatting");
    expect((await second).data.single.name, "Just Chatting");

    final cached = await cache.fetchTopCategoriesPage();

    expect(cached.data.single.name, "Just Chatting");
    expect(requests, 1);
  });

  test("caches channel details by normalized login and supports refresh", () async {
    var requests = 0;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((_) async {
        requests++;
        return _channelDetailsResponse(
          login: "jason",
          displayName: "Jason $requests",
        );
      }),
    );
    final cache = TwitchApiCache(clientLoader: () async => client);

    expect((await cache.fetchChannelDetails("Jason")).displayName, "Jason 1");
    expect((await cache.fetchChannelDetails("jason")).displayName, "Jason 1");
    expect(
      (await cache.fetchChannelDetails("jason", refresh: true)).displayName,
      "Jason 2",
    );
    expect(requests, 2);
  });

  test("evicts the least recently used value when capacity is exceeded", () async {
    var requests = 0;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((_) async {
        requests++;
        return _topGamesResponse(id: "$requests", name: "Category $requests");
      }),
    );
    final cache = TwitchApiCache(
      clientLoader: () async => client,
      maxEntries: 2,
    );

    await cache.fetchTopCategoriesPage(first: 1);
    await cache.fetchTopCategoriesPage(first: 2);
    await cache.fetchTopCategoriesPage(first: 1);
    await cache.fetchTopCategoriesPage(first: 3);

    expect(requests, 3);

    await cache.fetchTopCategoriesPage(first: 1);

    expect(requests, 3);

    await cache.fetchTopCategoriesPage(first: 2);

    expect(requests, 4);
  });

  test("clear prevents older in-flight requests from repopulating the cache", () async {
    var requests = 0;
    final firstResponse = Completer<http.Response>();
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((_) async {
        requests++;
        if (requests == 1) {
          return firstResponse.future;
        }
        return _topGamesResponse(id: "$requests", name: "Category $requests");
      }),
    );
    final cache = TwitchApiCache(clientLoader: () async => client);

    final first = cache.fetchTopCategoriesPage();
    await Future<void>.delayed(Duration.zero);
    cache.clear();
    firstResponse.complete(
      _topGamesResponse(id: "1", name: "Category 1"),
    );

    expect((await first).data.single.name, "Category 1");
    expect((await cache.fetchTopCategoriesPage()).data.single.name, "Category 2");
    expect(requests, 2);
  });
}

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

http.Response _topGamesResponse({
  required String id,
  required String name,
}) => _jsonResponse({
  "data": {
    "games": {
      "edges": [
        {
          "cursor": null,
          "node": {
            "id": id,
            "displayName": name,
            "boxArtURL": "https://static-cdn.jtvnw.net/ttv-boxart/$id-{width}x{height}.jpg",
          },
        },
      ],
      "pageInfo": {"hasNextPage": false},
    },
  },
});

http.Response _channelDetailsResponse({
  required String login,
  required String displayName,
}) => _jsonResponse({
  "data": {
    "user": {
      "id": "creator-1",
      "login": login,
      "displayName": displayName,
      "description": "",
      "profileImageURL": "https://static-cdn.jtvnw.net/creator-1.png",
      "followers": {"totalCount": 0},
      "stream": null,
      "videos": {
        "edges": const <Object?>[],
        "pageInfo": {"hasNextPage": false},
      },
    },
  },
});
