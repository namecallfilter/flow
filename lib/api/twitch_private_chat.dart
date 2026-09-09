import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:flow/api/twitch_api_cache.dart";

class TwitchPrivateChatNotices {
  TwitchPrivateChatNotices({
    required this.channelId,
    required this.userId,
    required this.clientLoader,
    required this.onNotice,
    Future<WebSocket> Function()? socketConnector,
  }) : _socketConnector = socketConnector ?? _openSocket {
    unawaited(_connect());
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_checkSession()));
  }

  final String channelId;
  final String userId;
  final TwitchApiClientLoader clientLoader;
  final void Function({required String id, required String type, required String text}) onNotice;
  final Future<WebSocket> Function() _socketConnector;
  late final Timer _sessionTimer;
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _deadline;
  Timer? _phaseDeadline;
  Timer? _retry;
  String _token = "";
  String _authId = "";
  String _requestId = "";
  String _subscriptionId = "";
  int _generation = 0;
  int _attempt = 0;
  int _keepaliveSeconds = 15;
  bool _subscribed = false;
  bool _disposed = false;

  static Future<WebSocket> _openSocket() => WebSocket.connect(
    "wss://hermes.twitch.tv/v1?clientId=kimne78kx3ncx6brgo4mv6wki5h1ko",
  );

  Future<void> _connect() async {
    final generation = ++_generation;
    _closeSocket();
    try {
      final client = await clientLoader().timeout(const Duration(seconds: 5));
      if (!_isCurrent(generation)) {
        return;
      }
      _token = client.gqlAccessToken?.trim() ?? "";
      if (_token.isEmpty) {
        return;
      }
      _deadline = Timer(const Duration(seconds: 10), () => _lost(generation));
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

  void _send(Map<String, Object?> message) => _socket?.add(
    jsonEncode({
      ...message,
      "timestamp": DateTime.now().toUtc().toIso8601String(),
    }),
  );

  void _receive(Object? raw, int generation) {
    if (!_isCurrent(generation) || raw is! String) {
      return;
    }
    try {
      final message = jsonDecode(raw) as Map<String, Object?>;
      _deadline?.cancel();
      _deadline = Timer(Duration(seconds: _keepaliveSeconds + 3), () => _lost(generation));
      switch (message["type"]) {
        case "welcome":
          final welcome = message["welcome"]! as Map<String, Object?>;
          _keepaliveSeconds = (welcome["keepaliveSec"] as num?)?.toInt() ?? 15;
          _authId = _uuid();
          _send({
            "id": _authId,
            "type": "authenticate",
            "authenticate": {"token": _token},
          });
          _phaseDeadline?.cancel();
          _phaseDeadline = Timer(const Duration(seconds: 10), () => _lost(generation));
        case "authenticateResponse":
          if (message["parentId"] != _authId) {
            return;
          }
          if ((message["authenticateResponse"]! as Map)["result"] != "ok") {
            _lost(generation);
            return;
          }
          _requestId = _uuid();
          _subscriptionId = _uuid();
          _send({
            "type": "subscribe",
            "id": _requestId,
            "subscribe": {
              "id": _subscriptionId,
              "type": "pubsub",
              "pubsub": {"topic": "viewer-milestones.$userId"},
            },
          });
          _phaseDeadline?.cancel();
          _phaseDeadline = Timer(const Duration(seconds: 10), () => _lost(generation));
        case "subscribeResponse":
          if (message["parentId"] != _requestId) {
            return;
          }
          if ((message["subscribeResponse"]! as Map)["result"] != "ok") {
            _lost(generation);
            return;
          }
          _phaseDeadline?.cancel();
          _subscribed = true;
          _attempt = 0;
        case "notification":
          final notification = message["notification"]! as Map<String, Object?>;
          if (!_subscribed ||
              notification["type"] != "pubsub" ||
              (notification["subscription"]! as Map)["id"] != _subscriptionId) {
            return;
          }
          final event = jsonDecode(notification["pubsub"]! as String) as Map<String, Object?>;
          final data = event["data"] as Map<String, Object?>?;
          final id = message["id"] as String?;
          final count = int.tryParse(data?["watch_streak_value"]?.toString() ?? "");
          if (event["type"] == "viewer-milestones-update" &&
              data?["event_type"] == "achieved" &&
              data?["channel_id"] == channelId &&
              id != null &&
              id.isNotEmpty &&
              count != null &&
              count > 0) {
            unawaited(_publish(id, count, generation));
          }
        case "reconnect":
        case "subscriptionRevocation":
          _lost(generation);
      }
    } on Object {
      _lost(generation);
    }
  }

  Future<void> _publish(String id, int count, int generation) async {
    try {
      await clientLoader().timeout(const Duration(seconds: 5));
      if (_isCurrent(generation)) {
        onNotice(
          id: "watch-streak:$id",
          type: "watch-streak",
          text: "You reached a $count-stream watch streak!",
        );
      }
    } on Object {
      _lost(generation);
    }
  }

  Future<void> _checkSession() async {
    final generation = _generation;
    try {
      await clientLoader().timeout(const Duration(seconds: 5));
    } on Object {
      _lost(generation);
    }
  }

  void _lost(int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    ++_generation;
    _closeSocket();
    _retry = Timer(
      Duration(seconds: min(30, 1 << min(_attempt++, 5))),
      () => unawaited(_connect()),
    );
  }

  void _closeSocket() {
    _deadline?.cancel();
    _phaseDeadline?.cancel();
    _retry?.cancel();
    _subscribed = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      unawaited(socket.close().then<void>((_) {}, onError: (Object _) {}));
    }
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    _sessionTimer.cancel();
    _closeSocket();
  }
}

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}";
}
