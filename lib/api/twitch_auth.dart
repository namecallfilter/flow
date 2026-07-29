import "dart:async";
import "dart:convert";
import "dart:math";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_cookie_extractor.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

export "package:flow/api/twitch_cookie_extractor.dart";

typedef OAuthStateGenerator = String Function();
typedef TwitchApiClientFactory =
    TwitchApiClient Function(
      String accessToken, {
      String? gqlAccessToken,
    });

class TwitchAuthException implements Exception {
  TwitchAuthException(this.message);

  final String message;

  @override
  String toString() => "TwitchAuthException: $message";
}

class TwitchAuthConfig {
  const TwitchAuthConfig({
    required this.clientId,
    this.graphQlClientId = TwitchApiClient.defaultGraphQlClientId,
    this.redirectUri = defaultRedirectUri,
    this.scope = "user:read:follows",
  });

  const TwitchAuthConfig.fromEnvironment()
    : clientId = const String.fromEnvironment("TWITCH_CLIENT_ID"),
      graphQlClientId = const String.fromEnvironment(
        "TWITCH_GQL_CLIENT_ID",
        defaultValue: TwitchApiClient.defaultGraphQlClientId,
      ),
      redirectUri = const String.fromEnvironment(
        "TWITCH_REDIRECT_URI",
        defaultValue: defaultRedirectUri,
      ),
      scope = "user:read:follows";

  static const defaultRedirectUri = "https://twitch.tv/login";

  final String clientId;
  final String graphQlClientId;
  final String redirectUri;
  final String scope;

  bool get isConfigured => clientId.trim().isNotEmpty;

  bool isRedirectUri(Uri uri) {
    final expectedUri = Uri.parse(redirectUri.trim());
    return uri.scheme == expectedUri.scheme &&
        _redirectHostsMatch(uri.host, expectedUri.host) &&
        _normalizeRedirectPath(uri.path) == _normalizeRedirectPath(expectedUri.path);
  }

  Uri authorizationUri({required String state}) => Uri.https("id.twitch.tv", "/oauth2/authorize", {
    "client_id": clientId.trim(),
    "redirect_uri": redirectUri.trim(),
    "response_type": "token",
    "scope": scope,
    "force_verify": "true",
    "state": state,
  });
}

class TwitchAuthCallback {
  const TwitchAuthCallback({
    required this.accessToken,
    required this.scope,
    required this.state,
  });

  factory TwitchAuthCallback.parse(Uri uri, {required String expectedState}) {
    final params = _callbackParameters(uri);
    final error = params["error"];
    if (error != null) {
      throw TwitchAuthException(params["error_description"] ?? error);
    }

    final returnedState = params["state"];
    if (expectedState.trim().isEmpty || returnedState != expectedState) {
      throw TwitchAuthException("OAuth state did not match.");
    }

    final accessToken = params["access_token"];
    if (accessToken == null || accessToken.isEmpty) {
      throw TwitchAuthException(
        "Twitch callback did not include access token.",
      );
    }

    return TwitchAuthCallback(
      accessToken: accessToken,
      scope: params["scope"] ?? "",
      state: returnedState ?? "",
    );
  }

  static bool hasOAuthResponse(Uri uri) {
    final params = _callbackParameters(uri);
    return params.containsKey("access_token") || params.containsKey("error");
  }

  final String accessToken;
  final String scope;
  final String state;
}

abstract interface class TwitchSecureStore {
  Future<void> savePendingState(String state);
  Future<String?> readPendingState();
  Future<void> clearPendingState();
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> saveWebSessionToken(String token);
  Future<String?> readWebSessionToken();
  Future<void> clearSession();
}

class SecureTwitchStore implements TwitchSecureStore {
  const SecureTwitchStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _pendingStateKey = "twitch_oauth_pending_state";
  static const _accessTokenKey = "twitch_access_token";
  static const _webSessionTokenKey = "twitch_web_session_token";

  final FlutterSecureStorage _storage;

  @override
  Future<void> clearSession() => Future.wait([
    _storage.delete(key: _pendingStateKey),
    _storage.delete(key: _accessTokenKey),
    _storage.delete(key: _webSessionTokenKey),
  ]);

  @override
  Future<void> clearPendingState() => _storage.delete(key: _pendingStateKey);

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readPendingState() => _storage.read(key: _pendingStateKey);

  @override
  Future<String?> readWebSessionToken() => _storage.read(key: _webSessionTokenKey);

  @override
  Future<void> saveAccessToken(String token) => _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<void> savePendingState(String state) =>
      _storage.write(key: _pendingStateKey, value: state);

  @override
  Future<void> saveWebSessionToken(String token) =>
      _storage.write(key: _webSessionTokenKey, value: token);
}

class TwitchAuthConnection {
  const TwitchAuthConnection({
    required this.user,
    required this.followedStreams,
    required this.followedChannels,
    this.usersById = const {},
    this.channelInfoByBroadcasterId = const {},
  });

