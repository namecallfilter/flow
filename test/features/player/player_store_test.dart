import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/features/player/player_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test("loads live playback URL", () async {
    final store = PlayerStore(
      apiCache: TwitchApiCache(
        clientLoader: () async => TwitchApiClient(
          clientId: "client-123",
          accessToken: "token-123",
          gqlAccessToken: "gql-token-123",
          httpClient: MockClient((_) async => _livePlaybackResponse(signature: "sig-1")),
        ),
      ),
      login: "jason",
    );

    final playback = await store.load();

    expect(playback, isNotNull);
    expect(store.playback?.playlistUri.queryParameters["sig"], "sig-1");
    expect(store.errorMessage, isNull);
    expect(store.isLoading, isFalse);
  });

  test("keeps a newer playback result when an older load finishes later", () async {
    var requests = 0;
    final firstResponse = Completer<http.Response>();
    final store = PlayerStore(
      apiCache: TwitchApiCache(
        clientLoader: () async => TwitchApiClient(
          clientId: "client-123",
          accessToken: "token-123",
          gqlAccessToken: "gql-token-123",
          httpClient: MockClient((_) {
            requests++;
            if (requests == 1) {
              return firstResponse.future;
            }
            return Future.value(_livePlaybackResponse(signature: "sig-2"));
          }),
        ),
      ),
      login: "jason",
    );

    final firstLoad = store.load();
    await Future<void>.delayed(Duration.zero);

    await store.load(refresh: true);
    expect(store.playback?.playlistUri.queryParameters["sig"], "sig-2");

    firstResponse.complete(_livePlaybackResponse(signature: "sig-1"));
    await firstLoad;

    expect(store.playback?.playlistUri.queryParameters["sig"], "sig-2");
    expect(store.errorMessage, isNull);
  });

  test("exposes API failures as an error message", () async {
    final store = PlayerStore(
      apiCache: TwitchApiCache(
        clientLoader: () async => TwitchApiClient(
          clientId: "client-123",
          accessToken: "token-123",
          gqlAccessToken: "gql-token-123",
          httpClient: MockClient(
            (_) async => _jsonResponse({
              "data": {
                "streamPlaybackAccessToken": {
                  "value": "token-value",
                  "signature": "sig-value",
                  "authorization": {
                    "isForbidden": true,
                    "forbiddenReasonCode": "SUB_ONLY",
                  },
                },
              },
            }),
          ),
        ),
      ),
      login: "jason",
    );

    final playback = await store.load();

    expect(playback, isNull);
    expect(store.playback, isNull);
    expect(store.errorMessage, contains("SUB_ONLY"));
    expect(store.isLoading, isFalse);
  });
}

http.Response _livePlaybackResponse({required String signature}) => _jsonResponse({
  "data": {
    "streamPlaybackAccessToken": {
      "value": "token-value",
      "signature": signature,
      "authorization": {"isForbidden": false},
    },
  },
});

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);
