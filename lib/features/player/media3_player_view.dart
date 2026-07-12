import "package:flow/features/player/media3_player_controller.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";

class Media3PlayerView extends StatelessWidget {
  const Media3PlayerView({
    required this.uri,
    required this.onControllerCreated,
    super.key,
    this.proxyUrls = const [],
  });

  final Uri uri;
  final List<String> proxyUrls;
  final ValueChanged<TwitchPlayerController> onControllerCreated;

  static const unsupportedMessage = "Playback is available on Android.";

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            unsupportedMessage,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return AndroidView(
      viewType: "flow/twitch_player",
      layoutDirection: TextDirection.ltr,
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      creationParams: {"url": uri.toString(), "proxyUrls": proxyUrls},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (viewId) =>
          onControllerCreated(MethodChannelTwitchPlayerController(viewId)),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Uri>("uri", uri));
    properties.add(IterableProperty<String>("proxyUrls", proxyUrls));
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchPlayerController>>.has(
        "onControllerCreated",
        onControllerCreated,
      ),
    );
  }
}
