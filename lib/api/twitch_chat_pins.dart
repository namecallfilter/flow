import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:flow/api/twitch_chat_message.dart";
import "package:flutter/foundation.dart";

class TwitchChatPins extends ChangeNotifier {
  TwitchChatPins({
    required this.channelId,
    required this.loadInitial,
    Future<WebSocket> Function()? socketConnector,
  }) : _socketConnector = socketConnector ?? _openSocket {
    unawaited(_connect());
  }

  final String channelId;
  final Future<TwitchPinnedChat?> Function() loadInitial;
  final Future<WebSocket> Function() _socketConnector;
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _deadline;
  Timer? _readyDeadline;
  Timer? _initialDeadline;
  Timer? _retry;
  Timer? _expiry;
  TwitchPinnedChat? _pin;
  Map<String, Map<String, Object?>>? _initialChanges;
  String _subscriptionId = "";
  String _requestId = "";
  int _generation = 0;
  int _revision = 0;
  int _attempt = 0;
  int _keepaliveSeconds = 15;
  bool _disposed = false;

  TwitchPinnedChat? get pin => _pin;

  static Future<WebSocket> _openSocket() => WebSocket.connect(
    "wss://hermes.twitch.tv/v1?clientId=kimne78kx3ncx6brgo4mv6wki5h1ko",
  );

