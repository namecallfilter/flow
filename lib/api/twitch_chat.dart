import "dart:async";
import "dart:collection";
import "dart:io";
import "dart:math";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flow/api/twitch_chat_pins.dart";
import "package:flutter/foundation.dart";

export "package:flow/api/twitch_chat_message.dart";

enum TwitchChatStatus { connecting, connected, reconnecting, disconnected }

class TwitchChatController extends ChangeNotifier {
  TwitchChatController({
    required this.clientLoader,
    required String channel,
    Future<WebSocket> Function()? socketConnector,
    this.pinSocketConnector,
    this.loadPins = true,
    bool autoConnect = true,
  }) : channel = channel.trim().toLowerCase(),
       _socketConnector = socketConnector ?? _openSocket {
    if (!RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(this.channel)) {
      _status = TwitchChatStatus.disconnected;
      _error = "This channel has no chat available.";
    } else if (autoConnect) {
      unawaited(_connect());
    }
  }

  final TwitchApiClientLoader clientLoader;
  final String channel;
  final Future<WebSocket> Function() _socketConnector;
  final Future<WebSocket> Function()? pinSocketConnector;
  final bool loadPins;
  TwitchChatPins? _pins;
  final List<TwitchChatMessage> _messages = [];
  final List<TwitchChatMessage> _recentHistory = [];
  final Map<String, String> _roomState = {};
  static final Queue<DateTime> _sentAt = Queue<DateTime>();
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  Timer? _connectTimer;
  Timer? _joinTimer;
  Timer? _notifyTimer;
  Timer? _sendTimer;
  ({String text, TwitchChatMessage? replyTo, Completer<bool> result})? _pendingSend;
  TwitchUser? _user;
  String? _userColor;
  String? _error;
  String? _readOnlyReason;
  String _buffer = "";
  TwitchChatStatus _status = TwitchChatStatus.connecting;
  int _generation = 0;
  int _attempt = 0;
  int _receivedMessageCount = 0;
  bool _disposed = false;
  bool _anonymousOnly = false;

  List<TwitchChatMessage> get messages => UnmodifiableListView(_messages);
  List<TwitchChatMessage> get recentHistory => UnmodifiableListView(_recentHistory);
  int get receivedMessageCount => _receivedMessageCount;
  TwitchPinnedChat? get pinnedChat => _pins?.pin;
  TwitchChatMessage? get pinnedMessage => pinnedChat?.message;
  DateTime? get pinnedUntil => _pins?.pin?.endsAt;
  TwitchChatStatus get status => _status;
  String? get error => _error;
  bool get isSignedIn => _user != null;
  Map<String, String> get roomState => UnmodifiableMapView(_roomState);
  bool get canSend => _status == TwitchChatStatus.connected && isSignedIn;

  static Future<WebSocket> _openSocket() => WebSocket.connect("wss://irc-ws.chat.twitch.tv:443");

