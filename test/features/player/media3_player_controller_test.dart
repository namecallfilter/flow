import "dart:async";

import "package:flow/features/player/media3_player_controller.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test("refreshPlaybackUri reports loader errors", () {
    const viewId = 43;
    const channel = MethodChannel("flow/twitch_player/$viewId");
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodChannelTwitchPlayerController(
      viewId,
      playbackUriRefresher: () => Future<Uri>.error(StateError("refresh failed")),
    );

    expect(
      () => _invokeFromPlatform(messenger, channel, "refreshPlaybackUri"),
      throwsA(isA<PlatformException>()),
    );
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

  test("initialize is ignored after disposal", () async {
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

    expect(calls, isEmpty);
  });

  test("initialize invokes native playback after construction", () async {
    const viewId = 46;
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

    await controller.initialize();

    expect(calls, ["initialize"]);
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
