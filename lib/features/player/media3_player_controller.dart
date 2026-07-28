import "package:flutter/services.dart";

sealed class TwitchPlayerEvent {
  const TwitchPlayerEvent();
}

class TwitchLatencyEvent extends TwitchPlayerEvent {
  const TwitchLatencyEvent(this.latencyMs);

  final int? latencyMs;
}

class TwitchAdEvent extends TwitchPlayerEvent {
  const TwitchAdEvent({
    required this.active,
    required this.current,
    required this.total,
    required this.remainingMs,
  });

  final bool active;
  final int current;
  final int total;
  final int remainingMs;
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
  });

  final String id;
  final String label;
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

  void dispose();

  Future<void> play();

  Future<void> pause();

  Future<void> togglePlayback();

  Future<void> jumpToLive();

  Future<void> setQuality(String id);
}

class MethodChannelTwitchPlayerController implements TwitchPlayerController {
  MethodChannelTwitchPlayerController(
    int viewId, {
    required Future<Uri> Function() playbackUriRefresher,
  }) : _methodChannel = MethodChannel("flow/twitch_player/$viewId"),
       _eventChannel = EventChannel("flow/twitch_player/$viewId/events") {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method != "refreshPlaybackUri") {
        throw MissingPluginException("Unknown Twitch player method ${call.method}");
      }
      return (await playbackUriRefresher()).toString();
    });
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  bool _disposed = false;
  late final Stream<TwitchPlayerEvent> _events = _eventChannel
      .receiveBroadcastStream()
      .map(_decodeEvent)
      .where((event) => event != null)
      .cast<TwitchPlayerEvent>();

  @override
  Stream<TwitchPlayerEvent> get events => _events;

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _methodChannel.setMethodCallHandler(null);
  }

  Future<void> initialize() =>
      _disposed ? Future<void>.value() : _methodChannel.invokeMethod<void>("initialize");

  @override
  Future<void> jumpToLive() => _methodChannel.invokeMethod<void>("jumpToLive");

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
    case "ad":
      return TwitchAdEvent(
        active: rawEvent["active"] == true,
        current: (rawEvent["current"] as num?)?.round() ?? 0,
        total: (rawEvent["total"] as num?)?.round() ?? 0,
        remainingMs: (rawEvent["remainingMs"] as num?)?.round() ?? 0,
      );
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
          if (id.isEmpty || label.isEmpty) {
            continue;
          }
          qualities.add(
            TwitchQualityOption(
              id: id,
              label: label,
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