  void reconnect() {
    if (!_disposed) {
      _attempt = 0;
      unawaited(_connect());
    }
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _closeSocket();
    _setPin(null);
    _deadline = Timer(const Duration(seconds: 10), () => _lost(generation));
    try {
      final socket = await _socketConnector();
      if (!_isCurrent(generation)) {
        unawaited(socket.close().then<void>((_) {}, onError: (Object _) {}));
        return;
      }
      _socket = socket;
      _subscription = socket.cast<Object?>().listen(
        (data) => _receive(data, generation),
        onDone: () => _lost(generation),
        onError: (Object _) => _lost(generation),
      );
    } on Object {
      _lost(generation);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _receive(Object? raw, int generation) {
    if (!_isCurrent(generation) || raw is! String) {
      return;
    }
    try {
      final message = jsonDecode(raw) as Map<String, Object?>;
      _deadline?.cancel();
      _deadline = Timer(
        Duration(seconds: _keepaliveSeconds + 3),
        () => _lost(generation),
      );
      switch (message["type"]) {
        case "welcome":
          final welcome = message["welcome"]! as Map<String, Object?>;
          _keepaliveSeconds = (welcome["keepaliveSec"] as num?)?.toInt() ?? 15;
          _requestId = _uuid();
          _subscriptionId = _uuid();
          _socket?.add(
            jsonEncode({
              "type": "subscribe",
              "id": _requestId,
              "timestamp": DateTime.now().toUtc().toIso8601String(),
              "subscribe": {
                "id": _subscriptionId,
                "type": "pubsub",
                "pubsub": {"topic": "pinned-chat-updates-v1.$channelId"},
              },
            }),
          );
          _readyDeadline = Timer(const Duration(seconds: 10), () => _lost(generation));
        case "subscribeResponse":
          if (message["parentId"] != _requestId) {
            return;
          }
          final response = message["subscribeResponse"]! as Map<String, Object?>;
          if (response["result"] != "ok") {
            _lost(generation);
            return;
          }
          _readyDeadline?.cancel();
          unawaited(_loadInitial(generation));
        case "notification":
          final notification = message["notification"]! as Map<String, Object?>;
          final subscription = notification["subscription"]! as Map<String, Object?>;
          if (subscription["id"] != _subscriptionId || notification["type"] != "pubsub") {
            return;
          }
          _receivePin(jsonDecode(notification["pubsub"]! as String) as Map<String, Object?>);
        case "reconnect":
        case "subscriptionRevocation":
          _lost(generation);
      }
    } on Object {
      _lost(generation);
    }
  }

  Future<void> _loadInitial(int generation) async {
    final revision = _revision;
    final changes = <String, Map<String, Object?>>{};
    _initialChanges = changes;
    _initialDeadline = Timer(const Duration(seconds: 15), () {
      if (_revision == revision) {
        _lost(generation);
      }
    });
    try {
      final pin = await loadInitial();
      if (_isCurrent(generation)) {
        _initialDeadline?.cancel();
        _initialChanges = null;
        _attempt = 0;
        if (_revision == revision) {
          _setPin(pin);
          for (final change in changes.values) {
            _receivePin(change);
          }
        }
      }
    } on Object {
      if (_isCurrent(generation) && _revision == revision) {
        _lost(generation);
      }
    }
  }

  void _receivePin(Map<String, Object?> event) {
    final data = event["data"]! as Map<String, Object?>;
    final changes = _initialChanges;
    if (changes != null &&
        (event["type"] == "unpin-message" || event["type"] == "update-message")) {
      changes[data["id"]! as String] = event;
      if (changes.length > 300) {
        _lost(_generation);
        return;
      }
    }
    switch (event["type"]) {
      case "pin-message":
        final message = data["message"]! as Map<String, Object?>;
        if (message["type"] != "MOD") {
          return;
        }
        _revision++;
        _attempt = 0;
        final pinner = data["pinned_by"] as Map<String, Object?>?;
        final pinnerId = pinner?["id"] as String?;
        _setPin(
          TwitchPinnedChat(
            id: data["id"]! as String,
            message: _messageFromPin(data),
            endsAt: _secondsDate(message["ends_at"]),
            pinnedBy: pinnerId == null || pinnerId.isEmpty
                ? null
                : (
                    id: pinnerId,
                    login: pinner?["login"] as String? ?? "",
                    displayName:
                        pinner?["display_name"] as String? ?? pinner?["login"] as String? ?? "",
                  ),
          ),
        );
      case "unpin-message":
        if (_pin?.id == data["id"]) {
          _setPin(null);
        }
      case "update-message":
        final pin = _pin;
        if (pin != null && pin.id == data["id"]) {
          _setPin(
            TwitchPinnedChat(
              id: pin.id,
              message: pin.message,
              endsAt: _secondsDate(data["ends_at"]),
              pinnedBy: pin.pinnedBy,
            ),
          );
        }
    }
  }

  void _setPin(TwitchPinnedChat? pin) {
    _expiry?.cancel();
    _pin = pin;
    final remaining = pin?.endsAt?.difference(DateTime.now());
    if (remaining != null) {
      if (remaining <= Duration.zero) {
        _pin = null;
      } else {
        _expiry = Timer(remaining, () => _setPin(null));
      }
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _lost(int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    ++_generation;
    _closeSocket();
    _setPin(null);
    _retry = Timer(
      Duration(seconds: min(30, 1 << min(_attempt++, 5))),
      () => unawaited(_connect()),
    );
  }

  void _closeSocket() {
    _deadline?.cancel();
    _readyDeadline?.cancel();
    _initialDeadline?.cancel();
    _initialChanges = null;
    _retry?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      unawaited(socket.close().then<void>((_) {}, onError: (Object _) {}));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _closeSocket();
    _expiry?.cancel();
    super.dispose();
  }
}

TwitchChatMessage _messageFromPin(Map<String, Object?> data) {
  final message = data["message"]! as Map<String, Object?>;
  final sender = message["sender"]! as Map<String, Object?>;
  final content = message["content"]! as Map<String, Object?>;
  final parent = data["parent_message"] as Map<String, Object?>?;
  final root = data["thread_parent_message"] as Map<String, Object?>?;
  final parentSender = parent?["sender"] as Map<String, Object?>?;
  final rootSender = root?["sender"] as Map<String, Object?>?;
  final parentContent = parent?["content"] as Map<String, Object?>?;
  final emotes = <TwitchChatEmote>[];
  var offset = 0;
  for (final fragment
      in (content["fragments"] as List<Object?>?)?.cast<Map<String, Object?>>() ??
          const <Map<String, Object?>>[]) {
    final text = fragment["text"] as String? ?? "";
    final emote = fragment["emoticon"] as Map<String, Object?>?;
    final id = emote?["emoticonID"] as String?;
    if (id != null && text.isNotEmpty) {
      emotes.add(TwitchChatEmote(id: id, start: offset, end: offset + text.length));
    }
    offset += text.length;
  }
  return TwitchChatMessage(
    id: message["id"]! as String,
    userId: sender["id"] as String?,
    login: sender["login"] as String? ?? "",
    displayName: sender["display_name"] as String? ?? sender["login"] as String? ?? "",
    text: content["text"] as String? ?? "",
    color: sender["chat_color"] as String?,
    badges: [
      for (final badge
          in (sender["badges"] as List<Object?>?)?.cast<Map<String, Object?>>() ??
              const <Map<String, Object?>>[])
        if (badge["id"] != null && badge["version"] != null) "${badge["id"]}/${badge["version"]}",
    ],
    emotes: emotes,
    timestamp: _secondsDate(message["sent_at"]),
    parentMessageId: parent?["id"] as String?,
    parentUserId: parentSender?["id"] as String?,
    parentLogin: parentSender?["login"] as String?,
    parentDisplayName: parentSender?["display_name"] as String?,
    parentText: parentContent?["text"] as String?,
    threadRootId: root?["id"] as String? ?? parent?["id"] as String?,
    threadRootLogin: rootSender?["login"] as String? ?? parentSender?["login"] as String?,
  );
}

DateTime? _secondsDate(Object? value) =>
    value is num ? DateTime.fromMillisecondsSinceEpoch((value * 1000).round(), isUtc: true) : null;

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}";
}