  void reconnect() {
    if (_disposed || !RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(channel)) {
      return;
    }
    _anonymousOnly = false;
    _attempt = 0;
    _pins?.reconnect();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _closeSocket();
    _status = _attempt == 0 && _status == TwitchChatStatus.connecting
        ? TwitchChatStatus.connecting
        : TwitchChatStatus.reconnecting;
    _user = null;
    _userColor = null;
    _error = _anonymousOnly ? "Chat sign-in expired. Sign in again to send messages." : null;
    _connectTimer = Timer(const Duration(seconds: 15), () => _lost(generation));
    notifyListeners();

    String? token;
    TwitchUser? user;
    String? readOnlyReason = _error;
    if (!_anonymousOnly) {
      try {
        final client = await clientLoader();
        if (!_isCurrent(generation)) {
          return;
        }
        final webToken = client.gqlAccessToken?.trim();
        token = webToken?.isNotEmpty == true ? webToken : client.accessToken.trim();
        if (token != null && token.isNotEmpty) {
          user = await client.fetchCurrentUser();
        }
      } on Object {
        token = null;
        readOnlyReason = "Could not verify your Twitch account. Retry chat to send messages.";
      }
    }
    if (!_isCurrent(generation)) {
      return;
    }
    _user = user;
    _readOnlyReason = readOnlyReason;
    if (user != null &&
        (!RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(user.login.toLowerCase()) ||
            token == null ||
            RegExp(r"[\x00-\x20\x7f]").hasMatch(token))) {
      _user = null;
    }
    try {
      final socket = await _socketConnector();
      if (!_isCurrent(generation)) {
        _close(socket);
        return;
      }
      _connectTimer?.cancel();
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 20);
      _subscription = socket.cast<Object?>().listen(
        (data) {
          if (_isCurrent(generation) && data is String) {
            _receive(data, generation);
          }
        },
        onDone: () => _lost(generation),
        onError: (Object _) => _lost(generation),
      );
      socket.add("CAP REQ :twitch.tv/tags twitch.tv/commands\r\n");
      if (_user != null) {
        socket.add("PASS oauth:$token\r\n");
      }
      final nick = _user?.login.toLowerCase() ?? "justinfan${Random().nextInt(900000) + 100000}";
      socket.add("NICK $nick\r\n");
      socket.add("JOIN #$channel\r\n");
      _joinTimer = Timer(const Duration(seconds: 15), () => _lost(generation));
    } on Object {
      _lost(generation);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _lost(int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    ++_generation;
    _closeSocket();
    _status = TwitchChatStatus.reconnecting;
    _error = null;
    final seconds = min(30, 1 << min(_attempt++, 5));
    _retryTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(_connect()),
    );
    notifyListeners();
  }

  void _receive(String data, int generation) {
    _buffer += data;
    var end = _buffer.indexOf("\r\n");
    while (end >= 0 && _isCurrent(generation)) {
      final line = _buffer.substring(0, end);
      _buffer = _buffer.substring(end + 2);
      final message = _IrcMessage.parse(line);
      if (message != null) {
        _handle(message, generation);
      }
      end = _buffer.indexOf("\r\n");
    }
    if (_buffer.length > 65536) {
      _lost(generation);
    }
  }

