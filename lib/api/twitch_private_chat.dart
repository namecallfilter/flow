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
    this.onSharedChatEnded,
    Future<WebSocket> Function()? socketConnector,
  }) : _socketConnector = socketConnector ?? _openSocket {
    unawaited(_connect());
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_checkSession()));
  }

  final String channelId;
  final String userId;
  final TwitchApiClientLoader clientLoader;
  final void Function()? onSharedChatEnded;
  final void Function({
    required String id,
    required String type,
    required String text,
    ({String label, Uri url})? action,
  })
  onNotice;
  final Future<WebSocket> Function() _socketConnector;
  late final Timer _sessionTimer;
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _deadline;
  Timer? _phaseDeadline;
  Timer? _retry;
  String _token = "";
  String _authId = "";
  final _pendingSubscriptions = <String, ({String id, String topic})>{};
  final _subscriptions = <String, String>{};
  final _publishedCallouts = <String>{};
  int _generation = 0;
  int _attempt = 0;
  int _keepaliveSeconds = 15;
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
        _lost(generation);
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
          for (final topic in [
            "viewer-milestones.$userId",
            if (onSharedChatEnded != null) "shared-chat-channel-v1.$channelId",
            "private-callout.$userId.$channelId",
          ]) {
            final requestId = _uuid();
            final subscriptionId = _uuid();
            _pendingSubscriptions[requestId] = (id: subscriptionId, topic: topic);
            _send({
              "type": "subscribe",
              "id": requestId,
              "subscribe": {
                "id": subscriptionId,
                "type": "pubsub",
                "pubsub": {"topic": topic},
              },
            });
          }
          _phaseDeadline?.cancel();
          _phaseDeadline = Timer(const Duration(seconds: 10), () => _lost(generation));
        case "subscribeResponse":
          final pending = _pendingSubscriptions.remove(message["parentId"]);
          if (pending == null) {
            return;
          }
          if ((message["subscribeResponse"]! as Map)["result"] != "ok") {
            _lost(generation);
            return;
          }
          _subscriptions[pending.id] = pending.topic;
          if (_pendingSubscriptions.isEmpty) {
            _phaseDeadline?.cancel();
            _attempt = 0;
          }
        case "notification":
          final notification = message["notification"];
          if (notification is! Map || notification["type"] != "pubsub") {
            return;
          }
          final subscription = notification["subscription"];
          final pubsub = notification["pubsub"];
          if (subscription is! Map || pubsub is! String) {
            return;
          }
          final topic = _subscriptions[subscription["id"]];
          if (topic == null) {
            return;
          }
          final Object? event;
          try {
            event = jsonDecode(pubsub);
          } on FormatException {
            return;
          }
          if (event is! Map) {
            return;
          }
          if (topic == "shared-chat-channel-v1.$channelId") {
            if (event["type"] == "session-ended") {
              onSharedChatEnded?.call();
            }
            return;
          }
          final data = event["data"];
          if (data is! Map) {
            return;
          }
          if (topic == "private-callout.$userId.$channelId") {
            final callout = data["private_callout"];
            if (event["type"] != "send-private-callout" || callout is! Map) {
              return;
            }
            final id = callout["id"];
            final body = callout["body"];
            if (id is String && id.trim().isNotEmpty && body is String && body.trim().isNotEmpty) {
              ({String label, Uri url})? action;
              final actions = callout["actions"];
              final first = actions is List && actions.isNotEmpty ? actions.first : null;
              if (first is Map && first["type"] == "click") {
                final label = first["body"];
                final rawUrl = first["url"];
                final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
                if (label is String &&
                    label.trim().isNotEmpty &&
                    url != null &&
                    (url.scheme == "https" || url.scheme == "http") &&
                    url.host.isNotEmpty) {
                  action = (label: label, url: url);
                }
              }
              unawaited(
                _publish(
                  "private-callout:$id",
                  "private-callout",
                  body,
                  generation,
                  action: action,
                ),
              );
            }
            return;
          }
          final id = message["id"] as String?;
          final count = int.tryParse(data["watch_streak_value"]?.toString() ?? "");
          if (event["type"] == "viewer-milestones-update" &&
              data["event_type"] == "achieved" &&
              data["channel_id"] == channelId &&
              id != null &&
              id.isNotEmpty &&
              count != null &&
              count > 0) {
            unawaited(
              _publish(
                "watch-streak:$id",
                "watch-streak",
                "You reached a $count-stream watch streak!",
                generation,
              ),
            );
          }
        case "reconnect":
        case "subscriptionRevocation":
          _lost(generation);
      }
    } on Object {
      _lost(generation);
    }
  }

  Future<void> _publish(
    String id,
    String type,
    String text,
    int generation, {
    ({String label, Uri url})? action,
  }) async {
    try {
      await clientLoader().timeout(const Duration(seconds: 5));
      if (_isCurrent(generation) && (type != "private-callout" || _publishedCallouts.add(id))) {
        onNotice(id: id, type: type, text: text, action: action);
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
    _pendingSubscriptions.clear();
    _subscriptions.clear();
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