  final TwitchUser user;
  final List<TwitchFollowedStream> followedStreams;
  final List<TwitchFollowedChannel> followedChannels;
  final Map<String, TwitchUser> usersById;
  final Map<String, TwitchChannelInfo> channelInfoByBroadcasterId;
}

class TwitchAuthController {
  TwitchAuthController({
    required this.config,
    required this.secureStore,
    required this.apiClientFactory,
    required this.cookieExtractor,
    OAuthStateGenerator? stateGenerator,
  }) : _stateGenerator = stateGenerator ?? generateOAuthState;

  final TwitchAuthConfig config;
  final TwitchSecureStore secureStore;
  final TwitchApiClientFactory apiClientFactory;
  final TwitchCookieExtractor cookieExtractor;
  final OAuthStateGenerator _stateGenerator;
  int _sessionRevision = 0;
  int? _pendingAuthRevision;
  String? _pendingAuthState;
  Future<void> _sessionStorageBarrier = Future<void>.value();

  Future<Uri> createAuthorizationUri() async {
    if (!config.isConfigured) {
      throw TwitchAuthException(
        "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to start Twitch auth.",
      );
    }

    final revision = ++_sessionRevision;
    final state = _stateGenerator();
    _pendingAuthRevision = revision;
    _pendingAuthState = state;
    try {
      await _withSessionStorageLock(() async {
        _ensurePendingAuthCurrent(revision);
        await secureStore.savePendingState(state);
        _ensurePendingAuthCurrent(revision);
      });
    } on Object {
      if (_pendingAuthRevision == revision) {
        _pendingAuthRevision = null;
        _pendingAuthState = null;
      }
      rethrow;
    }
    return config.authorizationUri(state: state);
  }

  Future<TwitchAuthConnection> completeAuth(Uri callbackUri) async {
    final revision = _pendingAuthRevision;
    if (revision == null) {
      throw TwitchAuthException("Twitch sign-in was canceled.");
    }
    _ensurePendingAuthCurrent(revision);
    final expectedState = await secureStore.readPendingState();
    _ensurePendingAuthCurrent(revision);
    final callback = TwitchAuthCallback.parse(
      callbackUri,
      expectedState: expectedState ?? "",
    );

    final validationClient = apiClientFactory(callback.accessToken);
    final isValid = await validationClient.validateAccessToken(callback.accessToken);
    _ensurePendingAuthCurrent(revision);
    if (!isValid) {
      throw TwitchAuthException("Twitch access token is invalid.");
    }

    final gqlAccessToken = (await cookieExtractor.extractTwitchAuthToken())?.trim();
    _ensurePendingAuthCurrent(revision);
    if (gqlAccessToken == null || gqlAccessToken.isEmpty) {
      throw TwitchAuthException("Twitch web session token is missing.");
    }
    final apiClient = apiClientFactory(
      callback.accessToken,
      gqlAccessToken: gqlAccessToken,
    );
    final connection = await _fetchConnection(apiClient);
    _ensurePendingAuthCurrent(revision);

    try {
      await _withSessionStorageLock(() async {
        var didStartReplacingSession = false;
        String? previousAccessToken;
        String? previousWebSessionToken;
        try {
          _ensurePendingAuthCurrent(revision);
          previousAccessToken = await secureStore.readAccessToken();
          _ensurePendingAuthCurrent(revision);
          previousWebSessionToken = await secureStore.readWebSessionToken();
          _ensurePendingAuthCurrent(revision);
          didStartReplacingSession = true;
          await secureStore.clearSession();
          _ensurePendingAuthCurrent(revision);
          await secureStore.saveAccessToken(callback.accessToken);
          _ensurePendingAuthCurrent(revision);
          await secureStore.saveWebSessionToken(gqlAccessToken);
          _ensurePendingAuthCurrent(revision);
        } on Object {
          if (didStartReplacingSession) {
            try {
              await secureStore.clearSession();
              if (previousAccessToken != null &&
                  previousAccessToken.isNotEmpty &&
                  previousWebSessionToken != null &&
                  previousWebSessionToken.isNotEmpty) {
                await secureStore.saveAccessToken(previousAccessToken);
                await secureStore.saveWebSessionToken(previousWebSessionToken);
              }
            } on Object {
              // Preserve the original completion error.
            }
          }
          rethrow;
        }
      });
    } on Object {
      if (_pendingAuthRevision == revision) {
        _pendingAuthRevision = null;
        _pendingAuthState = null;
      }
      rethrow;
    }
    if (_pendingAuthRevision == revision) {
      _pendingAuthRevision = null;
      _pendingAuthState = null;
    }
    return connection;
  }