  void _handle(_IrcMessage message, int generation) {
    if (message.command == "PING") {
      _socket?.add("PONG :${message.text}\r\n");
      return;
    }
    if (message.command == "RECONNECT") {
      _lost(generation);
      return;
    }
    if (message.command == "NOTICE" &&
        message.params.firstOrNull == "*" &&
        (message.text.toLowerCase().contains("auth") ||
            message.text.toLowerCase().contains("login"))) {
      if (_anonymousOnly) {
        _lost(generation);
        return;
      }
      _anonymousOnly = true;
      _user = null;
      unawaited(_connect());
      return;
    }
    if (!message.params.contains("#$channel")) {
      return;
    }
    switch (message.command) {
      case "ROOMSTATE":
      case "366":
        if (message.command == "ROOMSTATE") {
          _roomState.addAll(message.tags);
          final channelId = message.tags["room-id"].nullIfEmpty;
          if (loadPins && channelId != null && _pins?.channelId != channelId) {
            _pins?.dispose();
            _pins = TwitchChatPins(
              channelId: channelId,
              socketConnector: pinSocketConnector,
              loadInitial: () async => (await clientLoader()).fetchPinnedChat(channelId),
            )..addListener(_scheduleNotify);
          }
        }
        _joinTimer?.cancel();
        _attempt = 0;
        _status = TwitchChatStatus.connected;
        _error = _readOnlyReason;
        notifyListeners();
      case "USERSTATE":
        _userColor = message.tags["color"];
        final pending = _pendingSend;
        final id = message.tags["id"].nullIfEmpty;
        if (pending != null && id != null && !_messages.any((item) => item.id == id)) {
          _pendingSend = null;
          _sendTimer?.cancel();
          _append(
            TwitchChatMessage(
              id: id,
              login: _user!.login,
              displayName: _user!.displayName,
              text: pending.text,
              color: _userColor,
              badges: (message.tags["badges"] ?? "")
                  .split(",")
                  .where((badge) => badge.isNotEmpty)
                  .toList(),
              isOwn: true,
              timestamp: DateTime.now(),
              userId: _user!.id,
              parentMessageId: pending.replyTo?.id,
              parentUserId: pending.replyTo?.userId,
              parentLogin: pending.replyTo?.login,
              parentDisplayName: pending.replyTo?.displayName,
              parentText: pending.replyTo?.text,
              threadRootId: pending.replyTo?.threadRootId ?? pending.replyTo?.id,
              threadRootLogin: pending.replyTo?.threadRootLogin ?? pending.replyTo?.login,
            ),
          );
          pending.result.complete(true);
        }
      case "PRIVMSG":
      case "USERNOTICE":
        final isNotice = message.command == "USERNOTICE";
        final login = isNotice
            ? message.tags["login"].nullIfEmpty ?? ""
            : message.prefix.split("!").first;
        final id = message.tags["id"] ?? "${DateTime.now().microsecondsSinceEpoch}-$login";
        if (_messages.any((item) => item.id == id)) {
          return;
        }
        final isAction =
            message.text.startsWith("\u0001ACTION ") && message.text.endsWith("\u0001");
        final text = isAction ? message.text.substring(8, message.text.length - 1) : message.text;
        _append(
          TwitchChatMessage(
            id: id,
            login: login,
            displayName:
                message.tags["display-name"].nullIfEmpty ??
                (isNotice && login.isEmpty ? "Twitch" : login),
            text: text,
            color: message.tags["color"].nullIfEmpty,
            badges: (message.tags["badges"] ?? "")
                .split(",")
                .where((badge) => badge.isNotEmpty)
                .toList(),
            emotes: _parseEmotes(message.tags["emotes"] ?? "", text),
            isAction: isAction,
            isOwn: login.toLowerCase() == _user?.login.toLowerCase(),
            userId: message.tags["user-id"].nullIfEmpty,
            isFirstMessage: message.tags["first-msg"] == "1",
            noticeType: isNotice ? message.tags["msg-id"].nullIfEmpty ?? "notice" : null,
            noticeText: isNotice ? message.tags["system-msg"].nullIfEmpty : null,
            parentMessageId: message.tags["reply-parent-msg-id"].nullIfEmpty,
            parentUserId: message.tags["reply-parent-user-id"].nullIfEmpty,
            parentLogin: message.tags["reply-parent-user-login"].nullIfEmpty,
            parentDisplayName: message.tags["reply-parent-display-name"].nullIfEmpty,
            parentText: message.tags["reply-parent-msg-body"],
            threadRootId:
                message.tags["reply-thread-parent-msg-id"].nullIfEmpty ??
                message.tags["reply-parent-msg-id"].nullIfEmpty,
            threadRootLogin:
                message.tags["reply-thread-parent-user-login"].nullIfEmpty ??
                message.tags["reply-parent-user-login"].nullIfEmpty,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(message.tags["tmi-sent-ts"] ?? "") ??
                  DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        );
      case "CLEARMSG":
      case "CLEARCHAT":
        final target = message.tags["target-msg-id"];
        final login = message.text.toLowerCase();
        final targetUserId = message.tags["target-user-id"].nullIfEmpty;
        final timeoutSeconds = int.tryParse(message.tags["ban-duration"] ?? "");
        final moderation = message.command == "CLEARMSG"
            ? TwitchChatModeration.deleted
            : login.isEmpty && targetUserId == null
            ? TwitchChatModeration.cleared
            : timeoutSeconds == null
            ? TwitchChatModeration.ban
            : TwitchChatModeration.timeout;
        final moderatedAt = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(message.tags["tmi-sent-ts"] ?? "") ?? DateTime.now().millisecondsSinceEpoch,
        );
        var matchedVisibleMessage = false;
        for (final buffer in [_messages, _recentHistory]) {
          for (var index = 0; index < buffer.length; index++) {
            final item = buffer[index];
            final matches = message.command == "CLEARMSG"
                ? item.id == target
                : moderation == TwitchChatModeration.cleared ||
                      (targetUserId != null && item.userId != null
                          ? item.userId == targetUserId
                          : login.isNotEmpty && item.login.toLowerCase() == login);
            if (matches && identical(buffer, _messages)) {
              matchedVisibleMessage = true;
            }
            if (matches &&
                (!item.isDeleted ||
                    moderation == TwitchChatModeration.ban ||
                    moderation == TwitchChatModeration.timeout)) {
              buffer[index] = item.copyWith(
                isDeleted: true,
                moderation: moderation,
                timeoutSeconds: timeoutSeconds,
                moderatedAt: moderatedAt,
              );
            }
          }
        }
        if (!matchedVisibleMessage || moderation == TwitchChatModeration.cleared) {
          final targetLogin = message.command == "CLEARMSG"
              ? message.tags["login"].nullIfEmpty ?? ""
              : login;
          final displayName = targetLogin.isEmpty ? "A chatter" : targetLogin;
          _append(
            TwitchChatMessage(
              id: "moderation-${moderatedAt.microsecondsSinceEpoch}-${target ?? targetUserId ?? targetLogin}",
              login: targetLogin,
              displayName: displayName,
              userId: targetUserId,
              text: "",
              noticeType: "moderation",
              noticeText: switch (moderation) {
                TwitchChatModeration.timeout =>
                  "$displayName was timed out for $timeoutSeconds seconds.",
                TwitchChatModeration.ban => "$displayName was permanently banned.",
                TwitchChatModeration.deleted => "$displayName’s message was deleted.",
                TwitchChatModeration.cleared => "Chat was cleared.",
              },
              moderation: moderation,
              timeoutSeconds: timeoutSeconds,
              moderatedAt: moderatedAt,
              timestamp: moderatedAt,
            ),
          );
        }
        _scheduleNotify();
      case "NOTICE":
        _error = message.text;
        if ((message.tags["msg-id"] ?? "").startsWith("msg_") ||
            message.tags["msg-id"] == "unrecognized_cmd") {
          _failSend();
        }
        if (message.tags["msg-id"] == "msg_channel_suspended") {
          ++_generation;
          _closeSocket();
          _status = TwitchChatStatus.disconnected;
        }
        notifyListeners();
    }
  }

