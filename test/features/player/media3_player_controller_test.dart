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

    final controller = MethodChannelTwitchPlayerController(viewId);
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
}
