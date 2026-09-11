import "dart:async";
import "dart:collection";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;

enum ChatEmoteProvider { twitch, sevenTv, bttv, ffz }

enum ChatEmoteScope { channel, global, unlocked }

class ChatAssetEmote {
  const ChatAssetEmote({
    required this.name,
    required this.id,
    required this.url,
    required this.provider,
    this.zeroWidth = false,
    this.author,
    this.originalName,
  });

  final String name;
  final String id;
  final String url;
  final ChatEmoteProvider provider;
  final bool zeroWidth;
  final String? author;
  final String? originalName;

  String urlForBrightness(Brightness brightness) => provider == ChatEmoteProvider.twitch
      ? url.replaceFirst(RegExp("/(?:dark|light)/"), "/${brightness.name}/")
      : url;
}

class ChatAssetBadge {
  const ChatAssetBadge({
    required this.id,
    required this.title,
    required this.url,
    required this.provider,
    this.color,
  });

  final String id;
  final String title;
  final String url;
  final ChatEmoteProvider provider;
  final String? color;
}

enum ChatPaintLayerType { color, linearGradient, radialGradient, image }

enum ChatPaintRadialShape { circle, ellipse }

class ChatAssetPaint {
  const ChatAssetPaint({
    required this.id,
    required this.name,
    this.layers = const [],
    this.shadows = const [],
  });

  final String id;
  final String name;
  final List<ChatPaintLayer> layers;
  final List<Shadow> shadows;
}

class ChatPaintLayer {
  const ChatPaintLayer({
    required this.id,
    required this.type,
    this.opacity = 1,
    this.color,
    this.angle = 0,
    this.repeating = false,
    this.shape = ChatPaintRadialShape.ellipse,
    this.stops = const [],
    this.images = const [],
  });

  final String id;
  final ChatPaintLayerType type;
  final double opacity;
  final Color? color;
  final double angle;
  final bool repeating;
  final ChatPaintRadialShape shape;
  final List<({double at, Color color})> stops;
  final List<ChatPaintImage> images;
}

class ChatPaintImage {
  const ChatPaintImage({
    required this.url,
    required this.mime,
    this.scale = 1,
    this.width = 0,
    this.height = 0,
    this.frameCount = 1,
    this.size = 0,
  });

  final String url;
  final String mime;
  final int scale;
  final int width;
  final int height;
  final int frameCount;
  final int size;
}

class TwitchChatAssets extends ChangeNotifier {
  TwitchChatAssets({
    required this.clientLoader,
    required String channelLogin,
    this.channelId,
    http.Client? httpClient,
    bool autoLoad = true,
  }) : channelLogin = channelLogin.trim().toLowerCase(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    if (autoLoad) {
      unawaited(refresh(force: false));
    }
  }

  final TwitchApiClientLoader clientLoader;
  final String channelLogin;
  final String? channelId;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Map<String, Map<String, ChatAssetEmote>> _sources = {};
  Map<String, ChatAssetEmote> _emotesByName = const {};
  Map<String, String> _badgeUrls = const {};
  Map<String, ChatAssetBadge> _badgesById = const {};
  TwitchUser? _broadcaster;
  final Map<ChatEmoteProvider, Map<String, List<ChatAssetBadge>>> _providerBadges = {};
  Map<String, List<ChatAssetBadge>> _userBadgesByLogin = const {};
  final Map<String, ChatAssetPaint> _userPaintsByLogin = {};
  final List<String> _errors = [];
  bool _isLoading = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _deadline;
  Completer<void>? _abort;
  final Map<String, String> _observedSenders = {};
  final Map<String, String> _pendingSevenUsers = {};
  final Set<String> _sevenInFlight = {};
  Timer? _sevenTimer;
  Timer? _sevenDeadline;
  Completer<void>? _sevenAbort;
  bool _isLoadingUnlocked = false;
  String? _unlockedError;
  String? _unlockedToken;
  final Set<String> _imageQueue = {};
  final Set<String> _imagesInFlight = {};
  final Map<String, DateTime> _imageRetryAfter = {};
  bool _precaching = false;