  Future<bool> send(String value, {TwitchChatMessage? replyTo}) async {
    final text = value.trim();
    if (_disposed) {
      return false;
    }
    if (!canSend || _socket == null) {
      _error = isSignedIn
          ? "Wait for chat to reconnect before sending."
          : "Sign in to Twitch to chat.";
      notifyListeners();
      return false;
    }
    if (_pendingSend != null) {
      return false;
    }
    if (text.isEmpty || text.runes.length > 500 || RegExp(r"[\x00-\x1f\x7f]").hasMatch(text)) {
      _error = "Use a message of 1–500 characters on a single line.";
      notifyListeners();
      return false;
    }
    if (replyTo != null && !RegExp(r"^[a-zA-Z0-9_-]+$").hasMatch(replyTo.id)) {
      _error = "This message cannot be replied to.";
      notifyListeners();
      return false;
    }
    final now = DateTime.now();
    while (_sentAt.isNotEmpty && now.difference(_sentAt.first) >= const Duration(seconds: 30)) {
      _sentAt.removeFirst();
    }
    if (_sentAt.length >= 20 ||
        (_sentAt.isNotEmpty && now.difference(_sentAt.last) < const Duration(seconds: 1))) {
      _error = "You are sending messages too quickly. Try again shortly.";
      notifyListeners();
      return false;
    }
    try {
      final pending = (text: text, replyTo: replyTo, result: Completer<bool>());
      _pendingSend = pending;
      final tag = replyTo == null ? "" : "@reply-parent-msg-id=${replyTo.id} ";
      _socket!.add("${tag}PRIVMSG #$channel :$text\r\n");
      _sentAt.addLast(now);
      _error = null;
      _sendTimer = Timer(const Duration(seconds: 10), () {
        _lost(_generation);
        _error = "Twitch did not confirm delivery. Your draft has been kept.";
        notifyListeners();
      });
      return pending.result.future;
    } on Object {
      _lost(_generation);
      return false;
    }
  }

