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
      _jsonResponse({
        "data": [
          {
            "id": "509658",
            "name": "Just Chatting",
            "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/509658-{width}x{height}.jpg",
          },
        ],
      }),
    );

    expect((await first).data.single.name, "Just Chatting");
    expect((await second).data.single.name, "Just Chatting");

    final cached = await cache.fetchTopCategoriesPage();

    expect(cached.data.single.name, "Just Chatting");
    expect(requests, 1);
  });

  test("refresh bypasses cached API data", () async {
    var requests = 0;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((_) async {
        requests++;
        return _jsonResponse({
          "data": [
            {
              "id": "$requests",
              "name": "Category $requests",
              "box_art_url":
                  "https://static-cdn.jtvnw.net/ttv-boxart/$requests-{width}x{height}.jpg",
            },
          ],
        });
      }),
    );
    final cache = TwitchApiCache(clientLoader: () async => client);

    expect((await cache.fetchTopCategoriesPage()).data.single.name, "Category 1");
    expect((await cache.fetchTopCategoriesPage()).data.single.name, "Category 1");
    expect((await cache.fetchTopCategoriesPage(refresh: true)).data.single.name, "Category 2");
    expect(requests, 2);
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
        return _jsonResponse({
          "data": [
            {
              "id": "$requests",
              "name": "Category $requests",
              "box_art_url":
                  "https://static-cdn.jtvnw.net/ttv-boxart/$requests-{width}x{height}.jpg",
            },
          ],
        });
      }),
    );
    final cache = TwitchApiCache(clientLoader: () async => client);

    final first = cache.fetchTopCategoriesPage();
    await Future<void>.delayed(Duration.zero);
    cache.clear();
    firstResponse.complete(
      _jsonResponse({
        "data": [
          {
            "id": "1",
            "name": "Category 1",
            "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/1-{width}x{height}.jpg",
          },
        ],
      }),
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
