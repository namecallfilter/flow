import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flutter/foundation.dart";

class TwitchWatchTime {
  TwitchWatchTime({required this.clientLoader, this.clock = DateTime.now});

  final TwitchApiClientLoader clientLoader;
  final DateTime Function() clock;
  TwitchFollowedStream? _stream;
  TwitchApiClient? _client;
  String? _userId;
  Timer? _timer;
  DateTime? _startedAt;
  Duration _watched = Duration.zero;
  bool _playing = false;
  bool _disposed = false;
  bool _inFlight = false;
  int _generation = 0;

  void updateStream(TwitchFollowedStream stream) {
    if (_stream?.id != stream.id || _stream?.userId != stream.userId) {
      _stopTimer();
      _watched = Duration.zero;
      _generation++;
    }
    _stream = stream;
    _schedule();
  }

  void setPlaying({required bool playing}) {
    if (_playing == playing) {
      return;
    }
    _stopTimer();
    _playing = playing;
    _schedule();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (_startedAt case final startedAt?) {
      final elapsed = clock().difference(startedAt);
      if (!elapsed.isNegative) {
        _watched += elapsed;
      }
    }
    _startedAt = null;
  }

  void _schedule() {
    if (_disposed || !_playing || _stream == null || _timer != null) {
      return;
    }
    final now = clock();
    _startedAt ??= now;
    if (_client == null) {
      if (!_inFlight) {
        unawaited(_prepare());
      }
      return;
    }
    if (_inFlight) {
      return;
    }
    final elapsed = now.difference(_startedAt!);
    final watched = _watched + (elapsed.isNegative ? Duration.zero : elapsed);
    _timer = Timer(const Duration(minutes: 1) - watched, () {
      _stopTimer();
      // Report at most one real minute; never replay time after a delayed callback.
      _watched = Duration.zero;
      unawaited(_report());
      _schedule();
    });
  }

  Future<void> _prepare() async {
    _inFlight = true;
    final generation = _generation;
    try {
      final client = await clientLoader().timeout(const Duration(seconds: 5));
      if (client.gqlAccessToken?.trim().isNotEmpty == true) {
        final user = await client.fetchCurrentUser().timeout(const Duration(seconds: 10));
        if (!_disposed && generation == _generation) {
          _client = client;
          _userId = user.id;
        }
      }
    } on Object {
      // Watch reporting must not interrupt playback; try again next minute.
    } finally {
      _inFlight = false;
      if (_client == null) {
        _stopTimer();
        _watched = Duration.zero;
      }
      if (!_disposed && _playing && _client == null) {
        _timer = Timer(const Duration(minutes: 1), () {
          _timer = null;
          _schedule();
        });
      } else {
        _schedule();
      }
    }
  }

  Future<void> _report() async {
    _inFlight = true;
    final generation = _generation;
    final stream = _stream!;
    try {
      final current = await clientLoader().timeout(const Duration(seconds: 5));
      if (_disposed || generation != _generation || !_playing) {
        return;
      }
      if (current.gqlAccessToken != _client?.gqlAccessToken) {
        _stopTimer();
        _client = null;
        _userId = null;
        _watched = Duration.zero;
        return;
      }
      await current.reportMinuteWatched(stream: stream, userId: _userId!);
      if (kDebugMode) {
        debugPrint("Twitch watch time: minute accepted for ${stream.userLogin}");
      }
    } on Object {
      if (kDebugMode) {
        debugPrint("Twitch watch time: report failed; retrying after the next watched minute");
      }
    } finally {
      _inFlight = false;
      _schedule();
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _stopTimer();
  }
}
