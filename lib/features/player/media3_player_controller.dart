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
  });

  final bool isPlaying;
  final bool isBuffering;
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
      );
    case "error":
      final message = rawEvent["message"]?.toString().trim() ?? "";
      return TwitchPlayerErrorEvent(
        message.isEmpty ? "The stream could not be played." : message,
      );
  }
  return null;
}
