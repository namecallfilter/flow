import "dart:convert";
import "dart:math";

import "package:flow/api/twitch_api.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;

class GoLiveNotifications extends ChangeNotifier {
  GoLiveNotifications._();
  static final instance = GoLiveNotifications._();
  static const platform = MethodChannel("flow/go_live");
  static const _storage = FlutterSecureStorage();
  static const _storageKey = "flow_go_live_registration";
  static const _relayAddress = String.fromEnvironment("FLOW_GO_LIVE_RELAY_URL");
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String address = "";
  String accessKey = "";
  String userId = "";
  String installationId = "";
  Set<String> channels = {};
  bool enabled = false;
  bool pendingUnregister = false;
  String? _registeredToken;
  Future<void>? _loadFuture;
  Future<void> _tail = Future<void>.value();
  bool _disableRequested = false;

  Future<void> load() => _loadFuture ??= _load().catchError((Object error, StackTrace stack) {
    _loadFuture = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _load() async {
    final saved = await _storage.read(key: _storageKey);
    if (saved == null) {
      return;
    }
    final data = jsonDecode(saved) as Map<String, dynamic>;
    address = data["address"] as String? ?? "";
    accessKey = data["accessKey"] as String? ?? "";
    userId = data["userId"] as String? ?? "";
    installationId = data["installationId"] as String? ?? "";
    channels = (data["channels"] as List? ?? []).cast<String>().toSet();
    enabled = data["enabled"] == true;
    pendingUnregister = data["pendingUnregister"] == true;
    _registeredToken = data["token"] as String?;
  }

  Future<void> _save() async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        "address": address,
        "accessKey": accessKey,
        "userId": userId,
        "installationId": installationId,
        "channels": channels.toList(),
        "enabled": enabled,
        "pendingUnregister": pendingUnregister,
        "token": _registeredToken,
      }),
    );
    notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _tail.then((_) async {
      await load();
      await action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static Uri _relayUri(String address) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        uri.scheme != "https" ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != "/")) {
      throw const FormatException("Live notifications need setup in this build.");
    }
    return uri;
  }

  Future<Map<String, dynamic>> status() async {
    final result = supported
        ? Map<String, dynamic>.from(await platform.invokeMapMethod("status") ?? {})
        : <String, dynamic>{};
    try {
      _relayUri(_relayAddress);
    } on FormatException {
      result["configured"] = false;
    }
    return result;
  }

  Future<http.Response> _request(
    String method, {
    Object? body,
    bool allowUnauthorized = false,
  }) async {
    final request = http.Request(method, _relayUri(address).resolve("/v1/devices/$installationId"));
    request.followRedirects = false;
    request.headers.addAll({
      "Authorization": "Bearer $accessKey",
      "Content-Type": "application/json",
    });
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final client = http.Client();
    try {
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      if ((response.statusCode < 200 || response.statusCode >= 300) &&
          !(allowUnauthorized && response.statusCode == 401)) {
        throw StateError(
          response.statusCode == 401
              ? "Sign in to Twitch again to update live notifications."
              : "Live notifications could not be updated (${response.statusCode}). Try again.",
        );
      }
      return response;
    } finally {
      client.close();
    }
  }

  Future<void> enable(Future<TwitchApiClient> Function() clientLoader) {
    _disableRequested = false;
    return _enqueue(() => _sync(clientLoader, requestPermission: true));
  }

  Future<void> _sync(
    Future<TwitchApiClient> Function() clientLoader, {
    bool requestPermission = false,
  }) async {
    if (!requestPermission && !enabled && !pendingUnregister) {
      return;
    }
    if (!supported || (await status())["configured"] != true) {
      throw StateError("Live notifications need setup in this build.");
    }
    final client = await clientLoader();
    if (client.accessToken.isEmpty) {
      _disableRequested = true;
      await _disable();
      return;
    }
    final currentUser = await client.fetchCurrentUser();
    if (enabled && (userId != currentUser.id || address != _relayAddress)) {
      _disableRequested = true;
      await _disable();
      return;
    }
    if (pendingUnregister) {
      if (userId == currentUser.id && address == _relayAddress) {
        accessKey = client.accessToken;
        await _save();
      }
      await _retryUnregister(resetExpiredToken: requestPermission && userId != currentUser.id);
    }
    if (_disableRequested || (!requestPermission && !enabled)) {
      return;
    }
    final allowed = requestPermission
        ? await platform.invokeMethod<bool>("requestPermission")
        : (await status())["permission"] == true;
    if (allowed != true) {
      throw StateError(
        "Allow Flow notifications in Android settings to enable live notifications.",
      );
    }
    final selected = await client.fetchLiveNotificationChannelIds();
    if (selected.length > 1000) {
      throw StateError("Live notifications support up to 1,000 enabled Twitch channels.");
    }
    final token = await platform.invokeMethod<String>("token");
    if (token == null || token.isEmpty) {
      throw StateError("This device could not register for notifications.");
    }
    if (_disableRequested) {
      return;
    }
    address = _relayAddress;
    accessKey = client.accessToken;
    userId = currentUser.id;
    if (installationId.isEmpty) {
      final random = Random.secure();
      final hex = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
      installationId =
          "${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-8${hex.substring(17, 20)}-${hex.substring(20)}";
      await _save();
    }
    if (!enabled || token != _registeredToken || !setEquals(channels, selected)) {
      await _request("PUT", body: {"token": token, "channels": selected.toList()});
    }
    if (_disableRequested) {
      return;
    }
    channels = selected.toSet();
    enabled = true;
    pendingUnregister = false;
    _registeredToken = token;
    await _save();
    if (_disableRequested) {
      return;
    }
    await platform.invokeMethod<void>("setChannels", {
      "channels": channels.toList(),
      "userId": userId,
    });
  }

  Future<void> disable() async {
    _disableRequested = true;
    await platform.invokeMethod<void>("setChannels", {"channels": <String>[]});
    await _enqueue(_disable);
  }

  Future<void> _disable() async {
    await platform.invokeMethod<void>("setChannels", {"channels": <String>[]});
    pendingUnregister = installationId.isNotEmpty;
    enabled = false;
    _registeredToken = null;
    await _save();
    await _retryUnregister();
  }

  Future<void> _retryUnregister({bool resetExpiredToken = false}) async {
    if (!pendingUnregister) {
      return;
    }
    final response = await _request("DELETE", allowUnauthorized: resetExpiredToken);
    if (response.statusCode == 401) {
      await platform.invokeMethod<void>("setChannels", {"channels": <String>[]});
      await platform.invokeMethod<void>("resetToken");
      installationId = "";
      address = "";
      accessKey = "";
      userId = "";
      channels = {};
      enabled = false;
      _registeredToken = null;
    }
    pendingUnregister = false;
    await _save();
  }

  Future<void> sync(Future<TwitchApiClient> Function() clientLoader) async {
    if (!supported) {
      return;
    }
    await _enqueue(() => _sync(clientLoader));
  }
}
