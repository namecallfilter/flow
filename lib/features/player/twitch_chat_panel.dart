import "dart:async";
import "dart:math" show Random;
import "dart:ui" show BoxHeightStyle;

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_vod_chat.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/features/player/chat_username.dart";
import "package:flow/features/player/twitch_emote_picker.dart";
import "package:flow/features/player/twitch_report_screen.dart";
import "package:flow/shared/chat_links.dart";
import "package:flow/shared/chat_name_color.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/widgets/scroll_reactive_chrome.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:mobx/mobx.dart" show ReactionDisposer, reaction;

enum _ChatAction { video, refresh, reconnect, chatters, settings }

enum _ChatUserAction { block, report }

enum _ChatMessageAction { copy, paste, reply }

class TwitchChatPanel extends StatefulWidget {
  const TwitchChatPanel({
    required this.chatOnly,
    required this.isLive,
    required this.onToggleChatOnly,
    this.canShowVideo = true,
    this.controller,
    this.replayController,
    this.assets,
    this.preferences,
    this.settingsStore,
    this.onOpenSettings,
    this.onReportUser,
    this.onSubscribe,
    this.onInlineBackHandlerChanged,
    this.topPadding = 0,
    this.latencyMs,
    super.key,
  }) : assert((controller == null) != (replayController == null));

  final TwitchChatController? controller;
  final TwitchVodChatController? replayController;
  final TwitchChatAssets? assets;
  final FlowPreferences? preferences;
  final AppSettingsStore? settingsStore;
  final AsyncCallback? onOpenSettings;
  final Future<void> Function(String login)? onReportUser;
  final AsyncCallback? onSubscribe;
  final ValueChanged<VoidCallback?>? onInlineBackHandlerChanged;
  final bool chatOnly;
  final bool isLive;
  final bool canShowVideo;
  final double topPadding;
  final int? latencyMs;
  final VoidCallback onToggleChatOnly;

  Listenable get _source => controller ?? replayController!;

  @override
  State<TwitchChatPanel> createState() => _TwitchChatPanelState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatController?>("controller", controller));
    properties.add(
      DiagnosticsProperty<TwitchVodChatController?>("replayController", replayController),
    );
    properties.add(DiagnosticsProperty<TwitchChatAssets?>("assets", assets));
    properties.add(DiagnosticsProperty<FlowPreferences?>("preferences", preferences));
    properties.add(DiagnosticsProperty<AppSettingsStore?>("settingsStore", settingsStore));
    properties.add(ObjectFlagProperty<AsyncCallback?>.has("onOpenSettings", onOpenSettings));
    properties.add(ObjectFlagProperty<Object?>.has("onReportUser", onReportUser));
    properties.add(ObjectFlagProperty<Object?>.has("onSubscribe", onSubscribe));
    properties.add(
      ObjectFlagProperty<Object?>.has("onInlineBackHandlerChanged", onInlineBackHandlerChanged),
    );
    properties.add(DoubleProperty("topPadding", topPadding));
    properties.add(IntProperty("latencyMs", latencyMs));
    properties.add(FlagProperty("chatOnly", value: chatOnly, ifTrue: "chat only"));
    properties.add(FlagProperty("isLive", value: isLive, ifTrue: "live"));
    properties.add(FlagProperty("canShowVideo", value: canShowVideo, ifTrue: "can show video"));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onToggleChatOnly", onToggleChatOnly));
  }
}

class _TwitchChatPanelState extends State<TwitchChatPanel> {
  final _draft = TextEditingController();
  final _draftFocus = FocusNode();
  final _scroll = ScrollController();
  final _pinLayoutKey = GlobalKey();
  final _pinBodyKey = GlobalKey();
  final _pinReplyKey = GlobalKey();
  final _composerKey = GlobalKey();
  final _pinnerTap = TapGestureRecognizer();
  final _sheets = <Route<Object?>>{};
  final _blockedLogins = ValueNotifier(<String>{});
  final _knownChatUsers = <String, TwitchChatMessage>{};
  ({Listenable source, String? login, String? userId})? _chattersKey;
  Future<TwitchChatters>? _chattersRequest;
  Map<String, TwitchChatMessage> _rosterUsers = {};
  AppSettingsStore? _settingsStore;
  AppSettingsStore? _fallbackSettingsStore;
  ReactionDisposer? _settingsReaction;
  ChatPreferences _settings = const ChatPreferences();
  bool _following = true;
  bool _followingBeforePointer = false;
  bool _sending = false;
  int _receivedWhenPaused = 0;
  TwitchChatMessage? _replyTo;
  String? _dismissedPinId;
  String? _minimizedPinId;
  String? _autoCollapsePinId;
  Timer? _pinCollapseTimer;
  Timer? _pinProgressTimer;
  double _pinHeight = 0;
  double _composerHeight = 0;
  bool _layoutUpdateQueued = false;
  bool _showEmotes = false;
  bool _autocompleteEmotesLoaded = false;
  bool _composerGateOpen = false;
  String? _rulesKey;
  List<String> _acceptedRules = const [];
  Future<void>? _rulesLoad;
  static const _syncMessageId = "system-chat-sync";
  final _messageReleaseTimes = <String, DateTime>{};
  ({bool automatic, int manualMs, bool enabled})? _delayConfiguration;
  int? _syncedLatencyMs;
  DateTime? _syncDeadline;
  Timer? _delayTimer;
  Timer? _followerHintTimer;
  List<TwitchChatMessage>? _pausedMessages;
  List<TwitchChatMessage> _presentedMessages = [];
  final _seenMentionMessages = <String>{};
  String? _mentionUserId;

  @override
  void initState() {
    super.initState();
    widget._source.addListener(_chatChanged);
    widget.assets?.addListener(_chatChanged);
    _draft.addListener(_draftChanged);
    _draftFocus.addListener(_composerFocusChanged);
    _scroll.addListener(_scrolled);
    _resetMentionAlerts();
    _scrollToLatest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindSettings();
  }

