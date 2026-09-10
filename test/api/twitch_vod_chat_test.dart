import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_vod_chat.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("prefetches the next page without rebuilding unchanged chat", () async {
    final client = _ReplayClient();
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    addTearDown(replay.dispose);
    var notifications = 0;
    replay.addListener(() => notifications++);
    await _flush();
    client.requests[0].complete(
      TwitchVodChatPage(
        messages: [_message(0), _message(5)],
        cursor: "next",
        hasNextPage: true,
      ),
    );
    await _flush();
    expect(notifications, 1);
    replay.updatePosition(const Duration(seconds: 3));
    await _flush();
    expect(client.calls.last.cursor, "next");
    expect(replay.messages.length, 1);
    client.requests[1].complete(
      TwitchVodChatPage(
        messages: [_message(5), _message(6)],
        cursor: null,
        hasNextPage: false,
      ),
    );
    await _flush();
    expect(notifications, 1);
    replay.updatePosition(const Duration(seconds: 6));
    expect(replay.messages.map((message) => message.offsetSeconds), [0, 5, 6]);
    expect(notifications, 2);
  });

  test("releases recorded messages at playback time and paginates without duplicates", () async {
    final client = _ReplayClient();
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    addTearDown(replay.dispose);
    await _flush();
    expect(client.calls.single, (videoId: "123", offset: 0, cursor: null));
    client.requests[0].complete(
      TwitchVodChatPage(
        messages: [_message(0), _message(1.5), _message(4)],
        cursor: "page-one",
        hasNextPage: true,
      ),
    );
    await _flush();
    expect(replay.status, TwitchChatStatus.connected);
    expect(replay.messages.map((message) => message.offsetSeconds), [0]);
    replay.updatePosition(const Duration(milliseconds: 1400));
    expect(replay.messages.length, 1);
    replay.updatePosition(const Duration(milliseconds: 1500));
    expect(replay.messages.length, 2);
    replay.updatePosition(const Duration(seconds: 4));
    await _flush();
    expect(client.calls.last, (videoId: "123", offset: null, cursor: "page-one"));
    client.requests[1].complete(
      TwitchVodChatPage(messages: [_message(4), _message(6)], cursor: null, hasNextPage: false),
    );
    await _flush();
    expect(replay.messages.map((message) => message.offsetSeconds), [0, 1.5, 4]);
    replay.updatePosition(const Duration(seconds: 4));
    expect(replay.messages.length, 3);
    replay.updatePosition(const Duration(seconds: 6));
    expect(replay.messages.map((message) => message.offsetSeconds), [0, 1.5, 4, 6]);
    expect(client.calls.length, 2);
  });

  test("reconnecting after the final page reloads the current video position", () async {
    final client = _ReplayClient();
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    addTearDown(replay.dispose);
    await _flush();
    client.requests.single.complete(
      const TwitchVodChatPage(messages: [], cursor: null, hasNextPage: false),
    );
    await _flush();
    replay.updatePosition(const Duration(seconds: 4));
    replay.reconnect();
    await _flush();
    expect(client.calls.last, (videoId: "123", offset: 4, cursor: null));
    expect(client.calls.length, 2);
    client.requests.last.complete(
      TwitchVodChatPage(messages: [_message(4)], cursor: null, hasNextPage: false),
    );
    await _flush();
    expect(replay.status, TwitchChatStatus.connected);
    expect(replay.messages.single.offsetSeconds, 4);
  });

  test("seeking discards in-flight pages and resets both forward and backward", () async {
    final client = _ReplayClient();
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    addTearDown(replay.dispose);
    await _flush();
    replay.updatePosition(const Duration(seconds: 120), seek: true);
    await _flush();
    expect(client.calls.last.offset, 120);
    client.requests[0].complete(
      TwitchVodChatPage(messages: [_message(0)], cursor: null, hasNextPage: false),
    );
    await _flush();
    expect(replay.messages, isEmpty);
    expect(replay.status, TwitchChatStatus.connecting);
    client.requests[1].complete(
      TwitchVodChatPage(
        messages: [_message(119), _message(120), _message(121)],
        cursor: null,
        hasNextPage: false,
      ),
    );
    await _flush();
    expect(replay.messages.map((message) => message.offsetSeconds), [119, 120]);
    replay.updatePosition(const Duration(seconds: 90));
    expect(replay.messages, isEmpty);
    await _flush();
    expect(client.calls.last.offset, 90);
    client.requests[2].complete(
      TwitchVodChatPage(messages: [_message(90)], cursor: null, hasNextPage: false),
    );
    await _flush();
    expect(replay.messages.single.offsetSeconds, 90);
  });

  testWidgets("failed page automatically retries its cursor and disposal cancels retry", (
    tester,
  ) async {
    final client = _ReplayClient();
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    await tester.pump();
    client.requests[0].complete(
      TwitchVodChatPage(messages: [_message(0)], cursor: "next", hasNextPage: true),
    );
    await tester.pump();
    client.requests[1].completeError(const FormatException("connection dropped"));
    await tester.pump();
    expect(replay.status, TwitchChatStatus.reconnecting);
    expect(replay.messages.length, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(client.calls.last.cursor, "next");
    client.requests[2].completeError(const FormatException("still offline"));
    await tester.pump();
    replay.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(client.calls.length, 3);
  });

  test("bounds visible history and makes unavailable replay retryable", () async {
    final client = _ReplayClient();
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    addTearDown(replay.dispose);
    await _flush();
    client.requests[0].completeError(TwitchApiException("Chat replay is unavailable."));
    await _flush();
    expect(replay.status, TwitchChatStatus.disconnected);
    expect(replay.error, "Chat replay is unavailable.");
    replay.reconnect();
    await _flush();
    client.requests[1].complete(
      TwitchVodChatPage(
        messages: List.generate(
          310,
          (index) => TwitchChatMessage(
            id: "$index",
            login: "viewer",
            displayName: "Viewer",
            text: "message $index",
            offsetSeconds: 0,
          ),
        ),
        cursor: null,
        hasNextPage: false,
      ),
    );
    await _flush();
    expect(replay.messages.length, 300);
    expect(replay.messages.first.id, "10");
    expect(replay.error, isNull);
    expect(() => replay.messages.clear(), throwsUnsupportedError);
  });

  testWidgets("disposing a pending page cancels its deadline", (tester) async {
    final client = _ReplayClient();
    final replay = TwitchVodChatController(clientLoader: () async => client, videoId: "123");
    await tester.pump();
    expect(client.requests.length, 1);
    replay.dispose();
  });

  testWidgets("hung authentication retries and ignores its late completion", (tester) async {
    final client = _ReplayClient();
    final authentication = Completer<TwitchApiClient>();
    var loads = 0;
    final replay = TwitchVodChatController(
      clientLoader: () => ++loads == 1 ? authentication.future : Future.value(client),
      videoId: "123",
    );
    await tester.pump(const Duration(seconds: 15));
    expect(replay.status, TwitchChatStatus.reconnecting);
    await tester.pump(const Duration(seconds: 5));
    expect(client.requests.length, 1);
    authentication.complete(client);
    await tester.pump();
    expect(client.requests.length, 1);
    client.requests.single.complete(
      const TwitchVodChatPage(messages: [], cursor: null, hasNextPage: false),
    );
    await tester.pump();
    expect(replay.status, TwitchChatStatus.connected);
    replay.dispose();
  });
}

TwitchChatMessage _message(double offset) => TwitchChatMessage(
  id: "$offset",
  login: "viewer",
  displayName: "Viewer",
  text: "message at $offset",
  offsetSeconds: offset,
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _ReplayClient extends TwitchApiClient {
  _ReplayClient() : super(clientId: "test", accessToken: "");

  final calls = <({String videoId, int? offset, String? cursor})>[];
  final requests = <Completer<TwitchVodChatPage>>[];

  @override
  Future<TwitchVodChatPage> fetchVodChatPage(String videoId, {int? offsetSeconds, String? cursor}) {
    calls.add((videoId: videoId, offset: offsetSeconds, cursor: cursor));
    final result = Completer<TwitchVodChatPage>();
    requests.add(result);
    return result.future;
  }
}
