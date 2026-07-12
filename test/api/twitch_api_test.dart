import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
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
    expect(channel.liveStream?.category, "Just Chatting");
    expect(channel.liveStream?.viewerCount, 26300);
    expect(channel.pastBroadcasts.single.id, "vod-1");
    expect(channel.pastBroadcasts.single.title, "2025 Japan Trip");
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
    expect(uri.queryParameters["supported_codecs"], "h264");
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
