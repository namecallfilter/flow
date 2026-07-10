import "package:flutter/services.dart";

sealed class TwitchPlayerEvent {
  const TwitchPlayerEvent();
}

class TwitchLatencyEvent extends TwitchPlayerEvent {
  const TwitchLatencyEvent(this.latencyMs);

  final int? latencyMs;
}

class TwitchPlaybackStateEvent extends TwitchPlayerEvent {
  const TwitchPlaybackStateEvent({
    required this.isPlaying,
    required this.isBuffering,
    required this.playWhenReady,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool playWhenReady;
}

class TwitchQualityOption {
  const TwitchQualityOption({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrate,
  });

  final String id;
  final String label;
  final int width;
  final int height;
  final double? frameRate;
  final int? bitrate;
}

class TwitchQualitiesEvent extends TwitchPlayerEvent {
  const TwitchQualitiesEvent({
    required this.qualities,
    required this.selectedId,
  });

  final List<TwitchQualityOption> qualities;
  final String selectedId;
}

class TwitchPlayerErrorEvent extends TwitchPlayerEvent {
  const TwitchPlayerErrorEvent(this.message);

  final String message;
}

abstract interface class TwitchPlayerController {
  Stream<TwitchPlayerEvent> get events;

  Future<void> load(Uri uri);

  Future<void> play();

  Future<void> pause();

  Future<void> togglePlayback();

  Future<void> jumpToLive();

  Future<void> setQuality(String id);
}

class MethodChannelTwitchPlayerController implements TwitchPlayerController {
  MethodChannelTwitchPlayerController(int viewId)
    : _methodChannel = MethodChannel("flow/twitch_player/$viewId"),
      _eventChannel = EventChannel("flow/twitch_player/$viewId/events");

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Stream<TwitchPlayerEvent> get events => _events();

  Stream<TwitchPlayerEvent> _events() async* {
    await for (final rawEvent in _eventChannel.receiveBroadcastStream()) {
      final event = _decodeEvent(rawEvent);
      if (event != null) {
        yield event;
      }
    }
  }

  @override
  Future<void> jumpToLive() => _methodChannel.invokeMethod<void>("jumpToLive");

  @override
  Future<void> load(Uri uri) => _methodChannel.invokeMethod<void>("load", uri.toString());

  @override
  Future<void> pause() => _methodChannel.invokeMethod<void>("pause");

  @override
  Future<void> play() => _methodChannel.invokeMethod<void>("play");

  @override
  Future<void> setQuality(String id) => _methodChannel.invokeMethod<void>("setQuality", id);

  @override
  Future<void> togglePlayback() => _methodChannel.invokeMethod<void>("togglePlayback");
}

TwitchPlayerEvent? _decodeEvent(Object? rawEvent) {
  if (rawEvent is! Map) {
    return null;
  }
  final type = rawEvent["type"];
  switch (type) {
    case "latency":
      final latency = rawEvent["latencyMs"];
      return TwitchLatencyEvent(latency is num ? latency.round() : null);
    case "state":
      return TwitchPlaybackStateEvent(
        isPlaying: rawEvent["isPlaying"] == true,
        isBuffering: rawEvent["isBuffering"] == true,
        playWhenReady: rawEvent["playWhenReady"] == true,
      );
    case "qualities":
      final rawQualities = rawEvent["qualities"];
      final qualities = <TwitchQualityOption>[];
      if (rawQualities is List) {
        for (final rawQuality in rawQualities) {
          if (rawQuality is! Map) {
            continue;
          }
          final id = rawQuality["id"]?.toString() ?? "";
          final label = rawQuality["label"]?.toString() ?? "";
          final height = (rawQuality["height"] as num?)?.round() ?? 0;
          if (id.isEmpty || label.isEmpty || height <= 0) {
            continue;
          }
          qualities.add(
            TwitchQualityOption(
              id: id,
              label: label,
              width: (rawQuality["width"] as num?)?.round() ?? 0,
              height: height,
              frameRate: (rawQuality["fps"] as num?)?.toDouble(),
              bitrate: (rawQuality["bitrate"] as num?)?.round(),
            ),
          );
        }
      }
      return TwitchQualitiesEvent(
        qualities: qualities,
        selectedId: rawEvent["selectedId"]?.toString() ?? "auto",
      );
    case "error":
      final message = rawEvent["message"]?.toString().trim() ?? "";
      return TwitchPlayerErrorEvent(
        message.isEmpty ? "The stream could not be played." : message,
      );
  }
  return null;
}