  @override
  void didUpdateWidget(TwitchChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsStore != widget.settingsStore) {
      _bindSettings();
    }
    if (oldWidget._source != widget._source) {
      oldWidget.controller?.setAutoClaimChannelPoints(enabled: false);
      _closeSheets();
      oldWidget._source.removeListener(_chatChanged);
      widget._source.addListener(_chatChanged);
      _resetMentionAlerts();
      _draft.clear();
      _sending = false;
      _following = true;
      _pausedMessages = null;
      _replyTo = null;
      _knownChatUsers.clear();
      _dismissedPinId = null;
      _minimizedPinId = null;
      _autoCollapsePinId = null;
      _pinCollapseTimer?.cancel();
      _pinHeight = 0;
      _showEmotes = false;
      widget.onInlineBackHandlerChanged?.call(null);
      _rulesKey = null;
      _acceptedRules = const [];
      _rulesLoad = null;
      _messageReleaseTimes.clear();
      _delayConfiguration = null;
      _syncedLatencyMs = null;
      _syncDeadline = null;
      _delayTimer?.cancel();
      _scrollToLatest();
    }
    if (oldWidget.assets != widget.assets) {
      oldWidget.assets?.removeListener(_chatChanged);
      widget.assets?.addListener(_chatChanged);
      _autocompleteEmotesLoaded = false;
    }
    widget.controller?.setAutoClaimChannelPoints(
      enabled: widget.isLive && _settings.autoClaimChannelPoints,
    );
  }

  @override
  void dispose() {
    widget.onInlineBackHandlerChanged?.call(null);
    _settingsReaction?.call();
    widget._source.removeListener(_chatChanged);
    widget.assets?.removeListener(_chatChanged);
    _draft.dispose();
    _draftFocus.dispose();
    _pinnerTap.dispose();
    _delayTimer?.cancel();
    _followerHintTimer?.cancel();
    _pinCollapseTimer?.cancel();
    _scroll.dispose();
    _pinProgressTimer?.cancel();
    _closeSheets();
    _blockedLogins.dispose();
    super.dispose();
  }

  void _closeSheets() {
    final sheets = _sheets.toList().reversed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final sheet in sheets) {
        if (sheet.isActive) {
          sheet.navigator?.removeRoute(sheet);
        }
      }
    });
  }

  Future<T?> _showSheet<T>({required WidgetBuilder builder}) async {
    ModalRoute<Object?>? route;
    try {
      final result = await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          route = ModalRoute.of<Object?>(context);
          if (route != null) {
            _sheets.add(route!);
          }
          return ValueListenableBuilder(
            valueListenable: _blockedLogins,
            builder: (context, blocked, child) => builder(context),
          );
        },
      );
      await route?.completed;
      return result;
    } finally {
      _sheets.remove(route);
    }
  }

  void _bindSettings() {
    final store =
        widget.settingsStore ??
        AppSettingsScope.maybeOf(context) ??
        (_fallbackSettingsStore ??= AppSettingsStore(
          preferences: widget.preferences ?? SharedPreferencesFlowPreferences(),
        ));
    if (store == _settingsStore) {
      return;
    }
    _settingsReaction?.call();
    _settingsStore = store;
    _settings = store.chatPreferences;
    widget.controller?.setAutoClaimChannelPoints(
      enabled: widget.isLive && _settings.autoClaimChannelPoints,
    );
    _settingsReaction = reaction<ChatPreferences>(
      (_) => store.chatPreferences,
      (settings) {
        setState(() => _settings = settings);
        widget.controller?.setAutoClaimChannelPoints(
          enabled: widget.isLive && settings.autoClaimChannelPoints,
        );
      },
    );
    if (!store.isLoaded) {
      unawaited(_loadSettings(store));
    }
  }

  Future<void> _loadSettings(AppSettingsStore store) async {
    try {
      await store.load();
    } on Object catch (error) {
      debugPrint("Could not load chat settings: $error");
    }
  }

  void _chatChanged() {
    setState(() {});
    if (_following) {
      _scrollToLatest();
    }
  }

  void _resetMentionAlerts() {
    _mentionUserId = widget.controller?.currentUserId;
    _seenMentionMessages
      ..clear()
      ..addAll(widget.controller?.recentHistory.map((message) => message.id) ?? const []);
  }

  void _notifyMentions(List<TwitchChatMessage> messages, Set<String> retainedIds) {
    if (_mentionUserId != widget.controller?.currentUserId) {
      _resetMentionAlerts();
    }
    _seenMentionMessages.retainAll(retainedIds);
    var alert = false;
    for (final message in messages) {
      if (_seenMentionMessages.add(message.id) &&
          !message.isHistorical &&
          !_blockedLogins.value.contains(message.login.toLowerCase()) &&
          _mentionsViewer(message, widget.controller)) {
        alert = true;
      }
    }
    if (!alert || !widget.isLive || !_settings.mentionSounds || _settingsStore?.isLoaded != true) {
      return;
    }
    final source = widget._source;
    final userId = _mentionUserId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          widget._source != source ||
          widget.controller?.currentUserId != userId ||
          !_settings.mentionSounds) {
        return;
      }
      try {
        await const MethodChannel("flow/chat_notifications").invokeMethod<void>("mention");
      } on MissingPluginException {
        // Notification sounds are provided by the Android host.
      } on PlatformException catch (error) {
        debugPrint("Could not play mention sound: $error");
      }
    });
  }

  void _scrolled() {
    final following = _scroll.position.extentBefore < 1;
    if (_following != following) {
      setState(() {
        _following = following;
        _pausedMessages = following ? null : List.of(_presentedMessages);
        _receivedWhenPaused = widget.controller?.receivedMessageCount ?? 0;
      });
    }
  }

  List<TwitchChatMessage> _messagesForDisplay() {
    final now = DateTime.now();
    final configuration = (
      automatic: _settings.autoSyncChat,
      manualMs: _settings.autoSyncChat ? 0 : (_settings.manualChatDelaySeconds * 1000).round(),
      enabled: widget.controller != null && !widget.chatOnly && widget.isLive,
    );
    if (_delayConfiguration != configuration) {
      if (_delayConfiguration?.automatic != configuration.automatic ||
          _delayConfiguration?.enabled != configuration.enabled) {
        _syncedLatencyMs = null;
      }
      _delayConfiguration = configuration;
      _messageReleaseTimes.removeWhere((_, releaseAt) => releaseAt.isAfter(now));
      _syncDeadline = null;
    }
    final latency = widget.latencyMs;
    if (latency != null) {
      _syncedLatencyMs = latency;
    }
    final delay = Duration(
      milliseconds: !configuration.enabled
          ? 0
          : configuration.automatic
          ? _syncedLatencyMs ?? 0
          : configuration.manualMs,
    );
    if (delay <= Duration.zero) {
      _messageReleaseTimes.removeWhere((_, releaseAt) => releaseAt.isAfter(now));
    }
    final source = widget.controller?.recentHistory ?? widget.replayController!.messages;
    var lastVisibleRelease = _messageReleaseTimes[_presentedMessages.lastOrNull?.id];
    final ownReleases = {
      for (final message in _presentedMessages)
        if (message.isOwn && !message.isHistorical && message.timestamp != null)
          message.timestamp!: _messageReleaseTimes[message.id],
    };
    final retainedIds = source.map((message) => message.id).toSet();
    _messageReleaseTimes.removeWhere((id, _) => !retainedIds.contains(id));
    Duration? nextUpdate;
    DateTime? previousRelease;
    final ready = source.where((message) {
      final immediate =
          message.isOwn ||
          message.isHistorical ||
          message.isPrivate ||
          message.noticeType == "system";
      final bypass = immediate || message.timestamp == null || delay <= Duration.zero;
      if (message.isOwn && !message.isHistorical && ownReleases[message.timestamp] != null) {
        _messageReleaseTimes[message.id] = ownReleases[message.timestamp]!;
      }
      final releaseAt = _messageReleaseTimes.putIfAbsent(message.id, () {
        if (!message.isHistorical &&
            (message.isOwn || message.isPrivate || message.noticeType == "system")) {
          // Local rows keep their display position independently of server clocks.
          return lastVisibleRelease ?? DateTime.fromMillisecondsSinceEpoch(0);
        }
        final timestamp = message.timestamp == null || message.timestamp!.isAfter(now)
            ? now
            : message.timestamp!;
        final target = bypass ? timestamp : timestamp.add(delay);
        return !immediate && previousRelease != null && previousRelease!.isAfter(target)
            ? previousRelease!
            : target;
      });
      if (!immediate && (previousRelease == null || releaseAt.isAfter(previousRelease!))) {
        previousRelease = releaseAt;
      }
      final remaining = releaseAt.difference(now);
      if (bypass || remaining <= Duration.zero) {
        if (lastVisibleRelease == null || releaseAt.isAfter(lastVisibleRelease!)) {
          lastVisibleRelease = releaseAt;
        }
        return true;
      }
      if (nextUpdate == null || remaining < nextUpdate!) {
        nextUpdate = remaining;
      }
      return false;
    }).toList();
    if (_syncDeadline == null &&
        nextUpdate != null &&
        widget.controller?.status == TwitchChatStatus.connected) {
      _syncDeadline = now.add(nextUpdate!);
    }
    final syncing = _syncDeadline?.isAfter(now) == true && delay > Duration.zero;
    if (syncing) {
      final remaining = _syncDeadline!.difference(now);
      final tick = remaining < const Duration(seconds: 1) ? remaining : const Duration(seconds: 1);
      if (nextUpdate == null || tick < nextUpdate!) {
        nextUpdate = tick;
      }
    }
    ready.removeWhere((message) => message.id == _syncMessageId && !syncing);
    final sourceOrder = {for (final (index, message) in source.indexed) message.id: index};
    ready.sort((a, b) {
      final releaseOrder = _messageReleaseTimes[a.id]!.compareTo(_messageReleaseTimes[b.id]!);
      return releaseOrder != 0 ? releaseOrder : sourceOrder[a.id]!.compareTo(sourceOrder[b.id]!);
    });
    final messages = ready.length > 300 ? ready.sublist(ready.length - 300) : ready;
    _notifyMentions(ready, retainedIds);
    _delayTimer?.cancel();
    if (nextUpdate != null) {
      _delayTimer = Timer(nextUpdate!, _chatChanged);
    }
    final paused = _pausedMessages?.where(
      (message) =>
          (!message.isPrivate && !message.id.startsWith("pending:")) ||
          retainedIds.contains(message.id),
    );
    final byId = {
      for (final message in widget.controller?.recentHistory ?? source) message.id: message,
    };
    _presentedMessages =
        (paused == null ? messages : paused.map((message) => byId[message.id] ?? message)).where((
          message,
        ) {
          if (message.id == _syncMessageId && !syncing) {
            return false;
          }
          if (!_showMessage(message, _settings, _blockedLogins.value)) {
            return false;
          }
          if (message.isPrivate && message.noticeType == "watch-streak") {
            return false;
          }
          if (message.isPrivate) {
            return true;
          }
          return switch (message.noticeType) {
            "moderation" => _settings.showModerationNotices,
            "system" => true,
            "announcement" => _settings.showAnnouncements,
            "raid" => _settings.showRaidNotices,
            null => true,
            _ => _settings.showSubscriptionNotices,
          };
        }).toList();
    return _presentedMessages;
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _following &&
          _scroll.hasClients &&
          _scroll.position.pixels != _scroll.position.minScrollExtent) {
        _scroll.jumpTo(_scroll.position.minScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final controller = widget.controller;
    final text = _draft.text;
    if (controller == null || _sending || !controller.canSend || text.trim().isEmpty) {
      return;
    }
    if (!await _ensureCanCompose() || !mounted || controller != widget.controller) {
      return;
    }
    final draft = _draft.value;
    final replyTo = _replyTo;
    setState(() {
      _sending = true;
      _draft.clear();
      _replyTo = null;
      _following = true;
      _pausedMessages = null;
    });
    try {
      final sent = await controller.send(text, replyTo: replyTo);
      if (mounted && controller == widget.controller && !sent && _draft.text.isEmpty) {
        _draft.value = draft;
        _replyTo = replyTo;
      }
    } finally {
      if (mounted && controller == widget.controller) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _openMenu() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final room = widget.controller?.roomState ?? const <String, String>{};
    final followers = int.tryParse(room["followers-only"] ?? "") ?? -1;
    final slow = int.tryParse(room["slow"] ?? "") ?? 0;
    final restrictions = [
      if (followers >= 0) followers == 0 ? "Followers only" : "Followers · ${followers}m",
      if (slow > 0) "Slow mode · ${slow}s",
      if (room["subs-only"] == "1") "Subscribers only",
      if (room["emote-only"] == "1") "Emotes only",
      if (room["r9k"] == "1") "Unique chat",
    ];
    final action = await _showSheet<_ChatAction>(
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (restrictions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final restriction in restrictions) Chip(label: Text(restriction)),
                    ],
                  ),
                ),
              ListTile(
                key: const ValueKey("chat_only_toggle"),
                leading: Icon(
                  widget.chatOnly ? Icons.monitor : Icons.chat,
                ),
                title: Text(widget.chatOnly ? "Show video" : "Chat only"),
                enabled: !widget.chatOnly || widget.canShowVideo,
                onTap: widget.chatOnly && !widget.canShowVideo
                    ? null
                    : () => Navigator.pop(context, _ChatAction.video),
              ),
              ListTile(
                leading: const Icon(Icons.cached_rounded),
                title: const Text("Refresh emotes and badges"),
                enabled: widget.assets != null,
                onTap: () => Navigator.pop(context, _ChatAction.refresh),
              ),
              ListTile(
                key: const ValueKey("chat_reconnect"),
                leading: const Icon(Icons.refresh_rounded),
                title: const Text("Reconnect"),
                onTap: () => Navigator.pop(context, _ChatAction.reconnect),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline_rounded),
                title: const Text("Chatters"),
                onTap: () => Navigator.pop(context, _ChatAction.chatters),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text("Settings"),
                onTap: () => Navigator.pop(context, _ChatAction.settings),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case _ChatAction.video:
        widget.onToggleChatOnly();
      case _ChatAction.refresh:
        await widget.assets?.refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.assets?.errors.isEmpty == true
                    ? "Emotes and badges refreshed"
                    : "Some emotes or badges could not be refreshed",
              ),
            ),
          );
        }
      case _ChatAction.reconnect:
        (widget.controller?.reconnect ?? widget.replayController!.reconnect)();
      case _ChatAction.chatters:
        await _showChatters();
      case _ChatAction.settings:
        await _showSettings();
      case null:
        return;
    }
  }

  void _checkChattersScope() {
    final key = (
      source: widget._source,
      login: widget.controller?.channel ?? widget.assets?.channelLogin,
      userId: widget.controller?.currentUserId,
    );
    if (_chattersKey != key) {
      _chattersKey = key;
      _chattersRequest = null;
      _rosterUsers = {};
    }
  }

  Future<TwitchChatters> _loadChatters({bool refresh = false}) {
    _checkChattersScope();
    if (!refresh && _chattersRequest != null) {
      return _chattersRequest!;
    }
    final key = _chattersKey!;
    final loader = widget.controller?.clientLoader ?? widget.replayController!.clientLoader;
    final request = _chattersRequest = loader().then((client) => client.fetchChatters(key.login!));
    unawaited(
      request.then<void>(
        (result) {
          if (!mounted) {
            return;
          }
          _checkChattersScope();
          if (_chattersKey == key && _chattersRequest == request) {
            setState(() {
              _rosterUsers = {
                for (final login in result.groups.values.expand((names) => names))
                  login.toLowerCase(): TwitchChatMessage(
                    id: "",
                    login: login,
                    displayName: login,
                    text: "",
                  ),
              };
            });
          }
        },
        onError: (Object error, StackTrace stack) {
          if (_chattersRequest == request) {
            _chattersRequest = null;
          }
        },
      ),
    );
    return request;
  }

  Future<void> _showChatters() async {
    _checkChattersScope();
    if (_chattersKey!.login == null) {
      return;
    }
    var chatters = _loadChatters();
    var query = "";
    await _showSheet<void>(
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.65).clamp(
              0.0,
              MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) => FutureBuilder<TwitchChatters>(
                future: chatters,
                builder: (context, snapshot) {
                  final result = snapshot.data;
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Could not load chatters"),
                          TextButton(
                            onPressed: () => setSheetState(() {
                              chatters = _loadChatters(refresh: true);
                            }),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    );
                  }
                  if (result == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final groups = {
                    for (final group in result.groups.entries)
                      group.key: group.value
                          .where((login) => login.toLowerCase().contains(query))
                          .toList(),
                  };
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Chatters · ${result.count}",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: "Refresh chatters",
                              onPressed: () => setSheetState(() {
                                chatters = _loadChatters(refresh: true);
                              }),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        if (result.isPartial)
                          Text(
                            "Showing ${result.listedCount} names returned by Twitch",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        TextField(
                          key: const ValueKey("chatters_search"),
                          decoration: const InputDecoration(
                            hintText: "Search chatters",
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) =>
                              setSheetState(() => query = value.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: groups.values.every((names) => names.isEmpty)
                              ? const Center(child: Text("No chatters found"))
                              : CustomScrollView(
                                  slivers: [
                                    for (final group in groups.entries)
                                      if (group.value.isNotEmpty) ...[
                                        SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                                            child: Text(
                                              switch (group.key) {
                                                "broadcasters" => "Broadcasters",
                                                "moderators" => "Moderators",
                                                "vips" => "VIPs",
                                                "staff" => "Staff",
                                                "chatbots" => "Chatbots",
                                                "viewers" => "Viewers",
                                                _ => group.key,
                                              },
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                          ),
                                        ),
                                        SliverList.builder(
                                          itemCount: group.value.length,
                                          itemBuilder: (context, index) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            child: Text(group.value[index]),
                                          ),
                                        ),
                                      ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    await widget.onOpenSettings?.call();
  }

  FlowPreferences get _preferences => widget.preferences ?? _settingsStore!.preferences;

  String? get _currentRulesKey {
    final controller = widget.controller;
    final channelId = controller?.chatAccess?.channelId;
    final userId = controller?.currentUserId;
    return channelId == null || userId == null ? null : "$userId:$channelId";
  }

  bool get _rulesAccepted {
    final rules = widget.controller?.chatAccess?.rules;
    return rules != null &&
        (rules.isEmpty || (_rulesKey == _currentRulesKey && _acceptedRules.isNotEmpty));
  }

  bool get _canCompose => widget.controller?.canSend == true && _rulesAccepted;

  Future<void> _loadRulesAcceptance() {
    final key = _currentRulesKey;
    if (key == null || key == _rulesKey) {
      return _rulesLoad ?? Future.value();
    }
    _rulesKey = key;
    _acceptedRules = const [];
    return _rulesLoad = _preferences
        .readAcceptedChatRules(key)
        .then((rules) {
          if (mounted && _rulesKey == key) {
            setState(() => _acceptedRules = rules);
          }
        })
        .catchError((Object error) {
          debugPrint("Could not read accepted chat rules: $error");
        });
  }

  Future<bool> _ensureCanCompose() async {
    final controller = widget.controller;
    if (controller == null ||
        !controller.isSignedIn ||
        controller.status != TwitchChatStatus.connected) {
      return false;
    }
    if (_canCompose) {
      return true;
    }
    if (_composerGateOpen) {
      return false;
    }
    _composerGateOpen = true;
    _draftFocus.unfocus();
    try {
      if (controller.chatAccess == null) {
        await controller.refreshChatAccess();
      }
      if (!mounted || controller != widget.controller) {
        return false;
      }
      if (controller.chatAccess == null) {
        await _showSheet<void>(
          builder: (context) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Chat access", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(controller.chatAccessError ?? "Checking chat rules and follower status…"),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: controller.isCheckingChatAccess
                          ? null
                          : () async {
                              await controller.refreshChatAccess();
                              if (context.mounted && controller.chatAccess != null) {
                                Navigator.pop(context);
                              }
                            },
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (!mounted || controller != widget.controller || controller.chatAccess == null) {
        return false;
      }
      if (!controller.subscriberChatEligible) {
        await _showSubscriberGate(controller);
      }
      if (!mounted || controller != widget.controller || !controller.subscriberChatEligible) {
        return false;
      }
      if (!controller.followerChatEligible) {
        await _showFollowerGate(controller);
      }
      if (!mounted || controller != widget.controller || !controller.canSend) {
        return false;
      }
      await _loadRulesAcceptance();
      if (!mounted ||
          controller != widget.controller ||
          !controller.canSend ||
          controller.chatAccess == null) {
        return false;
      }
      if (!_rulesAccepted) {
        final access = controller.chatAccess!;
        final rulesKey = _currentRulesKey;
        final accepted = await _showSheet<bool>(
          builder: (context) => SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text("Chat Rules", style: Theme.of(context).textTheme.titleLarge),
                        ),
                        IconButton(
                          tooltip: "Close rules",
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (index, rule) in access.rules.indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text("${index + 1}. $rule"),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Okay, Got It!"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (accepted != true ||
            !mounted ||
            controller != widget.controller ||
            rulesKey != _currentRulesKey ||
            !listEquals(access.rules, controller.chatAccess?.rules)) {
          return false;
        }
        setState(() => _acceptedRules = List.of(access.rules));
        if (rulesKey case final key?) {
          unawaited(
            _preferences.saveAcceptedChatRules(key, access.rules).catchError((Object error) {
              debugPrint("Could not save accepted chat rules: $error");
            }),
          );
        }
      }
      return _canCompose;
    } finally {
      _composerGateOpen = false;
    }
  }

  Future<void> _showSubscriberGate(TwitchChatController controller) async {
    final subscribe = await _showSheet<bool>(
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (controller.subscriberChatEligible) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
                    Navigator.pop(context);
                  }
                });
              }
              final channel = controller.chatAccess?.channelDisplayName ?? controller.channel;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Subscriber-Only Chat", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text("Only $channel's subscribers can chat right now. Subscribe to join in."),
                  if (controller.chatAccessError case final error?) ...[
                    const SizedBox(height: 8),
                    Text(error),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: controller.isCheckingChatAccess
                        ? null
                        : () => Navigator.pop(context, true),
                    icon: const Icon(Icons.star_border_rounded),
                    label: const Text("Subscribe"),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (subscribe != true || !mounted || controller != widget.controller) {
      return;
    }
    if (widget.onSubscribe case final open?) {
      await open();
    } else {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TwitchReportScreen.subscribe(login: controller.channel),
        ),
      );
    }
    if (mounted && controller == widget.controller) {
      await controller.refreshChatAccess();
    }
  }

  Future<void> _showFollowerGate(TwitchChatController controller) {
    final seconds = Stream<void>.periodic(const Duration(seconds: 1));

    return _showSheet<void>(
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: StreamBuilder<void>(
            stream: seconds,
            builder: (context, _) => AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final access = controller.chatAccess;
                final channel = access?.channelDisplayName ?? controller.channel;
                final wait = controller.followingWaitRemaining;
                final following = access?.isFollowing == true;
                final minimum = Duration(
                  minutes: controller.followersOnlyMinutes,
                );
                if (following && controller.followerChatEligible) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
                      Navigator.pop(context);
                    }
                  });
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Followers-Only Chat", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(
                      following
                          ? "You need to be a follower for ${_chatDuration(minimum)} to chat, and you have ${_chatDuration(wait)} left."
                          : minimum > Duration.zero
                          ? "You need to be a follower of $channel for ${_chatDuration(minimum)} to chat."
                          : "You need to be a follower of $channel to chat.",
                    ),
                    if (controller.chatAccessError case final error?) ...[
                      const SizedBox(height: 8),
                      Text(error),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: controller.isFollowingChannel || controller.isCheckingChatAccess
                          ? null
                          : () async {
                              if (following) {
                                await controller.unfollowChannel();
                              } else {
                                await controller.followChannel();
                              }
                              if (context.mounted && controller.followerChatEligible) {
                                Navigator.pop(context);
                              }
                            },
                      icon: Icon(
                        following ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      ),
                      label: Text(
                        controller.isFollowingChannel
                            ? following
                                  ? "Unfollowing…"
                                  : "Following…"
                            : following
                            ? "Unfollow"
                            : "Follow",
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _focusComposer() async {
    _draftFocus.unfocus();
    if (await _ensureCanCompose() && mounted) {
      _setShowEmotes(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _draftFocus.requestFocus();
        }
      });
    }
  }

  Future<void> _toggleEmotes() async {
    if (_showEmotes) {
      await _focusComposer();
      return;
    }
    if (await _ensureCanCompose() && mounted) {
      _draftFocus.unfocus();
      _setShowEmotes(true);
      _scrollToLatest();
    }
  }

  void _setShowEmotes(bool show) {
    setState(() => _showEmotes = show);
    widget.onInlineBackHandlerChanged?.call(show ? () => _setShowEmotes(false) : null);
  }

  void _composerFocusChanged() {
    if (_draftFocus.hasFocus && widget.assets?.unlockedError != null) {
      _autocompleteEmotesLoaded = false;
    }
    _draftChanged();
  }

  void _draftChanged() {
    setState(() {});
    final value = _draft.value;
    if (_draftFocus.hasFocus &&
        _canCompose &&
        value.selection.isValid &&
        value.selection.isCollapsed &&
        RegExp(
          r"(?:^|\s)@[^\s:@]*$",
        ).hasMatch(value.text.substring(0, value.selection.extentOffset))) {
      unawaited(_loadChatters());
    }
    if (_draftFocus.hasFocus &&
        _canCompose &&
        _settings.emoteAutocomplete &&
        !_autocompleteEmotesLoaded &&
        widget.assets != null) {
      _autocompleteEmotesLoaded = true;
      unawaited(widget.assets!.loadUnlockedEmotes());
    }
  }

  ({TextSelection selection, List<ChatAssetEmote> emotes, List<TwitchChatMessage> users})?
  get _chatCompletion {
    final value = _draft.value;
    if (!_draftFocus.hasFocus ||
        !_canCompose ||
        _showEmotes ||
        !value.selection.isValid ||
        !value.selection.isCollapsed) {
      return null;
    }
    final cursor = value.selection.extentOffset;
    final match = RegExp(
      r"(?:^|\s)(@([^\s:@]*)|:?([^\s:@]{2,}))$",
    ).firstMatch(value.text.substring(0, cursor));
    if (match == null) {
      return null;
    }
    final mention = match.group(2) != null;
    if (!mention && !_settings.emoteAutocomplete) {
      return null;
    }
    final query = (match.group(2) ?? match.group(3))!.toLowerCase();
    int rank(String name) => name == query
        ? 0
        : name.startsWith(query)
        ? 1
        : 2;
    int compareNames(String a, String b) {
      final first = a.toLowerCase();
      final second = b.toLowerCase();
      final priority = rank(first).compareTo(rank(second));
      if (priority != 0) {
        return priority;
      }
      final alphabetical = first.compareTo(second);
      return alphabetical == 0 ? a.compareTo(b) : alphabetical;
    }

    final users = mention
        ? (_completionUsers
              .where(
                (user) =>
                    user.login.toLowerCase().contains(query) ||
                    user.displayName.toLowerCase().contains(query),
              )
              .toList()
            ..sort((a, b) => compareNames(a.login, b.login)))
        : <TwitchChatMessage>[];
    final emotes =
        mention
              ? <ChatAssetEmote>[]
              : (widget.assets?.emotesByName.values ?? <ChatAssetEmote>[]).where((emote) {
                  final enabled = switch (emote.provider) {
                    ChatEmoteProvider.twitch => _settings.twitchEmotes,
                    ChatEmoteProvider.sevenTv => _settings.sevenTvEmotes,
                    ChatEmoteProvider.bttv => _settings.bttvEmotes,
                    ChatEmoteProvider.ffz => _settings.ffzEmotes,
                  };
                  return enabled && emote.name.toLowerCase().contains(query);
                }).toList()
          ..sort((a, b) => compareNames(a.name, b.name));
    if (emotes.isEmpty && users.isEmpty) {
      return null;
    }
    final suffix = RegExp(r"^\S*").stringMatch(value.text.substring(cursor))!;
    final end = cursor + suffix.length;
    return (
      selection: TextSelection(
        baseOffset: cursor - match.group(1)!.length,
        extentOffset: end < value.text.length && value.text[end] == " " ? end + 1 : end,
      ),
      emotes: emotes.take(20).toList(),
      users: users.take(20).toList(),
    );
  }

  void _insertCompletion(String token, {TextSelection? replacement}) {
    if (!_canCompose) {
      return;
    }
    final value = _draft.value;
    final selection = replacement ?? value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final prefix = start > 0 && !RegExp(r"\s").hasMatch(value.text[start - 1]) ? " " : "";
    final text = "$prefix$token ";
    final updated = value.text.replaceRange(start, end, text);
    if (updated.length > 500) {
      return;
    }
    setState(
      () => _draft.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: start + text.length),
      ),
    );
  }

  List<TwitchChatMessage> get _history =>
      widget.controller?.recentHistory ?? widget.replayController!.messages;

  Map<String, TwitchChatMessage> get _knownUsers {
    final broadcaster = widget.assets?.broadcaster;
    if (broadcaster != null) {
      _rememberUsers([
        TwitchChatMessage(
          id: "broadcaster:${broadcaster.id}",
          login: broadcaster.login,
          displayName: broadcaster.displayName,
          userId: broadcaster.id,
          color: broadcaster.chatColor,
          text: "",
          isOwn: broadcaster.id == widget.controller?.currentUserId,
        ),
      ], historical: true);
    }
    _rememberUsers(_history);
    return _knownChatUsers;
  }

  Iterable<TwitchChatMessage> get _completionUsers sync* {
    _checkChattersScope();
    final known = _knownUsers;
    yield* known.values;
    yield* _rosterUsers.entries
        .where((entry) => !known.containsKey(entry.key))
        .map((entry) => entry.value);
  }

  void _rememberUsers(Iterable<TwitchChatMessage> messages, {bool historical = false}) {
    for (final message in messages) {
      final login = message.login.toLowerCase();
      if (login.isEmpty) {
        continue;
      }
      final known = _knownChatUsers[login];
      if (known == null ||
          (message.color?.isNotEmpty == true && (!historical || known.color == null))) {
        _knownChatUsers[login] = message;
      }
    }
    while (_knownChatUsers.length > 5000) {
      _knownChatUsers.remove(_knownChatUsers.keys.first);
    }
  }

  void _reply(TwitchChatMessage message) {
    if (_blockedLogins.value.contains(message.login.toLowerCase())) {
      return;
    }
    setState(() {
      _replyTo = message.text.isEmpty ? null : message;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_focusComposer());
      }
    });
  }

  Future<void> _showMessageActions(TwitchChatMessage message) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final source = widget._source;
    final action = await _showSheet<_ChatMessageAction>(
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChatMessageRow(
                key: const ValueKey("chat_message_preview"),
                message: message,
                isMention: _mentionsViewer(message, widget._source),
                settings: _settings,
                assets: widget.assets,
                knownUsers: _knownUsers,
                blockedLogins: _blockedLogins.value,
                onUserTap: (message) => unawaited(_showUser(message)),
                onEmoteTap: (emote) => unawaited(_showEmote(emote)),
                onBadgeTap: (badge) => unawaited(_showBadge(badge)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text("Copy message"),
                onTap: () => Navigator.pop(context, _ChatMessageAction.copy),
              ),
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: const Text("Copy message and paste"),
                enabled: widget.controller != null,
                onTap: () => Navigator.pop(context, _ChatMessageAction.paste),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text("Reply to message"),
                enabled:
                    widget.controller != null &&
                    message.login.isNotEmpty &&
                    !message.id.startsWith("pending:"),
                onTap: () => Navigator.pop(context, _ChatMessageAction.reply),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null ||
        !mounted ||
        source != widget._source ||
        _blockedLogins.value.contains(message.login.toLowerCase())) {
      return;
    }
    if (action == _ChatMessageAction.reply) {
      _closeSheets();
      _reply(message);
      return;
    }
    final text = message.text.isEmpty ? message.noticeText ?? "" : message.text;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted || source != widget._source) {
      return;
    }
    if (action == _ChatMessageAction.copy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message copied")));
      return;
    }
    _closeSheets();
    final value = _draft.value;
    final start = value.selection.isValid ? value.selection.start : value.text.length;
    final end = value.selection.isValid ? value.selection.end : value.text.length;
    setState(() {
      _draft.value = value.copyWith(
        text: value.text.replaceRange(start, end, text),
        selection: TextSelection.collapsed(offset: start + text.length),
        composing: TextRange.empty,
      );
    });
    unawaited(_focusComposer());
  }

  Future<void> _showThread(TwitchChatMessage message, {bool pinned = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final source = widget._source;
    final loader = widget.controller?.clientLoader ?? widget.replayController!.clientLoader;
    await _showSheet<void>(
      builder: (context) => _ChatThreadSheet(
        message: message,
        title: pinned ? "Pinned message" : "Reply thread",
        source: widget._source,
        messages: () => _history,
        knownUsers: () => _knownUsers,
        blockedLogins: _blockedLogins.value,
        loadHistory: () async {
          final history = await (await loader()).fetchChatReplyThread(
            message.threadRootId ?? message.parentMessageId ?? message.id,
          );
          if (mounted && widget._source == source) {
            setState(() => _rememberUsers(history, historical: true));
          }
          return history;
        },
        settings: () => _settings,
        assets: widget.assets,
        onUserTap: (message) => unawaited(_showUser(message)),
        onEmoteTap: (emote) => unawaited(_showEmote(emote)),
        onBadgeTap: (badge) => unawaited(_showBadge(badge)),
        onMessageHold: (message) => unawaited(_showMessageActions(message)),
      ),
    );
  }

  Future<void> _showUser(TwitchChatMessage message) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = widget.controller;
    final loader = controller?.clientLoader ?? widget.replayController!.clientLoader;
    final source = widget._source;
    Future<TwitchUser?> loadUser() async {
      final user = await (await loader()).fetchChatUser(
        userId: message.userId,
        login: message.login,
        channelId: controller?.chatAccess?.channelId ?? widget.assets?.channelId,
        channelLogin: controller?.channel ?? widget.assets?.channelLogin,
      );
      if (mounted && widget._source == source && user != null) {
        setState(
          () => _rememberUsers([
            TwitchChatMessage(
              id: "profile-${user.id}",
              userId: user.id,
              login: user.login,
              displayName: user.displayName,
              color: user.chatColor,
              text: "",
            ),
          ], historical: true),
        );
      }
      return user;
    }

    final profile = loadUser().onError((Object error, StackTrace stackTrace) => null);
    await _showSheet<void>(
      builder: (context) => _ChatUserSheet(
        message: message,
        profile: profile,
        source: widget._source,
        messages: () => controller?.recentHistory ?? widget.replayController!.messages,
        knownUsers: () => _knownUsers,
        blockedLogins: _blockedLogins.value,
        settings: () => _settings,
        assets: widget.assets,
        onEmoteTap: (emote) => unawaited(_showEmote(emote)),
        onBadgeTap: (badge) => unawaited(_showBadge(badge)),
        onUserTap: (message) => unawaited(_showUser(message)),
        onThreadTap: (message) => unawaited(_showThread(message)),
        onMessageHold: (message) => unawaited(_showMessageActions(message)),
        onMore: () => unawaited(_userActions(message, profile)),
        onReply: controller == null || message.id.startsWith("pending:")
            ? null
            : () {
                _closeSheets();
                _reply(message);
              },
      ),
    );
  }

  Future<void> _userActions(TwitchChatMessage message, Future<TwitchUser?> profile) async {
    final source = widget._source;
    final controller = widget.controller;
    final userId = controller?.currentUserId;
    final loader = controller?.clientLoader ?? widget.replayController!.clientLoader;
    bool isCurrent() => mounted && widget._source == source && controller?.currentUserId == userId;
    final action = await _showSheet<_ChatUserAction>(
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text("Report ${message.displayName}"),
              onTap: () => Navigator.pop(context, _ChatUserAction.report),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: Text("Block ${message.displayName}"),
              onTap: () => Navigator.pop(context, _ChatUserAction.block),
            ),
          ],
        ),
      ),
    );
    if (action == null || !isCurrent()) {
      return;
    }
    if (action == _ChatUserAction.report) {
      try {
        final report = widget.onReportUser;
        if (report == null) {
          throw const FormatException("Reporting is unavailable here.");
        }
        await report(message.login);
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
      return;
    }
    final TwitchApiClient originalClient;
    try {
      originalClient = await loader();
    } on Object catch (error) {
      if (mounted && isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not block user: $error")),
        );
      }
      return;
    }
    if (!isCurrent()) {
      return;
    }
    final confirmed = await _showSheet<bool>(
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Block ${message.displayName}?", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                "This will block this user on your Twitch account and hide their chat messages.",
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Block"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted || !isCurrent()) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = message.userId ?? (await profile)?.id;
      if (id == null) {
        throw const FormatException("Could not find this Twitch user. Try again.");
      }
      final client = await loader();
      if (!isCurrent() ||
          client.accessToken != originalClient.accessToken ||
          client.gqlAccessToken != originalClient.gqlAccessToken) {
        return;
      }
      await client.blockUser(id);
      if (isCurrent()) {
        final login = message.login.toLowerCase();
        setState(() {
          _blockedLogins.value = {..._blockedLogins.value, login};
          if (_replyTo?.login.toLowerCase() == login) {
            _replyTo = null;
          }
        });
        messenger.showSnackBar(SnackBar(content: Text("Blocked ${message.displayName}")));
      }
    } on Object catch (error) {
      if (isCurrent()) {
        messenger.showSnackBar(SnackBar(content: Text("Could not block user: $error")));
      }
    }
  }

  Future<void> _showEmote(ChatAssetEmote emote) => _showAsset(
    name: emote.name,
    url: emote.urlForBrightness(Theme.of(context).brightness),
    provider: emote.provider,
    author: emote.author,
    originalName: emote.originalName,
  );

  Future<void> _showBadge(ChatAssetBadge badge) => _showAsset(
    name: badge.title,
    url: badge.url,
    provider: badge.provider,
    isBadge: true,
    background: badge.color,
  );

  Future<void> _showAsset({
    required String name,
    required String url,
    required ChatEmoteProvider provider,
    bool isBadge = false,
    String? author,
    String? originalName,
    String? background,
  }) async {
    final origin = switch (provider) {
      ChatEmoteProvider.twitch => "Twitch",
      ChatEmoteProvider.sevenTv => "7TV",
      ChatEmoteProvider.bttv => "BTTV",
      ChatEmoteProvider.ffz => "FFZ",
    };
    final messenger = ScaffoldMessenger.of(context);
    Future<void> copy(String value, String label) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text("$label copied")));
      }
    }

    final color = int.tryParse(background?.replaceFirst("#", "") ?? "", radix: 16);
    await _showSheet<void>(
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColoredBox(
                color: color == null ? Colors.transparent : Color(0xFF000000 | color),
                child: SizedBox(
                  width: 144,
                  height: 144,
                  child: Uri.parse(url).path.endsWith(".svg")
                      ? SvgPicture.network(
                          url,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined, size: 64),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined, size: 64),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              Text("$origin ${isBadge ? 'badge' : 'emote'}"),
              if (originalName != null && originalName != name)
                Text("Original name: $originalName"),
              if (author != null && author.isNotEmpty) Text("By $author"),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text("Copy name"),
                onTap: () => unawaited(copy(name, "Name")),
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text("Copy image URL"),
                onTap: () => unawaited(copy(url, "Image URL")),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text("Open in browser"),
                onTap: () async {
                  try {
                    await ExternalUrlLauncher.open(Uri.parse(url));
                  } on Object catch (error) {
                    if (mounted) {
                      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pinnedChat(TwitchPinnedChat pin, Map<String, TwitchChatMessage> knownUsers) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pinner = pin.pinnedBy;
    final expanded = _minimizedPinId != pin.id;
    final fontSize = _settings.fontSize * _settings.messageScale;
    final startsAt = pin.startsAt;
    final endsAt = pin.endsAt;
    final role = pinner == null
        ? null
        : pinner.id == widget.controller?.roomState["room-id"] ||
              pinner.login.toLowerCase() == widget.controller?.channel
        ? "broadcaster/1"
        : "moderator/1";
    final badgeUrl = widget.assets?.badgeUrls[role];
    final pinnerPaint = _settings.sevenTvPaints
        ? widget.assets?.userPaintsByLogin[pinner?.login.toLowerCase()]
        : null;
    _pinnerTap.onTap = pinner == null
        ? null
        : () => unawaited(
            _showUser(
              knownUsers[pinner.login.toLowerCase()] ??
                  TwitchChatMessage(
                    id: "pinner-${pinner.id}",
                    userId: pinner.id,
                    login: pinner.login,
                    displayName: pinner.displayName,
                    text: "",
                  ),
            ),
          );
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _updateChatLayout();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: Material(
          key: const ValueKey("chat_pinned_message"),
          color: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(8, 0, 8, expanded ? 12 : 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.push_pin_rounded, size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: pinner == null ? "Pinned message" : "Pinned by "),
                            if (_settings.twitchBadges && badgeUrl != null)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: GestureDetector(
                                    onTap: () => unawaited(
                                      _showBadge(
                                        widget.assets?.badgesById[role] ??
                                            ChatAssetBadge(
                                              id: role!,
                                              title: role == "broadcaster/1"
                                                  ? "Broadcaster"
                                                  : "Moderator",
                                              url: badgeUrl,
                                              provider: ChatEmoteProvider.twitch,
                                            ),
                                      ),
                                    ),
                                    child: Image.network(
                                      badgeUrl,
                                      width: fontSize * _settings.badgeScale,
                                      height: fontSize * _settings.badgeScale,
                                      semanticLabel: role == "broadcaster/1"
                                          ? "Broadcaster"
                                          : "Moderator",
                                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            if (pinner != null)
                              if (pinnerPaint != null)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: _pinnerTap.onTap,
                                    child: ChatUsername(
                                      name: pinner.displayName,
                                      style: theme.textTheme.labelLarge!.copyWith(
                                        color: colors.onSurfaceVariant,
                                        fontSize: fontSize - 2,
                                      ),
                                      paint: pinnerPaint,
                                      animated: _settings.animatedPaints,
                                    ),
                                  ),
                                )
                              else
                                TextSpan(text: pinner.displayName, recognizer: _pinnerTap),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: fontSize - 2,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: expanded ? "Minimize pinned message" : "Expand pinned message",
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 28),
                        fixedSize: const Size(32, 28),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        _pinCollapseTimer?.cancel();
                        _autoCollapsePinId = pin.id;
                        setState(() => _minimizedPinId = expanded ? pin.id : null);
                      },
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: "Close pinned message",
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 28),
                        fixedSize: const Size(32, 28),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        _pinCollapseTimer?.cancel();
                        setState(() => _dismissedPinId = pin.id);
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 26, top: 1, right: 4),
                  child: GestureDetector(
                    onTap: () => unawaited(_showThread(pin.message, pinned: true)),
                    onLongPress: expanded
                        ? null
                        : () => unawaited(_showMessageActions(pin.message)),
                    child: expanded
                        ? _ChatMessageRow(
                            key: ValueKey("pinned-${pin.id}"),
                            message: pin.message,
                            isMention: _mentionsViewer(pin.message, widget._source),
                            settings: _settings,
                            assets: widget.assets,
                            knownUsers: knownUsers,
                            blockedLogins: _blockedLogins.value,
                            pinned: true,
                            bodyKey: _pinBodyKey,
                            replyContextKey: _pinReplyKey,
                            onThreadTap: (message) => unawaited(_showThread(message, pinned: true)),
                            onUserTap: (message) => unawaited(_showUser(message)),
                            onEmoteTap: (emote) => unawaited(_showEmote(emote)),
                            onBadgeTap: (badge) => unawaited(_showBadge(badge)),
                            onMessageHold: (message) => unawaited(_showMessageActions(message)),
                          )
                        : Text(
                            pin.message.text.substring(_replyBodyStart(pin.message)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize),
                          ),
                  ),
                ),
                if (startsAt != null && endsAt != null && endsAt.isAfter(startsAt))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      key: const ValueKey("chat_pin_timer"),
                      value:
                          (endsAt.difference(DateTime.now()).inMilliseconds /
                                  endsAt.difference(startsAt).inMilliseconds)
                              .clamp(0.0, 1.0),
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(2),
                      semanticsLabel: "Pinned message time remaining",
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _schedulePinCollapse(String id, bool exceedsTwoLines) {
    if (_autoCollapsePinId == id) {
      if (!exceedsTwoLines && _pinCollapseTimer?.isActive == true) {
        _pinCollapseTimer!.cancel();
        _autoCollapsePinId = null;
      }
      return;
    }
    _pinCollapseTimer?.cancel();
    if (!exceedsTwoLines) {
      return;
    }
    _autoCollapsePinId = id;
    _pinCollapseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.controller?.pinnedChat?.id == id && _dismissedPinId != id) {
        setState(() => _minimizedPinId = id);
      }
    });
  }

  void _updateChatLayout() {
    if (_layoutUpdateQueued) {
      return;
    }
    _layoutUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutUpdateQueued = false;
      if (!mounted) {
        return;
      }
      final box = _pinLayoutKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height ?? 0;
      if ((height - _pinHeight).abs() > 0.5) {
        setState(() => _pinHeight = height);
      }
      final composerHeight = _composerKey.currentContext?.size?.height ?? 0;
      if ((composerHeight - _composerHeight).abs() > 0.5) {
        setState(() => _composerHeight = composerHeight);
      }
      final pin = widget.controller?.pinnedChat;
      if (pin?.startsAt != null &&
          pin?.endsAt?.isAfter(DateTime.now()) == true &&
          _dismissedPinId != pin!.id &&
          _pinProgressTimer?.isActive != true) {
        _pinProgressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final currentPin = widget.controller?.pinnedChat;
          if (currentPin?.endsAt?.isAfter(DateTime.now()) != true ||
              _dismissedPinId == currentPin?.id) {
            timer.cancel();
          }
          setState(() {});
        });
      }
      final paragraph = _pinBodyKey.currentContext?.findRenderObject();
      if (pin != null && paragraph is RenderParagraph) {
        final paragraphs = [
          paragraph,
          if (_pinReplyKey.currentContext?.findRenderObject() case final RenderParagraph reply)
            reply,
        ];
        final lines = paragraphs
            .map(
              (paragraph) => paragraph
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: 0,
                      extentOffset: paragraph.text
                          .toPlainText(includeSemanticsLabels: false)
                          .length,
                    ),
                    boxHeightStyle: BoxHeightStyle.max,
                  )
                  .map((box) => box.top)
                  .toSet()
                  .length,
            )
            .fold(0, (total, count) => total + count);
        _schedulePinCollapse(pin.id, lines > 2);
      }
      widget.assets?.precacheMessages(context, [
        ..._presentedMessages,
        ?widget.controller?.pinnedMessage,
      ]);
      unawaited(_loadRulesAcceptance());
      final remaining = _syncDeadline?.difference(DateTime.now());
      if (widget.controller?.status == TwitchChatStatus.connected &&
          remaining != null &&
          remaining > Duration.zero) {
        widget.controller!.upsertSystemMessage(
          _syncMessageId,
          "Chat will sync in ${(remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil()}s...",
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final replay = widget.replayController;
    final messages = _messagesForDisplay();
    _updateChatLayout();
    final knownUsers = _knownUsers;
    final moderationNotices = _moderationNoticeIds(messages);
    final unread = (controller?.receivedMessageCount ?? 0) - _receivedWhenPaused;
    final pinned = controller?.pinnedChat;
    final watchNotice = controller?.recentHistory.reversed
        .where((message) => message.isPrivate && message.noticeType == "watch-streak")
        .firstOrNull;
    final status = controller?.status ?? replay!.status;
    final error = controller?.error ?? replay?.error;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final connected = status == TwitchChatStatus.connected;
    final followerWait = controller?.followingWaitRemaining ?? Duration.zero;
    final slowModeWait = controller?.slowModeWaitRemaining ?? Duration.zero;
    final waitingToChat =
        connected &&
        controller?.isSignedIn == true &&
        controller?.chatAccess?.isFollowing == true &&
        controller?.followerChatEligible == false &&
        followerWait > Duration.zero;
    _followerHintTimer?.cancel();
    if (waitingToChat) {
      _followerHintTimer = Timer(const Duration(seconds: 1), _chatChanged);
    }
    final connectionMessage = switch (status) {
      TwitchChatStatus.connecting =>
        replay == null ? "Connecting to chat…" : "Loading chat replay…",
      TwitchChatStatus.reconnecting =>
        replay == null ? "Reconnecting to chat…" : "Reconnecting to chat replay…",
      _ => null,
    };
    final hint = !connected
        ? status == TwitchChatStatus.connecting
              ? connectionMessage!
              : "Chat disconnected"
        : controller?.isSignedIn != true
        ? "Sign in from Following to chat"
        : !controller!.subscriberChatEligible
        ? "Subscriber-Only Mode"
        : controller.chatAccess == null
        ? controller.chatAccessError == null
              ? "Checking chat access…"
              : "Tap to retry chat"
        : waitingToChat
        ? "You can chat in ${_chatDuration(followerWait)}"
        : slowModeWait > Duration.zero
        ? "You can chat in ${_chatDuration(slowModeWait)}"
        : _replyTo == null
        ? "Send a message"
        : "@${_replyTo!.login}";
    final hasDraft = _draft.text.trim().isNotEmpty;
    final completion = _chatCompletion;
    final messageIndices = {
      for (var index = 0; index < messages.length; index++)
        ValueKey(messages[index].id): messages.length - index - 1,
    };
    return PopScope<Object?>(
      canPop: !_showEmotes,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showEmotes) {
          _setShowEmotes(false);
        }
      },
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Expanded(
              flex: _showEmotes ? 55 : 1,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(
                      child: Stack(
                        children: [
                          if (messages.isEmpty && replay != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    connectionMessage ??
                                        (connected
                                            ? "No messages at this point in the video"
                                            : "Chat disconnected"),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Listener(
                            onPointerDown: (_) => _followingBeforePointer = _following,
                            onPointerCancel: (_) {
                              if (_followingBeforePointer) {
                                setState(() {
                                  _following = true;
                                  _pausedMessages = null;
                                });
                                _scrollToLatest();
                              }
                            },
                            child: ListView.builder(
                              key: const ValueKey("chat_messages"),
                              controller: _scroll,
                              reverse: true,
                              padding: EdgeInsets.fromLTRB(
                                0,
                                widget.topPadding + _pinHeight + 8,
                                0,
                                _composerHeight + 4,
                              ),
                              itemCount: messages.length,
                              findChildIndexCallback: (key) => messageIndices[key],
                              itemBuilder: (context, index) => _ChatMessageRow(
                                key: ValueKey(messages[messages.length - index - 1].id),
                                message: messages[messages.length - index - 1],
                                isMention: _mentionsViewer(
                                  messages[messages.length - index - 1],
                                  widget._source,
                                ),
                                horizontalPadding: 12,
                                settings: _settings,
                                assets: widget.assets,
                                knownUsers: knownUsers,
                                blockedLogins: _blockedLogins.value,
                                showModeration: moderationNotices.contains(
                                  messages[messages.length - index - 1].id,
                                ),
                                onUserTap: (message) => unawaited(_showUser(message)),
                                onThreadTap: (message) => unawaited(_showThread(message)),
                                onEmoteTap: (emote) => unawaited(_showEmote(emote)),
                                onBadgeTap: (badge) => unawaited(_showBadge(badge)),
                                onMessageHold: (message) => unawaited(_showMessageActions(message)),
                              ),
                            ),
                          ),
                          if (!_following)
                            Positioned(
                              bottom: _composerHeight + 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: FilledButton.tonalIcon(
                                  onPressed: () {
                                    setState(() {
                                      _following = true;
                                      _pausedMessages = null;
                                    });
                                    _scrollToLatest();
                                  },
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                                  label: Text(
                                    unread > 0
                                        ? "$unread new ${unread == 1 ? 'message' : 'messages'}"
                                        : "Jump to latest",
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (pinned != null &&
                        pinned.id != _dismissedPinId &&
                        !_blockedLogins.value.contains(pinned.message.login.toLowerCase()))
                      Positioned(
                        top: widget.topPadding,
                        left: 8,
                        right: 8,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                (constraints.maxHeight - widget.topPadding).clamp(
                                  0,
                                  double.infinity,
                                ) *
                                0.6,
                          ),
                          child: Padding(
                            key: _pinLayoutKey,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _pinnedChat(pinned, knownUsers),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Positioned.fill(
                            top: -4,
                            child: RotatedBox(quarterTurns: 2, child: TopHeaderMaterial()),
                          ),
                          Column(
                            key: _composerKey,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (completion != null)
                                ConstrainedBox(
                                  key: ValueKey(
                                    completion.users.isEmpty
                                        ? "chat_emote_autocomplete"
                                        : "chat_username_autocomplete",
                                  ),
                                  constraints: BoxConstraints(
                                    maxHeight: (constraints.maxHeight * 0.4).clamp(0.0, 240.0),
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemExtent: completion.users.isEmpty ? 48 : 32,
                                      itemCount: completion.users.isEmpty
                                          ? completion.emotes.length
                                          : completion.users.length,
                                      itemBuilder: (context, index) {
                                        if (completion.users.isNotEmpty) {
                                          final user = completion.users[index];
                                          final name = user.displayName.isEmpty
                                              ? user.login
                                              : user.displayName;
                                          final style = theme.textTheme.bodyMedium!.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: _chatNameColor(user, theme.brightness),
                                          );
                                          final paint = _settings.sevenTvPaints
                                              ? widget.assets?.userPaintsByLogin[user.login
                                                    .toLowerCase()]
                                              : null;
                                          return ListTile(
                                            minTileHeight: 32,
                                            dense: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            title: paint == null
                                                ? Text(
                                                    name,
                                                    style: style,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  )
                                                : ChatUsername(
                                                    name: name,
                                                    style: style,
                                                    paint: paint,
                                                    animated: _settings.animatedPaints,
                                                  ),
                                            onTap: () {
                                              _insertCompletion(
                                                "@${user.login}",
                                                replacement: completion.selection,
                                              );
                                              _draftFocus.requestFocus();
                                            },
                                          );
                                        }
                                        final emote = completion.emotes[index];
                                        return Tooltip(
                                          message: emote.name,
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            leading: Image.network(
                                              emote.urlForBrightness(theme.brightness),
                                              width: 80,
                                              height: 40,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) => const Icon(
                                                Icons.sentiment_satisfied_alt_rounded,
                                                size: 40,
                                              ),
                                            ),
                                            title: Text(
                                              emote.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onTap: () {
                                              _insertCompletion(
                                                emote.name,
                                                replacement: completion.selection,
                                              );
                                              _draftFocus.requestFocus();
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              if (replay != null &&
                                  messages.isNotEmpty &&
                                  connectionMessage != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      connectionMessage,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      error,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.error,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_replyTo case final message?)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.reply_rounded, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _ChatMessageRow(
                                          key: const ValueKey("chat_composer_reply_preview"),
                                          message: message,
                                          settings: _settings,
                                          assets: widget.assets,
                                          knownUsers: knownUsers,
                                          blockedLogins: _blockedLogins.value,
                                          previewPrefix: "Replying to ${message.displayName}: ",
                                          previewLines: 1,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: "Cancel reply",
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setState(() => _replyTo = null),
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              if (controller != null &&
                                  widget.isLive &&
                                  controller.isSignedIn &&
                                  _settings.showWatchStreakPopups)
                                _WatchStreakCallout(
                                  key: ValueKey((controller, controller.currentUserId)),
                                  notice: watchNotice,
                                  onLayoutChanged: _updateChatLayout,
                                ),
                              SafeArea(
                                top: false,
                                bottom: !_showEmotes,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: controller == null
                                            ? Text(
                                                "Chat replay",
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: colors.onSurfaceVariant,
                                                ),
                                              )
                                            : TextField(
                                                key: const ValueKey("chat_message_input"),
                                                controller: _draft,
                                                focusNode: _draftFocus,
                                                enabled: connected && controller.isSignedIn,
                                                readOnly: !_canCompose || _showEmotes,
                                                showCursor: _canCompose && !_showEmotes,
                                                enableInteractiveSelection: _canCompose,
                                                textInputAction: TextInputAction.send,
                                                textCapitalization: TextCapitalization.sentences,
                                                maxLength: 500,
                                                decoration: InputDecoration(
                                                  hintText: hint,
                                                  counterText: "",
                                                  suffixIcon: widget.assets == null
                                                      ? null
                                                      : IconButton(
                                                          key: const ValueKey("chat_emote_toggle"),
                                                          tooltip: _showEmotes
                                                              ? "Show keyboard"
                                                              : "Show emotes",
                                                          onPressed:
                                                              connected && controller.isSignedIn
                                                              ? () => unawaited(_toggleEmotes())
                                                              : null,
                                                          icon: Icon(
                                                            _showEmotes
                                                                ? Icons.keyboard_rounded
                                                                : Icons
                                                                      .sentiment_satisfied_alt_rounded,
                                                          ),
                                                        ),
                                                ),
                                                onTap: () {
                                                  if (!_canCompose || _showEmotes) {
                                                    unawaited(_focusComposer());
                                                  }
                                                },
                                                onSubmitted: (_) => unawaited(_send()),
                                              ),
                                      ),
                                      if (hasDraft && controller != null)
                                        IconButton(
                                          key: const ValueKey("chat_send"),
                                          tooltip: "Send message",
                                          onPressed: controller.canSend && !_sending
                                              ? () => unawaited(_send())
                                              : null,
                                          color: colors.primary,
                                          icon: const Icon(Icons.send_rounded),
                                        )
                                      else
                                        IconButton(
                                          key: const ValueKey("chat_menu"),
                                          tooltip: "Chat options",
                                          onPressed: () => unawaited(_openMenu()),
                                          icon: const Icon(Icons.more_vert_rounded),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showEmotes && controller != null && widget.assets != null)
              Expanded(
                flex: 45,
                child: TwitchEmotePicker(
                  assets: widget.assets!,
                  preferences: _preferences,
                  onSelected: (emote) => _insertCompletion(emote.name),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WatchStreakCallout extends StatefulWidget {
  const _WatchStreakCallout({required this.notice, required this.onLayoutChanged, super.key});

  final TwitchChatMessage? notice;
  final VoidCallback onLayoutChanged;

  @override
  State<_WatchStreakCallout> createState() => _WatchStreakCalloutState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatMessage?>("notice", notice));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onLayoutChanged", onLayoutChanged));
  }
}

class _WatchStreakCalloutState extends State<_WatchStreakCallout>
    with SingleTickerProviderStateMixin {
  static const _lifetime = Duration(seconds: 30);
  final _dismissedIds = <String>{};
  late final _dismissal = AnimationController(vsync: this, duration: _lifetime)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dismiss();
      }
    });
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _updateNotice();
  }

  @override
  void didUpdateWidget(_WatchStreakCallout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice?.id != widget.notice?.id) {
      _updateNotice();
    }
  }

  void _updateNotice() {
    _dismissal.stop();
    final notice = widget.notice;
    final timestamp = notice?.timestamp;
    final remaining = timestamp?.add(_lifetime).difference(DateTime.now());
    _visible =
        notice != null &&
        !_dismissedIds.contains(notice.id) &&
        remaining != null &&
        remaining > Duration.zero;
    if (_visible) {
      unawaited(
        _dismissal.forward(
          from: 1 - (remaining!.inMicroseconds / _lifetime.inMicroseconds).clamp(0.0, 1.0),
        ),
      );
    }
  }

  void _dismiss() {
    _dismissal.stop();
    if (widget.notice case final notice?) {
      _dismissedIds.add(notice.id);
    }
    setState(() => _visible = false);
    widget.onLayoutChanged();
  }

  @override
  void dispose() {
    _dismissal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_visible
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Material(
            key: const ValueKey("chat_watch_streak_callout"),
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.notice!.noticeText ?? widget.notice!.text,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: "Dismiss watch streak",
                        onPressed: _dismiss,
                        icon: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _dismissal,
                    builder: (context, _) => LinearProgressIndicator(
                      key: const ValueKey("chat_watch_streak_dismissal"),
                      value: 1 - _dismissal.value,
                      minHeight: 2,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}

Widget _chatBadge(
  ChatAssetBadge badge, {
  required double size,
  ValueChanged<ChatAssetBadge>? onTap,
}) {
  final color = int.tryParse(badge.color?.replaceFirst("#", "") ?? "", radix: 16);
  return GestureDetector(
    onTap: onTap == null ? null : () => onTap(badge),
    child: ColoredBox(
      color: color == null ? Colors.transparent : Color(0xFF000000 | color),
      child: Uri.parse(badge.url).path.endsWith(".svg")
          ? SvgPicture.network(
              badge.url,
              width: size,
              height: size,
              semanticsLabel: badge.title,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : Image.network(
              badge.url,
              width: size,
              height: size,
              semanticLabel: badge.title,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
    ),
  );
}

class _ChatUserSheet extends StatefulWidget {
  const _ChatUserSheet({
    required this.message,
    required this.profile,
    required this.source,
    required this.messages,
    required this.knownUsers,
    required this.blockedLogins,
    required this.settings,
    required this.assets,
    required this.onMore,
    required this.onReply,
    required this.onEmoteTap,
    required this.onBadgeTap,
    required this.onUserTap,
    required this.onThreadTap,
    required this.onMessageHold,
  });

  final TwitchChatMessage message;
  final Future<TwitchUser?> profile;
  final Listenable source;
  final List<TwitchChatMessage> Function() messages;
  final ValueGetter<Map<String, TwitchChatMessage>> knownUsers;
  final Set<String> blockedLogins;
  final ChatPreferences Function() settings;
  final TwitchChatAssets? assets;
  final VoidCallback onMore;
  final VoidCallback? onReply;
  final ValueChanged<ChatAssetEmote> onEmoteTap;
  final ValueChanged<ChatAssetBadge> onBadgeTap;
  final ValueChanged<TwitchChatMessage> onUserTap;
  final ValueChanged<TwitchChatMessage> onThreadTap;
  final ValueChanged<TwitchChatMessage> onMessageHold;

  @override
  State<_ChatUserSheet> createState() => _ChatUserSheetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatMessage>("message", message));
    properties.add(DiagnosticsProperty<Future<TwitchUser?>>("profile", profile));
    properties.add(DiagnosticsProperty<Listenable>("source", source));
    properties.add(ObjectFlagProperty<Object>.has("messages", messages));
    properties.add(ObjectFlagProperty<Object>.has("knownUsers", knownUsers));
    properties.add(IterableProperty<String>("blockedLogins", blockedLogins));
    properties.add(ObjectFlagProperty<Object>.has("settings", settings));
    properties.add(DiagnosticsProperty<TwitchChatAssets?>("assets", assets));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onMore", onMore));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onReply", onReply));
    properties.add(ObjectFlagProperty<Object>.has("onEmoteTap", onEmoteTap));
    properties.add(ObjectFlagProperty<Object>.has("onBadgeTap", onBadgeTap));
    properties.add(ObjectFlagProperty<Object>.has("onUserTap", onUserTap));
    properties.add(ObjectFlagProperty<Object>.has("onThreadTap", onThreadTap));
    properties.add(ObjectFlagProperty<Object>.has("onMessageHold", onMessageHold));
  }
}

class _ChatUserSheetState extends State<_ChatUserSheet> {
  final _history = <String, TwitchChatMessage>{};
  final _scroll = ScrollController();
  bool _following = true;

  @override
  void initState() {
    super.initState();
    widget.source.addListener(_updated);
    widget.assets?.addListener(_updated);
    _scroll.addListener(_scrolled);
    _updated();
  }

  void _scrolled() => _following = _scroll.position.extentAfter < 1;

  void _updated() {
    for (final message in widget.messages()) {
      if (message.login.toLowerCase() == widget.message.login.toLowerCase()) {
        _history[message.id] = _retainModeration(_history[message.id], message);
      }
    }
    if (widget.message.text.isNotEmpty) {
      _history.putIfAbsent(widget.message.id, () => widget.message);
    }
    while (_history.length > 5000) {
      _history.remove(_history.keys.first);
    }
    setState(() {});
    if (_following) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _following && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.source.removeListener(_updated);
    widget.assets?.removeListener(_updated);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings();
    final logs = _history.values
        .where((message) => _showMessage(message, settings, widget.blockedLogins))
        .toList();
    final knownUsers = widget.knownUsers();
    final moderationNotices = _moderationNoticeIds(logs);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            FutureBuilder<TwitchUser?>(
              future: widget.profile,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final observed = knownUsers[widget.message.login.toLowerCase()] ?? widget.message;
                final name = profile?.displayName ?? observed.displayName;
                final user = TwitchChatMessage(
                  id: observed.id,
                  userId: profile?.id ?? observed.userId,
                  login: observed.login,
                  displayName: name,
                  color: profile?.chatColor ?? observed.color,
                  text: "",
                );
                final style = Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _chatNameColor(user, Theme.of(context).brightness),
                );
                final paint = settings.sevenTvPaints
                    ? widget.assets?.userPaintsByLogin[user.login.toLowerCase()]
                    : null;
                final badgeIds = <String>{};
                final badges = [
                  for (final badge in profile?.badges ?? <TwitchUserBadge>[])
                    ChatAssetBadge(
                      id: badge.id,
                      title: badge.title,
                      url: badge.imageUrl,
                      provider: ChatEmoteProvider.twitch,
                    ),
                  for (final id in observed.badges)
                    if (widget.assets?.badgeUrls[id] case final url?)
                      widget.assets?.badgesById[id] ??
                          ChatAssetBadge(
                            id: id,
                            title: id.split("/").first,
                            url: url,
                            provider: ChatEmoteProvider.twitch,
                          ),
                  ...widget.assets?.userBadgesByLogin[user.login.toLowerCase()] ??
                      <ChatAssetBadge>[],
                ].where((badge) => badgeIds.add("${badge.provider.name}:${badge.id}")).toList();
                final tier = switch (profile?.subscriptionTier) {
                  "1000" || "1" => "Tier 1",
                  "2000" || "2" => "Tier 2",
                  "3000" || "3" => "Tier 3",
                  _ => null,
                };
                final months = profile?.subscriptionMonths;
                final subscription = [
                  switch (profile?.isSubscribed) {
                    true => "Subscriber",
                    false => "Not currently subscribed",
                    null => "Subscription details unavailable",
                  },
                  ?tier,
                  if (profile?.subscriptionIsPrime == true) "Prime",
                  if (months != null && months >= 0) "$months month${months == 1 ? '' : 's'} total",
                ].join(" · ");
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            child: profile?.profileImageUrl == null
                                ? const Icon(Icons.person_rounded)
                                : ClipOval(
                                    child: Image.network(
                                      profile!.profileImageUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(Icons.person_rounded),
                                    ),
                                  ),
                          ),
                          title: paint == null
                              ? Text(name, key: const ValueKey("chat_user_name"), style: style)
                              : ChatUsername(
                                  key: const ValueKey("chat_user_name"),
                                  name: name,
                                  style: style,
                                  paint: paint,
                                  animated: settings.animatedPaints,
                                ),
                          subtitle: Text("@${widget.message.login}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onReply != null)
                                IconButton(
                                  key: const ValueKey("chat_user_reply"),
                                  tooltip: "Reply",
                                  onPressed: widget.onReply,
                                  icon: const Icon(Icons.reply_rounded),
                                ),
                              IconButton(
                                key: const ValueKey("chat_user_more"),
                                tooltip: "User options",
                                onPressed: widget.onMore,
                                icon: const Icon(Icons.more_vert_rounded),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (badges.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Wrap(
                                    key: const ValueKey("chat_user_badges"),
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final badge in badges)
                                        Tooltip(
                                          message: badge.title,
                                          child: _chatBadge(
                                            badge,
                                            size: 24,
                                            onTap: widget.onBadgeTap,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              if (snapshot.connectionState == ConnectionState.done) ...[
                                Text(
                                  profile?.createdAt == null
                                      ? "Account creation date unavailable"
                                      : "Account created · ${MaterialLocalizations.of(context).formatShortDate(profile!.createdAt!.toLocal())}",
                                  key: const ValueKey("chat_user_created"),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subscription,
                                  key: const ValueKey("chat_user_subscription"),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                key: const ValueKey("chat_user_history"),
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) => _ChatMessageRow(
                  key: ValueKey("log-${logs[index].id}"),
                  message: logs[index],
                  isMention: _mentionsViewer(logs[index], widget.source),
                  settings: settings,
                  assets: widget.assets,
                  showTimestamps: true,
                  knownUsers: knownUsers,
                  blockedLogins: widget.blockedLogins,
                  showModeration: moderationNotices.contains(logs[index].id),
                  onUserTap: (message) {
                    if (message.login.toLowerCase() != widget.message.login.toLowerCase()) {
                      widget.onUserTap(message);
                    }
                  },
                  onThreadTap: widget.onThreadTap,
                  onEmoteTap: widget.onEmoteTap,
                  onBadgeTap: widget.onBadgeTap,
                  onMessageHold: widget.onMessageHold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _showMessage(
  TwitchChatMessage message,
  ChatPreferences settings,
  Set<String> blockedLogins,
) =>
    !blockedLogins.contains(message.login.toLowerCase()) &&
    (message.isPrivate ||
        ((message.noticeType != "moderation" || settings.showModerationNotices) &&
            (settings.showDeletedMessages ||
                !message.isDeleted ||
                (settings.showModerationNotices &&
                    (message.moderation == TwitchChatModeration.timeout ||
                        message.moderation == TwitchChatModeration.ban)))));

TwitchChatMessage _retainModeration(TwitchChatMessage? previous, TwitchChatMessage incoming) {
  if (previous == null || (!previous.isDeleted && previous.moderation == null)) {
    return incoming;
  }
  final latest =
      incoming.moderation != null &&
          (previous.moderation == null ||
              (incoming.moderatedAt != null &&
                  (previous.moderatedAt == null ||
                      !incoming.moderatedAt!.isBefore(previous.moderatedAt!))))
      ? incoming
      : previous;
  return incoming.copyWith(
    isDeleted: incoming.isDeleted || previous.isDeleted,
    moderation: latest.moderation,
    timeoutSeconds: latest.timeoutSeconds,
    moderatedAt: latest.moderatedAt,
  );
}

Set<String> _moderationNoticeIds(Iterable<TwitchChatMessage> messages) => {
  ...{
    for (final message in messages)
      if (message.moderation == TwitchChatModeration.timeout ||
          message.moderation == TwitchChatModeration.ban)
        "${message.userId ?? message.login}/${message.moderatedAt}": message.id,
  }.values,
};

class _ChatThreadSheet extends StatefulWidget {
  const _ChatThreadSheet({
    required this.message,
    required this.title,
    required this.source,
    required this.messages,
    required this.knownUsers,
    required this.blockedLogins,
    required this.loadHistory,
    required this.settings,
    required this.assets,
    required this.onUserTap,
    required this.onEmoteTap,
    required this.onBadgeTap,
    required this.onMessageHold,
  });

  final TwitchChatMessage message;
  final String title;
  final Listenable source;
  final List<TwitchChatMessage> Function() messages;
  final ValueGetter<Map<String, TwitchChatMessage>> knownUsers;
  final Set<String> blockedLogins;
  final Future<List<TwitchChatMessage>> Function() loadHistory;
  final ChatPreferences Function() settings;
  final TwitchChatAssets? assets;
  final ValueChanged<TwitchChatMessage> onUserTap;
  final ValueChanged<ChatAssetEmote> onEmoteTap;
  final ValueChanged<ChatAssetBadge> onBadgeTap;
  final ValueChanged<TwitchChatMessage> onMessageHold;

  @override
  State<_ChatThreadSheet> createState() => _ChatThreadSheetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatMessage>("message", message));
    properties.add(StringProperty("title", title));
    properties.add(DiagnosticsProperty<Listenable>("source", source));
    properties.add(ObjectFlagProperty<Object>.has("messages", messages));
    properties.add(ObjectFlagProperty<Object>.has("knownUsers", knownUsers));
    properties.add(IterableProperty<String>("blockedLogins", blockedLogins));
    properties.add(ObjectFlagProperty<Object>.has("loadHistory", loadHistory));
    properties.add(ObjectFlagProperty<Object>.has("settings", settings));
    properties.add(DiagnosticsProperty<TwitchChatAssets?>("assets", assets));
    properties.add(ObjectFlagProperty<Object>.has("onUserTap", onUserTap));
    properties.add(ObjectFlagProperty<Object>.has("onEmoteTap", onEmoteTap));
    properties.add(ObjectFlagProperty<Object>.has("onBadgeTap", onBadgeTap));
    properties.add(ObjectFlagProperty<Object>.has("onMessageHold", onMessageHold));
  }
}

class _ChatThreadSheetState extends State<_ChatThreadSheet> {
  Future<List<TwitchChatMessage>>? _history;
  final _retained = <String, TwitchChatMessage>{};

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      child: FutureBuilder<List<TwitchChatMessage>>(
        future: _history ??= widget.loadHistory(),
        builder: (context, snapshot) => AnimatedBuilder(
          animation: Listenable.merge([widget.source, widget.assets]),
          builder: (context, child) {
            final message = widget.message;
            final history = <String, TwitchChatMessage>{};
            for (final item in [
              ...?snapshot.data,
              ..._retained.values,
              ...widget.messages(),
            ]) {
              history[item.id] = _retainModeration(history[item.id], item);
            }
            history[message.id] = _retainModeration(message, history[message.id] ?? message);
            final loadedIds = history.keys.toSet();
            var root =
                snapshot.data?.firstOrNull?.id ??
                message.threadRootId ??
                message.parentMessageId ??
                message.id;
            final ids = {message.id};
            while (ids.add(root)) {
              final ancestor = history[root];
              final parent = ancestor?.threadRootId ?? ancestor?.parentMessageId;
              if (parent == null || parent == root) {
                break;
              }
              root = parent;
            }
            ids.add(root);
            if (message.parentMessageId case final parentId?) {
              ids.add(parentId);
              history.putIfAbsent(
                parentId,
                () => TwitchChatMessage(
                  id: parentId,
                  login:
                      message.parentLogin ??
                      (parentId == message.threadRootId ? message.threadRootLogin : null) ??
                      "",
                  displayName:
                      message.parentDisplayName ?? message.parentLogin ?? "Original message",
                  userId: message.parentUserId,
                  text: message.parentText ?? "Original message is unavailable",
                  emotes: message.parentEmotes,
                  gifs: message.parentGifs,
                ),
              );
            }
            var previousSize = -1;
            while (previousSize != ids.length) {
              previousSize = ids.length;
              for (final item in history.values) {
                if (item.threadRootId == root || ids.contains(item.parentMessageId)) {
                  ids.add(item.id);
                }
              }
            }
            final preferences = widget.settings();
            final members = history.values.where((item) => ids.contains(item.id)).toList();
            _retained.addAll({
              for (final item in members)
                if (loadedIds.contains(item.id)) item.id: item,
            });
            final children = <String, List<TwitchChatMessage>>{};
            for (final item in members) {
              if (item.id == root) {
                continue;
              }
              final parent = item.parentMessageId;
              final parentId = parent != item.id && ids.contains(parent) ? parent! : root;
              (children[parentId] ??= []).add(item);
            }
            final thread = <TwitchChatMessage>[];
            final depths = <String, int>{};
            void append(TwitchChatMessage item, int depth) {
              if (depths.containsKey(item.id)) {
                return;
              }
              depths[item.id] = depth;
              if (_showMessage(item, preferences, widget.blockedLogins)) {
                thread.add(item);
              }
              for (final child in children[item.id] ?? <TwitchChatMessage>[]) {
                append(child, depth + 1);
              }
            }

            if (history[root] case final rootMessage?) {
              append(rootMessage, 0);
            }
            for (final item in members) {
              append(item, item.id == root ? 0 : 1);
            }
            final knownUsers = widget.knownUsers();
            final moderationNotices = _moderationNoticeIds(thread);
            final indices = {
              for (var index = 0; index < thread.length; index++)
                ValueKey("thread-item-${thread[index].id}"): index,
            };
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  title: Text(
                    widget.title == "Reply thread" ? "REPLIES" : widget.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: "Close thread",
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                if (snapshot.hasError)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Could not load older replies"),
                      TextButton(
                        onPressed: () => setState(() {
                          _history = null;
                        }),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                Flexible(
                  child: ListView.builder(
                    key: const ValueKey("chat_reply_thread"),
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: thread.length,
                    findChildIndexCallback: (key) => indices[key],
                    itemBuilder: (context, index) => Padding(
                      key: ValueKey("thread-item-${thread[index].id}"),
                      padding: EdgeInsets.only(
                        left: ((depths[thread[index].id]! - 1) * 16.0).clamp(
                          0.0,
                          MediaQuery.sizeOf(context).width * 0.4,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (thread[index].id != root)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, top: 5, right: 12),
                              child: Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Expanded(
                            child: _ChatMessageRow(
                              key: ValueKey("thread-${thread[index].id}"),
                              message: thread[index],
                              isMention: _mentionsViewer(thread[index], widget.source),
                              settings: preferences,
                              assets: widget.assets,
                              knownUsers: knownUsers,
                              blockedLogins: widget.blockedLogins,
                              showModeration: moderationNotices.contains(thread[index].id),
                              showTimestamps: false,
                              showReplyContext: false,
                              onUserTap: widget.onUserTap,
                              onEmoteTap: widget.onEmoteTap,
                              onBadgeTap: widget.onBadgeTap,
                              onMessageHold: widget.onMessageHold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

// Google Material Symbols, domino_mask (Apache-2.0).
// https://github.com/google/material-design-icons/tree/master/symbols/web/domino_mask
const _dominoMaskSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="'
    "M312-240q-51 0-97.5-18T131-311q-48-45-69.5-106.5T40-545q0-78 38-126.5T189-720"
    "q14 0 26.5 2.5T241-710l239 89 239-89q13-5 25.5-7.5T771-720q73 0 111 48.5T920-545"
    "q0 66-21.5 127.5T829-311q-37 35-83.5 53T648-240q-66 0-112-30l-46-30h-20l-46 30"
    "q-46 30-112 30Zm0-80q37 0 69-17.5t59-42.5h80q27 25 59 42.5t69 17.5q36 0 69.5-12.5"
    "T777-371q34-34 48.5-80t14.5-94q0-41-17-68.5T769-640q-3 0-22 4L480-536 213-636"
    "q-5-2-10.5-3t-11.5-1q-37 0-54 27t-17 68q0 49 14.5 95t49.5 80q26 25 59 37.5t69 12.5"
    "Zm49-60q37 0 58-16.5t21-45.5q0-49-64.5-93.5T239-580q-37 0-58 16.5T160-518"
    "q0 49 64.5 93.5T361-380Zm-6-60q-38 0-82.5-25T220-516q5-2 11.5-3.5T245-521"
    "q38 0 82.5 25.5T380-444q-5 2-11.5 3t-13.5 1Zm244 61q72 0 136.5-45t64.5-94"
    "q0-29-20.5-46T721-581q-72 0-136.5 45T520-442q0 29 21 46t58 17Zm6-61q-7 0-13-1t-11-3"
    'q8-26 52.5-51t82.5-25q7 0 13 1t11 3q-8 26-52.5 51T605-440Zm-125-40Z"/></svg>';

// Google Material Symbols, mode_heat (Apache-2.0).
// https://github.com/google/material-design-icons/tree/master/symbols/web/mode_heat
const _modeHeatSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="'
    "M480-80q-134 0-227-93t-93-227q0-113 67-217t184-182q22-15 45.5-1.5T480-760v52"
    "q0 34 23.5 57t57.5 23q17 0 32.5-7.5T621-657q8-10 20.5-12.5T665-664q63 45 99 115"
    "t36 149q0 134-93 227T480-80ZM240-400q0 52 21 98.5t60 81.5q-1-5-1-9v-9q0-32 12-60"
    "t35-51l113-111 113 111q23 23 35 51t12 60v9q0 4-1 9 39-35 60-81.5t21-98.5q0-50-18.5-94.5"
    "T648-574q-20 13-42 19.5t-45 6.5q-62 0-107.5-41T401-690q-78 66-119.5 140.5T240-400Z"
    "m240 52-57 56q-11 11-17 25t-6 29q0 32 23.5 55t56.5 23q33 0 56.5-23t23.5-55"
    'q0-16-6-29.5T537-292l-57-56Z"/></svg>';

// Google Material Symbols, crown (Apache-2.0).
// https://github.com/google/material-design-icons/tree/master/symbols/web/crown
const _crownSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="'
    "M240-160q-17 0-28.5-11.5T200-200q0-17 11.5-28.5T240-240h480q17 0 28.5 11.5T760-200"
    "q0 17-11.5 28.5T720-160H240Zm28-140q-29 0-51.5-19T189-367l-40-254q-2 0-4.5.5t-4.5.5"
    "q-25 0-42.5-17.5T80-680q0-25 17.5-42.5T140-740q25 0 42.5 17.5T200-680q0 7-1.5 13t-3.5 11"
    "l125 56 125-171q-11-8-18-21t-7-28q0-25 17.5-42.5T480-880q25 0 42.5 17.5T540-820q0 15-7 28"
    "t-18 21l125 171 125-56q-2-5-3.5-11t-1.5-13q0-25 17.5-42.5T820-740q25 0 42.5 17.5T880-680"
    "q0 25-17.5 42.5T820-620q-2 0-4.5-.5t-4.5-.5l-40 254q-5 29-27.5 48T692-300H268Zm0-80h424"
    "l26-167-46 20q-26 11-53 4t-44-30l-95-131-95 131q-17 23-44 30t-53-4l-46-20 26 167Z"
    'm212 0Z"/></svg>';

// Google Material Symbols, featured_seasonal_and_gifts (Apache-2.0).
// https://github.com/google/material-design-icons/tree/master/symbols/web/featured_seasonal_and_gifts
const _featuredSeasonalAndGiftsSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="'
    "M160-160v-360q-33 0-56.5-23.5T80-600v-80q0-33 23.5-56.5T160-760h128q-5-9-6.5-19t-1.5-21"
    "q0-50 35-85t85-35q23 0 43 8.5t37 23.5q17-16 37-24t43-8q50 0 85 35t35 85q0 11-2 20.5t-6 19.5"
    "h128q33 0 56.5 23.5T880-680v80q0 33-23.5 56.5T800-520v360q0 33-23.5 56.5T720-80H240"
    "q-33 0-56.5-23.5T160-160Zm400-680q-17 0-28.5 11.5T520-800q0 17 11.5 28.5T560-760q17 0 28.5-11.5"
    "T600-800q0-17-11.5-28.5T560-840Zm-200 40q0 17 11.5 28.5T400-760q17 0 28.5-11.5T440-800"
    "q0-17-11.5-28.5T400-840q-17 0-28.5 11.5T360-800ZM160-680v80h280v-80H160Zm280 520v-360"
    'H240v360h200Zm80 0h200v-360H520v360Zm280-440v-80H520v80h280Z"/></svg>';

String _chatDuration(Duration duration) {
  final remaining = (duration.inMilliseconds / 1000).ceil();
  return remaining < 60
      ? "${remaining}s"
      : remaining % 60 == 0
      ? "${remaining ~/ 60}m"
      : "${remaining ~/ 60}m ${(remaining % 60).toString().padLeft(2, '0')}s";
}

final _chatNameRandom = Random();
final _defaultChatNameColors = <String, int>{};

Color _chatNameColor(TwitchChatMessage message, Brightness brightness) {
  final rawColor = message.color?.replaceFirst("#", "");
  final colorValue = rawColor?.length == 6 ? int.tryParse(rawColor!, radix: 16) : null;
  const defaults = [
    0xFFFF0000,
    0xFF0000FF,
    0xFF008000,
    0xFFB22222,
    0xFFFF7F50,
    0xFF9ACD32,
    0xFFFF4500,
    0xFF2E8B57,
    0xFFDAA520,
    0xFFD2691E,
    0xFF5F9EA0,
    0xFF1E90FF,
    0xFFFF69B4,
    0xFF8A2BE2,
    0xFF00FF7F,
  ];
  final fallback = colorValue == null
      ? _defaultChatNameColors.putIfAbsent(
          message.login.toLowerCase(),
          () {
            if (_defaultChatNameColors.length >= 5000) {
              _defaultChatNameColors.remove(_defaultChatNameColors.keys.first);
            }
            return defaults[_chatNameRandom.nextInt(defaults.length)];
          },
        )
      : 0xFF000000 | colorValue;
  return readableChatNameColor(
    Color(fallback),
    brightness,
  );
}

bool _mentionsViewer(TwitchChatMessage message, Listenable? source) {
  if (source is! TwitchChatController ||
      !source.isSignedIn ||
      message.isOwn ||
      message.isDeleted ||
      message.isPrivate ||
      message.noticeType == "system") {
    return false;
  }
  final userId = source.currentUserId;
  final login = source.currentUserLogin?.toLowerCase();
  if ((userId != null && message.userId == userId) ||
      (login != null && message.login.toLowerCase() == login)) {
    return false;
  }
  if (message.parentMessageId != null &&
      (message.parentUserId != null && userId != null
          ? message.parentUserId == userId
          : login != null && message.parentLogin?.toLowerCase() == login)) {
    return true;
  }
  return login != null &&
      login.isNotEmpty &&
      RegExp(
        "(^|[^A-Za-z0-9_])@${RegExp.escape(login)}(?![A-Za-z0-9_])",
        caseSensitive: false,
      ).hasMatch(message.text);
}

int _replyBodyStart(TwitchChatMessage message) {
  final parentLogin = message.parentLogin;
  return parentLogin != null && parentLogin.isNotEmpty
      ? RegExp(
              "^@${RegExp.escape(parentLogin)}(?:\\s+|\$)",
              caseSensitive: false,
            ).firstMatch(message.text)?.end ??
            0
      : 0;
}

class _ChatMessageRow extends StatefulWidget {
  const _ChatMessageRow({
    required this.message,
    required this.settings,
    this.assets,
    this.onUserTap,
    this.onThreadTap,
    this.onMessageHold,
    this.knownUsers = const {},
    this.blockedLogins = const {},
    this.showModeration = true,
    this.onEmoteTap,
    this.onBadgeTap,
    this.showTimestamps,
    this.showReplyContext = true,
    this.pinned = false,
    this.horizontalPadding = 0,
    this.bodyKey,
    this.replyContextKey,
    this.previewPrefix,
    this.previewLines = 2,
    this.isMention = false,
    super.key,
  });

  final TwitchChatMessage message;
  final ChatPreferences settings;
  final TwitchChatAssets? assets;
  final ValueChanged<TwitchChatMessage>? onUserTap;
  final ValueChanged<TwitchChatMessage>? onThreadTap;
  final ValueChanged<TwitchChatMessage>? onMessageHold;
  final Map<String, TwitchChatMessage> knownUsers;
  final Set<String> blockedLogins;
  final bool showModeration;
  final ValueChanged<ChatAssetEmote>? onEmoteTap;
  final ValueChanged<ChatAssetBadge>? onBadgeTap;
  final bool? showTimestamps;
  final bool showReplyContext;
  final bool pinned;
  final double horizontalPadding;
  final Key? bodyKey;
  final Key? replyContextKey;
  final String? previewPrefix;
  final int previewLines;
  final bool isMention;

  @override
  State<_ChatMessageRow> createState() => _ChatMessageRowState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatMessage>("message", message));
    properties.add(DiagnosticsProperty<ChatPreferences>("settings", settings));
    properties.add(DiagnosticsProperty<TwitchChatAssets?>("assets", assets));
    properties.add(ObjectFlagProperty<Object?>.has("onUserTap", onUserTap));
    properties.add(ObjectFlagProperty<Object?>.has("onThreadTap", onThreadTap));
    properties.add(ObjectFlagProperty<Object?>.has("onMessageHold", onMessageHold));
    properties.add(DiagnosticsProperty<Map<String, TwitchChatMessage>>("knownUsers", knownUsers));
    properties.add(IterableProperty<String>("blockedLogins", blockedLogins));
    properties.add(
      FlagProperty("showModeration", value: showModeration, ifTrue: "show moderation"),
    );
    properties.add(ObjectFlagProperty<Object?>.has("onEmoteTap", onEmoteTap));
    properties.add(ObjectFlagProperty<Object?>.has("onBadgeTap", onBadgeTap));
    properties.add(
      DiagnosticsProperty<bool?>("showTimestamps", showTimestamps),
    );
    properties.add(
      FlagProperty("showReplyContext", value: showReplyContext, ifTrue: "show reply context"),
    );
    properties.add(FlagProperty("pinned", value: pinned, ifTrue: "pinned message"));
    properties.add(DoubleProperty("horizontalPadding", horizontalPadding));
    properties.add(DiagnosticsProperty<Key?>("bodyKey", bodyKey));
    properties.add(DiagnosticsProperty<Key?>("replyContextKey", replyContextKey));
    properties.add(StringProperty("previewPrefix", previewPrefix));
    properties.add(IntProperty("previewLines", previewLines));
    properties.add(FlagProperty("isMention", value: isMention, ifTrue: "mentions you"));
  }
}

class _ChatMessageRowState extends State<_ChatMessageRow> {
  static final _emojiPattern = RegExp(
    r"[\p{ExtPict}\p{RI}\u{20E3}]",
    unicode: true,
  );
  final _nameTap = TapGestureRecognizer();
  final _textTaps = <String, TapGestureRecognizer>{};
  bool _holding = false;

  TwitchChatMessage get message => widget.message;
  ChatPreferences get settings => widget.settings;
  TwitchChatAssets? get assets => widget.assets;
  ValueChanged<TwitchChatMessage>? get onUserTap => widget.onUserTap;
  ValueChanged<ChatAssetEmote>? get onEmoteTap => widget.onEmoteTap;
  ValueChanged<ChatAssetBadge>? get onBadgeTap => widget.onBadgeTap;
  bool get showTimestamps => widget.showTimestamps ?? settings.showTimestamps;

  @override
  void initState() {
    super.initState();
    _nameTap.onTap = () => widget.onUserTap?.call(widget.message);
  }

  @override
  void dispose() {
    _nameTap.dispose();
    for (final recognizer in _textTaps.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  double get _fontSize =>
      settings.fontSize * settings.messageScale - (widget.previewPrefix == null ? 0 : 2);

  void _onLongPressDown(LongPressDownDetails details) {
    final box = context.findRenderObject()! as RenderBox;
    final hit = BoxHitTestResult();
    box.hitTest(hit, position: box.globalToLocal(details.globalPosition));
    final interactive =
        widget.pinned ||
        hit.path.any(
          (entry) => switch (entry.target) {
            TextSpan(:final recognizer) => recognizer != null,
            RenderSemanticsGestureHandler(:final onTap) => onTap != null,
            RenderSemanticsAnnotations(:final properties) => properties.onTap != null,
            _ => false,
          },
        );
    setState(() => _holding = !interactive);
  }

  Widget _moderatedContent(Widget child) => message.isDeleted
      ? ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0,
            0,
            0,
            0.5,
            0,
          ]),
          child: child,
        )
      : child;

  bool _enabled(ChatEmoteProvider provider) => switch (provider) {
    ChatEmoteProvider.twitch => settings.twitchEmotes,
    ChatEmoteProvider.sevenTv => settings.sevenTvEmotes,
    ChatEmoteProvider.bttv => settings.bttvEmotes,
    ChatEmoteProvider.ffz => settings.ffzEmotes,
  };

  Widget _emote(ChatAssetEmote emote) => GestureDetector(
    onTap: onEmoteTap == null ? null : () => onEmoteTap!(emote),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 24),
      child: Image.network(
        emote.urlForBrightness(Theme.of(context).brightness),
        height: _fontSize * 1.7 * settings.emoteScale,
        fit: BoxFit.contain,
        semanticLabel: emote.name,
        errorBuilder: (_, _, _) => Text(emote.name, style: TextStyle(fontSize: _fontSize)),
      ),
    ),
  );

  InlineSpan _badge(ChatAssetBadge badge) {
    final size = _fontSize * 1.2 * settings.badgeScale;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: _chatBadge(badge, size: size, onTap: onBadgeTap),
      ),
    );
  }

  void _appendText(List<InlineSpan> content, String text) {
    for (final token in RegExp(r"\s+|\S+").allMatches(text)) {
      final word = token[0]!;
      final emote = assets?.emotesByName[word];
      if (emote == null ||
          (emote.provider == ChatEmoteProvider.twitch &&
              (!message.isOwn || message.emotes.isNotEmpty)) ||
          !_enabled(emote.provider)) {
        _appendLinksAndMentions(content, word);
        continue;
      }
      final image = _emote(emote);
      if (emote.zeroWidth) {
        final gap = content.isNotEmpty && content.last is TextSpan
            ? content.last as TextSpan
            : null;
        final hadGap = gap?.text?.trim().isEmpty == true;
        var previous = content.length - (hadGap ? 2 : 1);
        if (previous >= 0 && content[previous] is TextSpan) {
          final span = content[previous] as TextSpan;
          final emoji = span.text?.characters.lastOrNull;
          if (span.recognizer == null && emoji != null && _emojiPattern.hasMatch(emoji)) {
            content[previous] = TextSpan(
              text: span.text!.substring(0, span.text!.length - emoji.length),
              style: span.style,
            );
            content.insert(
              ++previous,
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Text(
                  emoji,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: _fontSize),
                ),
              ),
            );
          }
        }
        if (previous >= 0 && content[previous] is WidgetSpan) {
          final base = content[previous] as WidgetSpan;
          content.removeRange(previous, content.length);
          content.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  base.child,
                  image,
                ],
              ),
            ),
          );
          continue;
        }
      }
      content.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: image));
    }
  }

  Widget? _chatArt() {
    final text = message.text
        .substring(_replyBodyStart(message))
        .trim()
        .replaceFirst(RegExp(r"\u034f+$"), "")
        .trim();
    if (!RegExp(r"[\u2800-\u28ff]").hasMatch(text)) {
      return null;
    }
    final tokens = text.split(RegExp(r"\s+"));
    final content = <InlineSpan>[];
    final braille =
        tokens.length >= 3 &&
        RegExp(r"[\u2801-\u28ff]").hasMatch(text) &&
        tokens.every(
          (token) =>
              token.length == tokens.first.length && RegExp(r"^[\u2800-\u28ff]+$").hasMatch(token),
        );
    if (braille) {
      content.add(TextSpan(text: tokens.join("\n")));
    } else {
      final rows = <({int indent, List<String> words})>[];
      for (final token in tokens) {
        if (RegExp(r"^\u2800{2,}$").hasMatch(token)) {
          if (rows.isNotEmpty && rows.last.words.isEmpty) {
            if (rows.length != 1) {
              return null;
            }
            rows.clear();
          }
          rows.add((indent: token.length, words: []));
        } else {
          if (rows.isEmpty) {
            return null;
          }
          rows.last.words.add(token);
        }
      }
      if (rows.length < 3 || rows.first.words.length != 1) {
        return null;
      }
      final name = rows.first.words.single;
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        if (row.words.length != index + 1 ||
            row.words.any((word) => word != name) ||
            (index > 0 && row.indent >= rows[index - 1].indent)) {
          return null;
        }
      }
      var emote = assets?.emotesByName[name];
      if (emote?.provider == ChatEmoteProvider.twitch &&
          (!message.isOwn || message.emotes.isNotEmpty)) {
        emote = null;
      }
      for (final native in message.emotes) {
        if (native.start >= 0 &&
            native.end <= message.text.length &&
            native.start < native.end &&
            message.text.substring(native.start, native.end) == name) {
          emote = ChatAssetEmote(
            id: native.id,
            name: name,
            provider: ChatEmoteProvider.twitch,
            url:
                "https://static-cdn.jtvnw.net/emoticons/v2/${Uri.encodeComponent(native.id)}/default/${Theme.of(context).brightness.name}/2.0",
          );
          break;
        }
      }
      if (emote == null || emote.zeroWidth) {
        return null;
      }
      for (var index = 0; index < rows.length; index++) {
        if (index > 0) {
          content.add(const TextSpan(text: "\n"));
        }
        for (var column = 0; column <= index; column++) {
          if (column > 0) {
            content.add(const TextSpan(text: " "));
          }
          content.add(
            _enabled(emote.provider)
                ? WidgetSpan(alignment: PlaceholderAlignment.middle, child: _emote(emote))
                : TextSpan(text: name),
          );
        }
      }
    }
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        key: ValueKey("chat_message_art-${message.id}"),
        fit: braille && tokens.first.length >= 16 ? BoxFit.fitWidth : BoxFit.scaleDown,
        alignment: braille ? Alignment.centerLeft : Alignment.center,
        child: Text.rich(
          TextSpan(children: content),
          key: widget.bodyKey,
          softWrap: false,
          textAlign: braille ? TextAlign.left : TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.4,
            fontSize: _fontSize,
            color: message.isDeleted
                ? theme.colorScheme.onSurfaceVariant
                : message.isAction
                ? _chatNameColor(message, theme.brightness)
                : null,
            fontStyle: message.isAction ? FontStyle.italic : null,
          ),
        ),
      ),
    );
  }

  void _appendLinksAndMentions(List<InlineSpan> content, String text) {
    var offset = 0;
    for (final match in RegExp(
      r"https?://\S+|"
      r"(?<![\w@.-])(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?(?![\w@-])(?::[0-9]{1,5})?(?:[/?#]\S*)?|"
      r"(?<![\w@])@[a-zA-Z0-9_]{1,25}(?![a-zA-Z0-9_])|"
      r"(?<![\w@./-])[a-zA-Z0-9_]{1,25}(?![\w@./-])",
      caseSensitive: false,
    ).allMatches(text)) {
      final token = match[0]!;
      final explicitMention = token.startsWith("@");
      final login = token.substring(explicitMention ? 1 : 0).toLowerCase();
      final knownUser = widget.knownUsers[login];
      final mention = explicitMention || knownUser != null;
      var label = mention ? token : token.replaceFirst(RegExp(r"[.,!?;:]+$"), "");
      if (!mention) {
        while (label.isNotEmpty) {
          final closing = label[label.length - 1];
          final opening = const {")": "(", "]": "[", "}": "{"}[closing];
          if (opening == null ||
              closing.allMatches(label).length <= opening.allMatches(label).length) {
            break;
          }
          label = label.substring(0, label.length - 1).replaceFirst(RegExp(r"[.,!?;:]+$"), "");
        }
      }
      final uri = mention ? null : chatLinkUri(label);
      if (!mention && uri == null) {
        continue;
      }
      content.add(TextSpan(text: text.substring(offset, match.start)));
      final user =
          knownUser ??
          TwitchChatMessage(
            id: "mention-$login",
            login: login,
            displayName: token.substring(explicitMention ? 1 : 0),
            text: "",
          );
      final recognizer = _textTaps.putIfAbsent(label, TapGestureRecognizer.new);
      recognizer.onTap = mention
          ? () => widget.onUserTap?.call(user)
          : () async {
              try {
                await ExternalUrlLauncher.open(uri!);
              } on Object catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            };
      content.add(
        (mention
                ? _paintedName(
                    user,
                    label,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      height: 1.4,
                      fontSize: _fontSize,
                      fontStyle: message.isAction ? FontStyle.italic : null,
                      fontWeight: FontWeight.w700,
                      color: _chatNameColor(user, Theme.of(context).brightness),
                    ),
                    onTap: widget.onUserTap == null ? null : recognizer.onTap,
                  )
                : null) ??
            TextSpan(
              text: label,
              style: TextStyle(
                color: message.isDeleted
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : mention
                    ? _chatNameColor(user, Theme.of(context).brightness)
                    : Theme.of(context).colorScheme.primary,
                fontWeight: mention ? FontWeight.w700 : null,
                decoration: mention ? null : TextDecoration.underline,
              ),
              recognizer: mention && widget.onUserTap == null ? null : recognizer,
            ),
      );
      content.add(TextSpan(text: token.substring(label.length)));
      offset = match.end;
    }
    content.add(TextSpan(text: text.substring(offset)));
  }

  WidgetSpan? _paintedName(
    TwitchChatMessage user,
    String label, {
    required TextStyle style,
    VoidCallback? onTap,
  }) {
    final paint = settings.sevenTvPaints && !message.isDeleted
        ? assets?.userPaintsByLogin[user.login.toLowerCase()]
        : null;
    if (paint == null) {
      return null;
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: onTap,
        child: ChatUsername(
          name: label,
          style: style,
          paint: paint,
          animated: settings.animatedPaints,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parentLogin =
        message.parentLogin ??
        (message.parentMessageId == message.threadRootId ? message.threadRootLogin : null);
    final nameColor = message.isDeleted
        ? theme.colorScheme.onSurfaceVariant
        : _chatNameColor(message, theme.brightness);
    final moderation =
        !settings.showModerationNotices ||
            !widget.showModeration ||
            message.noticeType == "moderation"
        ? null
        : switch (message.moderation) {
            TwitchChatModeration.timeout =>
              "${message.displayName} was timed out${message.timeoutSeconds == null ? '' : ' for ${message.timeoutSeconds}s'}",
            TwitchChatModeration.ban => "${message.displayName} was permanently banned",
            _ => null,
          };
    final hidden = message.isDeleted && !settings.showDeletedMessages;
    if (!_showMessage(message, settings, widget.blockedLogins) || (hidden && moderation == null)) {
      return const SizedBox.shrink();
    }
    final content = <InlineSpan>[];
    var offset = widget.previewPrefix == null ? _replyBodyStart(message) : 0;
    final media = [
      for (final emote in message.emotes) (emote.start, emote.end, emote as Object),
      for (final gif in message.gifs) (gif.start, gif.end, gif as Object),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (start, end, asset) in media) {
      if (start < offset || end > message.text.length || start >= end) {
        continue;
      }
      _appendText(content, message.text.substring(offset, start));
      final label = message.text.substring(start, end);
      content.add(
        asset is TwitchChatGif
            ? WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.previewPrefix == null ? null : 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.previewPrefix == null ? 140 : 48,
                      maxHeight: widget.previewPrefix == null ? 140 : _fontSize * 1.7,
                    ),
                    child: Image.network(
                      asset.url,
                      key: ValueKey("chat_gif-${message.id}-$start"),
                      fit: BoxFit.contain,
                      semanticLabel: label,
                      errorBuilder: (_, _, _) => Text(label, style: TextStyle(fontSize: _fontSize)),
                    ),
                  ),
                ),
              )
            : asset is TwitchChatEmote && _enabled(ChatEmoteProvider.twitch)
            ? WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _emote(
                  ChatAssetEmote(
                    id: asset.id,
                    name: label,
                    provider: ChatEmoteProvider.twitch,
                    url:
                        "https://static-cdn.jtvnw.net/emoticons/v2/${Uri.encodeComponent(asset.id)}/default/${theme.brightness.name}/2.0",
                  ),
                ),
              )
            : TextSpan(text: label),
      );
      offset = end;
    }
    _appendText(content, message.text.substring(offset));
    if (widget.previewPrefix case final prefix?) {
      return IgnorePointer(
        child: Text.rich(
          key: widget.bodyKey,
          TextSpan(text: prefix, children: content),
          maxLines: widget.previewLines,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: _fontSize,
          ),
        ),
      );
    }
    final art = hidden ? null : _chatArt();
    final recordedAt = message.offsetSeconds;
    final time = message.timestamp?.toLocal();
    final timestamp = recordedAt != null
        ? "${recordedAt ~/ 60}:${(recordedAt.toInt() % 60).toString().padLeft(2, "0")}"
        : time == null
        ? null
        : "${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}";
    final firstMessage = settings.highlightFirstMessages && message.isFirstMessage;
    final notice =
        message.noticeText ??
        (message.isHighlighted
            ? "Highlighted message"
            : message.noticeType == "announcement"
            ? "Announcement"
            : null);
    final system = message.noticeType == "system";
    final highlighted =
        firstMessage ||
        message.isHighlighted ||
        (settings.highlightMentions && widget.isMention) ||
        (notice != null && !system);
    final watchStreak = message.noticeType == "watch-streak";
    final subscription =
        !message.isPrivate &&
        switch (message.noticeType) {
          null || "announcement" || "raid" || "moderation" || "system" => false,
          _ => true,
        };
    final gift = subscription && message.noticeType!.contains("gift");
    final anonymousGift = gift && message.noticeType!.startsWith("anon");
    final noticeImage = message.noticeType == "channel-points"
        ? (_featuredSeasonalAndGiftsSvg, "Channel points")
        : message.isPrimeSubscription
        ? (_crownSvg, "Prime subscription")
        : watchStreak
        ? (_modeHeatSvg, "Watch streak")
        : anonymousGift
        ? (_dominoMaskSvg, "Anonymous gift")
        : null;
    final nameSeparator = widget.pinned
        ? ""
        : message.isAction
        ? " "
        : ": ";
    final paintedSender = _paintedName(
      message,
      message.displayName,
      style:
          (widget.pinned
                  ? theme.textTheme.bodySmall!
                  : theme.textTheme.bodyMedium!.copyWith(height: 1.4))
              .copyWith(
                fontSize: _fontSize - (widget.pinned ? 2 : 0),
                fontWeight: FontWeight.w700,
                color: nameColor,
              ),
      onTap: onUserTap == null ? null : _nameTap.onTap,
    );
    final sender = <InlineSpan>[
      if (settings.twitchBadges)
        for (final badge in message.badges)
          if (assets?.badgeUrls[badge] case final String url)
            _badge(
              assets?.badgesById[badge] ??
                  ChatAssetBadge(
                    id: badge,
                    title: badge.split("/").first,
                    url: url,
                    provider: ChatEmoteProvider.twitch,
                  ),
            ),
      for (final badge
          in assets?.userBadgesByLogin[message.login.toLowerCase()] ?? <ChatAssetBadge>[])
        if (switch (badge.provider) {
          ChatEmoteProvider.twitch => settings.twitchBadges,
          ChatEmoteProvider.sevenTv => settings.sevenTvBadges,
          ChatEmoteProvider.bttv => settings.bttvBadges,
          ChatEmoteProvider.ffz => settings.ffzBadges,
        })
          _badge(badge),
      ?paintedSender,
      TextSpan(
        text: "${paintedSender == null ? message.displayName : ''}$nameSeparator",
        style: TextStyle(color: nameColor, fontWeight: FontWeight.w700),
        recognizer: onUserTap == null ? null : _nameTap,
      ),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressDown: widget.onMessageHold == null ? null : _onLongPressDown,
      onLongPressCancel: widget.onMessageHold == null
          ? null
          : () => setState(() => _holding = false),
      onLongPressEnd: widget.onMessageHold == null ? null : (_) => setState(() => _holding = false),
      onLongPress: widget.onMessageHold == null
          ? null
          : () async {
              final startedOnControl = !_holding;
              setState(() => _holding = true);
              unawaited(HapticFeedback.selectionClick());
              if (startedOnControl) {
                await Future<void>.delayed(const Duration(milliseconds: 150));
              }
              if (mounted) {
                widget.onMessageHold?.call(message);
              }
            },
      child: AnimatedContainer(
        key: ValueKey("chat_message_highlight-${message.id}"),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(vertical: widget.pinned ? 0 : settings.messageSpacing / 2),
        padding: widget.horizontalPadding == 0
            ? highlighted
                  ? const EdgeInsets.all(6)
                  : EdgeInsets.zero
            : EdgeInsets.fromLTRB(
                widget.horizontalPadding - (highlighted ? 3 : 0),
                highlighted ? 6 : 0,
                widget.horizontalPadding,
                highlighted ? 6 : 0,
              ),
        decoration: _holding || highlighted
            ? BoxDecoration(
                color: _holding
                    ? theme.colorScheme.primary.withValues(alpha: 0.18)
                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                border: highlighted
                    ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 3))
                    : null,
              )
            : const BoxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _moderatedContent(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isPrivate)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: _fontSize - 2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "Only visible to you",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.showReplyContext && message.parentMessageId != null && !hidden)
                    InkWell(
                      key: ValueKey("reply-context-${message.id}"),
                      onTap: widget.onThreadTap == null ? null : () => widget.onThreadTap!(message),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.flip(
                              flipX: true,
                              flipY: true,
                              child: Icon(
                                Icons.format_quote_rounded,
                                size: _fontSize + 2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: widget.blockedLogins.contains(parentLogin?.toLowerCase())
                                  ? Text(
                                      "Blocked message",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: _fontSize - 2,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : _ChatMessageRow(
                                      message: TwitchChatMessage(
                                        id: message.parentMessageId!,
                                        login: parentLogin ?? "",
                                        displayName:
                                            message.parentDisplayName ?? parentLogin ?? "Reply",
                                        text: message.parentText ?? "View thread",
                                        emotes: message.parentEmotes,
                                        gifs: message.parentGifs,
                                        isOwn:
                                            widget.knownUsers[parentLogin?.toLowerCase()]?.isOwn ??
                                            false,
                                      ),
                                      settings: settings,
                                      assets: assets,
                                      knownUsers: widget.knownUsers,
                                      blockedLogins: widget.blockedLogins,
                                      bodyKey: widget.replyContextKey,
                                      previewPrefix:
                                          "${message.parentDisplayName ?? parentLogin ?? 'Reply'}: ",
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (firstMessage)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome, size: _fontSize),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text("First-time chatter", style: theme.textTheme.labelSmall),
                        ),
                      ],
                    ),
                  if (notice != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (noticeImage != null ||
                            subscription ||
                            message.noticeType == "announcement") ...[
                          if (noticeImage != null)
                            SvgPicture.string(
                              noticeImage.$1,
                              width: _fontSize,
                              height: _fontSize,
                              colorFilter: ColorFilter.mode(
                                theme.colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                              semanticsLabel: noticeImage.$2,
                            )
                          else
                            Icon(
                              message.noticeType == "announcement"
                                  ? Icons.campaign
                                  : gift
                                  ? Icons.redeem
                                  : Icons.star_rounded,
                              size: _fontSize,
                            ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            message.text.isEmpty && showTimestamps && timestamp != null
                                ? "$timestamp $notice"
                                : notice,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: _fontSize - 2,
                              color: system ? theme.colorScheme.onSurfaceVariant : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (message.text.isNotEmpty && !hidden && (!widget.pinned || art == null))
                    Text.rich(
                      TextSpan(
                        children: [
                          if (!widget.pinned && showTimestamps && timestamp != null)
                            TextSpan(
                              text: "$timestamp ",
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: _fontSize - 2,
                              ),
                            ),
                          if (!widget.pinned) ...sender,
                          if (art == null)
                            TextSpan(
                              children: content,
                              style: TextStyle(
                                color: message.isDeleted
                                    ? theme.colorScheme.onSurfaceVariant
                                    : message.isAction
                                    ? nameColor
                                    : null,
                                fontStyle: message.isAction ? FontStyle.italic : null,
                              ),
                            ),
                        ],
                      ),
                      key: art == null ? widget.bodyKey : null,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, fontSize: _fontSize),
                    ),
                  ?art,
                  if (widget.pinned && !hidden)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            ...sender,
                            if (time != null)
                              TextSpan(
                                text:
                                    " sent at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}",
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: _fontSize - 2),
                      ),
                    ),
                ],
              ),
            ),
            if (moderation != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  moderation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: _fontSize - 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatMessage>("message", message));
    properties.add(DiagnosticsProperty<ChatPreferences>("settings", settings));
    properties.add(DiagnosticsProperty<TwitchChatAssets?>("assets", assets));
    properties.add(ObjectFlagProperty<Object?>.has("onUserTap", onUserTap));
    properties.add(ObjectFlagProperty<Object?>.has("onEmoteTap", onEmoteTap));
    properties.add(ObjectFlagProperty<Object?>.has("onBadgeTap", onBadgeTap));
    properties.add(
      FlagProperty("showTimestamps", value: showTimestamps, ifTrue: "show timestamps"),
    );
  }
}
