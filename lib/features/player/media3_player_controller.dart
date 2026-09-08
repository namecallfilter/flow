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
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isEnded = false,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool playWhenReady;
  final Duration position;
  final Duration duration;
  final bool isEnded;
}

class TwitchPictureInPictureEvent extends TwitchPlayerEvent {
  const TwitchPictureInPictureEvent({required this.active});

  final bool active;
}

class TwitchPictureInPictureTransitionEvent extends TwitchPlayerEvent {
  const TwitchPictureInPictureTransitionEvent({required this.active});

  final bool active;
}

class TwitchPlaybackDismissedEvent extends TwitchPlayerEvent {
  const TwitchPlaybackDismissedEvent();
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
    this.currentLabel,
  });

  final List<TwitchQualityOption> qualities;
  final String selectedId;
  final String? currentLabel;
}

class TwitchPlaybackReloadEvent extends TwitchPlayerEvent {
  const TwitchPlaybackReloadEvent();
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

  Future<void> stop();

  Future<void> togglePlayback();

  Future<void> jumpToLive();

  Future<void> seekTo(Duration position);

  Future<void> setQuality(String id);

  Future<void> setPictureInPictureEnabled({required bool enabled});
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

  Future<void> _invoke(String method, [Object? arguments]) =>
      _disposed ? Future<void>.value() : _methodChannel.invokeMethod<void>(method, arguments);

  Future<void> initialize() => _invoke("initialize");

  @override
  Future<void> jumpToLive() => _invoke("jumpToLive");

  @override
  Future<void> seekTo(Duration position) => _invoke("seekTo", position.inMilliseconds);

  @override
  Future<void> pause() => _invoke("pause");

  @override
  Future<void> stop() => _invoke("stop");

  @override
  Future<void> play() => _invoke("play");

  @override
  Future<void> setQuality(String id) => _invoke("setQuality", id);

  @override
  Future<void> setPictureInPictureEnabled({required bool enabled}) =>
      _invoke("setPictureInPictureEnabled", enabled);

  @override
  Future<void> togglePlayback() => _invoke("togglePlayback");
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
        position: Duration(milliseconds: (rawEvent["positionMs"] as num?)?.round() ?? 0),
        duration: Duration(milliseconds: (rawEvent["durationMs"] as num?)?.round() ?? 0),
        isEnded: rawEvent["isEnded"] == true,
      );
    case "pip":
      return TwitchPictureInPictureEvent(active: rawEvent["active"] == true);
    case "pipTransition":
      return TwitchPictureInPictureTransitionEvent(active: rawEvent["active"] == true);
    case "dismissed":
      return const TwitchPlaybackDismissedEvent();
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
        currentLabel: rawEvent["currentLabel"] as String?,
      );
    case "reload":
      return const TwitchPlaybackReloadEvent();
    case "error":
      final message = rawEvent["message"]?.toString().trim() ?? "";
      return TwitchPlayerErrorEvent(
        message.isEmpty ? "The stream could not be played." : message,
      );
  }
  return null;
}
