import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_vod_chat.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/shared/chat_links.dart";
import "package:flow/shared/external_url_opener.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
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
    this.controller,
    this.replayController,
    this.assets,
    this.preferences,
    this.settingsStore,
    this.onOpenSettings,
    this.onReportUser,
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
  final bool chatOnly;
  final bool isLive;
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
    properties.add(DoubleProperty("topPadding", topPadding));
    properties.add(IntProperty("latencyMs", latencyMs));
    properties.add(FlagProperty("chatOnly", value: chatOnly, ifTrue: "chat only"));
    properties.add(FlagProperty("isLive", value: isLive, ifTrue: "live"));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onToggleChatOnly", onToggleChatOnly));
  }
}

class _TwitchChatPanelState extends State<TwitchChatPanel> {
  final _draft = TextEditingController();
  final _draftFocus = FocusNode();
  final _scroll = ScrollController();
  final _sheets = <Route<Object?>>{};
  final _blockedLogins = <String>{};
  AppSettingsStore? _settingsStore;
  AppSettingsStore? _fallbackSettingsStore;
  ReactionDisposer? _settingsReaction;
  ChatPreferences _settings = const ChatPreferences();
  bool _following = true;
  bool _sending = false;
  int _receivedWhenPaused = 0;
  TwitchChatMessage? _replyTo;
  String? _dismissedPinId;
  String? _minimizedPinId;
  Timer? _delayTimer;
  List<TwitchChatMessage>? _pausedMessages;
  List<TwitchChatMessage> _presentedMessages = [];

