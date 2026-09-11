import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class TwitchEmotePicker extends StatefulWidget {
  const TwitchEmotePicker({
    required this.assets,
    required this.preferences,
    required this.onSelected,
    super.key,
  });

  final TwitchChatAssets assets;
  final FlowPreferences preferences;
  final ValueChanged<ChatAssetEmote> onSelected;

  @override
  State<TwitchEmotePicker> createState() => _TwitchEmotePickerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChatAssets>("assets", assets));
    properties.add(DiagnosticsProperty<FlowPreferences>("preferences", preferences));
    properties.add(ObjectFlagProperty<ValueChanged<ChatAssetEmote>>.has("onSelected", onSelected));
  }
}

class _TwitchEmotePickerState extends State<TwitchEmotePicker> {
  ChatEmoteProvider? _provider;
  ChatEmoteScope _scope = ChatEmoteScope.channel;
  List<ChatAssetEmote> _recent = [];
  late Future<List<ChatAssetEmote>> _recentLoad;
  Future<void> _save = Future.value();

  @override
  void initState() {
    super.initState();
    widget.assets.addListener(_changed);
    _recentLoad = _loadRecent();
  }

  @override
  void didUpdateWidget(TwitchEmotePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assets != widget.assets) {
      oldWidget.assets.removeListener(_changed);
      widget.assets.addListener(_changed);
      if (_scope == ChatEmoteScope.unlocked) {
        unawaited(widget.assets.loadUnlockedEmotes());
      } else {
        _loadRecentTwitchEmotes();
      }
    }
    if (oldWidget.preferences != widget.preferences) {
      _recent = [];
      _recentLoad = _loadRecent();
    }
  }

  void _changed() => setState(() {});

  Future<List<ChatAssetEmote>> _loadRecent() async {
    final preferences = widget.preferences;
    try {
      final stored = await preferences.readRecentChatEmotes();
      final loaded = stored.map(_decode).whereType<ChatAssetEmote>().toList();
      if (widget.preferences != preferences) {
        return loaded;
      }
      final seen = <String>{};
      _recent = [
        ..._recent,
        ...loaded,
      ].where((emote) => seen.add(_key(emote))).take(40).toList();
      if (mounted) {
        setState(() {});
        _loadRecentTwitchEmotes();
      }
      return loaded;
    } on Object {
      // The picker remains usable if stored recents are unavailable.
      return const [];
    }
  }

  static String _key(ChatAssetEmote emote) => "${emote.provider.name}:${emote.id}:${emote.name}";

  void _loadRecentTwitchEmotes() {
    if (_recent.any((emote) => emote.provider == ChatEmoteProvider.twitch)) {
      unawaited(widget.assets.loadUnlockedEmotes());
    }
  }

  List<ChatAssetEmote> get _availableRecent {
    final available = {
      for (final emote in widget.assets.emotesByName.values)
        if (emote.provider != ChatEmoteProvider.twitch) _key(emote): emote,
      for (final scope in [ChatEmoteScope.global, ChatEmoteScope.unlocked])
        for (final emote in widget.assets.emotesFor(ChatEmoteProvider.twitch, scope))
          _key(emote): emote,
    };
    return [for (final emote in _recent) ?available[_key(emote)]];
  }

  static ChatAssetEmote? _decode(String encoded) {
    try {
      final data = jsonDecode(encoded) as Map<String, Object?>;
      final provider = ChatEmoteProvider.values
          .where((value) => value.name == data["provider"])
          .firstOrNull;
      final name = data["name"] as String?;
      final id = data["id"] as String?;
      final url = data["url"] as String?;
      final uri = url == null ? null : Uri.tryParse(url);
      if (provider == null ||
          name == null ||
          name.isEmpty ||
          id == null ||
          id.isEmpty ||
          uri?.scheme != "https" ||
          uri!.host.isEmpty) {
        return null;
      }
      return ChatAssetEmote(
        name: name,
        id: id,
        url: url!,
        provider: provider,
        zeroWidth: data["zeroWidth"] == true,
        originalName: data["originalName"] as String?,
        author: data["author"] as String?,
      );
    } on Object {
      return null;
    }
  }

  void _select(ChatAssetEmote emote) {
    setState(() {
      _recent = [emote, ..._recent.where((value) => _key(value) != _key(emote))].take(40).toList();
    });
    final preferences = widget.preferences;
    final ready = _recentLoad;
    final selected = List<ChatAssetEmote>.of(_recent);
    _save = _save
        .then((_) async {
          final loaded = await ready;
          final seen = <String>{};
          final encoded = [...selected, ...loaded]
              .where((value) => seen.add(_key(value)))
              .take(40)
              .map(
                (value) => jsonEncode({
                  "provider": value.provider.name,
                  "id": value.id,
                  "name": value.name,
                  "url": value.url,
                  if (value.zeroWidth) "zeroWidth": true,
                  if (value.originalName != null) "originalName": value.originalName,
                  if (value.author != null) "author": value.author,
                }),
              )
              .toList();
          await preferences.saveRecentChatEmotes(encoded);
        })
        .onError<Object>((_, _) {});
    widget.onSelected(emote);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = _provider;
    final unlocked = provider == ChatEmoteProvider.twitch && _scope == ChatEmoteScope.unlocked;
    final loading = unlocked ? widget.assets.isLoadingUnlocked : widget.assets.isLoading;
    final error = unlocked ? widget.assets.unlockedError : widget.assets.errors.firstOrNull;
    final emotes = provider == null ? _availableRecent : widget.assets.emotesFor(provider, _scope);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in <ChatEmoteProvider?, String>{
                    null: "Recent",
                    ChatEmoteProvider.twitch: "Twitch",
                    ChatEmoteProvider.sevenTv: "7TV",
                    ChatEmoteProvider.bttv: "BTTV",
                    ChatEmoteProvider.ffz: "FFZ",
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        labelStyle: theme.textTheme.labelMedium,
                        labelPadding: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        selected: provider == entry.key,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() {
                            _provider = entry.key;
                            _scope = ChatEmoteScope.channel;
                          });
                          if (entry.key == null) {
                            _loadRecentTwitchEmotes();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (provider != null)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final scope in ChatEmoteScope.values)
                      if (scope != ChatEmoteScope.unlocked || provider == ChatEmoteProvider.twitch)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ChoiceChip(
                            labelStyle: theme.textTheme.labelMedium,
                            labelPadding: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            label: Text(switch (scope) {
                              ChatEmoteScope.channel => "Channel",
                              ChatEmoteScope.global => "Global",
                              ChatEmoteScope.unlocked => "Unlocked",
                            }),
                            selected: _scope == scope,
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() => _scope = scope);
                              if (scope == ChatEmoteScope.unlocked) {
                                unawaited(widget.assets.loadUnlockedEmotes());
                              }
                            },
                          ),
                        ),
                  ],
                ),
              ),
            ),
          if (provider != null && loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (emotes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider == null
                            ? "Emotes you use will appear here."
                            : loading
                            ? "Loading emotes…"
                            : error ?? "No emotes available.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (provider != null && !loading && error != null)
                        TextButton(
                          onPressed: () => unawaited(
                            unlocked ? widget.assets.loadUnlockedEmotes() : widget.assets.refresh(),
                          ),
                          child: const Text("Retry"),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottomPadding),
              sliver: SliverGrid.builder(
                key: ValueKey("${provider?.name ?? "recent"}:${_scope.name}"),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  mainAxisExtent: 80,
                ),
                itemCount: emotes.length,
                itemBuilder: (context, index) {
                  final emote = emotes[index];
                  return Tooltip(
                    message: emote.originalName == null
                        ? emote.name
                        : "${emote.name}\nOriginal name: ${emote.originalName}",
                    child: InkWell(
                      onTap: () => _select(emote),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            Expanded(
                              child: Image.network(
                                emote.urlForBrightness(theme.brightness),
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                            Text(
                              emote.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.assets.removeListener(_changed);
    super.dispose();
  }
}
