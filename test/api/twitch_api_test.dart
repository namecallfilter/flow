import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  tearDown(() => TwitchApiClient.restoreWebSessionDeviceId(null));

  for (final operation in ["current user", "live follows", "follows", "subscription", "playback"]) {
    test("$operation recovers an integrity challenge before returning data", () async {
      var requests = 0;
      final client = TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        gqlAccessToken: "web-token-123",
        integrityContextLoader: (_) async => {
          "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
          "X-Device-ID": "browser-device",
          "Client-Session-Id": "page-session",
          "Client-Version": "page-build",
          "Client-Integrity": "new-grant",
        },
        httpClient: MockClient((request) async {
          requests++;
          expect(request.headers["Authorization"], "OAuth web-token-123");
          if (requests == 1) {
            return _jsonResponse({
              "errors": [
                {"message": "failed integrity check"},
              ],
            });
          }
          expect(request.headers["Client-Integrity"], "new-grant");
          final connection = {
            "edges": <Object?>[],
            "pageInfo": {"hasNextPage": false},
          };
          return _jsonResponse({
            "data": {
              "currentUser": {
                "id": "viewer",
                "followedLiveUsers": connection,
                "follows": connection,
              },
              "user": {
                "self": {"subscriptionBenefit": null},
              },
              "streamPlaybackAccessToken": {"value": "playback-token", "signature": "signature"},
            },
          });
        }),
      );
      await switch (operation) {
        "current user" => client.fetchCurrentUser(),
        "live follows" => client.fetchFollowedStreams("viewer"),
        "follows" => client.fetchFollowedChannels("viewer"),
        "subscription" => client.fetchChannelSubscriptionStatus("creator"),
        _ => client.fetchLivePlaybackUri("creator"),
      };
      expect(requests, 2);
    });
  }

  test("concurrent and late challenges share recovery across existing clients", () async {
    final observed = Completer<Map<String, String>?>();
    final observationStarted = Completer<void>();
    final lateResponse = Completer<http.Response>();
    final initialRequests = Completer<void>();
    var requests = 0;
    var observations = 0;
    final challenge = _jsonResponse({
      "errors": [
        {"message": "failed integrity check"},
      ],
    });
    final clients = List.generate(3, (index) {
      var calls = 0;
      return TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        gqlAccessToken: "web-token-123",
        integrityContextLoader: (_) {
          observations++;
          if (!observationStarted.isCompleted) {
            observationStarted.complete();
          }
          return observed.future;
        },
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            if (++requests == 3) {
              initialRequests.complete();
            }
            return index == 2 ? lateResponse.future : challenge;
          }
          expect(request.headers["Client-Integrity"], "shared-grant");
          expect(request.headers["X-Device-ID"], "browser-device");
          return _jsonResponse({
            "data": {
              "games": {
                "edges": <Object?>[],
                "pageInfo": {"hasNextPage": false},
              },
            },
          });
        }),
      );
    });
    final loads = [
      for (final client in clients)
        client.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou),
    ];
    await initialRequests.future;
    await observationStarted.future;
    observed.complete({
      "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
      "X-Device-ID": "browser-device",
      "Client-Session-Id": "page-session",
      "Client-Version": "page-build",
      "Client-Integrity": "shared-grant",
    });
    await Future.wait(loads.take(2));
    lateResponse.complete(challenge);
    await loads.last;
    expect(observations, 1);
  });

  test("existing clients pick up a refreshed grant and drop it on session reset", () async {
    final sentTokens = <String?>[];
    var challenged = false;
    final httpClient = MockClient((request) async {
      sentTokens.add(request.headers["Client-Integrity"]);
      if (sentTokens.length == 2 && !challenged) {
        challenged = true;
        return _jsonResponse({
          "errors": [
            {"message": "failed integrity check"},
          ],
        });
      }
      return _jsonResponse({
        "data": {
          "games": {
            "edges": <Object?>[],
            "pageInfo": {"hasNextPage": false},
          },
        },
      });
    });
    TwitchApiClient client() => TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      gqlAccessToken: "web-token-123",
      httpClient: httpClient,
      integrityContextLoader: (_) async => {
        "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
        "X-Device-ID": "browser-device",
        "Client-Session-Id": "page-session",
        "Client-Version": "page-build",
        "Client-Integrity": "new-grant",
      },
    );
    final existing = client();
    final recovering = client();
    await existing.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou);
    await recovering.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou);
    await existing.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou);
    TwitchApiClient.restoreWebSessionDeviceId(null);
    await recovering.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou);
    expect(sentTokens, [null, null, "new-grant", "new-grant", null]);
  });

  for (final throws in [false, true]) {
    test("shared recovery failure is released for the next refresh (throws=$throws)", () async {
      final observed = Completer<Map<String, String>?>();
      final started = Completer<void>();
      var observations = 0;
      final client = TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        gqlAccessToken: "web-token-123",
        integrityContextLoader: (_) {
          observations++;
          if (observations == 1) {
            started.complete();
            return observed.future;
          }
          return Future.value({
            "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
            "X-Device-ID": "browser-device",
            "Client-Session-Id": "page-session",
            "Client-Version": "page-build",
            "Client-Integrity": "new-grant",
          });
        },
        httpClient: MockClient(
          (request) async => _jsonResponse(
            request.headers["Client-Integrity"] == null
                ? {
                    "errors": [
                      {"message": "failed integrity check"},
                    ],
                  }
                : {
                    "data": {
                      "games": {"edges": <Object?>[]},
                    },
                  },
          ),
        ),
      );
      final failures = [
        for (var i = 0; i < 2; i++)
          expectLater(
            client.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou),
            throwsA(isA<TwitchApiException>()),
          ),
      ];
      await started.future;
      if (throws) {
        observed.completeError(StateError("WebView unavailable"));
      } else {
        observed.complete(null);
      }
      await Future.wait(failures);
      expect(observations, 1);
      await client.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou);
      expect(observations, 2);
    });
  }

  for (final (failure, transient) in [
    (http.ClientException("Connection reset by peer", Uri.https("gql.twitch.tv", "/gql")), true),
    (TimeoutException("Request timed out"), true),
    (http.Response('{"errors":[{"message":"Unavailable"}]}', 503), true),
    (http.Response("Service unavailable", 503), true),
    (http.Response("Too many requests", 429), true),
    (http.Response("Unauthorized", 401), false),
    (
      _jsonResponse({
        "errors": [
          {"message": "Unauthorized"},
        ],
      }),
      false,
    ),
  ]) {
    final failureDescription = failure is http.Response
        ? "${failure.statusCode} ${failure.body}"
        : failure.toString();
    test("classifies GraphQL failure as transient=$transient: $failureDescription", () async {
      final client = TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        httpClient: MockClient((_) async {
          if (failure is http.Response) {
            return failure;
          }
          throw failure as Exception;
        }),
      );

      await expectLater(
        client.fetchUsersByIds(["creator-1"]),
        throwsA(
          isA<TwitchApiException>().having((error) => error.isTransient, "isTransient", transient),
        ),
      );
    });
  }

  test("token validation separates expired credentials from a temporary outage", () async {
    var status = 401;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((_) async => http.Response("Unavailable", status)),
    );
    expect(await client.validateAccessToken("token-123"), isFalse);
    status = 503;
    await expectLater(
      client.validateAccessToken("token-123"),
      throwsA(
        isA<TwitchApiException>().having((error) => error.isTransient, "isTransient", isTrue),
      ),
    );
  });

  test("channel info reads the actual last broadcast and category identity", () async {
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((request) async {
        expect(request.body, contains("lastBroadcast"));
        return _jsonResponse({
          "data": {
            "users": [
              {
                "id": "creator-1",
                "login": "creator",
                "displayName": "Creator",
                "lastBroadcast": {"startedAt": "2026-09-02T02:37:34.734703Z"},
                "broadcastSettings": {
                  "title": "Back later",
                  "game": {"id": "509658", "displayName": "Just Chatting"},
                },
              },
              {
                "id": "creator-2",
                "login": "unknown",
                "displayName": "Unknown",
                "lastBroadcast": null,
                "broadcastSettings": null,
              },
            ],
          },
        });
      }),
    );

    final channels = await client.fetchChannelInfoByBroadcasterIds(["creator-1", "creator-2"]);

    expect(
      channels["creator-1"]?.lastBroadcastStartedAt?.toUtc(),
      DateTime.parse("2026-09-02T02:37:34.734703Z"),
    );
    expect(channels["creator-1"]?.gameId, "509658");
    expect(channels["creator-1"]?.gameName, "Just Chatting");
    expect(channels["creator-2"]?.lastBroadcastStartedAt, isNull);
    expect(channels["creator-2"]?.gameId, isEmpty);
  });

  for (final clearDuring in ["initial request", "session observation"]) {
    test("clearing the web session cancels recovery during $clearDuring", () async {
      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      final observationStarted = Completer<void>();
      final observed = Completer<Map<String, String>?>();
      var requests = 0;
      final client = TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        gqlAccessToken: "web-token-123",
        integrityContextLoader: (_) {
          observationStarted.complete();
          return observed.future;
        },
        httpClient: MockClient((_) {
          requests++;
          requestStarted.complete();
          return response.future;
        }),
      );
      final load = client.fetchLiveStreamsPage(
        sort: StreamSort.recommendedForYou,
        cursor: "personal-next",
      );
      final failure = expectLater(load, throwsA(isA<TwitchApiException>()));
      await requestStarted.future;
      if (clearDuring == "initial request") {
        TwitchApiClient.restoreWebSessionDeviceId(null);
      }
      response.complete(
        _jsonResponse({
          "errors": [
            {"message": "failed integrity check"},
          ],
        }),
      );
      if (clearDuring == "session observation") {
        await observationStarted.future;
        TwitchApiClient.restoreWebSessionDeviceId(null);
        observed.complete({
          "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
          "X-Device-ID": "browser-device",
          "Client-Session-Id": "page-session",
          "Client-Version": "page-build",
          "Client-Integrity": "issued-before-sign-out",
        });
      }
      await failure;
      expect(requests, 1);
      expect(observationStarted.isCompleted, clearDuring == "session observation");
    });
  }

  for (final (directory, outcome) in [
    ("global", "success"),
    ("category", "success"),
    ("global", "challenge again"),
    ("global", "no observed token"),
  ]) {
    test("authenticated $directory integrity recovery retries at most once: $outcome", () async {
      final gqlRequests = <http.Request>[];
      var observedSessions = 0;
      final client = TwitchApiClient(
        clientId: "client-123",
        accessToken: "token-123",
        gqlAccessToken: "web-token-123",
        integrityContextLoader: (authorization) async {
          observedSessions++;
          expect(authorization, "OAuth web-token-123");
          return {
            "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
            "X-Device-ID": "observed-browser-device",
            "Client-Session-Id": "observed-page-session",
            "Client-Version": "observed-page-build",
            if (outcome != "no observed token") "Client-Integrity": "server-issued-integrity-token",
          };
        },
        httpClient: MockClient((request) async {
          expect(request.headers["Authorization"], "OAuth web-token-123");
          expect(request.headers["Client-Id"], "kimne78kx3ncx6brgo4mv6wki5h1ko");
          expect(request.url.path, "/gql");
          gqlRequests.add(request);
          if (gqlRequests.length == 1 || outcome == "challenge again") {
            return _jsonResponse({
              "errors": [
                {"message": "failed integrity check"},
              ],
            });
          }
          expect(request.body, gqlRequests.first.body);
          expect(request.headers["Client-Integrity"], "server-issued-integrity-token");
          expect(request.headers["Client-Session-Id"], "observed-page-session");
          return _jsonResponse({
            "data": {
              "streams": {
                "edges": <Object?>[],
                "pageInfo": {"hasNextPage": false},
              },
            },
          });
        }),
      );
      final load = client.fetchLiveStreamsPage(
        sort: StreamSort.recommendedForYou,
        gameIds: directory == "category" ? ["category-id"] : const [],
        cursor: "personal-page-2",
      );
      if (outcome == "success") {
        await load;
      } else {
        await expectLater(load, throwsA(isA<TwitchApiException>()));
      }
      expect(observedSessions, 1);
      expect(gqlRequests, hasLength(outcome == "no observed token" ? 1 : 2));
    });
  }

  test("personalized recommendations use mobile context and retain auth across pages", () async {
    final requests = <http.Request>[];
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      gqlAccessToken: "web-token-123",
      httpClient: MockClient((request) async {
        requests.add(request);
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
    await client.fetchLiveStreamsPage(sort: StreamSort.recommendedForYou);
    await client.fetchLiveStreamsPage(
      sort: StreamSort.recommendedForYou,
      cursor: "personal-page-2",
    );
    await client.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou);
    await client.fetchTopCategoriesPage(
      sort: CategorySort.recommendedForYou,
      cursor: "game-page-2",
    );
    final options = requests.map((request) {
      expect(request.headers["Authorization"], "OAuth web-token-123");
      expect(request.headers["Client-Id"], "kimne78kx3ncx6brgo4mv6wki5h1ko");
      expect(request.headers["X-Device-ID"], matches(RegExp(r"^[0-9a-f]{32}$")));
      final variables =
          (jsonDecode(request.body) as Map<String, Object?>)["variables"]! as Map<String, Object?>;
      return variables["options"]! as Map<String, Object?>;
    }).toList();
    for (final option in options) {
      expect(option["sort"], "RELEVANCE");
      expect(option["recommendationsContext"], {"platform": "mobile_web"});
      expect(option["requestID"], isNull);
    }
    for (final option in options.take(2)) {
      expect(option["broadcasterLanguages"], isEmpty);
      expect(option["includeRestricted"], ["SUB_ONLY_LIVE"]);
    }
    expect(
      requests.map(
        (request) =>
            ((jsonDecode(request.body) as Map<String, Object?>)["variables"]!
                as Map<String, Object?>)["first"],
      ),
      [8, 24, 12, 36],
    );
    final secondVariables =
        (jsonDecode(requests[1].body) as Map<String, Object?>)["variables"]!
            as Map<String, Object?>;
    expect(secondVariables["after"], "personal-page-2");
    expect(requests.map((request) => request.headers["X-Device-ID"]).toSet(), hasLength(1));
    final nextClient = TwitchApiClient(
      clientId: "client-123",
      graphQlClientId: "public-client-override",
      accessToken: "token-123",
      httpClient: MockClient((request) async {
        expect(request.headers["X-Device-ID"], requests.first.headers["X-Device-ID"]);
        expect(request.headers["Authorization"], isNull);
        expect(request.headers["Client-Id"], "public-client-override");
        return _jsonResponse({
          "data": {
            "streams": {
              "edges": <Object?>[],
              "pageInfo": {"hasNextPage": false},
            },
          },
        });
      }),
    );
    await nextClient.fetchLiveStreamsPage();
  });

  test("mobile recommendation pagination overlaps the last four results", () async {
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient(
        (_) async => _jsonResponse({
          "data": {
            "streams": {
              "edges": [
                for (var index = 0; index < 8; index++)
                  {
                    "cursor": "stream-$index",
                    "node": {
                      "id": "$index",
                      "broadcaster": {"id": "$index"},
                    },
                  },
              ],
              "pageInfo": {"hasNextPage": true},
            },
            "games": {
              "edges": [
                for (var index = 0; index < 12; index++)
                  {
                    "cursor": "game-$index",
                    "node": {"id": "$index", "displayName": "Game $index", "viewersCount": 4200},
                  },
              ],
              "pageInfo": {"hasNextPage": true},
            },
          },
        }),
      ),
    );
    final streams = await client.fetchLiveStreamsPage(sort: StreamSort.recommendedForYou);
    final games = await client.fetchTopCategoriesPage(sort: CategorySort.recommendedForYou);
    expect(streams.data, hasLength(8));
    expect(streams.cursor, "stream-3");
    expect(games.data, hasLength(12));
    expect(games.data.first.viewerCount, 4200);
    expect(games.cursor, "game-7");
    expect((await client.fetchLiveStreamsPage()).cursor, "stream-7");
    expect((await client.fetchTopCategoriesPage()).cursor, "game-11");
  });

  test("following pagination stops repeated cursors and merges duplicate channels", () async {
    var requests = 0;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      gqlAccessToken: "web-token-123",
      httpClient: MockClient((_) async {
        requests++;
        if (requests > 4) {
          throw StateError("Repeated cursor was requested again.");
        }
        final connection = {
          "edges": [
            {
              "cursor": "repeated-cursor",
              "node": {
                "id": "creator-1",
                "login": "creator",
                "displayName": "Creator",
                "profileImageURL": null,
                "stream": {
                  "id": "stream-1",
                  "viewersCount": 10,
                  "freeformTags": <Object?>[],
                },
              },
            },
          ],
          "pageInfo": {"hasNextPage": true},
        };
        return _jsonResponse({
          "data": {
            "currentUser": {"followedLiveUsers": connection, "follows": connection},
          },
        });
      }),
    );

    expect((await client.fetchFollowedStreams("viewer")).single.userId, "creator-1");
    expect((await client.fetchFollowedChannels("viewer")).single.broadcasterId, "creator-1");
    expect(requests, 4);
  });

  test("fetches channel details with live status and past broadcasts", () async {
    late http.Request capturedRequest;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          "data": {
            "user": {
              "id": "creator-1",
              "login": "jason",
              "displayName": "Jason",
              "description": "Hi Im Jason",
              "profileImageURL": "https://static-cdn.jtvnw.net/creator-1.png",
              "followers": {"totalCount": 2300000},
              "stream": {
                "id": "live-1",
                "createdAt": "2026-07-04T01:00:00Z",
                "game": {"id": "509658", "displayName": "Just Chatting"},
                "previewImageURL":
                    "https://static-cdn.jtvnw.net/previews-ttv/live_user_jason-320x180.jpg",
                "viewersCount": 26300,
                "broadcaster": {
                  "broadcastSettings": {"title": "Live with chat"},
                },
              },
              "videos": {
                "edges": [
                  {
                    "cursor": "vod-cursor-1",
                    "node": {
                      "id": "vod-1",
                      "title": "2025 Japan Trip",
                      "game": {"id": "509658", "displayName": "Just Chatting"},
                      "lengthSeconds": 17999,
                      "previewThumbnailURL": "https://static-cdn.jtvnw.net/vod-1.jpg",
                      "publishedAt": "2026-07-03T20:00:00Z",
                      "createdAt": "2026-07-03T19:30:00Z",
                      "viewCount": 91234,
                    },
                  },
                ],
                "pageInfo": {"hasNextPage": true},
              },
            },
          },
        });
      }),
    );

    final channel = await client.fetchChannelDetails("jason");

    final body = jsonDecode(capturedRequest.body) as Map<String, Object?>;
    final variables = body["variables"]! as Map<String, Object?>;

    expect(capturedRequest.method, "POST");
    expect(capturedRequest.url.host, "gql.twitch.tv");
    expect(capturedRequest.url.path, "/gql");
    expect(body["query"], contains("edges"));
    expect(body["query"], contains("node"));
    expect(body["query"], contains("pageInfo"));
    expect(variables["login"], "jason");
    expect(variables["videosFirst"], 30);
    expect(variables["videosAfter"], isNull);
    expect(channel.id, "creator-1");
    expect(channel.login, "jason");
    expect(channel.displayName, "Jason");
    expect(channel.description, "Hi Im Jason");
    expect(channel.profileImageUrl, "https://static-cdn.jtvnw.net/creator-1.png");
    expect(channel.followers, 2300000);
    expect(channel.liveStream?.title, "Live with chat");
    expect(channel.liveStream?.categoryId, "509658");
    expect(channel.liveStream?.category, "Just Chatting");
    expect(channel.liveStream?.viewerCount, 26300);
    expect(channel.pastBroadcasts.single.id, "vod-1");
    expect(channel.pastBroadcasts.single.title, "2025 Japan Trip");
    expect(channel.pastBroadcasts.single.categoryId, "509658");
    expect(channel.pastBroadcasts.single.category, "Just Chatting");
    expect(channel.pastBroadcasts.single.duration, const Duration(seconds: 17999));
    expect(channel.pastBroadcasts.single.viewCount, 91234);
  });

  test("builds a signed Twitch live HLS playback URI", () async {
    late http.Request capturedRequest;
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      gqlAccessToken: "web-token-123",
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          "data": {
            "streamPlaybackAccessToken": {
              "value": "{\"expires\":1780000000}",
              "signature": "signature-123",
              "authorization": {
                "isForbidden": false,
                "forbiddenReasonCode": null,
              },
            },
          },
        });
      }),
    );

    final uri = await client.fetchLivePlaybackUri("KaiCenat");
    final body = jsonDecode(capturedRequest.body) as Map<String, Object?>;
    final variables = body["variables"]! as Map<String, Object?>;

    expect(capturedRequest.headers["Authorization"], "OAuth web-token-123");
    expect(variables["login"], "KaiCenat");
    expect(variables["platform"], "web");
    expect(variables["playerType"], "site");
    expect(body["query"], contains('playerBackend: "mediaplayer"'));
    expect(uri.scheme, "https");
    expect(uri.host, "usher.ttvnw.net");
    expect(uri.path, "/api/v2/channel/hls/KaiCenat.m3u8");
    expect(uri.queryParameters["sig"], "signature-123");
    expect(uri.queryParameters["token"], "{\"expires\":1780000000}");
    expect(uri.queryParameters["fast_bread"], "true");
    expect(int.tryParse(uri.queryParameters["p"] ?? ""), isNotNull);
    expect(uri.queryParameters["supported_codecs"], isNull);
  });

  test("retries a failed authenticated playback-token query anonymously", () async {
    final authorizationHeaders = <String?>[];
    final client = TwitchApiClient(
      clientId: "client-123",
      accessToken: "token-123",
      gqlAccessToken: "stale-web-token",
      httpClient: MockClient((request) async {
        final authorization = request.headers["Authorization"];
        authorizationHeaders.add(authorization);
        if (authorization != null) {
          return _jsonResponse({
            "errors": [
              {"message": "Unauthorized"},
            ],
          });
        }
        return _jsonResponse({
          "data": {
            "streamPlaybackAccessToken": {
              "value": "anonymous-token",
              "signature": "anonymous-signature",
              "authorization": {
                "isForbidden": false,
                "forbiddenReasonCode": null,
              },
            },
          },
        });
      }),
    );

    final uri = await client.fetchLivePlaybackUri("publicchannel");

    expect(authorizationHeaders, ["OAuth stale-web-token", null]);
    expect(uri.queryParameters["sig"], "anonymous-signature");
    expect(uri.queryParameters["token"], "anonymous-token");
  });
}

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);
