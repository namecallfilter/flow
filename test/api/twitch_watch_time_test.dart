import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_watch_time.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test(
    "reports a real signed-in broadcast as a form-encoded Twitch minute-watched event",
    () async {
      final requests = <http.Request>[];
      final client = TwitchApiClient(
        clientId: "test",
        accessToken: "",
        gqlAccessToken: "private-token",
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response("", 204);
        }),
      );
      await client.reportMinuteWatched(stream: _stream(), userId: "123");
      final request = requests.single;
      expect(request.method, "POST");
      expect(request.url.toString(), "https://spade.twitch.tv/track");
      expect(request.headers["content-type"], contains("application/x-www-form-urlencoded"));
      expect(request.headers, isNot(contains("authorization")));
      expect(request.body, isNot(contains("private-token")));
      final encoded = Uri.splitQueryString(request.body)["data"]!;
      expect(jsonDecode(utf8.decode(base64Decode(encoded))), [
        {
          "event": "minute-watched",
          "properties": {
            "channel_id": "1",
            "broadcast_id": "100",
            "player": "site",
            "user_id": 123,
            "live": true,
            "channel": "channel",
            "game": "Game",
            "game_id": "10",
          },
        },
      ]);
      await expectLater(
        client.reportMinuteWatched(stream: _stream(), userId: ""),
        throwsA(isA<TwitchApiException>()),
      );
      expect(requests, hasLength(1));
    },
  );

  testWidgets("counts only played time and resets for a new broadcast or disposal", (tester) async {
    final client = _Client("first");
    final tracker = TwitchWatchTime(
      clientLoader: () async => client,
      stopwatch: tester.binding.clock.stopwatch(),
    );
    Future<void> advance(int seconds) async {
      await tester.pump(Duration(seconds: seconds));
    }

    tracker.updateStream(_stream());
    await advance(120);
    expect(client.reports, isEmpty);
    tracker.setPlaying(playing: true);
    await tester.pump();
    await advance(30);
    tracker.setPlaying(playing: false);
    await advance(120);
    expect(client.reports, isEmpty);
    tracker.setPlaying(playing: true);
    await advance(29);
    expect(client.reports, isEmpty);
    tracker.updateStream(_stream());
    tracker.setPlaying(playing: true);
    await advance(1);
    expect(client.reports, ["first:100"]);
    await advance(30);
    tracker.updateStream(_stream(id: "101"));
    await advance(30);
    expect(client.reports, hasLength(1));
    await advance(30);
    expect(client.reports, ["first:100", "first:101"]);
    tracker.dispose();
    await advance(120);
    expect(client.reports, hasLength(2));
  });

  testWidgets("keeps counting playback, excluding pauses, while a report is pending", (
    tester,
  ) async {
    final client = _Client("first");
    final pendingReport = Completer<void>();
    client.pendingReport = pendingReport;
    final tracker = TwitchWatchTime(
      clientLoader: () async => client,
      stopwatch: tester.binding.clock.stopwatch(),
    );
    Future<void> advance(int seconds) async {
      await tester.pump(Duration(seconds: seconds));
    }

    tracker.updateStream(_stream());
    tracker.setPlaying(playing: true);
    await tester.pump();
    await advance(60);
    expect(client.reports, hasLength(1));
    await advance(5);
    tracker.setPlaying(playing: false);
    await advance(20);
    tracker.setPlaying(playing: true);
    await advance(5);
    pendingReport.complete();
    client.pendingReport = null;
    await tester.pump();
    await advance(49);
    expect(client.reports, hasLength(1));
    await advance(1);
    expect(client.reports, hasLength(2));
    tracker.dispose();
  });

  testWidgets("reports elapsed playback minutes and retains partial time across a long pause", (
    tester,
  ) async {
    final client = _Client("first");
    final tracker = TwitchWatchTime(
      clientLoader: () async => client,
      stopwatch: tester.binding.clock.stopwatch(),
    );
    tracker.updateStream(_stream());
    tracker.setPlaying(playing: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 150));
    expect(client.reports, ["first:100", "first:100"]);
    tracker.setPlaying(playing: false);
    await tester.pump(const Duration(days: 1));
    expect(client.reports, hasLength(2));
    tracker.setPlaying(playing: true);
    await tester.pump(const Duration(seconds: 29));
    expect(client.reports, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(client.reports, hasLength(3));
    tracker.dispose();
  });

  testWidgets("counts playback during initial client and user loading, excluding pauses", (
    tester,
  ) async {
    final client = _Client("first")..pendingUser = Completer<void>();
    Completer<TwitchApiClient>? pendingClient = Completer<TwitchApiClient>();
    final tracker = TwitchWatchTime(
      clientLoader: () async => pendingClient?.future ?? client,
      stopwatch: tester.binding.clock.stopwatch(),
    );
    Future<void> advance(int seconds) async {
      await tester.pump(Duration(seconds: seconds));
    }

    tracker.updateStream(_stream());
    tracker.setPlaying(playing: true);
    await advance(2);
    tracker.setPlaying(playing: false);
    await advance(1);
    pendingClient.complete(client);
    pendingClient = null;
    await tester.pump();
    await advance(2);
    tracker.setPlaying(playing: true);
    await advance(3);
    client.pendingUser!.complete();
    await tester.pump();
    await advance(54);
    expect(client.reports, isEmpty);
    await advance(1);
    expect(client.reports, ["first:100"]);
    tracker.dispose();
  });

  for (final loading in ["client", "user"]) {
    testWidgets("retains preparation when the broadcast changes during $loading loading", (
      tester,
    ) async {
      final client = _Client("first");
      final pendingClient = Completer<TwitchApiClient>();
      final pendingUser = Completer<void>();
      if (loading == "user") {
        client.pendingUser = pendingUser;
        pendingClient.complete(client);
      }
      final tracker = TwitchWatchTime(
        clientLoader: () => pendingClient.future,
        stopwatch: tester.binding.clock.stopwatch(),
      );
      tracker.updateStream(_stream());
      tracker.setPlaying(playing: true);
      await tester.pump(const Duration(seconds: 2));
      tracker.updateStream(_stream(id: "101"));
      await tester.pump(const Duration(seconds: 1));
      if (loading == "client") {
        pendingClient.complete(client);
      } else {
        pendingUser.complete();
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 58));
      expect(client.reports, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(client.reports, ["first:101"]);
      tracker.dispose();
    });
  }

  for (final signedOut in [true, false]) {
    testWidgets("discards preparation and retry time when signedOut=$signedOut", (tester) async {
      final unavailable = _Client(signedOut ? "" : "first")..failUser = !signedOut;
      final signedIn = _Client("second");
      var client = unavailable;
      Completer<TwitchApiClient>? pendingClient = Completer<TwitchApiClient>();
      final tracker = TwitchWatchTime(
        clientLoader: () async => pendingClient?.future ?? client,
        stopwatch: tester.binding.clock.stopwatch(),
      );
      Future<void> advance(int seconds) async {
        await tester.pump(Duration(seconds: seconds));
      }

      tracker.updateStream(_stream());
      tracker.setPlaying(playing: true);
      await advance(3);
      tracker.setPlaying(playing: false);
      pendingClient.complete(unavailable);
      pendingClient = null;
      await tester.pump();
      await advance(120);
      tracker.setPlaying(playing: true);
      await tester.pump();
      await advance(59);
      client = signedIn;
      await advance(1);
      expect(unavailable.reports, isEmpty);
      expect(signedIn.reports, isEmpty);
      await advance(59);
      expect(signedIn.reports, isEmpty);
      await advance(1);
      expect(signedIn.reports, ["second:100"]);
      tracker.dispose();
    });
  }

  testWidgets("sign-out and account changes discard minutes attributed to the previous session", (
    tester,
  ) async {
    final first = _Client("first");
    final second = _Client("second");
    var client = first;
    final tracker = TwitchWatchTime(
      clientLoader: () async => client,
      stopwatch: tester.binding.clock.stopwatch(),
    );
    Future<void> advance() async {
      await tester.pump(const Duration(minutes: 1));
    }

    tracker.updateStream(_stream());
    tracker.setPlaying(playing: true);
    await tester.pump();
    client = _Client("");
    await advance();
    expect(first.reports, isEmpty);
    await advance();
    expect(client.reports, isEmpty);
    client = second;
    await advance();
    expect(second.reports, isEmpty);
    await advance();
    expect(second.reports, ["second:100"]);
    client = first;
    await advance();
    expect(first.reports, isEmpty);
    await advance();
    expect(first.reports, ["first:100"]);
    tracker.dispose();
  });

  for (final stage in ["preparation", "session read"]) {
    testWidgets("an in-flight $stage cannot send after the player closes", (tester) async {
      final client = _Client("first");
      Completer<TwitchApiClient>? pending = stage == "preparation"
          ? Completer<TwitchApiClient>()
          : null;
      final tracker = TwitchWatchTime(
        clientLoader: () async => pending?.future ?? client,
        stopwatch: tester.binding.clock.stopwatch(),
      );
      tracker.updateStream(_stream());
      tracker.setPlaying(playing: true);
      await tester.pump();
      if (stage == "session read") {
        pending = Completer<TwitchApiClient>();
        await tester.pump(const Duration(minutes: 1));
      }
      tracker.dispose();
      pending!.complete(client);
      await tester.pump(const Duration(minutes: 2));
      expect(client.reports, isEmpty);
    });
  }
}

TwitchFollowedStream _stream({String id = "100"}) => TwitchFollowedStream(
  id: id,
  userId: "1",
  userLogin: "channel",
  userName: "Channel",
  gameName: "Game",
  gameId: "10",
  title: "Stream",
  viewerCount: 1,
);

class _Client extends TwitchApiClient {
  _Client(String token) : super(clientId: "test", accessToken: "", gqlAccessToken: token);

  final List<String> reports = [];
  Completer<void>? pendingReport;
  Completer<void>? pendingUser;
  bool failUser = false;

  @override
  Future<TwitchUser> fetchCurrentUser() async {
    await pendingUser?.future;
    if (failUser) {
      throw TwitchApiException("User unavailable");
    }
    return TwitchUser(id: "123", login: gqlAccessToken!, displayName: "Viewer");
  }

  @override
  Future<void> reportMinuteWatched({
    required TwitchFollowedStream stream,
    required String userId,
  }) async {
    reports.add("$gqlAccessToken:${stream.id}");
    await pendingReport?.future;
  }
}
