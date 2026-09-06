import "dart:async";

import "package:flow/features/player/media3_player_controller.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("decodes rendered quality and playback recovery events", () async {
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
        "qualities": <Object?>[],
        "selectedId": "auto",
        "currentLabel": "1080p60",
      },
      {"type": "reload"},
    ]) {
      await messenger.handlePlatformMessage(
        eventChannel.name,
        eventChannel.codec.encodeSuccessEnvelope(event),
        (_) {},
      );
    }
    expect((events.first as TwitchQualitiesEvent).currentLabel, "1080p60");
    expect(events.last, isA<TwitchPlaybackReloadEvent>());
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
    await controller.setQuality("auto");

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
