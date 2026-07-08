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
}

class SecureTwitchStore implements TwitchSecureStore {
  const SecureTwitchStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _pendingStateKey = "twitch_oauth_pending_state";
  static const _accessTokenKey = "twitch_access_token";
  static const _webSessionTokenKey = "twitch_web_session_token";

  final FlutterSecureStorage _storage;

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

  Future<Uri> createAuthorizationUri() async {
    if (!config.isConfigured) {
      throw TwitchAuthException(
        "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to start Twitch auth.",
      );
    }

    final state = _stateGenerator();
    await secureStore.savePendingState(state);
    return config.authorizationUri(state: state);
  }

  Future<TwitchAuthConnection> completeAuth(Uri callbackUri) async {
    final expectedState = await secureStore.readPendingState();
    final callback = TwitchAuthCallback.parse(
      callbackUri,
      expectedState: expectedState ?? "",
    );

    final validationClient = apiClientFactory(callback.accessToken);
    final isValid = await validationClient.validateAccessToken(callback.accessToken);
    if (!isValid) {
      throw TwitchAuthException("Twitch access token is invalid.");
    }

    await secureStore.saveAccessToken(callback.accessToken);
    await secureStore.clearPendingState();
    final gqlAccessToken = await extractAndStoreWebSessionToken();

    final apiClient = apiClientFactory(
      callback.accessToken,
      gqlAccessToken: gqlAccessToken,
    );
    return _fetchConnection(apiClient);
  }

  Future<TwitchAuthConnection?> loadSavedConnection() async {
    if (!config.isConfigured) {
      return null;
    }

    final accessToken = await secureStore.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final validationClient = apiClientFactory(accessToken);
    final isValid = await validationClient.validateAccessToken(accessToken);
    if (!isValid) {
      return null;
    }

    final gqlAccessToken = await _loadWebSessionToken();
    return _fetchConnectionWithWebSessionRetry(
      accessToken: accessToken,
      gqlAccessToken: gqlAccessToken,
    );
  }

  Future<TwitchAuthConnection> _fetchConnectionWithWebSessionRetry({
    required String accessToken,
    required String? gqlAccessToken,
  }) async {
    try {
      return await _fetchConnection(
        apiClientFactory(accessToken, gqlAccessToken: gqlAccessToken),
      );
    } on TwitchApiException {
      final refreshedGqlAccessToken = await extractAndStoreWebSessionToken();
      if (refreshedGqlAccessToken == null || refreshedGqlAccessToken == gqlAccessToken) {
        rethrow;
      }
      return _fetchConnection(
        apiClientFactory(
          accessToken,
          gqlAccessToken: refreshedGqlAccessToken,
        ),
      );
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

  Future<String?> extractAndStoreWebSessionToken() async {
    final webSessionToken = await cookieExtractor.extractTwitchAuthToken();
    final token = webSessionToken?.trim();
    if (token == null || token.isEmpty) {
      return null;
    }

    await secureStore.saveWebSessionToken(token);
    return token;
  }

  Future<String?> _loadWebSessionToken() async {
    final token = (await secureStore.readWebSessionToken())?.trim();
    if (token != null && token.isNotEmpty) {
      return token;
    }
    return extractAndStoreWebSessionToken();
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
