import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_chat_message.dart";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

enum ChatEmoteProvider { twitch, sevenTv, bttv, ffz }

class ChatAssetEmote {
  const ChatAssetEmote({
    required this.name,
    required this.id,
    required this.url,
    required this.provider,
    this.zeroWidth = false,
    this.author,
  });

  final String name;
  final String id;
  final String url;
  final ChatEmoteProvider provider;
  final bool zeroWidth;
  final String? author;
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
  final Map<ChatEmoteProvider, Map<String, List<ChatAssetBadge>>> _providerBadges = {};
  Map<String, List<ChatAssetBadge>> _userBadgesByLogin = const {};
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

  static final Map<String, ({DateTime expires, Map<String, ChatAssetEmote> emotes})> _emoteCache =
      {};
  static final Map<String, ({DateTime expires, TwitchNativeChatAssets assets})> _nativeCache = {};
  static final Map<ChatEmoteProvider, ({DateTime expires, Map<String, List<ChatAssetBadge>> users})>
  _badgeCache = {};
  static final Map<String, ({DateTime expires, ChatAssetBadge? badge})> _sevenBadgeCache = {};
  static const _sevenBadgeQuery =
      r"query($id: String!) { users { userByConnection(platform: TWITCH, platformId: $id) { style { activeBadge { id name images { url mime scale } } } } } }";
  static const _sourceOrder = [
    "twitch",
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
  Map<String, List<ChatAssetBadge>> get userBadgesByLogin => _userBadgesByLogin;
  bool get isLoading => _isLoading;
  List<String> get errors => List.unmodifiable(_errors);

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
      for (final id in _observedSenders.keys) {
        _sevenBadgeCache.remove(id);
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
      _publish("twitch", {
        for (final entry in assets.emoteIdsByName.entries)
          entry.key: ChatAssetEmote(
            name: entry.key,
            id: entry.value,
            url: "https://static-cdn.jtvnw.net/emoticons/v2/${entry.value}/default/dark/2.0",
            provider: ChatEmoteProvider.twitch,
          ),
      });
      return assets.channelId;
    } on Object {
      if (_isCurrent(generation)) {
        _errors.add("Twitch badges and emote names could not be loaded.");
        notifyListeners();
      }
      return null;
    }
  }

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
      final cached = _sevenBadgeCache[sender.key];
      if (cached != null && cached.expires.isAfter(DateTime.now())) {
        if (cached.badge != null && badges[sender.value]?.firstOrNull != cached.badge) {
          badges[sender.value] = [cached.badge!];
          changed = true;
        } else if (cached.badge == null && badges.remove(sender.value) != null) {
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
                  "query": _sevenBadgeQuery,
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
      final loaded = <ChatAssetBadge?>[];
      for (final result in results) {
        final document = _map(result);
        if (document?["errors"] != null || _map(document?["data"]) == null) {
          throw const FormatException("7TV badge lookup failed.");
        }
        final user = _map(_map(_map(document?["data"])?["users"])?["userByConnection"]);
        final badge = _map(_map(user?["style"])?["activeBadge"]);
        if (badge == null) {
          loaded.add(null);
          continue;
        }
        final images = _maps(_list(badge["images"]));
        final image =
            images
                .where((item) => item["mime"] == "image/webp" && item["scale"] == 2)
                .firstOrNull ??
            images.firstOrNull;
        final url = _httpsUrl(image?["url"]);
        loaded.add(
          url == null
              ? null
              : ChatAssetBadge(
                  id: "7tv/${badge["id"]}",
                  title: badge["name"] as String? ?? "7TV badge",
                  url: url,
                  provider: ChatEmoteProvider.sevenTv,
                ),
        );
      }
      if (_disposed) {
        return;
      }
      final users = _providerBadges.putIfAbsent(ChatEmoteProvider.sevenTv, () => {});
      var index = 0;
      for (final entry in batch.entries) {
        final badge = loaded[index++];
        _sevenBadgeCache[entry.key] = (
          expires: DateTime.now().add(const Duration(minutes: 30)),
          badge: badge,
        );
        if (badge == null) {
          users.remove(entry.value);
        } else {
          users[entry.value] = [badge];
        }
      }
      while (_sevenBadgeCache.length > 2048) {
        _sevenBadgeCache.remove(_sevenBadgeCache.keys.first);
      }
      while (users.length > 600) {
        users.remove(users.keys.first);
      }
      _errors.remove("7TV badges could not be loaded.");
      _publishUserBadges();
    } on Object {
      if (!_disposed) {
        _pendingSevenUsers.addAll(batch);
        retryDelay = const Duration(seconds: 30);
        if (!_errors.contains("7TV badges could not be loaded.")) {
          _errors.add("7TV badges could not be loaded.");
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