  void _failSend() {
    _sendTimer?.cancel();
    _pendingSend?.result.complete(false);
    _pendingSend = null;
  }

  void _append(TwitchChatMessage message) {
    _receivedMessageCount++;
    _messages.add(message);
    _recentHistory.add(message);
    if (_messages.length > 300) {
      _messages.removeRange(0, _messages.length - 300);
    }
    if (_recentHistory.length > 5000) {
      _recentHistory.removeRange(0, _recentHistory.length - 5000);
    }
    _scheduleNotify();
  }

  void _scheduleNotify() {
    _notifyTimer ??= Timer(const Duration(milliseconds: 80), () {
      _notifyTimer = null;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  static void _close(WebSocket socket) {
    unawaited(socket.close().then<void>((_) {}, onError: (Object _) {}));
  }

  void _closeSocket() {
    _failSend();
    _retryTimer?.cancel();
    _connectTimer?.cancel();
    _joinTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      _close(socket);
    }
    _buffer = "";
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _closeSocket();
    _notifyTimer?.cancel();
    _pins?.dispose();
    super.dispose();
  }
}

class _IrcMessage {
  const _IrcMessage(
    this.tags,
    this.prefix,
    this.command,
    this.params,
    this.text,
  );

  final Map<String, String> tags;
  final String prefix;
  final String command;
  final List<String> params;
  final String text;

  static _IrcMessage? parse(String line) {
    final match = RegExp(
      r"^(?:@(\S+) )?(?::(\S+) )?(\S+)(?: (.*))?$",
    ).firstMatch(line);
    if (match == null) {
      return null;
    }
    final tags = <String, String>{};
    for (final tag in (match[1] ?? "").split(";")) {
      final separator = tag.indexOf("=");
      if (separator >= 0) {
        tags[tag.substring(0, separator)] = tag
            .substring(separator + 1)
            .replaceAllMapped(
              RegExp(r"\\(.)"),
              (escape) => switch (escape[1]) {
                ":" => ";",
                "s" => " ",
                "r" => "\r",
                "n" => "\n",
                final String value => value,
                _ => "",
              },
            );
      }
    }
    final arguments = match[4] ?? "";
    final trailing = arguments.startsWith(":") ? 0 : arguments.indexOf(" :");
    return _IrcMessage(
      tags,
      match[2] ?? "",
      match[3]!,
      (trailing < 0 ? arguments : arguments.substring(0, trailing)).split(" "),
      trailing < 0 ? "" : arguments.substring(trailing + (trailing == 0 ? 1 : 2)),
    );
  }
}

List<TwitchChatEmote> _parseEmotes(String tag, String text) {
  final offsets = <int>[0];
  for (final rune in text.runes) {
    offsets.add(offsets.last + (rune > 0xffff ? 2 : 1));
  }
  final emotes = <TwitchChatEmote>[];
  for (final match in RegExp(r"([^/:]+):([\d,\-]+)").allMatches(tag)) {
    for (final range in match[2]!.split(",")) {
      final bounds = range.split("-");
      if (bounds.length != 2) {
        continue;
      }
      final start = int.tryParse(bounds[0]);
      final end = int.tryParse(bounds[1]);
      if (start != null && end != null && start >= 0 && end >= start && end + 1 < offsets.length) {
        emotes.add(
          TwitchChatEmote(
            id: match[1]!,
            start: offsets[start],
            end: offsets[end + 1],
          ),
        );
      }
    }
  }
  emotes.sort((a, b) => a.start.compareTo(b.start));
  return emotes;
}

extension on String? {
  String? get nullIfEmpty => this == null || this!.isEmpty ? null : this;
}
