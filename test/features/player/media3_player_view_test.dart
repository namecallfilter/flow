import "package:flow/features/player/media3_player_controller.dart";
import "package:flow/features/player/media3_player_view.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets(
    "VOD recreation forwards its saved position and removal disposes the native view",
    (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final platformCalls = <MethodCall>[];
      Map<Object?, Object?>? creationParams;
      TwitchPlayerController? controller;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        platformCalls.add(call);
        if (call.method == "create") {
          final arguments = call.arguments as Map<Object?, Object?>;
          creationParams =
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(arguments["params"]! as Uint8List),
                  )
                  as Map<Object?, Object?>?;
          final channel = MethodChannel("flow/twitch_player/${arguments["id"]}");
          messenger.setMockMethodCallHandler(channel, (_) async => null);
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Media3PlayerView(
            uri: Uri.parse("https://example.com/vod.m3u8"),
            playbackUriRefresher: () async => Uri.parse("https://example.com/vod.m3u8"),
            onControllerCreated: (value) => controller = value,
            isLive: false,
            initialPosition: const Duration(minutes: 12, seconds: 34),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(creationParams?["positionMs"], 754000);
      expect(creationParams?["isLive"], isFalse);
      expect(controller, isNotNull);

      controller!.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(platformCalls.where((call) => call.method == "dispose"), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
