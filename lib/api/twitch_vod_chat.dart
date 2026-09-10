import "dart:async";
import "dart:collection";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flutter/foundation.dart";

class TwitchVodChatController extends ChangeNotifier {
  TwitchVodChatController({
    required this.clientLoader,
    required this.videoId,
    bool autoLoad = true,
  }) {
    if (autoLoad) {
      unawaited(_loadPage());
    }
  }

  final TwitchApiClientLoader clientLoader;
  final String videoId;
  final _messages = <TwitchChatMessage>[];
  final _messageIds = <String>{};
  final _upcoming = Queue<TwitchChatMessage>();
  Duration _position = Duration.zero;
  TwitchChatStatus _status = TwitchChatStatus.connecting;
  String? _error;
  String? _cursor;
  Timer? _retry;
  Timer? _deadline;
  bool _hasNextPage = true;
  bool _loading = false;
  bool _disposed = false;
  int _generation = 0;

  List<TwitchChatMessage> get messages => UnmodifiableListView(_messages);
  TwitchChatStatus get status => _status;
  String? get error => _error;

  void updatePosition(Duration position, {bool seek = false}) {
    if (_disposed) {
      return;
    }
    final next = position < Duration.zero ? Duration.zero : position;
    final reset = seek || next < _position || next - _position > const Duration(seconds: 10);
    _position = next;
    if (reset) {
      _generation++;
      _retry?.cancel();
      _deadline?.cancel();
      _upcoming.clear();
      _messages.clear();
      _messageIds.clear();
      _cursor = null;
      _hasNextPage = true;
      _loading = false;
      _status = TwitchChatStatus.connecting;
      _error = null;
      notifyListeners();
    }
    _advance();
  }

  void _advance({bool statusChanged = false}) {
    final seconds = _position.inMilliseconds / Duration.millisecondsPerSecond;
    var changed = statusChanged;
    while (_upcoming.isNotEmpty && _upcoming.first.offsetSeconds! <= seconds) {
      final message = _upcoming.removeFirst();
      if (_messageIds.add(message.id)) {
        _messages.add(message);
        changed = true;
      }
    }
    if (_messages.length > 300) {
      for (final message in _messages.take(_messages.length - 300)) {
        _messageIds.remove(message.id);
      }
      _messages.removeRange(0, _messages.length - 300);
    }
    if (changed) {
      notifyListeners();
    }
    if ((_upcoming.isEmpty || _upcoming.last.offsetSeconds! <= seconds + 2) &&
        _hasNextPage &&
        !_loading &&
        _error == null) {
      unawaited(_loadPage());
    }
  }

  Future<void> _loadPage() async {
    if (_disposed || _loading || !_hasNextPage) {
      return;
    }
    _loading = true;
    final generation = _generation;
    final cursor = _cursor;
    final offset = _position.inSeconds;
    _deadline = Timer(
      const Duration(seconds: 15),
      () => _failed(generation, TimeoutException("Chat replay request timed out")),
    );
    try {
      final client = await clientLoader();
      if (_disposed || generation != _generation) {
        return;
      }
      final page = await client.fetchVodChatPage(
        videoId,
        offsetSeconds: cursor == null ? offset : null,
        cursor: cursor,
      );
      if (_disposed || generation != _generation) {
        return;
      }
      _cursor = page.cursor;
      _deadline?.cancel();
      _hasNextPage = page.hasNextPage && page.cursor != null && page.cursor != cursor;
      _upcoming.addAll(page.messages);
      final changed = _status != TwitchChatStatus.connected || _error != null;
      _status = TwitchChatStatus.connected;
      _error = null;
      _loading = false;
      _advance(statusChanged: changed);
    } on Object catch (error) {
      _failed(generation, error);
    }
  }

  void _failed(int generation, Object error) {
    if (_disposed || generation != _generation) {
      return;
    }
    _generation++;
    _deadline?.cancel();
    _loading = false;
    final retry = error is! TwitchApiException || error.isTransient;
    _status = retry ? TwitchChatStatus.reconnecting : TwitchChatStatus.disconnected;
    _error = error is TwitchApiException ? error.message : "Could not load chat replay. Retrying…";
    notifyListeners();
    if (retry) {
      _retry = Timer(const Duration(seconds: 5), reconnect);
    }
  }

  void reconnect() {
    if (_disposed || _loading) {
      return;
    }
    if (!_hasNextPage) {
      updatePosition(_position, seek: true);
      return;
    }
    _retry?.cancel();
    _error = null;
    _status = TwitchChatStatus.connecting;
    notifyListeners();
    unawaited(_loadPage());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _retry?.cancel();
    _deadline?.cancel();
    super.dispose();
  }
}
