import "dart:async";
import "dart:collection";
import "dart:io";
import "dart:math";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flow/api/twitch_chat_pins.dart";
import "package:flow/api/twitch_private_chat.dart";
import "package:flutter/foundation.dart";

export "package:flow/api/twitch_chat_message.dart";

enum TwitchChatStatus { connecting, connected, reconnecting, disconnected }

class TwitchChatController extends ChangeNotifier {
  TwitchChatController({
    required this.clientLoader,
    required String channel,
    Future<WebSocket> Function()? socketConnector,
    this.pinSocketConnector,
    this.privateSocketConnector,
    this.loadPins = true,
    this.loadPrivateNotices = true,
    this.loadRecentHistory = true,
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
  final Future<WebSocket> Function()? privateSocketConnector;
  final bool loadPins;
  final bool loadPrivateNotices;
  final bool loadRecentHistory;
  TwitchChatPins? _pins;
  TwitchPrivateChatNotices? _privateNotices;
  String? _privateUserId;
  ({String accessToken, String? gqlAccessToken})? _sessionCredentials;
  final Set<String> _privateNoticeIds = {};
  final List<TwitchChatMessage> _messages = [];
  final List<TwitchChatMessage> _recentHistory = [];
  int _historyRequestedGeneration = -1;
  final Set<String> _historyOnlyIds = {};
  List<TwitchChatMessage Function(TwitchChatMessage)>? _historyModeration;
  final Map<String, String> _roomState = {};
  static final Queue<DateTime> _sentAt = Queue<DateTime>();
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  Timer? _connectTimer;
  Timer? _joinTimer;
  Timer? _notifyTimer;
  Timer? _sendTimer;
  Timer? _slowModeTimer;
  DateTime? _lastMessageSentAt;
  DateTime? _slowModeRejectedUntil;
  Timer? _followerTimer;
  Timer? _claimTimer;
  bool _autoClaimChannelPoints = false;
  bool _claimInFlight = false;
  int _claimRevision = 0;
  final Set<String> _claimedPointIds = {};
  ({
    String text,
    String localId,
    DateTime sentAt,
    TwitchChatMessage? replyTo,
    Completer<bool> result,
  })?
  _pendingSend;
  TwitchUser? _user;
  TwitchChatAccess? _chatAccess;
  String? _chatAccessError;
  bool _isCheckingChatAccess = false;
  bool _isFollowingChannel = false;
  bool _isPrivileged = false;
  bool _isSubscriber = false;
  int _userStateRevision = 0;
  bool _welcomed = false;
  int _systemMessageCount = 0;
  int _accessRevision = 0;
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
  String? get currentUserId => _user?.id;
  String? get currentUserLogin => _user?.login.toLowerCase();
  TwitchChatAccess? get chatAccess => _chatAccess;
  String? get chatAccessError => _chatAccessError;
  bool get isCheckingChatAccess => _isCheckingChatAccess;
  bool get isFollowingChannel => _isFollowingChannel;
  int get followersOnlyMinutes => int.tryParse(_roomState["followers-only"] ?? "") ?? -1;
  bool get subscriberChatEligible =>
      _roomState["subs-only"] != "1" ||
      (isSignedIn &&
          (_user!.login.toLowerCase() == channel ||
              _isSubscriber ||
              _isPrivileged ||
              _chatAccess?.isModerator == true ||
              _chatAccess?.isVip == true));
  bool get followerChatEligible =>
      followersOnlyMinutes < 0 ||
      (isSignedIn &&
          (_user!.login.toLowerCase() == channel ||
              _isPrivileged ||
              _chatAccess?.isModerator == true ||
              _chatAccess?.isVip == true ||
              (_chatAccess?.isFollowing == true &&
                  (followersOnlyMinutes == 0 ||
                      (_chatAccess?.followedAt != null &&
                          followingWaitRemaining == Duration.zero)))));
  Duration get followingWaitRemaining {
    final followedAt = _chatAccess?.followedAt;
    if (followedAt == null || followersOnlyMinutes <= 0) {
      return Duration.zero;
    }
    final remaining = followedAt
        .add(Duration(minutes: followersOnlyMinutes))
        .difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, String> get roomState => UnmodifiableMapView(_roomState);
  Duration get slowModeWaitRemaining {
    var sentAt = _pendingSend?.sentAt;
    if (sentAt == null || _lastMessageSentAt?.isAfter(sentAt) == true) {
      sentAt = _lastMessageSentAt;
    }
    final exempt =
        _user?.login.toLowerCase() == channel ||
        _isPrivileged ||
        _chatAccess?.isModerator == true ||
        _chatAccess?.isVip == true ||
        _chatAccess?.isSlowModeRestricted == false;
    final until =
        _slowModeRejectedUntil ??
        (exempt
            ? null
            : sentAt?.add(Duration(seconds: int.tryParse(_roomState["slow"] ?? "") ?? 0)));
    final remaining = until?.difference(DateTime.now()) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canSend =>
      _status == TwitchChatStatus.connected &&
      isSignedIn &&
      subscriberChatEligible &&
      followerChatEligible &&
      slowModeWaitRemaining == Duration.zero;

  void _scheduleSlowMode() {
    _slowModeTimer?.cancel();
    final remaining = slowModeWaitRemaining;
    if (!_disposed && remaining > Duration.zero) {
      _slowModeTimer = Timer(
        remaining < const Duration(seconds: 1) ? remaining : const Duration(seconds: 1),
        () {
          _scheduleSlowMode();
          notifyListeners();
        },
      );
    }
  }

  Future<void> refreshChatAccess() async {
    if (_disposed) {
      return;
    }
    final generation = _generation;
    final revision = ++_accessRevision;
    _isCheckingChatAccess = true;
    _chatAccessError = null;
    notifyListeners();
    try {
      final client = await _loadSessionClient();
      if (!_isCurrent(generation) || revision != _accessRevision) {
        return;
      }
      final access = await client.fetchChatAccess(channel);
      if (!_isCurrent(generation) || revision != _accessRevision) {
        return;
      }
      _chatAccess = access;
      if (!subscriberChatEligible) {
        final userStateRevision = _userStateRevision;
        final subscribed = await client.fetchChannelSubscriptionStatus(channel);
        if (!_isCurrent(generation) || revision != _accessRevision) {
          return;
        }
        if (userStateRevision == _userStateRevision) {
          _isSubscriber = subscribed;
        }
      }
      final lastMessage = access.lastRecentChatMessageAt;
      if (lastMessage != null &&
          (_lastMessageSentAt == null || lastMessage.isAfter(_lastMessageSentAt!))) {
        _lastMessageSentAt = lastMessage;
      }
    } on Object catch (error) {
      if (!_isCurrent(generation) || revision != _accessRevision) {
        return;
      }
      _chatAccess = null;
      _chatAccessError = error is TwitchApiException
          ? error.message
          : "Could not load channel rules and follower status. Try again.";
    } finally {
      if (_isCurrent(generation) && revision == _accessRevision) {
        _isCheckingChatAccess = false;
        _scheduleFollowerEligibility();
        _scheduleSlowMode();
        notifyListeners();
      }
    }
  }

  Future<bool> followChannel() => _setFollowing(true);

  Future<bool> unfollowChannel() => _setFollowing(false);

  Future<bool> _setFollowing(bool follow) async {
    final access = _chatAccess;
    if (_disposed || !isSignedIn || access == null || _isFollowingChannel) {
      return false;
    }
    if (access.isFollowing == follow) {
      return true;
    }
    final generation = _generation;
    _isFollowingChannel = true;
    _chatAccessError = null;
    notifyListeners();
    try {
      final client = await _loadSessionClient();
      if (!_isCurrent(generation)) {
        return false;
      }
      DateTime? followedAt;
      if (follow) {
        followedAt = await client.followChannel(access.channelId);
      } else {
        await client.unfollowChannel(access.channelId);
      }
      if (!_isCurrent(generation)) {
        return false;
      }
      await refreshChatAccess();
      if (!_isCurrent(generation)) {
        return false;
      }
      final current = _chatAccess ?? access;
      _chatAccess = TwitchChatAccess(
        channelId: current.channelId,
        channelDisplayName: current.channelDisplayName,
        rules: current.rules,
        isFollowing: follow,
        followedAt: followedAt,
        isModerator: current.isModerator,
        isVip: current.isVip,
        isSlowModeRestricted: current.isSlowModeRestricted,
        lastRecentChatMessageAt: current.lastRecentChatMessageAt,
      );
      _chatAccessError = null;
      _scheduleFollowerEligibility();
      return true;
    } on Object catch (error) {
      if (_isCurrent(generation)) {
        _chatAccessError = error is TwitchApiException
            ? error.message
            : "Could not ${follow ? "follow" : "unfollow"} this channel. Try again.";
      }
      return false;
    } finally {
      if (_isCurrent(generation)) {
        _isFollowingChannel = false;
        notifyListeners();
      }
    }
  }

  void _scheduleFollowerEligibility() {
    _followerTimer?.cancel();
    final remaining = followingWaitRemaining;
    if (!followerChatEligible && remaining > Duration.zero) {
      _followerTimer = Timer(remaining, () {
        if (!_disposed) {
          notifyListeners();
        }
      });
    }
  }

  void addSystemMessage(String text) =>
      upsertSystemMessage("system-${_systemMessageCount++}", text);

  void addPrivateNotice({required String id, required String type, required String text}) {
    if (_disposed ||
        text.trim().isEmpty ||
        _privateNoticeIds.contains(id) ||
        _recentHistory.any((message) => message.id == id)) {
      return;
    }
    _privateNoticeIds.add(id);
    if (_privateNoticeIds.length > 256) {
      _privateNoticeIds.remove(_privateNoticeIds.first);
    }
    _append(
      TwitchChatMessage(
        id: id,
        login: "",
        displayName: "",
        text: "",
        isPrivate: true,
        noticeType: type,
        noticeText: text,
        timestamp: DateTime.now(),
      ),
    );
  }

  void setAutoClaimChannelPoints({required bool enabled}) {
    if (_disposed || enabled == _autoClaimChannelPoints) {
      return;
    }
    _autoClaimChannelPoints = enabled;
    ++_claimRevision;
    _claimTimer?.cancel();
    _claimTimer = null;
    if (enabled) {
      unawaited(_claimAvailableChannelPoints());
    }
  }

  bool get _canClaimPoints =>
      !_disposed && _autoClaimChannelPoints && isSignedIn && _status == TwitchChatStatus.connected;

  Future<void> _claimAvailableChannelPoints() async {
    if (!_canClaimPoints || _claimInFlight || _claimTimer != null) {
      return;
    }
    _claimInFlight = true;
    final generation = _generation;
    final revision = _claimRevision;
    final userId = currentUserId;
    bool isCurrent() => _canClaimPoints && _isCurrent(generation) && revision == _claimRevision;
    try {
      final client = await _loadSessionClient();
      if (!isCurrent()) {
        return;
      }
      final available = await client.fetchAvailableChannelPointsClaim(channel);
      if (!isCurrent() || available == null || _claimedPointIds.contains(available.claimId)) {
        return;
      }
      final claimClient = await _loadSessionClient();
      if (!isCurrent()) {
        return;
      }
      final amount = await claimClient.claimChannelPoints(available.channelId, available.claimId);
      if (_disposed || _privateUserId != userId) {
        return;
      }
      _claimedPointIds.add(available.claimId);
      if (_claimedPointIds.length > 64) {
        _claimedPointIds.remove(_claimedPointIds.first);
      }
      if (isCurrent()) {
        addPrivateNotice(
          id: "channel-points-${available.claimId}",
          type: "channel-points",
          text: "Claimed $amount channel points.",
        );
      }
    } on Object {
      // Twitch can expire or consume a bonus before the next check.
    } finally {
      _claimInFlight = false;
      if (_canClaimPoints) {
        _claimTimer = Timer(const Duration(seconds: 60), () {
          _claimTimer = null;
          unawaited(_claimAvailableChannelPoints());
        });
      }
    }
  }

  void upsertSystemMessage(String id, String text) {
    if (_disposed || text.trim().isEmpty) {
      return;
    }
    var found = false;
    for (final history in [_messages, _recentHistory]) {
      final index = history.indexWhere(
        (message) => message.id == id && message.noticeType == "system",
      );
      if (index >= 0) {
        found = true;
        if (history[index].noticeText != text) {
          history[index] = history[index].copyWith(noticeText: text);
          _scheduleNotify();
        }
      }
    }
    if (found) {
      return;
    }
    _append(
      TwitchChatMessage(
        id: id,
        login: "",
        displayName: "",
        text: "",
        noticeType: "system",
        noticeText: text,
        timestamp: DateTime.now(),
      ),
    );
  }

  static Future<WebSocket> _openSocket() => WebSocket.connect("wss://irc-ws.chat.twitch.tv:443");

  Future<TwitchApiClient> _loadSessionClient() async {
    final generation = _generation;
    final client = await clientLoader().timeout(const Duration(seconds: 5));
    if (!_isCurrent(generation)) {
      throw TwitchApiException("The chat session changed. Try again.");
    }
    if (_sessionCredentials !=
        (accessToken: client.accessToken, gqlAccessToken: client.gqlAccessToken)) {
      _messages.removeWhere((message) => message.isPrivate);
      _recentHistory.removeWhere((message) => message.isPrivate);
      reconnect();
      throw TwitchApiException("The Twitch account changed. Reconnecting chat.");
    }
    return client;
  }

  void reconnect() {
    if (_disposed || !RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(channel)) {
      return;
    }
    _anonymousOnly = false;
    _attempt = 0;
    _pins?.reconnect();
    unawaited(_connect());
  }

  Future<void> _loadRecentHistory(String channelId, int generation) async {
    if (!loadRecentHistory || _historyRequestedGeneration == generation) {
      return;
    }
    _historyRequestedGeneration = generation;
    final moderation = <TwitchChatMessage Function(TwitchChatMessage)>[];
    _historyModeration = moderation;
    try {
      final client = await _loadSessionClient();
      if (!_isCurrent(generation)) {
        return;
      }
      final snapshot = await client.fetchRecentChat(channelId);
      if (!_isCurrent(generation) || !identical(_historyModeration, moderation)) {
        return;
      }
      final byId = {for (final message in _recentHistory) message.id: message};
      for (var message in snapshot) {
        if (message.id.isEmpty || message.timestamp == null || byId.containsKey(message.id)) {
          continue;
        }
        message = message.copyWith(
          isHistorical: true,
          isOwn: message.userId != null && message.userId == currentUserId,
        );
        for (final apply in moderation) {
          message = apply(message);
        }
        byId[message.id] = message;
        _historyOnlyIds.add(message.id);
      }
      final ordered = byId.values.toList();
      final positions = {for (final (index, message) in ordered.indexed) message.id: index};
      ordered.sort((a, b) {
        final byTime = (a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
        return byTime != 0 ? byTime : positions[a.id]!.compareTo(positions[b.id]!);
      });
      _recentHistory
        ..clear()
        ..addAll(ordered.skip(max(0, ordered.length - 5000)));
      _messages
        ..clear()
        ..addAll(_recentHistory.skip(max(0, _recentHistory.length - 300)));
      final retainedIds = _recentHistory.map((message) => message.id).toSet();
      _historyOnlyIds.removeWhere((id) => !retainedIds.contains(id));
      _scheduleNotify();
    } on Object {
      if (_historyRequestedGeneration == generation) {
        _historyRequestedGeneration = -1;
      }
      // Live IRC remains usable when Twitch does not provide recent history.
    } finally {
      if (identical(_historyModeration, moderation)) {
        _historyModeration = null;
      }
    }
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _closeSocket();
    final nextStatus = _attempt == 0 && _status == TwitchChatStatus.connecting
        ? TwitchChatStatus.connecting
        : TwitchChatStatus.reconnecting;
    if (generation == 1 || _status != nextStatus) {
      addSystemMessage(
        nextStatus == TwitchChatStatus.connecting
            ? "Connecting to chat..."
            : "Reconnecting to chat...",
      );
    }
    _status = nextStatus;
    _user = null;
    _userColor = null;
    _isPrivileged = false;
    _isSubscriber = false;
    _chatAccess = null;
    _chatAccessError = null;
    _isFollowingChannel = false;
    _isCheckingChatAccess = true;
    _error = _anonymousOnly ? "Chat sign-in expired. Sign in again to send messages." : null;
    notifyListeners();

    String? token;
    TwitchUser? user;
    var credentials = _sessionCredentials;
    String? readOnlyReason = _error;
    if (!_anonymousOnly) {
      try {
        final client = await clientLoader().timeout(const Duration(seconds: 5));
        if (!_isCurrent(generation)) {
          return;
        }
        credentials = (accessToken: client.accessToken, gqlAccessToken: client.gqlAccessToken);
        final webToken = client.gqlAccessToken?.trim();
        token = webToken?.isNotEmpty == true ? webToken : client.accessToken.trim();
        if (token != null && token.isNotEmpty) {
          user = await client.fetchCurrentUser().timeout(const Duration(seconds: 30));
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
    _sessionCredentials = credentials;
    _readOnlyReason = readOnlyReason;
    if (user != null &&
        (!RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(user.login.toLowerCase()) ||
            token == null ||
            RegExp(r"[\x00-\x20\x7f]").hasMatch(token))) {
      _user = null;
    }
    if (_privateUserId != _user?.id) {
      _lastMessageSentAt = null;
      _slowModeRejectedUntil = null;
      _messages.removeWhere((message) => message.isPrivate);
      _recentHistory.removeWhere((message) => message.isPrivate);
      _claimedPointIds.clear();
      _privateNoticeIds.clear();
      _privateUserId = _user?.id;
    }
    unawaited(refreshChatAccess());
    try {
      _connectTimer = Timer(const Duration(seconds: 15), () => _lost(generation));
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
    if (_status != TwitchChatStatus.reconnecting) {
      addSystemMessage("Reconnecting to chat...");
    }
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
          final previousFollowerMode = followersOnlyMinutes;
          final previousSubscriberMode = _roomState["subs-only"];
          final previousSlowMode = _roomState["slow"];
          _roomState.addAll(message.tags);
          if (message.tags.containsKey("slow")) {
            if (previousSlowMode != _roomState["slow"]) {
              _slowModeRejectedUntil = null;
            }
            _scheduleSlowMode();
          }
          if (previousFollowerMode != followersOnlyMinutes) {
            _scheduleFollowerEligibility();
          }
          if ((previousFollowerMode != followersOnlyMinutes ||
                  previousSubscriberMode != _roomState["subs-only"] ||
                  previousSlowMode != _roomState["slow"]) &&
              isSignedIn) {
            unawaited(refreshChatAccess());
          }
          final channelId = message.tags["room-id"].nullIfEmpty;
          if (channelId != null) {
            unawaited(_loadRecentHistory(channelId, generation));
          }
          if (loadPins && channelId != null && _pins?.channelId != channelId) {
            _pins?.dispose();
            _pins = TwitchChatPins(
              channelId: channelId,
              socketConnector: pinSocketConnector,
              loadInitial: () async => (await clientLoader()).fetchPinnedChat(channelId),
            )..addListener(_scheduleNotify);
          }
          final userId = currentUserId;
          if (loadPrivateNotices &&
              channelId != null &&
              userId != null &&
              _privateNotices?.channelId != channelId) {
            _privateNotices?.dispose();
            _privateNotices = TwitchPrivateChatNotices(
              channelId: channelId,
              userId: userId,
              clientLoader: _loadSessionClient,
              socketConnector: privateSocketConnector,
              onNotice: ({required id, required type, required text}) {
                if (_isCurrent(generation) && currentUserId == userId) {
                  addPrivateNotice(id: id, type: type, text: text);
                }
              },
            );
          }
        }
        _joinTimer?.cancel();
        _attempt = 0;
        _status = TwitchChatStatus.connected;
        _error = _readOnlyReason;
        if (!_welcomed) {
          _welcomed = true;
          addSystemMessage("Welcome to $channel's Chat!");
        }
        unawaited(_claimAvailableChannelPoints());
        notifyListeners();
      case "USERSTATE":
        _userStateRevision++;
        _userColor = message.tags["color"];
        final badges = (message.tags["badges"] ?? "").split(",");
        _isSubscriber =
            message.tags["subscriber"] == "1" ||
            badges.any((badge) => badge.startsWith("subscriber/") || badge.startsWith("founder/"));
        _isPrivileged =
            message.tags["mod"] == "1" ||
            badges.any(
              (badge) =>
                  badge.startsWith("moderator/") ||
                  badge.startsWith("broadcaster/") ||
                  badge.startsWith("vip/"),
            );
        _scheduleFollowerEligibility();
        _scheduleSlowMode();
        _scheduleNotify();
        final pending = _pendingSend;
        final id = message.tags["id"].nullIfEmpty;
        final existing = _recentHistory.where((item) => item.id == id).firstOrNull;
        final pendingInHistory =
            existing != null &&
            _historyOnlyIds.contains(id) &&
            existing.userId == _user?.id &&
            existing.text == pending?.text;
        if (pending != null && id != null && (existing == null || pendingInHistory)) {
          if (_lastMessageSentAt == null || pending.sentAt.isAfter(_lastMessageSentAt!)) {
            _lastMessageSentAt = pending.sentAt;
          }
          _pendingSend = null;
          _scheduleSlowMode();
          _sendTimer?.cancel();
          _historyOnlyIds.remove(id);
          final local = _recentHistory.where((item) => item.id == pending.localId).firstOrNull;
          var moderated = existing?.isDeleted == true ? existing : null;
          if (local?.isDeleted == true &&
              (moderated == null ||
                  local!.moderatedAt?.isAfter(
                        moderated.moderatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                      ) ==
                      true)) {
            moderated = local;
          }
          final confirmed = TwitchChatMessage(
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
            isDeleted: moderated?.isDeleted ?? false,
            moderation: moderated?.moderation,
            timeoutSeconds: moderated?.timeoutSeconds,
            moderatedAt: moderated?.moderatedAt,
            timestamp: local?.timestamp ?? existing?.timestamp ?? DateTime.now(),
            userId: _user!.id,
            parentMessageId: pending.replyTo?.id,
            parentUserId: pending.replyTo?.userId,
            parentLogin: pending.replyTo?.login,
            parentDisplayName: pending.replyTo?.displayName,
            parentText: pending.replyTo?.text,
            parentEmotes: pending.replyTo?.emotes ?? const [],
            parentGifs: pending.replyTo?.gifs ?? const [],
            threadRootId: pending.replyTo?.threadRootId ?? pending.replyTo?.id,
            threadRootLogin: pending.replyTo?.threadRootLogin ?? pending.replyTo?.login,
          );
          for (final history in [_messages, _recentHistory]) {
            if (pendingInHistory) {
              history.removeWhere((item) => item.id == id);
            }
            final index = history.indexWhere((item) => item.id == pending.localId);
            if (index >= 0) {
              history[index] = confirmed;
            }
          }
          _receivedMessageCount++;
          _scheduleNotify();
          pending.result.complete(true);
        }
      case "PRIVMSG":
      case "USERNOTICE":
        final isNotice = message.command == "USERNOTICE";
        final login = isNotice
            ? message.tags["login"].nullIfEmpty ?? ""
            : message.prefix.split("!").first;
        final id = message.tags["id"] ?? "${DateTime.now().microsecondsSinceEpoch}-$login";
        final previous = _recentHistory.where((item) => item.id == id).firstOrNull;
        final historyOnly = _historyOnlyIds.remove(id);
        if (previous != null && !historyOnly) {
          return;
        }
        final isAction =
            message.text.startsWith("\u0001ACTION ") && message.text.endsWith("\u0001");
        final text = isAction ? message.text.substring(8, message.text.length - 1) : message.text;
        final isSubscription =
            isNotice && (message.tags["msg-id"] == "sub" || message.tags["msg-id"] == "resub");
        var noticeText = isNotice ? message.tags["system-msg"].nullIfEmpty : null;
        final prepaidMonths = int.tryParse(message.tags["msg-param-multimonth-duration"] ?? "");
        if (isSubscription &&
            const {"1000", "2000", "3000"}.contains(message.tags["msg-param-sub-plan"]) &&
            prepaidMonths != null &&
            prepaidMonths > 1 &&
            int.tryParse(message.tags["msg-param-multimonth-tenure"] ?? "") == 0) {
          noticeText = noticeText?.replaceFirstMapped(
            RegExp(r"(subscribed at Tier [123])(?=[.!]|$)", caseSensitive: false),
            (match) => "${match[1]} for $prepaidMonths months in advance",
          );
        }
        final parentId = message.tags["reply-parent-msg-id"].nullIfEmpty;
        final parentText = message.tags["reply-parent-msg-body"];
        final parent = parentId == null
            ? null
            : _recentHistory
                  .where((item) => item.id == parentId && item.text == parentText)
                  .firstOrNull;
        var item = TwitchChatMessage(
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
          gifs: _parseGifs(message.tags["gifs"] ?? "", text),
          isAction: isAction,
          isOwn: login.toLowerCase() == _user?.login.toLowerCase(),
          isHistorical: previous?.isHistorical ?? false,
          userId: message.tags["user-id"].nullIfEmpty,
          isFirstMessage: message.tags["first-msg"] == "1",
          isHighlighted: message.tags["msg-id"] == "highlighted-message",
          isPrimeSubscription: isSubscription && message.tags["msg-param-sub-plan"] == "Prime",
          noticeType: !isNotice
              ? null
              : message.tags["msg-id"] == "viewermilestone" &&
                    message.tags["msg-param-category"] == "watch-streak"
              ? "watch-streak"
              : message.tags["msg-id"].nullIfEmpty ?? "notice",
          noticeText: noticeText,
          parentMessageId: parentId,
          parentUserId: message.tags["reply-parent-user-id"].nullIfEmpty,
          parentLogin: message.tags["reply-parent-user-login"].nullIfEmpty,
          parentDisplayName: message.tags["reply-parent-display-name"].nullIfEmpty,
          parentText: parentText,
          parentEmotes:
              parent?.emotes ??
              (previous?.parentText == parentText ? previous?.parentEmotes : null) ??
              const [],
          parentGifs:
              parent?.gifs ??
              (previous?.parentText == parentText ? previous?.parentGifs : null) ??
              const [],
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
        );
        for (final apply
            in _historyModeration ?? <TwitchChatMessage Function(TwitchChatMessage)>[]) {
          item = apply(item);
        }
        if (previous?.isDeleted == true) {
          item = item.copyWith(
            isDeleted: true,
            moderation: previous!.moderation,
            timeoutSeconds: previous.timeoutSeconds,
            moderatedAt: previous.moderatedAt,
          );
        }
        if (item.isOwn &&
            !isNotice &&
            previous?.isHistorical != true &&
            (_lastMessageSentAt == null || item.timestamp!.isAfter(_lastMessageSentAt!))) {
          _lastMessageSentAt = item.timestamp;
          _slowModeRejectedUntil = null;
          _scheduleSlowMode();
        }
        _append(item, countReceived: previous?.isHistorical != true);
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
        bool matches(TwitchChatMessage item) =>
            item.noticeType != "system" &&
            !item.isPrivate &&
            (message.command == "CLEARMSG"
                ? item.id == target
                : moderation == TwitchChatModeration.cleared ||
                      (targetUserId != null && item.userId != null
                          ? item.userId == targetUserId
                          : login.isNotEmpty && item.login.toLowerCase() == login));
        final pendingHistory = _historyModeration;
        if (pendingHistory != null) {
          if (pendingHistory.length >= 5000) {
            _historyModeration = null;
          } else {
            pendingHistory.add((item) {
              if (!matches(item) ||
                  (message.command != "CLEARMSG" && item.timestamp?.isAfter(moderatedAt) == true) ||
                  (item.isDeleted &&
                      moderation != TwitchChatModeration.ban &&
                      moderation != TwitchChatModeration.timeout)) {
                return item;
              }
              return item.copyWith(
                isDeleted: true,
                moderation: moderation,
                timeoutSeconds: timeoutSeconds,
                moderatedAt: moderatedAt,
              );
            });
          }
        }
        var matchedVisibleMessage = false;
        for (final buffer in [_messages, _recentHistory]) {
          for (var index = 0; index < buffer.length; index++) {
            final item = buffer[index];
            if (!matches(item)) {
              continue;
            }
            if (identical(buffer, _messages)) {
              matchedVisibleMessage = true;
            }
            if (!item.isDeleted ||
                moderation == TwitchChatModeration.ban ||
                moderation == TwitchChatModeration.timeout) {
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
        addPrivateNotice(
          id: message.tags["id"] ?? "private-${_systemMessageCount++}",
          type: "notice",
          text: message.text,
        );
        final followersOnlyRejection = (message.tags["msg-id"] ?? "").startsWith(
          "msg_followersonly",
        );
        final subscribersOnlyRejection = message.tags["msg-id"] == "msg_subsonly";
        if (subscribersOnlyRejection) {
          _roomState["subs-only"] = "1";
          _isSubscriber = false;
        }
        if (message.tags["msg-id"] == "msg_slowmode") {
          final seconds = int.tryParse(
            RegExp(r"(\d+) seconds?\b").firstMatch(message.text)?[1] ?? "",
          );
          _slowModeRejectedUntil = DateTime.now().add(
            Duration(seconds: seconds ?? int.tryParse(_roomState["slow"] ?? "") ?? 1),
          );
          _scheduleSlowMode();
        }
        _error = followersOnlyRejection || subscribersOnlyRejection ? null : message.text;
        if ((message.tags["msg-id"] ?? "").startsWith("msg_") ||
            message.tags["msg-id"] == "unrecognized_cmd") {
          _failSend();
        }
        if (followersOnlyRejection || subscribersOnlyRejection) {
          _chatAccess = null;
          unawaited(refreshChatAccess());
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
      _error = !isSignedIn
          ? "Sign in to Twitch to chat."
          : _status != TwitchChatStatus.connected
          ? "Wait for chat to reconnect before sending."
          : null;
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
      final pending = (
        text: text,
        localId: "pending:${now.microsecondsSinceEpoch}",
        sentAt: now,
        replyTo: replyTo,
        result: Completer<bool>(),
      );
      _pendingSend = pending;
      final tag = replyTo == null ? "" : "@reply-parent-msg-id=${replyTo.id} ";
      _socket!.add("${tag}PRIVMSG #$channel :$text\r\n");
      _append(
        TwitchChatMessage(
          id: pending.localId,
          login: _user!.login,
          displayName: _user!.displayName,
          text: text,
          color: _userColor,
          isOwn: true,
          timestamp: now,
          userId: _user!.id,
          parentMessageId: replyTo?.id,
          parentUserId: replyTo?.userId,
          parentLogin: replyTo?.login,
          parentDisplayName: replyTo?.displayName,
          parentText: replyTo?.text,
          parentEmotes: replyTo?.emotes ?? const [],
          parentGifs: replyTo?.gifs ?? const [],
          threadRootId: replyTo?.threadRootId ?? replyTo?.id,
          threadRootLogin: replyTo?.threadRootLogin ?? replyTo?.login,
        ),
        countReceived: false,
      );
      _sentAt.addLast(now);
      _slowModeRejectedUntil = null;
      _scheduleSlowMode();
      _error = null;
      _sendTimer = Timer(const Duration(seconds: 10), () {
        _lost(_generation);
        _error = "Twitch did not confirm delivery. Your draft has been kept.";
        notifyListeners();
      });
      notifyListeners();
      return pending.result.future;
    } on Object {
      _lost(_generation);
      return false;
    }
  }

  void _failSend() {
    _sendTimer?.cancel();
    final pending = _pendingSend;
    if (pending != null) {
      _messages.removeWhere((message) => message.id == pending.localId);
      _recentHistory.removeWhere((message) => message.id == pending.localId);
      pending.result.complete(false);
      _scheduleNotify();
    }
    _pendingSend = null;
    _scheduleSlowMode();
  }

  void _append(TwitchChatMessage message, {bool countReceived = true}) {
    if (countReceived && message.noticeType != "system" && !message.isPrivate) {
      _receivedMessageCount++;
    }
    for (final buffer in [_messages, _recentHistory]) {
      final index = buffer.indexWhere((item) => item.id == message.id && item.isHistorical);
      if (index >= 0) {
        buffer[index] = message;
      } else {
        buffer.add(message);
      }
    }
    if (_messages.length > 300) {
      _messages.removeRange(0, _messages.length - 300);
    }
    if (_recentHistory.length > 5000) {
      for (final evicted in _recentHistory.take(_recentHistory.length - 5000)) {
        _historyOnlyIds.remove(evicted.id);
      }
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
    _historyModeration = null;
    _retryTimer?.cancel();
    _connectTimer?.cancel();
    _joinTimer?.cancel();
    _followerTimer?.cancel();
    _slowModeTimer?.cancel();
    _claimTimer?.cancel();
    _claimTimer = null;
    _privateNotices?.dispose();
    _privateNotices = null;
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

// Twitch supplies inclusive character ranges and requires preserving the full GIF URL.
// https://dev.twitch.tv/docs/chat/irc/#privmsg-tags
List<TwitchChatGif> _parseGifs(String tag, String text) {
  final offsets = <int>[0];
  for (final rune in text.runes) {
    offsets.add(offsets.last + (rune > 0xffff ? 2 : 1));
  }
  final gifs = <TwitchChatGif>[];
  for (final item in tag.split(",")) {
    final match = RegExp(r"^(\d+)-(\d+)\|([^|]+)\|(.+)$").firstMatch(item);
    if (match == null) {
      continue;
    }
    final start = int.tryParse(match[1]!);
    final end = int.tryParse(match[2]!);
    final uri = Uri.tryParse(match[4]!);
    if (start == null ||
        end == null ||
        end < start ||
        end + 1 >= offsets.length ||
        uri == null ||
        uri.scheme != "https" ||
        uri.host.isEmpty) {
      continue;
    }
    gifs.add(
      TwitchChatGif(id: match[3]!, url: match[4]!, start: offsets[start], end: offsets[end + 1]),
    );
  }
  gifs.sort((a, b) => a.start.compareTo(b.start));
  return gifs;
}

extension on String? {
  String? get nullIfEmpty => this == null || this!.isEmpty ? null : this;
}
