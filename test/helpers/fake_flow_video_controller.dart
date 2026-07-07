import "package:flow/features/player/player_controller.dart";
import "package:flutter/material.dart";

class FakeFlowVideoController extends FlowVideoController {
  FakeFlowVideoController(
    this.playlistUri, {
    List<FlowVideoQuality>? qualities,
  }) : _qualities = qualities ?? _defaultQualities;

  static const _defaultQualities = [
    FlowVideoQuality.auto,
    FlowVideoQuality(id: "1080p60", label: "1080p60"),
    FlowVideoQuality(id: "720p60", label: "720p60"),
  ];

  final Uri playlistUri;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  List<FlowVideoQuality> _qualities;
  String _selectedQualityId = FlowVideoQuality.auto.id;
  int seekToLiveCallCount = 0;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isBuffering => _isBuffering;

  @override
  double get aspectRatio => 16 / 9;

  @override
  double? get latencySeconds => _isInitialized ? 2.875 : null;

  @override
  List<FlowVideoQuality> get qualities => _qualities;

  @override
  String get selectedQualityId => _selectedQualityId;

  @override
  String? get errorDescription => null;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seekToLive() async {
    seekToLiveCallCount++;
    _isPlaying = true;
    notifyListeners();
  }

  void setQualities(List<FlowVideoQuality> qualities) {
    _qualities = qualities;
    notifyListeners();
  }

  void setBuffering({required bool isBuffering}) {
    _isBuffering = isBuffering;
    notifyListeners();
  }

  @override
  Future<void> setQuality(String id) async {
    _selectedQualityId = id;
    notifyListeners();
  }

  @override
  Widget buildView() => ColoredBox(
    key: ValueKey("fake_video_${playlistUri.path}"),
    color: const Color(0xFF101010),
  );
}