  @override
  void initState() {
    super.initState();
    widget._source.addListener(_chatChanged);
    widget.assets?.addListener(_chatChanged);
    _scroll.addListener(_scrolled);
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
      _closeSheets();
      oldWidget._source.removeListener(_chatChanged);
      widget._source.addListener(_chatChanged);
      _draft.clear();
      _sending = false;
      _following = true;
      _pausedMessages = null;
      _replyTo = null;
      _dismissedPinId = null;
      _minimizedPinId = null;
      _scrollToLatest();
    }
    if (oldWidget.assets != widget.assets) {
      oldWidget.assets?.removeListener(_chatChanged);
      widget.assets?.addListener(_chatChanged);
    }
  }

  @override
  void dispose() {
    _settingsReaction?.call();
    widget._source.removeListener(_chatChanged);
    widget.assets?.removeListener(_chatChanged);
    _draft.dispose();
    _draftFocus.dispose();
    _delayTimer?.cancel();
    _scroll.dispose();
    _closeSheets();
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
    Route<Object?>? route;
    try {
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          route = ModalRoute.of<Object?>(context);
          if (route != null) {
            _sheets.add(route!);
          }
          return builder(context);
        },
      );
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
    _settingsReaction = reaction<ChatPreferences>(
      (_) => store.chatPreferences,
      (settings) => setState(() => _settings = settings),
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
    final delay = widget.controller == null
        ? Duration.zero
        : Duration(
            milliseconds: _settings.autoSyncChat
                ? widget.latencyMs ?? 0
                : (_settings.manualChatDelaySeconds * 1000).round(),
          );
    final source = widget.controller == null
        ? widget.replayController!.messages
        : delay == Duration.zero
        ? widget.controller!.messages
        : widget.controller!.recentHistory;
    final now = DateTime.now();
    Duration? nextUpdate;
    final ready = source.where((message) {
      if (message.isOwn || message.timestamp == null || delay == Duration.zero) {
        return true;
      }
      final remaining = message.timestamp!.add(delay).difference(now);
      if (remaining <= Duration.zero) {
        return true;
      }
      if (nextUpdate == null || remaining < nextUpdate!) {
        nextUpdate = remaining;
      }
      return false;
    }).toList();
    final messages = ready.length > 300 ? ready.sublist(ready.length - 300) : ready;
    _delayTimer?.cancel();
    if (nextUpdate != null) {
      _delayTimer = Timer(nextUpdate!, _chatChanged);
    }
    final paused = _pausedMessages;
    final byId = {
      for (final message in widget.controller?.recentHistory ?? source) message.id: message,
    };
    _presentedMessages =
        (paused == null ? messages : paused.map((message) => byId[message.id] ?? message)).where((
          message,
        ) {
          if (_blockedLogins.contains(message.login.toLowerCase())) {
            return false;
          }
          if (!_showMessage(message, _settings)) {
            return false;
          }
          return switch (message.noticeType) {
            "moderation" => true,
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
      if (mounted && _following && _scroll.hasClients) {
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
    setState(() => _sending = true);
    final replyTo = _replyTo;
    try {
      final sent = await controller.send(text, replyTo: replyTo);
      if (mounted && controller == widget.controller && sent) {
        if (_draft.text == text) {
          _draft.clear();
          if (_replyTo == replyTo) {
            _replyTo = null;
          }
        }
        _following = true;
        _pausedMessages = null;
        _scrollToLatest();
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
                  widget.chatOnly ? Icons.play_arrow_rounded : Icons.chat_bubble_outline_rounded,
                ),
                title: Text(widget.chatOnly ? "Show video" : "Chat only"),
                onTap: () => Navigator.pop(context, _ChatAction.video),
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

  Future<void> _showChatters() async {
    final login = widget.assets?.channelLogin ?? widget.controller?.channel;
    if (login == null) {
      return;
    }
    final loader = widget.controller?.clientLoader ?? widget.replayController!.clientLoader;
    Future<TwitchChatters> load() async => (await loader()).fetchChatters(login);
    Future<TwitchChatters>? chatters;
    await _showSheet<void>(
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: StatefulBuilder(
            builder: (context, setSheetState) => FutureBuilder<TwitchChatters>(
              future: chatters ??= load(),
              builder: (context, snapshot) {
                final result = snapshot.data;
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Could not load chatters"),
                        TextButton(
                          onPressed: () => setSheetState(() => chatters = null),
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  );
                }
                if (result == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    Text(
                      "Chatters · ${result.count}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (result.groups.values.fold(0, (count, names) => count + names.length) <
                        result.count)
                      Text(
                        "Showing ${result.groups.values.fold(0, (count, names) => count + names.length)} names returned by Twitch",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 16),
                    for (final group in result.groups.entries)
                      if (group.value.isNotEmpty) ...[
                        Text(
                          switch (group.key) {
                            "broadcasters" => "Broadcasters",
                            "moderators" => "Moderators",
                            "vips" => "VIPs",
                            "staff" => "Staff",
                            "viewers" => "Viewers",
                            _ => group.key,
                          },
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        for (final login in group.value)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(login),
                          ),
                        const SizedBox(height: 16),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    await widget.onOpenSettings?.call();
  }

  List<TwitchChatMessage> get _history =>
      widget.controller?.recentHistory ?? widget.replayController!.messages;

  Map<String, TwitchChatMessage> get _knownUsers => {
    for (final message in _history) message.login.toLowerCase(): message,
  };

  void _reply(TwitchChatMessage message) {
    setState(() {
      _replyTo = message.text.isEmpty ? null : message;
      _draft.text = "@${message.login} ${_draft.text}";
      _draft.selection = TextSelection.collapsed(offset: _draft.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _draftFocus.requestFocus();
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
                settings: _settings,
                assets: widget.assets,
                knownUsers: _knownUsers,
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
                enabled: widget.controller != null && message.login.isNotEmpty,
                onTap: () => Navigator.pop(context, _ChatMessageAction.reply),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted || source != widget._source) {
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
    _draftFocus.requestFocus();
  }

  Future<void> _showThread(TwitchChatMessage message, {bool pinned = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final loader = widget.controller?.clientLoader ?? widget.replayController!.clientLoader;
    await _showSheet<void>(
      builder: (context) => _ChatThreadSheet(
        message: message,
        title: pinned ? "Pinned message" : "Reply thread",
        source: widget._source,
        messages: () => _history,
        loadHistory: () async => (await loader()).fetchChatReplyThread(
          message.threadRootId ?? message.parentMessageId ?? message.id,
        ),
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
    Future<TwitchUser?> loadUser() async => (await loader()).fetchChatUser(
      userId: message.userId,
      login: message.login,
    );
    final profile = loadUser().onError((Object error, StackTrace stackTrace) => null);
    await _showSheet<void>(
      builder: (context) => _ChatUserSheet(
        message: message,
        profile: profile,
        source: widget._source,
        messages: () => controller?.recentHistory ?? widget.replayController!.messages,
        settings: () => _settings,
        assets: widget.assets,
        onEmoteTap: (emote) => unawaited(_showEmote(emote)),
        onBadgeTap: (badge) => unawaited(_showBadge(badge)),
        onUserTap: (message) => unawaited(_showUser(message)),
        onThreadTap: (message) => unawaited(_showThread(message)),
        onMessageHold: (message) => unawaited(_showMessageActions(message)),
        onMore: () => unawaited(_userActions(message, profile)),
        onReply: controller == null
            ? null
            : () {
                _closeSheets();
                _reply(message);
              },
      ),
    );
  }

  Future<void> _userActions(TwitchChatMessage message, Future<TwitchUser?> profile) async {
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
    if (action == null || !mounted) {
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
    if (confirmed != true || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = message.userId ?? (await profile)?.id;
      if (id == null) {
        throw const FormatException("Could not find this Twitch user. Try again.");
      }
      final loader = widget.controller?.clientLoader ?? widget.replayController!.clientLoader;
      await (await loader()).blockUser(id);
      if (mounted) {
        setState(() => _blockedLogins.add(message.login.toLowerCase()));
        messenger.showSnackBar(SnackBar(content: Text("Blocked ${message.displayName}")));
      }
    } on Object catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text("Could not block user: $error")));
      }
    }
  }

  Future<void> _showEmote(ChatAssetEmote emote) => _showAsset(
    name: emote.name,
    url: emote.url,
    provider: emote.provider,
    author: emote.author,
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
    final role = pinner == null
        ? null
        : pinner.id == widget.controller?.roomState["room-id"] ||
              pinner.login.toLowerCase() == widget.controller?.channel
        ? "broadcaster/1"
        : "moderator/1";
    final badgeUrl = widget.assets?.badgeUrls[role];
    return Material(
      key: const ValueKey("chat_pinned_message"),
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        if (pinner != null) TextSpan(text: pinner.displayName),
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
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _minimizedPinId = expanded ? pin.id : null),
                  icon: Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: "Close pinned message",
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _dismissedPinId = pin.id),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26, right: 4),
              child: GestureDetector(
                onTap: () => unawaited(_showThread(pin.message, pinned: true)),
                onLongPress: expanded ? null : () => unawaited(_showMessageActions(pin.message)),
                child: expanded
                    ? _ChatMessageRow(
                        key: ValueKey("pinned-${pin.id}"),
                        message: pin.message,
                        settings: _settings,
                        assets: widget.assets,
                        knownUsers: knownUsers,
                        pinned: true,
                        showReplyContext: false,
                        onUserTap: (message) => unawaited(_showUser(message)),
                        onEmoteTap: (emote) => unawaited(_showEmote(emote)),
                        onBadgeTap: (badge) => unawaited(_showBadge(badge)),
                        onMessageHold: (message) => unawaited(_showMessageActions(message)),
                      )
                    : Text(
                        pin.message.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final replay = widget.replayController;
    final messages = _messagesForDisplay();
    final knownUsers = _knownUsers;
    final moderationNotices = _moderationNoticeIds(_history);
    final unread = (controller?.receivedMessageCount ?? 0) - _receivedWhenPaused;
    final pinned = controller?.pinnedChat;
    final status = controller?.status ?? replay!.status;
    final error = controller?.error ?? replay?.error;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final connected = status == TwitchChatStatus.connected;
    final connectionMessage = switch (status) {
      TwitchChatStatus.connecting =>
        replay == null ? "Connecting to chat…" : "Loading chat replay…",
      TwitchChatStatus.reconnecting =>
        replay == null ? "Reconnecting to chat…" : "Reconnecting to chat replay…",
      _ => null,
    };
    final hint = !connected
        ? connectionMessage ?? "Chat disconnected"
        : controller?.isSignedIn != true
        ? "Sign in from Following to chat"
        : controller?.canSend != true
        ? "Sign in again to enable chat"
        : "Send a message";
    final hasDraft = _draft.text.trim().isNotEmpty;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: widget.topPadding),
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    if (pinned != null && pinned.id != _dismissedPinId)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.6),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: _pinnedChat(pinned, knownUsers),
                        ),
                      ),
                    Expanded(
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
                          ListView.builder(
                            key: const ValueKey("chat_messages"),
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) => _ChatMessageRow(
                              key: ValueKey(messages[messages.length - index - 1].id),
                              message: messages[messages.length - index - 1],
                              settings: _settings,
                              assets: widget.assets,
                              knownUsers: knownUsers,
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
                          if (!_following)
                            Positioned(
                              bottom: 8,
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
                  ],
                ),
              ),
            ),
          ),
          if (replay != null && messages.isNotEmpty && connectionMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  connectionMessage,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Semantics(
                liveRegion: true,
                child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: colors.error)),
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
                    child: Text(
                      "Replying to ${message.displayName}: ${message.text}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
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
          SafeArea(
            top: false,
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
                            enabled: controller.canSend,
                            textInputAction: TextInputAction.send,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 500,
                            decoration: InputDecoration(hintText: hint, counterText: ""),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => unawaited(_send()),
                          ),
                  ),
                  if (hasDraft && controller != null)
                    IconButton(
                      key: const ValueKey("chat_send"),
                      tooltip: "Send message",
                      onPressed: controller.canSend && !_sending ? () => unawaited(_send()) : null,
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
    );
  }
}

class _ChatUserSheet extends StatefulWidget {
  const _ChatUserSheet({
    required this.message,
    required this.profile,
    required this.source,
    required this.messages,
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
        _history[message.id] = message;
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
    final logs = _history.values.where((message) => _showMessage(message, settings)).toList();
    final knownUsers = {
      for (final message in widget.messages()) message.login.toLowerCase(): message,
    };
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
                return ListTile(
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
                  title: Text(profile?.displayName ?? widget.message.displayName),
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
                  settings: settings,
                  assets: widget.assets,
                  showTimestamps: true,
                  knownUsers: knownUsers,
                  showModeration: moderationNotices.contains(logs[index].id),
                  onUserTap: widget.onUserTap,
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

bool _showMessage(TwitchChatMessage message, ChatPreferences settings) =>
    settings.showDeletedMessages ||
    !message.isDeleted ||
    message.moderation == TwitchChatModeration.timeout ||
    message.moderation == TwitchChatModeration.ban;

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
            final history = {
              for (final item in snapshot.data ?? <TwitchChatMessage>[]) item.id: item,
              ..._retained,
              for (final item in widget.messages()) item.id: item,
            };
            history.putIfAbsent(message.id, () => message);
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
                  login: message.parentLogin ?? message.threadRootLogin ?? "",
                  displayName:
                      message.parentDisplayName ?? message.parentLogin ?? "Original message",
                  userId: message.parentUserId,
                  text: message.parentText ?? "Original message is unavailable",
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
            final thread = members.where((item) => _showMessage(item, preferences)).toList();
            // A parent supplied by Twitch can predate the retained session history.
            final parentIndex = thread.indexWhere((item) => item.id == message.parentMessageId);
            final replyIndex = thread.indexWhere((item) => item.id == message.id);
            if (parentIndex > replyIndex && replyIndex >= 0) {
              thread.insert(replyIndex, thread.removeAt(parentIndex));
            }
            final rootIndex = thread.indexWhere((item) => item.id == root);
            if (rootIndex > 0) {
              thread.insert(0, thread.removeAt(rootIndex));
            }
            final knownUsers = {for (final item in history.values) item.login.toLowerCase(): item};
            final moderationNotices = _moderationNoticeIds(thread);
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
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
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
                    itemBuilder: (context, index) => Row(
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
                            settings: preferences,
                            assets: widget.assets,
                            knownUsers: knownUsers,
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
              ],
            );
          },
        ),
      ),
    ),
  );
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
    this.showModeration = true,
    this.onEmoteTap,
    this.onBadgeTap,
    this.showTimestamps,
    this.showReplyContext = true,
    this.pinned = false,
    super.key,
  });

  final TwitchChatMessage message;
  final ChatPreferences settings;
  final TwitchChatAssets? assets;
  final ValueChanged<TwitchChatMessage>? onUserTap;
  final ValueChanged<TwitchChatMessage>? onThreadTap;
  final ValueChanged<TwitchChatMessage>? onMessageHold;
  final Map<String, TwitchChatMessage> knownUsers;
  final bool showModeration;
  final ValueChanged<ChatAssetEmote>? onEmoteTap;
  final ValueChanged<ChatAssetBadge>? onBadgeTap;
  final bool? showTimestamps;
  final bool showReplyContext;
  final bool pinned;

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
  }
}

class _ChatMessageRowState extends State<_ChatMessageRow> {
  final _nameTap = TapGestureRecognizer();
  final _textTaps = <String, TapGestureRecognizer>{};

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

  double get _fontSize => settings.fontSize * settings.messageScale;

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
        emote.url,
        height: _fontSize * 1.7 * settings.emoteScale,
        fit: BoxFit.contain,
        semanticLabel: emote.name,
        errorBuilder: (_, _, _) => Text(emote.name, style: TextStyle(fontSize: _fontSize)),
      ),
    ),
  );

  InlineSpan _badge(ChatAssetBadge badge) {
    final size = _fontSize * 1.2 * settings.badgeScale;
    final color = int.tryParse(badge.color?.replaceFirst("#", "") ?? "", radix: 16);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: GestureDetector(
          onTap: onBadgeTap == null ? null : () => onBadgeTap!(badge),
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
        ),
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
        final previous = content.length - (hadGap ? 2 : 1);
        if (previous >= 0 && content[previous] is WidgetSpan) {
          final base = content[previous] as WidgetSpan;
          content.removeRange(previous, content.length);
          content.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  base.child,
                  Positioned.fill(child: image),
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

  void _appendLinksAndMentions(List<InlineSpan> content, String text) {
    var offset = 0;
    for (final match in RegExp(
      r"https?://\S+|"
      r"(?<![\w@.-])(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?(?![\w@-])(?::[0-9]{1,5})?(?:[/?#]\S*)?|"
      r"(?<![\w@])@[a-zA-Z0-9_]{1,25}(?![a-zA-Z0-9_])",
      caseSensitive: false,
    ).allMatches(text)) {
      content.add(TextSpan(text: text.substring(offset, match.start)));
      final token = match[0]!;
      final mention = token.startsWith("@");
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
        content.add(TextSpan(text: token));
        offset = match.end;
        continue;
      }
      final login = mention ? token.substring(1).toLowerCase() : "";
      final user =
          widget.knownUsers[login] ??
          TwitchChatMessage(
            id: "mention-$login",
            login: login,
            displayName: token.substring(mention ? 1 : 0),
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
        TextSpan(
          text: label,
          style: TextStyle(
            color: mention
                ? _nameColor(user, Theme.of(context).brightness)
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

  Color _nameColor(TwitchChatMessage message, Brightness brightness) {
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
    final hash = message.login.runes.fold(0, (value, rune) => (value * 31 + rune) & 0x7fffffff);
    final useGrey =
        colorValue != null &&
        [colorValue >> 16, (colorValue >> 8) & 0xFF, colorValue & 0xFF].every(
          (channel) => brightness == Brightness.light ? channel >= 245 : channel <= 10,
        );
    return Color(
      useGrey
          ? 0xFF808080
          : colorValue == null
          ? defaults[hash % defaults.length]
          : 0xFF000000 | colorValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameColor = _nameColor(message, theme.brightness);
    final moderation = !widget.showModeration || message.noticeType == "moderation"
        ? null
        : switch (message.moderation) {
            TwitchChatModeration.timeout =>
              "${message.displayName} was timed out${message.timeoutSeconds == null ? '' : ' for ${message.timeoutSeconds}s'}",
            TwitchChatModeration.ban => "${message.displayName} was permanently banned",
            _ => null,
          };
    final hidden = message.isDeleted && !settings.showDeletedMessages;
    if (hidden && moderation == null) {
      return const SizedBox.shrink();
    }
    final content = <InlineSpan>[];
    var offset = 0;
    for (final emote in message.emotes) {
      if (emote.start < offset || emote.end > message.text.length || emote.start >= emote.end) {
        continue;
      }
      _appendText(content, message.text.substring(offset, emote.start));
      final label = message.text.substring(emote.start, emote.end);
      content.add(
        _enabled(ChatEmoteProvider.twitch)
            ? WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _emote(
                  ChatAssetEmote(
                    id: emote.id,
                    name: label,
                    provider: ChatEmoteProvider.twitch,
                    url:
                        "https://static-cdn.jtvnw.net/emoticons/v2/${Uri.encodeComponent(emote.id)}/default/${theme.brightness.name}/2.0",
                  ),
                ),
              )
            : TextSpan(text: label),
      );
      offset = emote.end;
    }
    _appendText(content, message.text.substring(offset));
    final recordedAt = message.offsetSeconds;
    final time = message.timestamp?.toLocal();
    final timestamp = recordedAt != null
        ? "${recordedAt ~/ 60}:${(recordedAt.toInt() % 60).toString().padLeft(2, "0")}"
        : time == null
        ? null
        : "${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}";
    final firstMessage = settings.highlightFirstMessages && message.isFirstMessage;
    final notice =
        message.noticeText ?? (message.noticeType == "announcement" ? "Announcement" : null);
    final subscription = switch (message.noticeType) {
      null || "announcement" || "raid" || "moderation" => false,
      _ => true,
    };
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
      for (final badge in assets?.userBadgesByLogin[message.login] ?? <ChatAssetBadge>[])
        if (switch (badge.provider) {
          ChatEmoteProvider.twitch => settings.twitchBadges,
          ChatEmoteProvider.sevenTv => settings.sevenTvBadges,
          ChatEmoteProvider.bttv => settings.bttvBadges,
          ChatEmoteProvider.ffz => settings.ffzBadges,
        })
          _badge(badge),
      TextSpan(
        text:
            "${message.displayName}${widget.pinned
                ? ''
                : message.isAction
                ? ' '
                : ': '}",
        style: TextStyle(color: nameColor, fontWeight: FontWeight.w700),
        recognizer: onUserTap == null ? null : _nameTap,
      ),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: widget.onMessageHold == null ? null : () => widget.onMessageHold!(message),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: settings.messageSpacing / 2),
        padding: firstMessage || notice != null ? const EdgeInsets.all(6) : EdgeInsets.zero,
        decoration: firstMessage || notice != null
            ? BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showReplyContext && message.parentMessageId != null && !hidden)
              InkWell(
                key: ValueKey("reply-context-${message.id}"),
                onTap: widget.onThreadTap == null ? null : () => widget.onThreadTap!(message),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: _fontSize + 2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${message.parentDisplayName ?? message.parentLogin ?? 'Reply'}: ${message.parentText ?? 'View thread'}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: _fontSize - 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (firstMessage)
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: _fontSize),
                  const SizedBox(width: 4),
                  Expanded(child: Text("First-time chatter", style: theme.textTheme.labelSmall)),
                ],
              ),
            if (notice != null)
              Row(
                children: [
                  if (subscription) ...[
                    Icon(Icons.star_rounded, size: _fontSize),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      message.text.isEmpty && showTimestamps && timestamp != null
                          ? "$timestamp $notice"
                          : notice,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: _fontSize - 2),
                    ),
                  ),
                ],
              ),
            if (message.text.isNotEmpty && !hidden)
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
                    TextSpan(
                      children: content,
                      style: TextStyle(
                        color: message.isDeleted
                            ? theme.colorScheme.onSurfaceVariant
                            : message.isAction
                            ? nameColor
                            : null,
                        fontStyle: message.isAction ? FontStyle.italic : null,
                        decoration: message.isDeleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (message.isDeleted) const TextSpan(text: " (deleted)"),
                  ],
                ),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, fontSize: _fontSize),
              ),
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