  static final Map<String, ({DateTime expires, Map<String, ChatAssetEmote> emotes})> _emoteCache =
      {};
  static final Map<String, ({DateTime expires, TwitchNativeChatAssets assets})> _nativeCache = {};
  static final Map<ChatEmoteProvider, ({DateTime expires, Map<String, List<ChatAssetBadge>> users})>
  _badgeCache = {};
  static final Map<String, ({DateTime expires, ChatAssetBadge? badge, ChatAssetPaint? paint})>
  _sevenStyleCache = {};
  // https://github.com/SevenTV/SevenTV/blob/main/apps/website/schema.graphql
  static const _sevenStyleQuery = r"""
query($id: String!) {
  users {
    userByConnection(platform: TWITCH, platformId: $id) {
      style {
        activeBadge { id name images { url mime scale } }
        activePaint {
          id name
          data {
            layers {
              id opacity
              ty {
                __typename
                ... on PaintLayerTypeSingleColor { color { r g b a } }
                ... on PaintLayerTypeLinearGradient {
                  angle repeating stops { at color { r g b a } }
                }
                ... on PaintLayerTypeRadialGradient {
                  shape repeating stops { at color { r g b a } }
                }
                ... on PaintLayerTypeImage {
                  images { url mime scale width height frameCount size }
                }
              }
            }
            shadows { color { r g b a } offsetX offsetY blur }
          }
        }
      }
    }
  }
}
""";
  static const _sourceOrder = [
    "twitch",
    "twitch-unlocked",
    "ffz-global",
    "bttv-global",
    "7tv-global",
    "ffz-channel",
    "bttv-channel",
    "7tv-channel",
  ];

  Map<String, ChatAssetEmote> get emotesByName => _emotesByName;
  Map<String, String> get badgeUrls => _badgeUrls;
  Map<String, ChatAssetBadge> get badgesById => _badgesById;
  TwitchUser? get broadcaster => _broadcaster;
  Map<String, List<ChatAssetBadge>> get userBadgesByLogin => _userBadgesByLogin;
  Map<String, ChatAssetPaint> get userPaintsByLogin => UnmodifiableMapView(_userPaintsByLogin);
  bool get isLoading => _isLoading;
  List<String> get errors => List.unmodifiable(_errors);
  bool get isLoadingUnlocked => _isLoadingUnlocked;
  String? get unlockedError => _unlockedError;

  List<ChatAssetEmote> emotesFor(ChatEmoteProvider provider, ChatEmoteScope scope) {
    final source = switch (provider) {
      ChatEmoteProvider.twitch => "twitch",
      ChatEmoteProvider.sevenTv => "7tv",
      ChatEmoteProvider.bttv => "bttv",
      ChatEmoteProvider.ffz => "ffz",
    };
    final emotes = _sources["$source-${scope.name}"]?.values.toList() ?? <ChatAssetEmote>[];
    emotes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(emotes);
  }

