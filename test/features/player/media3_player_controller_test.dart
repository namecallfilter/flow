import "dart:async";

import "package:flow/features/player/media3_player_controller.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("forwards PiP preference values to the native player", () async {
    const viewId = 48;
    const channel = MethodChannel("flow/twitch_player/$viewId");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final controller = MethodChannelTwitchPlayerController(
      viewId,
      playbackUriRefresher: () async => Uri.parse("https://example.com/live.m3u8"),
    );
    await controller.setPictureInPictureEnabled(enabled: false);
    await controller.setPictureInPictureEnabled(enabled: true);
    expect(calls.map((call) => (call.method, call.arguments)), [
      ("setPictureInPictureEnabled", false),
      ("setPictureInPictureEnabled", true),
    ]);
    controller.dispose();
  });

  test("decodes quality, recovery, PiP and recording progress events", () async {
    const viewId = 47;
    const eventChannel = MethodChannel("flow/twitch_player/$viewId/events");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(eventChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(eventChannel, null));
    final controller = MethodChannelTwitchPlayerController(
      viewId,
      playbackUriRefresher: () async => Uri.parse("https://example.com/live.m3u8"),
    );
    final events = <TwitchPlayerEvent>[];
    final subscription = controller.events.listen(events.add);
    await Future<void>.delayed(Duration.zero);
    for (final event in [
      {
        "type": "qualities",
        "qualities": [
          {"id": "audio_only", "label": "Audio only"},
        ],
        "selectedId": "audio_only",
        "currentLabel": "Audio only",
      },
      {"type": "reload"},
      {"type": "pipTransition", "active": true},
      {"type": "pipTransition", "active": false},
      {"type": "pip", "active": true},
      {"type": "pip", "active": false},
      {"type": "dismissed"},
      {
        "type": "state",
        "isPlaying": false,
        "isBuffering": false,
        "playWhenReady": true,
        "positionMs": 120000,
        "durationMs": 120000,
        "isEnded": true,
      },
    ]) {
      await messenger.handlePlatformMessage(
        eventChannel.name,
        eventChannel.codec.encodeSuccessEnvelope(event),
        (_) {},
      );
    }
    final quality = events.first as TwitchQualitiesEvent;
    expect(quality.currentLabel, "Audio only");
    expect(quality.selectedId, "audio_only");
    expect(quality.qualities.single.id, "audio_only");
    expect(events[1], isA<TwitchPlaybackReloadEvent>());
    expect((events[2] as TwitchPictureInPictureTransitionEvent).active, isTrue);
    expect((events[3] as TwitchPictureInPictureTransitionEvent).active, isFalse);
    expect((events[4] as TwitchPictureInPictureEvent).active, isTrue);
    expect((events[5] as TwitchPictureInPictureEvent).active, isFalse);
    expect(events[6], isA<TwitchPlaybackDismissedEvent>());
    final progress = events.last as TwitchPlaybackStateEvent;
    expect(progress.position, const Duration(minutes: 2));
    expect(progress.duration, const Duration(minutes: 2));
    expect(progress.isEnded, isTrue);
    await subscription.cancel();
    controller.dispose();
  });

  test("events uses one broadcast platform subscription", () async {
    const viewId = 41;
    const eventMethodChannel = MethodChannel("flow/twitch_player/$viewId/events");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final methodCalls = <String>[];
    messenger.setMockMethodCallHandler(eventMethodChannel, (call) async {
      methodCalls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(eventMethodChannel, null));

    final controller = MethodChannelTwitchPlayerController(
      viewId,
      playbackUriRefresher: () async => Uri.parse("https://example.com/live.m3u8"),
    );
    final events = controller.events;
    expect(controller.events, same(events));
    expect(events.isBroadcast, isTrue);

    final firstSubscription = events.listen((_) {});
    final secondSubscription = events.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(methodCalls, ["listen"]);

    await firstSubscription.cancel();
    expect(methodCalls, ["listen"]);
    await secondSubscription.cancel();
    expect(methodCalls, ["listen", "cancel"]);
  });

  test("refreshPlaybackUri returns a fresh URI", () async {
    const viewId = 42;
    const channel = MethodChannel("flow/twitch_player/$viewId");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var refreshes = 0;
    MethodChannelTwitchPlayerController(
      viewId,
      playbackUriRefresher: () async {
        refreshes++;
        return Uri.parse("https://example.com/live-$refreshes.m3u8");
      },
    );

    final first = await _invokeFromPlatform(messenger, channel, "refreshPlaybackUri");
    final second = await _invokeFromPlatform(messenger, channel, "refreshPlaybackUri");

    expect(first, "https://example.com/live-1.m3u8");
    expect(second, "https://example.com/live-2.m3u8");
  });

  test("dispose unregisters the playback URI handler", () async {
    const viewId = 44;
    const channel = MethodChannel("flow/twitch_player/$viewId");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final controller = MethodChannelTwitchPlayerController(
      viewId,
      playbackUriRefresher: () async => Uri.parse("https://example.com/live.m3u8"),
    );

    controller.dispose();

    final response = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall("refreshPlaybackUri")),
      response.complete,
    );
    expect(await response.future, isNull);
  });

  test("commands are ignored after disposal", () async {
    const viewId = 45;
    const channel = MethodChannel("flow/twitch_player/$viewId");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final controller = MethodChannelTwitchPlayerController(
      viewId,
      playbackUriRefresher: () async => Uri.parse("https://example.com/live.m3u8"),
    );

    controller.dispose();
    await controller.initialize();
    await controller.play();
    await controller.pause();
    await controller.togglePlayback();
    await controller.jumpToLive();
    await controller.seekTo(const Duration(seconds: 30));
    await controller.setQuality("auto");
    await controller.setPictureInPictureEnabled(enabled: false);

    expect(calls, isEmpty);
  });
}

Future<Object?> _invokeFromPlatform(
  TestDefaultBinaryMessenger messenger,
  MethodChannel channel,
  String method,
) async {
  final response = Completer<ByteData?>();
  await messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method)),
    response.complete,
  );
  final envelope = await response.future;
  return channel.codec.decodeEnvelope(envelope!);
}
