import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:video_player/video_player.dart";

typedef FlowVideoControllerFactory = FlowVideoController Function(Uri playlistUri);

FlowVideoControllerFactory _flowVideoControllerFactory = _createDefaultFlowVideoController;

FlowVideoController createFlowVideoController(Uri playlistUri) =>
    _flowVideoControllerFactory(playlistUri);

@visibleForTesting
void debugSetFlowVideoControllerFactory(
  FlowVideoControllerFactory factory,
) {
  _flowVideoControllerFactory = factory;
}

@visibleForTesting
void debugResetFlowVideoControllerFactory() {
  _flowVideoControllerFactory = _createDefaultFlowVideoController;
}

class FlowVideoQuality {
  const FlowVideoQuality({
    required this.id,
    required this.label,
  });

  static const auto = FlowVideoQuality(id: "auto", label: "Auto");

  final String id;
  final String label;
}

abstract class FlowVideoController extends ChangeNotifier {
  bool get isInitialized;

  bool get isPlaying;

  bool get isBuffering;

  double get aspectRatio;

  double? get latencySeconds;

  List<FlowVideoQuality> get qualities;

  String get selectedQualityId;

  String? get errorDescription;

  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> seekToLive();

  Future<void> setQuality(String id);

  Widget buildView();
}

FlowVideoController _createDefaultFlowVideoController(Uri playlistUri) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return _AndroidLowLatencyFlowVideoController(playlistUri);
  }
  return _createNativeFlowVideoController(playlistUri);
}

FlowVideoController _createNativeFlowVideoController(Uri playlistUri) =>
    _NativeFlowVideoController(playlistUri);

class _AndroidLowLatencyFlowVideoController extends FlowVideoController {
  _AndroidLowLatencyFlowVideoController(this.playlistUri);

  final Uri playlistUri;
  final _initializeCompleter = Completer<void>();
  MethodChannel? _channel;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isBuffering = false;
  double? _latencySeconds;
  List<FlowVideoQuality> _qualities = const [FlowVideoQuality.auto];
  String _selectedQualityId = FlowVideoQuality.auto.id;
  String? _errorDescription;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isBuffering => _isBuffering;

  @override
  double get aspectRatio => 16 / 9;

  @override
  double? get latencySeconds => _latencySeconds;

  @override
  List<FlowVideoQuality> get qualities => _qualities;

  @override
  String get selectedQualityId => _selectedQualityId;

  @override
  String? get errorDescription => _errorDescription;

  @override
  Future<void> initialize() => _initializeCompleter.future;

  @override
  Future<void> play() async {
    _isPlaying = true;
    notifyListeners();
    await _channel?.invokeMethod<void>("play");
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
    await _channel?.invokeMethod<void>("pause");
  }

  @override
  Future<void> seekToLive() async {
    await _channel?.invokeMethod<void>("seekToLive");
  }

  @override
  Future<void> setQuality(String id) async {
    _selectedQualityId = id;
    notifyListeners();
    await _channel?.invokeMethod<void>("setQuality", id);
  }

  @override
  Widget buildView() => AndroidView(
    // Keep the native surface alive when the player is reparented into fullscreen.
    key: GlobalObjectKey(this),
    viewType: "flow/low_latency_video",
    creationParams: {"url": playlistUri.toString()},
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: _handlePlatformViewCreated,
  );

  void _handlePlatformViewCreated(int viewId) {
    final channel = MethodChannel("flow/low_latency_video/$viewId");
    _channel = channel;
    channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
    if (!_initializeCompleter.isCompleted) {
      _initializeCompleter.complete();
    }
    notifyListeners();
    unawaited(channel.invokeMethod<void>("attach"));
    if (_isPlaying) {
      unawaited(channel.invokeMethod<void>("play"));
    } else {
      unawaited(channel.invokeMethod<void>("pause"));
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "playing":
        _isPlaying = call.arguments == true;
      case "latency":
        final value = call.arguments;
        _latencySeconds = value is num ? value.toDouble() : null;
      case "qualities":
        final payload = call.arguments;
        if (payload is Map) {
          _qualities = _qualitiesFromPlatform(payload["qualities"]);
          _selectedQualityId = payload["selectedQualityId"]?.toString() ?? FlowVideoQuality.auto.id;
        }
      case "error":
        _errorDescription = call.arguments?.toString() ?? "Video playback failed.";
      case "buffering":
        _isBuffering = call.arguments == true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      channel.setMethodCallHandler(null);
      unawaited(channel.invokeMethod<void>("dispose"));
    }
    if (!_initializeCompleter.isCompleted) {
      _initializeCompleter.complete();
    }
    super.dispose();
  }

  static List<FlowVideoQuality> _qualitiesFromPlatform(Object? value) {
    if (value is! List) {
      return const [FlowVideoQuality.auto];
    }

    final qualities = <FlowVideoQuality>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final id = item["id"]?.toString();
      final label = item["label"]?.toString();
      if (id != null && id.isNotEmpty && label != null && label.isNotEmpty) {
        qualities.add(FlowVideoQuality(id: id, label: label));
      }
    }

    if (qualities.isEmpty || qualities.first.id != FlowVideoQuality.auto.id) {
      qualities.insert(0, FlowVideoQuality.auto);
    }
    return qualities;
  }
}

class _NativeFlowVideoController extends FlowVideoController {
  _NativeFlowVideoController(Uri playlistUri)
    : _controller = VideoPlayerController.networkUrl(
        playlistUri,
        formatHint: VideoFormat.hls,
      ) {
    _controller.addListener(notifyListeners);
  }

  final VideoPlayerController _controller;

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  bool get isBuffering => _controller.value.isBuffering;

  @override
  double get aspectRatio {
    if (!_controller.value.isInitialized) {
      return 16 / 9;
    }
    return _controller.value.aspectRatio;
  }

  @override
  double? get latencySeconds {
    final value = _controller.value;
    if (!value.isInitialized || value.duration <= Duration.zero) {
      return null;
    }

    final latency = value.duration - value.position;
    if (latency < Duration.zero) {
      return 0;
    }
    return latency.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  List<FlowVideoQuality> get qualities => const [FlowVideoQuality.auto];

  @override
  String get selectedQualityId => FlowVideoQuality.auto.id;

  @override
  String? get errorDescription {
    if (!_controller.value.hasError) {
      return null;
    }
    return _controller.value.errorDescription ?? "Video playback failed.";
  }

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    await _controller.setLooping(false);
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekToLive() async {
    final value = _controller.value;
    if (value.isInitialized && value.duration > Duration.zero) {
      await _controller.seekTo(value.duration);
    }
    await _controller.play();
  }

  @override
  Future<void> setQuality(String id) async {}

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    unawaited(_controller.dispose());
    super.dispose();
  }
}