  Future<TwitchAuthConnection?> loadSavedConnection() async {
    if (!config.isConfigured) {
      return null;
    }

    final revision = _sessionRevision;
    final credentials =
        await _withSessionStorageLock<({String accessToken, String gqlAccessToken})?>(() async {
          if (revision != _sessionRevision || _pendingAuthRevision != null) {
            return null;
          }
          final accessToken = await secureStore.readAccessToken();
          if (revision != _sessionRevision || _pendingAuthRevision != null) {
            return null;
          }
          final gqlAccessToken = await secureStore.readWebSessionToken();
          if (revision != _sessionRevision || _pendingAuthRevision != null) {
            return null;
          }
          if (accessToken == null ||
              accessToken.isEmpty ||
              gqlAccessToken == null ||
              gqlAccessToken.trim().isEmpty) {
            await secureStore.clearSession();
            return null;
          }
          return (
            accessToken: accessToken,
            gqlAccessToken: gqlAccessToken,
          );
        });
    if (credentials == null) {
      return null;
    }
    final apiClient = apiClientFactory(
      credentials.accessToken,
      gqlAccessToken: credentials.gqlAccessToken,
    );
    final isValid = await apiClient.validateAccessToken(credentials.accessToken);
    if (revision != _sessionRevision) {
      return null;
    }
    if (!isValid) {
      await _clearSessionIfCurrent(revision);
      return null;
    }

    final connection = await _fetchConnection(apiClient);
    return revision == _sessionRevision ? connection : null;
  }

  Future<void> cancelPendingAuth(String state) {
    if (_pendingAuthRevision == null || _pendingAuthState != state) {
      return Future<void>.value();
    }
    final revision = ++_sessionRevision;
    _pendingAuthRevision = null;
    _pendingAuthState = null;
    return _withSessionStorageLock(() async {
      if (revision == _sessionRevision && _pendingAuthRevision == null) {
        await secureStore.clearPendingState();
      }
    });
  }

  Future<void> signOut() {
    _sessionRevision++;
    _pendingAuthRevision = null;
    _pendingAuthState = null;
    return _withSessionStorageLock(secureStore.clearSession);
  }

  Future<({String? accessToken, String? webSessionToken})> readSavedTokens() =>
      _withSessionStorageLock(() async {
        final accessToken = await secureStore.readAccessToken();
        final webSessionToken = await secureStore.readWebSessionToken();
        return (
          accessToken: accessToken,
          webSessionToken: webSessionToken,
        );
      });

  Future<void> _clearSessionIfCurrent(int revision) => _withSessionStorageLock(() async {
    if (revision == _sessionRevision) {
      await secureStore.clearSession();
    }
  });

  void _ensurePendingAuthCurrent(int revision) {
    if (revision != _sessionRevision || _pendingAuthRevision != revision) {
      throw TwitchAuthException("Twitch sign-in was canceled.");
    }
  }

  Future<T> _withSessionStorageLock<T>(Future<T> Function() operation) async {
    final previous = _sessionStorageBarrier;
    final release = Completer<void>();
    _sessionStorageBarrier = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  Future<TwitchAuthConnection> _fetchConnection(
    TwitchApiClient apiClient,
  ) async {
    final user = await apiClient.fetchCurrentUser();
    final streams = await apiClient.fetchFollowedStreams(user.id);
    final channels = await apiClient.fetchFollowedChannels(user.id);
    final profileIds = <String>{
      user.id,
      for (final stream in streams) stream.userId,
      for (final channel in channels) channel.broadcasterId,
    }.toList();
    final usersById = await apiClient.fetchUsersByIds(profileIds);
    final channelInfoByBroadcasterId = await apiClient.fetchChannelInfoByBroadcasterIds([
      for (final channel in channels) channel.broadcasterId,
    ]);

    return TwitchAuthConnection(
      user: user,
      followedStreams: streams,
      followedChannels: channels,
      usersById: usersById,
      channelInfoByBroadcasterId: channelInfoByBroadcasterId,
    );
  }
}

String generateOAuthState() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll("=", "");
}

Map<String, String> _callbackParameters(Uri uri) {
  final params = <String, String>{...uri.queryParameters};
  if (uri.fragment.isNotEmpty) {
    params.addAll(Uri.splitQueryString(uri.fragment));
  }
  return params;
}

bool _redirectHostsMatch(String actualHost, String expectedHost) {
  final actual = actualHost.toLowerCase();
  final expected = expectedHost.toLowerCase();
  if (actual == expected) {
    return true;
  }

  return _withoutWww(actual) == "twitch.tv" && _withoutWww(actual) == _withoutWww(expected);
}

String _withoutWww(String host) => host.startsWith("www.") ? host.substring(4) : host;

String _normalizeRedirectPath(String path) {
  if (path.length > 1 && path.endsWith("/")) {
    return path.substring(0, path.length - 1);
  }
  return path.isEmpty ? "/" : path;
}