  Future<void> loadUnlockedEmotes() async {
    if (_disposed || _isLoadingUnlocked) {
      return;
    }
    _isLoadingUnlocked = true;
    _unlockedError = null;
    notifyListeners();
    try {
      final client = await clientLoader();
      if (_disposed) {
        return;
      }
      if (_unlockedToken != client.gqlAccessToken) {
        _unlockedToken = client.gqlAccessToken;
        _publish("twitch-unlocked", {});
      }
      Map<String, ChatAssetEmote>? loaded;
      try {
        final native =
            _nativeCache[channelLogin]?.assets ??
            await client.fetchChatAssets(channelLogin).timeout(const Duration(seconds: 15));
        final namesById = {
          for (final entry in native.globalEmoteIdsByName.entries) entry.value: entry.key,
        };
        final emotes = await client
            .fetchUnlockedChatEmotes(channelId ?? native.channelId)
            .timeout(const Duration(seconds: 15));
        loaded = _nativeEmotes({
          for (final entry in emotes.entries) namesById[entry.value] ?? entry.key: entry.value,
        });
      } finally {
        final current = await clientLoader();
        if (!_disposed) {
          if (_unlockedToken != current.gqlAccessToken) {
            _unlockedToken = current.gqlAccessToken;
            _publish("twitch-unlocked", {});
          } else if (loaded != null) {
            _publish("twitch-unlocked", loaded);
          }
        }
      }
    } on Object {
      if (!_disposed) {
        _unlockedError = "Your unlocked Twitch emotes could not be loaded.";
      }
    } finally {
      _isLoadingUnlocked = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void precacheMessages(BuildContext context, Iterable<TwitchChatMessage> messages) {
    if (_disposed || !context.mounted) {
      return;
    }
    final brightness = Theme.of(context).brightness;
    for (final message in messages) {
      if (message.isDeleted) {
        continue;
      }
      _imageQueue.addAll(
        message.emotes.map(
          (emote) => emote.imageUrl.replaceFirst("/dark/", "/${brightness.name}/"),
        ),
      );
      for (final token in RegExp(r"\S+").allMatches(message.text)) {
        if (message.emotes.any((emote) => emote.start < token.end && emote.end > token.start)) {
          continue;
        }
        final emote = _emotesByName[token.group(0)];
        if (emote != null &&
            (emote.provider != ChatEmoteProvider.twitch ||
                (message.isOwn && message.emotes.isEmpty))) {
          _imageQueue.add(emote.urlForBrightness(brightness));
        }
      }
      _imageQueue.addAll(message.badges.map((badge) => _badgeUrls[badge]).whereType<String>());
      _imageQueue.addAll(
        (_userBadgesByLogin[message.login.toLowerCase()] ?? const []).map((badge) => badge.url),
      );
    }
    _imageRetryAfter.removeWhere((_, retryAfter) => retryAfter.isBefore(DateTime.now()));
    _imageQueue.removeAll(_imageRetryAfter.keys);
    _imageQueue.removeAll(_imagesInFlight);
    _imageQueue.removeWhere(
      (url) =>
          url.endsWith(".svg") ||
          PaintingBinding.instance.imageCache.containsKey(NetworkImage(url)),
    );
    while (_imageQueue.length > 512) {
      _imageQueue.remove(_imageQueue.first);
    }
    if (!_precaching && _imageQueue.isNotEmpty) {
      unawaited(_precacheQueued(context));
    }
  }

  Future<void> _precacheQueued(BuildContext context) async {
    _precaching = true;
    while (!_disposed && context.mounted && _imageQueue.isNotEmpty) {
      final batch = _imageQueue.take(4).toList();
      _imageQueue.removeAll(batch);
      _imagesInFlight.addAll(batch);
      await Future.wait(
        batch.map(
          (url) => precacheImage(
            NetworkImage(url),
            context,
            onError: (error, stack) {
              _imageRetryAfter[url] = DateTime.now().add(const Duration(seconds: 30));
              if (_imageRetryAfter.length > 512) {
                _imageRetryAfter.remove(_imageRetryAfter.keys.first);
              }
            },
          ),
        ),
      );
      _imagesInFlight.removeAll(batch);
    }
    _precaching = false;
  }

  Future<void> refresh({bool force = true}) async {
    if (_disposed) {
      return;
    }
    _cancel();
    final generation = ++_generation;
    final abort = Completer<void>();
    _abort = abort;
    _errors.clear();
    if (force) {
      _imageRetryAfter.clear();
      for (final id in _observedSenders.keys) {
        _sevenStyleCache.remove(id);
      }
      _queueSevenUsers();
    }
    if (!RegExp(r"^[a-z0-9_]{1,25}$").hasMatch(channelLogin)) {
      _errors.add("Channel emotes are unavailable.");
      notifyListeners();
      return;
    }
    _isLoading = true;
    _deadline = Timer(const Duration(seconds: 15), () {
      if (_isCurrent(generation)) {
        ++_generation;
        _cancel();
        _isLoading = false;
        _errors.add("Some chat images could not be loaded. Retry to load them.");
        notifyListeners();
      }
    });
    notifyListeners();
    final native = _loadNative(generation, force: force);
    final tasks = <Future<void>>[
      native.then<void>((_) {}),
      _loadBadges(
        ChatEmoteProvider.ffz,
        "https://api.frankerfacez.com/v1/badges",
        _ffzBadges,
        generation,
        abort,
        force: force,
      ),
      _loadBadges(
        ChatEmoteProvider.bttv,
        "https://api.betterttv.net/3/cached/badges",
        _bttvBadges,
        generation,
        abort,
        force: force,
      ),
      _load(
        "7tv-global",
        "https://7tv.io/v3/emote-sets/global",
        _sevenTv,
        generation,
        abort,
        force: force,
      ),
      _load(
        "bttv-global",
        "https://api.betterttv.net/3/cached/emotes/global",
        _bttv,
        generation,
        abort,
        force: force,
      ),
      _load(
        "ffz-global",
        "https://api.frankerfacez.com/v1/set/global",
        (data) => _ffz(data, global: true),
        generation,
        abort,
        force: force,
      ),
      _load(
        "ffz-channel",
        "https://api.frankerfacez.com/v1/room/$channelLogin",
        _ffz,
        generation,
        abort,
        force: force,
      ),
      () async {
        final suppliedId = channelId?.trim() ?? "";
        final id = RegExp(r"^\d+$").hasMatch(suppliedId) ? suppliedId : await native;
        if (!_isCurrent(generation) || id == null) {
          return;
        }
        await Future.wait([
          _load(
            "7tv-channel",
            "https://7tv.io/v3/users/twitch/$id",
            (data) => _map(data)?["emote_set"] == null ? {} : _sevenTv(_map(data)?["emote_set"]),
            generation,
            abort,
            force: force,
          ),
          _load(
            "bttv-channel",
            "https://api.betterttv.net/3/cached/users/twitch/$id",
            (data) => _bttv([
              ..._list(_map(data)?["channelEmotes"]),
              ..._list(_map(data)?["sharedEmotes"]),
            ]),
            generation,
            abort,
            force: force,
          ),
        ]);
      }(),
    ];
    await Future.any<void>([Future.wait(tasks).then<void>((_) {}), abort.future]);
    if (_isCurrent(generation)) {
      _deadline?.cancel();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _loadNative(int generation, {required bool force}) async {
    try {
      final cached = _nativeCache[channelLogin];
      final TwitchNativeChatAssets assets;
      final useCached = !force && cached != null && cached.expires.isAfter(DateTime.now());
      if (useCached) {
        assets = cached.assets;
      } else {
        final client = await clientLoader();
        if (!_isCurrent(generation)) {
          return null;
        }
        assets = await client.fetchChatAssets(channelLogin);
      }
      if (!_isCurrent(generation)) {
        return null;
      }
      _nativeCache[channelLogin] = (
        expires: useCached ? cached.expires : DateTime.now().add(const Duration(minutes: 10)),
        assets: assets,
      );
      if (_nativeCache.length > 16) {
        _nativeCache.remove(_nativeCache.keys.first);
      }
      _broadcaster = assets.broadcaster;
      _badgeUrls = Map.unmodifiable({
        for (final entry in assets.badgeUrls.entries) entry.key: ?_httpsUrl(entry.value),
      });
      _badgesById = Map.unmodifiable({
        for (final entry in _badgeUrls.entries)
          entry.key: ChatAssetBadge(
            id: entry.key,
            title: assets.badgeTitles[entry.key] ?? entry.key,
            url: entry.value,
            provider: ChatEmoteProvider.twitch,
          ),
      });
      _sources["twitch-global"] = _nativeEmotes(assets.globalEmoteIdsByName);
      _sources["twitch-channel"] = _nativeEmotes(assets.channelEmoteIdsByName);
      _publish("twitch", _nativeEmotes(assets.emoteIdsByName));
      return assets.channelId;
    } on Object {
      if (_isCurrent(generation)) {
        _errors.add("Twitch badges and emote names could not be loaded.");
        notifyListeners();
      }
      return null;
    }
  }

  static Map<String, ChatAssetEmote> _nativeEmotes(Map<String, String> emotes) => {
    for (final entry in emotes.entries)
      entry.key: ChatAssetEmote(
        name: entry.key,
        id: entry.value,
        url: "https://static-cdn.jtvnw.net/emoticons/v2/${entry.value}/default/dark/2.0",
        provider: ChatEmoteProvider.twitch,
      ),
  };

  Future<void> _load(
    String source,
    String url,
    Map<String, ChatAssetEmote> Function(Object? data) parse,
    int generation,
    Completer<void> abort, {
    required bool force,
  }) async {
    try {
      final cached = _emoteCache[url];
      final Map<String, ChatAssetEmote> emotes;
      final useCached = !force && cached != null && cached.expires.isAfter(DateTime.now());
      if (useCached) {
        emotes = cached.emotes;
      } else {
        final data = await _fetchJson(url, abort, allowMissing: source.endsWith("-channel"));
        emotes = data == null ? {} : parse(data);
      }
      if (!_isCurrent(generation)) {
        return;
      }
      _emoteCache[url] = (
        expires: useCached ? cached.expires : DateTime.now().add(const Duration(minutes: 10)),
        emotes: emotes,
      );
      if (_emoteCache.length > 32) {
        _emoteCache.remove(_emoteCache.keys.first);
      }
      _publish(source, emotes);
    } on Object {
      if (_isCurrent(generation)) {
        _errors.add(
          "${source.split("-").first.toUpperCase()} ${source.endsWith("global") ? "global" : "channel"} emotes could not be loaded.",
        );
        notifyListeners();
      }
    }
  }

  Future<Object?> _fetchJson(String url, Completer<void> abort, {bool allowMissing = false}) async {
    final response = await http.Response.fromStream(
      await _httpClient.send(
        http.AbortableRequest("GET", Uri.parse(url), abortTrigger: abort.future),
      ),
    );
    if (response.statusCode == 404 && allowMissing) {
      return null;
    }
    if (response.statusCode != 200) {
      throw http.ClientException("Chat image request failed (${response.statusCode}).");
    }
    return jsonDecode(response.body);
  }

  Future<void> _loadBadges(
    ChatEmoteProvider provider,
    String url,
    Map<String, List<ChatAssetBadge>> Function(Object? data) parse,
    int generation,
    Completer<void> abort, {
    required bool force,
  }) async {
    try {
      final cached = _badgeCache[provider];
      final useCached = !force && cached != null && cached.expires.isAfter(DateTime.now());
      final users = useCached ? cached.users : parse(await _fetchJson(url, abort));
      if (!_isCurrent(generation)) {
        return;
      }
      _badgeCache[provider] = (
        expires: useCached ? cached.expires : DateTime.now().add(const Duration(minutes: 30)),
        users: users,
      );
      _providerBadges[provider] = users;
      _publishUserBadges();
    } on Object {
      if (_isCurrent(generation)) {
        _errors.add("${provider.name.toUpperCase()} badges could not be loaded.");
        notifyListeners();
      }
    }
  }

  void _publishUserBadges() {
    while (_userPaintsByLogin.length > 600) {
      _userPaintsByLogin.remove(_userPaintsByLogin.keys.first);
    }
    final combined = <String, List<ChatAssetBadge>>{};
    for (final source in _providerBadges.values) {
      for (final entry in source.entries) {
        combined.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }
    _userBadgesByLogin = Map.unmodifiable({
      for (final entry in combined.entries)
        entry.key: List<ChatAssetBadge>.unmodifiable(entry.value),
    });
    notifyListeners();
  }

  void observeMessages(Iterable<TwitchChatMessage> messages) {
    if (_disposed) {
      return;
    }
    _observedSenders.clear();
    for (final message in messages) {
      final id = message.userId;
      if (id != null && RegExp(r"^\d+$").hasMatch(id)) {
        _observedSenders[id] = message.login.toLowerCase();
      }
    }
    _queueSevenUsers();
  }

  void _queueSevenUsers() {
    final badges = _providerBadges.putIfAbsent(ChatEmoteProvider.sevenTv, () => {});
    var changed = false;
    for (final sender in _observedSenders.entries) {
      final cached = _sevenStyleCache[sender.key];
      if (cached != null && cached.expires.isAfter(DateTime.now())) {
        if (cached.badge != null && badges[sender.value]?.firstOrNull != cached.badge) {
          badges[sender.value] = [cached.badge!];
          changed = true;
        } else if (cached.badge == null && badges.remove(sender.value) != null) {
          changed = true;
        }
        if (cached.paint != null && _userPaintsByLogin[sender.value] != cached.paint) {
          _userPaintsByLogin[sender.value] = cached.paint!;
          changed = true;
        } else if (cached.paint == null && _userPaintsByLogin.remove(sender.value) != null) {
          changed = true;
        }
      } else if (!_sevenInFlight.contains(sender.key)) {
        _pendingSevenUsers[sender.key] = sender.value;
      }
    }
    while (_pendingSevenUsers.length > 300) {
      _pendingSevenUsers.remove(_pendingSevenUsers.keys.first);
    }
    if (changed) {
      _publishUserBadges();
    }
    _scheduleSevenBadges(const Duration(milliseconds: 400));
  }

  void _scheduleSevenBadges(Duration delay) {
    if (!_disposed &&
        _sevenTimer == null &&
        _sevenInFlight.isEmpty &&
        _pendingSevenUsers.isNotEmpty) {
      _sevenTimer = Timer(delay, () {
        _sevenTimer = null;
        unawaited(_loadSevenBadges());
      });
    }
  }

  Future<void> _loadSevenBadges() async {
    final batch = Map<String, String>.fromEntries(_pendingSevenUsers.entries.take(30));
    if (_disposed || batch.isEmpty) {
      return;
    }
    for (final id in batch.keys) {
      _pendingSevenUsers.remove(id);
    }
    _sevenInFlight.addAll(batch.keys);
    final abort = Completer<void>();
    _sevenAbort = abort;
    _sevenDeadline = Timer(const Duration(seconds: 10), () {
      if (!abort.isCompleted) {
        abort.complete();
      }
    });
    var retryDelay = const Duration(seconds: 2);
    try {
      final request =
          http.AbortableRequest(
              "POST",
              Uri.parse("https://7tv.io/v4/gql"),
              abortTrigger: abort.future,
            )
            ..headers["Content-Type"] = "application/json"
            ..body = jsonEncode([
              for (final id in batch.keys)
                {
                  "query": _sevenStyleQuery,
                  "variables": {"id": id},
                },
            ]);
      final response = await http.Response.fromStream(await _httpClient.send(request));
      if (response.statusCode != 200) {
        throw http.ClientException("7TV badge request failed (${response.statusCode}).");
      }
      final results = _list(jsonDecode(response.body));
      if (results.length != batch.length) {
        throw const FormatException("7TV badge results are incomplete.");
      }
      final loaded = <({ChatAssetBadge? badge, ChatAssetPaint? paint})>[];
      for (final result in results) {
        final document = _map(result);
        if (document?["errors"] != null || _map(document?["data"]) == null) {
          throw const FormatException("7TV badge lookup failed.");
        }
        final user = _map(_map(_map(document?["data"])?["users"])?["userByConnection"]);
        final style = _map(user?["style"]);
        final badge = _map(style?["activeBadge"]);
        final images = _maps(badge == null ? const [] : _list(badge["images"]));
        final image =
            images
                .where((item) => item["mime"] == "image/webp" && item["scale"] == 2)
                .firstOrNull ??
            images.firstOrNull;
        final url = _httpsUrl(image?["url"]);
        loaded.add((
          badge: url == null
              ? null
              : ChatAssetBadge(
                  id: "7tv/${badge?["id"]}",
                  title: badge?["name"] as String? ?? "7TV badge",
                  url: url,
                  provider: ChatEmoteProvider.sevenTv,
                ),
          paint: _sevenPaint(style?["activePaint"]),
        ));
      }
      if (_disposed) {
        return;
      }
      final users = _providerBadges.putIfAbsent(ChatEmoteProvider.sevenTv, () => {});
      var index = 0;
      for (final entry in batch.entries) {
        final style = loaded[index++];
        _sevenStyleCache[entry.key] = (
          expires: DateTime.now().add(const Duration(minutes: 30)),
          badge: style.badge,
          paint: style.paint,
        );
        if (style.badge == null) {
          users.remove(entry.value);
        } else {
          users[entry.value] = [style.badge!];
        }
        if (style.paint == null) {
          _userPaintsByLogin.remove(entry.value);
        } else {
          _userPaintsByLogin[entry.value] = style.paint!;
        }
      }
      while (_sevenStyleCache.length > 2048) {
        _sevenStyleCache.remove(_sevenStyleCache.keys.first);
      }
      while (users.length > 600) {
        users.remove(users.keys.first);
      }
      _errors.remove("7TV badges and paints could not be loaded.");
      _publishUserBadges();
    } on Object {
      if (!_disposed) {
        _pendingSevenUsers.addAll(batch);
        retryDelay = const Duration(seconds: 30);
        if (!_errors.contains("7TV badges and paints could not be loaded.")) {
          _errors.add("7TV badges and paints could not be loaded.");
          notifyListeners();
        }
      }
    } finally {
      _sevenDeadline?.cancel();
      _sevenAbort = null;
      _sevenInFlight.clear();
      _scheduleSevenBadges(retryDelay);
    }
  }

  static ChatAssetPaint? _sevenPaint(Object? value) {
    final paint = _map(value);
    final id = paint?["id"];
    final name = paint?["name"];
    final data = _map(paint?["data"]);
    if (id is! String || id.isEmpty || name is! String || data?["layers"] is! List<Object?>) {
      return null;
    }
    final layers = <ChatPaintLayer>[];
    for (final layer in _maps(_list(data?["layers"]))) {
      final ty = _map(layer["ty"]);
      final type = switch (ty?["__typename"]) {
        "PaintLayerTypeSingleColor" => ChatPaintLayerType.color,
        "PaintLayerTypeLinearGradient" => ChatPaintLayerType.linearGradient,
        "PaintLayerTypeRadialGradient" => ChatPaintLayerType.radialGradient,
        "PaintLayerTypeImage" => ChatPaintLayerType.image,
        _ => null,
      };
      if (type == null || layer["id"] is! String) {
        continue;
      }
      final color = _paintColor(ty?["color"]);
      final stops = <({double at, Color color})>[];
      for (final stop in _maps(ty?["stops"] is List<Object?> ? _list(ty?["stops"]) : const [])) {
        final at = _paintNumber(stop["at"]);
        final color = _paintColor(stop["color"]);
        if (at != null && color != null) {
          stops.add((at: at, color: color));
        }
      }
      final images = <ChatPaintImage>[];
      for (final image in _maps(ty?["images"] is List<Object?> ? _list(ty?["images"]) : const [])) {
        final url = _httpsUrl(image["url"]);
        final mime = image["mime"];
        if (url != null && mime is String && mime.startsWith("image/")) {
          images.add(
            ChatPaintImage(
              url: url,
              mime: mime,
              scale: _int(image["scale"]),
              width: _int(image["width"]),
              height: _int(image["height"]),
              frameCount: _int(image["frameCount"]),
              size: _int(image["size"]),
            ),
          );
        }
      }
      if ((type == ChatPaintLayerType.color && color == null) ||
          ((type == ChatPaintLayerType.linearGradient ||
                  type == ChatPaintLayerType.radialGradient) &&
              stops.isEmpty) ||
          (type == ChatPaintLayerType.image && images.isEmpty)) {
        continue;
      }
      layers.add(
        ChatPaintLayer(
          id: layer["id"]! as String,
          type: type,
          opacity: (_paintNumber(layer["opacity"]) ?? 1).clamp(0, 1),
          color: color,
          angle: _paintNumber(ty?["angle"]) ?? 0,
          repeating: ty?["repeating"] == true,
          shape: ty?["shape"] == "CIRCLE"
              ? ChatPaintRadialShape.circle
              : ChatPaintRadialShape.ellipse,
          stops: List.unmodifiable(stops),
          images: List.unmodifiable(images),
        ),
      );
    }
    final shadows = <Shadow>[];
    for (final shadow in _maps(
      data?["shadows"] is List<Object?> ? _list(data?["shadows"]) : const [],
    )) {
      final color = _paintColor(shadow["color"]);
      final x = _paintNumber(shadow["offsetX"]);
      final y = _paintNumber(shadow["offsetY"]);
      final blur = _paintNumber(shadow["blur"]);
      if (color != null && x != null && y != null && blur != null && blur >= 0) {
        shadows.add(Shadow(color: color, offset: Offset(x, y), blurRadius: blur));
      }
    }
    return layers.isEmpty && shadows.isEmpty
        ? null
        : ChatAssetPaint(
            id: id,
            name: name,
            layers: List.unmodifiable(layers),
            shadows: List.unmodifiable(shadows),
          );
  }

  static double? _paintNumber(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  static Color? _paintColor(Object? value) {
    final color = _map(value);
    if (color == null ||
        ["r", "g", "b", "a"].any(
          (key) => color[key] is! int || _int(color[key]) < 0 || _int(color[key]) > 255,
        )) {
      return null;
    }
    return Color.fromARGB(_int(color["a"]), _int(color["r"]), _int(color["g"]), _int(color["b"]));
  }

  static Map<String, List<ChatAssetBadge>> _bttvBadges(Object? data) {
    final result = <String, List<ChatAssetBadge>>{};
    for (final entry in _maps(_list(data))) {
      final badge = _map(entry["badge"]);
      final url = _httpsUrl(badge?["svg"]);
      final login = entry["name"] as String?;
      if (url != null && login != null && login.isNotEmpty) {
        result
            .putIfAbsent(login.toLowerCase(), () => [])
            .add(
              ChatAssetBadge(
                id: "bttv/${badge?["type"]}",
                title: badge?["description"] as String? ?? "BetterTTV badge",
                url: url,
                provider: ChatEmoteProvider.bttv,
              ),
            );
      }
    }
    return result;
  }

  static Map<String, List<ChatAssetBadge>> _ffzBadges(Object? data) {
    final document = _map(data);
    final users = _map(document?["users"]);
    if (users == null) {
      throw const FormatException("Badge assignments are missing.");
    }
    final result = <String, List<ChatAssetBadge>>{};
    for (final badge in _maps(_list(document?["badges"]))) {
      final id = badge["id"].toString();
      final urls = _map(badge["urls"]);
      final url = _httpsUrl(urls?["2"] ?? urls?["1"] ?? badge["image"]);
      if (url == null) {
        continue;
      }
      final asset = ChatAssetBadge(
        id: "ffz/$id",
        title: badge["title"] as String? ?? "FrankerFaceZ badge",
        url: url,
        provider: ChatEmoteProvider.ffz,
        color: badge["color"] as String?,
      );
      for (final login in (users[id] as List<Object?>? ?? const []).whereType<String>()) {
        result.putIfAbsent(login.toLowerCase(), () => []).add(asset);
      }
    }
    return result;
  }

  void _publish(String source, Map<String, ChatAssetEmote> emotes) {
    _sources[source] = emotes;
    _emotesByName = Map.unmodifiable({
      for (final key in _sourceOrder) ...?_sources[key],
    });
    notifyListeners();
  }

  static Map<String, ChatAssetEmote> _sevenTv(Object? data) {
    final result = <String, ChatAssetEmote>{};
    for (final emote in _maps(_list(_map(data)?["emotes"]))) {
      final details = _map(emote["data"]);
      final owner = _map(details?["owner"]);
      final host = _map(details?["host"]);
      final baseUrl = _httpsUrl(host?["url"]);
      final files = _maps(_list(host?["files"]));
      final image =
          files.where((file) => file["name"] == "2x.webp").firstOrNull ??
          files
              .where(
                (file) => RegExp(r"\.(webp|gif|png)$").hasMatch(file["name"]?.toString() ?? ""),
              )
              .firstOrNull;
      final name = emote["name"] as String?;
      final id = emote["id"] as String?;
      if (name == null || name.isEmpty || id == null || baseUrl == null || image == null) {
        continue;
      }
      result[name] = ChatAssetEmote(
        name: name,
        id: id,
        url: "$baseUrl/${image["name"]}",
        provider: ChatEmoteProvider.sevenTv,
        author: owner?["display_name"] as String? ?? owner?["username"] as String?,
        originalName: details?["name"] is String && details?["name"] != name
            ? details!["name"]! as String
            : null,
        zeroWidth: ((_int(emote["flags"]) & 1) != 0) || ((_int(details?["flags"]) & 256) != 0),
      );
    }
    return result;
  }

  static Map<String, ChatAssetEmote> _bttv(Object? data) => {
    for (final emote in _maps(_list(data)))
      if (emote["code"] case final String name)
        if (emote["id"] case final String id)
          name: ChatAssetEmote(
            name: name,
            id: id,
            url: "https://cdn.betterttv.net/emote/$id/2x",
            provider: ChatEmoteProvider.bttv,
            zeroWidth: emote["modifier"] == true,
          ),
  };

  static Map<String, ChatAssetEmote> _ffz(Object? data, {bool global = false}) {
    final document = _map(data);
    final sets = _map(document?["sets"]);
    if (sets == null) {
      throw const FormatException("Emote sets are missing.");
    }
    final included = global
        ? _list(document?["default_sets"]).map((id) => id.toString()).toSet()
        : sets.keys.toSet();
    final result = <String, ChatAssetEmote>{};
    for (final key in included) {
      for (final emote in _maps(_list(_map(sets[key])?["emoticons"]))) {
        final urls = _map(emote["animated"]) ?? _map(emote["urls"]);
        final url = _httpsUrl(urls?["2"] ?? urls?["1"] ?? urls?["4"]);
        final name = emote["name"] as String?;
        if (name == null || name.isEmpty || url == null || emote["id"] == null) {
          continue;
        }
        result[name] = ChatAssetEmote(
          name: name,
          id: emote["id"].toString(),
          url: url,
          provider: ChatEmoteProvider.ffz,
          zeroWidth: emote["modifier"] == true,
        );
      }
    }
    return result;
  }

  static Map<String, Object?>? _map(Object? value) => value is Map<String, Object?> ? value : null;
  static List<Object?> _list(Object? value) {
    if (value is! List<Object?>) {
      throw const FormatException("Emote list is missing.");
    }
    return value;
  }

  static Iterable<Map<String, Object?>> _maps(List<Object?> values) =>
      values.whereType<Map<String, Object?>>();
  static int _int(Object? value) => value is int ? value : 0;
  static String? _httpsUrl(Object? value) {
    if (value is! String) {
      return null;
    }
    final uri = Uri.tryParse(value.startsWith("//") ? "https:$value" : value);
    return uri?.scheme == "https" && uri!.host.isNotEmpty ? uri.toString() : null;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _cancel() {
    _deadline?.cancel();
    final abort = _abort;
    _abort = null;
    if (abort != null && !abort.isCompleted) {
      abort.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _imageQueue.clear();
    ++_generation;
    _cancel();
    _sevenTimer?.cancel();
    _sevenDeadline?.cancel();
    final abort = _sevenAbort;
    if (abort != null && !abort.isCompleted) {
      abort.complete();
    }
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    super.dispose();
  }
}
