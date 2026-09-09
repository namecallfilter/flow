import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("VOD seek metadata retries missing storyboards and caches complete results", () async {
    var requests = 0;
    final cache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client",
        accessToken: "token",
        httpClient: MockClient((request) async {
          if (request.method == "GET") {
            return requests == 1
                ? http.Response("Still processing", 503)
                : http.Response(
                    jsonEncode([
                      {
                        "width": 160,
                        "height": 90,
                        "cols": 1,
                        "rows": 1,
                        "count": 1,
                        "interval": 10,
                        "images": ["preview.jpg"],
                      },
                    ]),
                    200,
                  );
          }
          requests++;
          return _jsonResponse({
            "data": {
              "video": {
                "seekPreviewsURL": "https://example.com/storyboard.json",
                "muteInfo": null,
              },
            },
          });
        }),
      ),
    );
    final first = await cache.fetchVodSeekMetadata("123456");
    expect(first.storyboard, isNull);
    expect(requests, 1);
    final retried = await cache.fetchVodSeekMetadata("123456");
    expect(retried.storyboard, isNotNull);
    expect(await cache.fetchVodSeekMetadata(" 123456 "), same(retried));
    expect(requests, 2);
    await cache.fetchVodSeekMetadata("654321");
    await cache.fetchVodSeekMetadata("123456", refresh: true);
    expect(requests, 4);
  });

  test("directory cache defaults to recommendations and isolates server ordering", () async {
    final requests = <Map<String, Object?>>[];
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      gqlAccessToken: "web-token-123",
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final variables = body["variables"]! as Map<String, Object?>;
        requests.add(variables);
        final sort = (variables["options"]! as Map<String, Object?>)["sort"];
        expect(
          request.headers["Authorization"],
          sort == "RELEVANCE" ? "OAuth web-token-123" : null,
        );
        return _jsonResponse({
          "data": {
            "streams": {
              "edges": <Object?>[],
              "pageInfo": {"hasNextPage": false},
            },
            "games": {
              "edges": <Object?>[],
              "pageInfo": {"hasNextPage": false},
            },
          },
        });
      }),
    );
    final cache = TwitchApiCache(clientLoader: () async => client);
    await cache.fetchLiveStreamsPage();
    for (final sort in StreamSort.values) {
      await cache.fetchLiveStreamsPage(sort: sort);
      await cache.fetchLiveStreamsPage(sort: sort);
    }
    await cache.fetchLiveStreamsPage(sort: StreamSort.viewersLowToHigh, cursor: "ascending-page-2");
    expect(requests.last["after"], "ascending-page-2");
    await cache.fetchTopCategoriesPage();
    for (final sort in CategorySort.values) {
      await cache.fetchTopCategoriesPage(sort: sort);
      await cache.fetchTopCategoriesPage(sort: sort);
    }
    expect(requests.map((variables) => (variables["options"]! as Map<String, Object?>)["sort"]), [
      "RELEVANCE",
      "VIEWER_COUNT",
      "VIEWER_COUNT_ASC",
      "RECENT",
      "VIEWER_COUNT_ASC",
      "RELEVANCE",
      "VIEWER_COUNT",
    ]);
  });
  test("a slow request cannot replace the result of a newer refresh", () async {
    final responses = <Completer<http.Response>>[];
    final cache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((_) {
          final response = Completer<http.Response>();
          responses.add(response);
          return response.future;
        }),
      ),
    );
    final oldRequest = cache.fetchTopCategoriesPage();
    await Future<void>.delayed(Duration.zero);
    final refresh = cache.fetchTopCategoriesPage(refresh: true);
    await Future<void>.delayed(Duration.zero);

    responses[1].complete(_topGamesResponse(id: "new", name: "New"));
    await refresh;
    responses[0].complete(_topGamesResponse(id: "old", name: "Old"));
    await oldRequest;

    expect((await cache.fetchTopCategoriesPage()).data.single.name, "New");
    expect(responses, hasLength(2));
  });

  test("category cache keys preserve which category is requested first", () async {
    var requests = 0;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((_) async {
        requests++;
        return _jsonResponse({
          "data": {"users": <Object?>[], "game": null},
        });
      }),
    );
    final cache = TwitchApiCache(clientLoader: () async => client);

    await cache.fetchLiveStreamsPage(gameIds: ["1", "2"]);
    await cache.fetchLiveStreamsPage(gameIds: ["2", "1"]);

    expect(requests, 2);
  });

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
