import "dart:async";

import "package:flow/features/player/media3_player_controller.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";

class Media3PlayerView extends StatelessWidget {
  const Media3PlayerView({
    required this.uri,
    required this.playbackUriRefresher,
    required this.onControllerCreated,
    super.key,
    this.proxyUrls = const [],
    this.initialQualityId = "auto",
    this.initialPosition = Duration.zero,
    this.mediaTitle = "Flow",
    this.mediaArtist = "",
    this.isLive = true,
    this.pictureInPictureEnabled = true,
  });

  final Uri uri;
  final Future<Uri> Function() playbackUriRefresher;
  final List<String> proxyUrls;
  final String initialQualityId;
  final Duration initialPosition;
  final String mediaTitle;
  final String mediaArtist;
  final bool isLive;
  final bool pictureInPictureEnabled;
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

    return PlatformViewLink(
      viewType: "flow/twitch_player",
      surfaceFactory: (_, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        gestureRecognizers: const {},
      ),
      onCreatePlatformView: (params) {
        // Native composition avoids asynchronous texture resizing during PiP transitions.
        final view = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: params.viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: {
            "url": uri.toString(),
            "proxyUrls": proxyUrls,
            "qualityId": initialQualityId,
            "positionMs": initialPosition.inMilliseconds,
            "title": mediaTitle,
            "artist": mediaArtist,
            "isLive": isLive,
            "pictureInPictureEnabled": pictureInPictureEnabled,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        view.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        view.addOnPlatformViewCreatedListener((viewId) {
          final controller = MethodChannelTwitchPlayerController(
            viewId,
            playbackUriRefresher: playbackUriRefresher,
          );
          onControllerCreated(controller);
          unawaited(controller.initialize());
        });
        unawaited(view.create());
        return view;
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Uri>("uri", uri));
    properties.add(
      ObjectFlagProperty<Future<Uri> Function()>.has(
        "playbackUriRefresher",
        playbackUriRefresher,
      ),
    );
    properties.add(IntProperty("proxyUrlCount", proxyUrls.length));
    properties.add(StringProperty("initialQualityId", initialQualityId));
    properties.add(DiagnosticsProperty<Duration>("initialPosition", initialPosition));
    properties.add(StringProperty("mediaTitle", mediaTitle));
    properties.add(StringProperty("mediaArtist", mediaArtist));
    properties.add(DiagnosticsProperty<bool>("isLive", isLive));
    properties.add(DiagnosticsProperty<bool>("pictureInPictureEnabled", pictureInPictureEnabled));
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchPlayerController>>.has(
        "onControllerCreated",
        onControllerCreated,
      ),
    );
  }
}
