import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/features/following/following_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  test("keeps saved following data in memory until refresh", () async {
    var followedRequests = 0;
    final store = FollowingStore(
      authController: _authController(
        onRequest: (request) {
          if (_isGraphQlOperation(request, "FlowFollowedLiveUsers")) {
            followedRequests++;
          }
        },
      ),
    );

    await store.loadSavedConnection();
    await store.loadSavedConnection();

    expect(store.connection?.user.displayName, "Flow Tester");
    expect(store.sessionStatus, TwitchSessionStatus.authenticated);
    expect(store.liveChannels.single.name, "AussieAntics");
    expect(followedRequests, 1);

    await store.loadSavedConnection(refresh: true);

    expect(followedRequests, 2);
  });

  test("tracks logged-out sessions and clears authenticated state", () async {
    final secureStore = _MemoryTwitchStore();
    final store = FollowingStore(
      authController: _authController(secureStore: secureStore),
    );

    await store.loadSavedConnection();

    expect(store.sessionStatus, TwitchSessionStatus.loggedOut);
    expect(store.isLoggedIn, isFalse);

    store.applyConnection(
      const TwitchAuthConnection(
        user: TwitchUser(id: "user-123", login: "tester", displayName: "Tester"),
        followedStreams: [],
        followedChannels: [],
      ),
    );
    expect(store.isLoggedIn, isTrue);

    await store.signOut();

    expect(store.sessionStatus, TwitchSessionStatus.loggedOut);
    expect(store.connection, isNull);
  });

  test("a completed login wins over an older session restore", () async {
    final authController = _DelayedAuthController();
    final store = FollowingStore(authController: authController);
    final restore = store.loadSavedConnection();
    final duplicateRestore = store.loadSavedConnection();
    final queuedRefresh = store.loadSavedConnection(refresh: true);
    final loginConnection = _connection("new-user");

    expect(authController.loadCalls, 1);
    store.applyConnection(loginConnection);
    authController.restore.complete(_connection("old-user"));
    await Future.wait([restore, duplicateRestore, queuedRefresh]);

    expect(authController.loadCalls, 1);
    expect(store.connection, same(loginConnection));
    expect(store.sessionStatus, TwitchSessionStatus.authenticated);
    expect(store.isLoadingFollowing, isFalse);
  });

  test("honors a refresh requested after login while an older restore finishes", () async {
    final authController = _DelayedAuthController();
    final store = FollowingStore(authController: authController);
    final restore = store.loadSavedConnection();
    final loginConnection = _connection("new-user");

    store.applyConnection(loginConnection);
    final refresh = store.loadSavedConnection(refresh: true);
    authController.restore.complete(_connection("old-user"));
    await Future<void>.delayed(Duration.zero);

    expect(authController.loadCalls, 2);
    authController.refreshedRestore.complete(loginConnection);
    await Future.wait([restore, refresh]);

    expect(store.connection, same(loginConnection));
    expect(store.sessionStatus, TwitchSessionStatus.authenticated);
  });

  test("queues and coalesces refreshes during session restoration", () async {
    final authController = _DelayedAuthController();
    final apiCache = _CountingApiCache();
    final store = FollowingStore(
      authController: authController,
      apiCache: apiCache,
    );
    final restore = store.loadSavedConnection();
    final refresh = store.loadSavedConnection(refresh: true);
    final duplicateRefresh = store.loadSavedConnection(refresh: true);

    await Future<void>.delayed(Duration.zero);
    expect(authController.loadCalls, 1);

    authController.restore.complete(_connection("stale-user"));
    await Future<void>.delayed(Duration.zero);

    expect(authController.loadCalls, 2);
    expect(apiCache.clearCalls, 1);
    authController.refreshedRestore.complete(_connection("fresh-user"));
    await Future.wait([restore, refresh, duplicateRefresh]);

    expect(authController.loadCalls, 2);
    expect(store.connection?.user.id, "fresh-user");
    expect(store.sessionStatus, TwitchSessionStatus.authenticated);
  });

  test("keeps authenticated state when secure sign-out fails", () async {
    final connection = _connection("current-user");
    final store = FollowingStore(
      authController: _authController(
        secureStore: _FailingClearTwitchStore(),
      ),
    )..applyConnection(connection);

    await expectLater(store.signOut(), throwsStateError);

    expect(store.connection, same(connection));
    expect(store.sessionStatus, TwitchSessionStatus.authenticated);
    expect(store.followingError, contains("Secure storage is unavailable."));
  });
}

TwitchAuthConnection _connection(String id) => TwitchAuthConnection(
  user: TwitchUser(id: id, login: id, displayName: id),
  followedStreams: const [],
  followedChannels: const [],
);

TwitchAuthController _authController({
  _RequestObserver? onRequest,
  _MemoryTwitchStore? secureStore,
}) {
  final resolvedSecureStore =
      secureStore ??
      (_MemoryTwitchStore()
        ..accessToken = "token-123"
        ..webSessionToken = "gql-token-123");
  return TwitchAuthController(
    config: const TwitchAuthConfig(clientId: "client-123"),
    secureStore: resolvedSecureStore,
    apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
      clientId: "client-123",
      accessToken: accessToken,
      gqlAccessToken: gqlAccessToken,
      httpClient: _followingHttpClient(onRequest: onRequest),
    ),
    cookieExtractor: const _StaticCookieExtractor(),
  );
}

MockClient _followingHttpClient({_RequestObserver? onRequest}) => MockClient((request) async {
  onRequest?.call(request);

  if (request.url.host == "id.twitch.tv" && request.url.path == "/oauth2/validate") {
    return _jsonResponse({"client_id": "client-123", "user_id": "user-123"});
  }

  if (request.url.host == "gql.twitch.tv") {
    final query = _graphQlQuery(request);
    final variables = _graphQlVariables(request);

    if (query.contains("FlowCurrentUser")) {
      return _jsonResponse({
        "data": {
          "currentUser": _userJson("user-123"),
        },
      });
    }

    if (query.contains("FlowFollowedLiveUsers")) {
      return _jsonResponse({
        "data": {
          "currentUser": {
            "followedLiveUsers": {
              "edges": [
                {
                  "cursor": null,
                  "node": _userJson("creator-1")
                    ..["stream"] = _streamJson(
                      id: "stream-123",
                      userId: "creator-1",
                      userLogin: "aussieantics",
                      userName: "AussieAntics",
                      gameName: "Fortnite",
                      title: "DROPS ON",
                      viewerCount: 10706,
                    ),
                },
              ],
              "pageInfo": {"hasNextPage": false},
            },
          },
        },
      });
    }

    if (query.contains("FlowFollowedUsers")) {
      return _jsonResponse({
        "data": {
          "currentUser": {
            "follows": {
              "edges": const <Object?>[],
              "pageInfo": {"hasNextPage": false},
            },
          },
        },
      });
    }

    if (query.contains("FlowUsers")) {
      final ids = (variables["ids"] as List<Object?>?)?.cast<String>() ?? const <String>[];
      return _jsonResponse({
        "data": {
          "users": [
            for (final id in ids) _userJson(id),
          ],
        },
      });
    }
  }

  return http.Response("not found", 404);
});

bool _isGraphQlOperation(http.Request request, String operationName) =>
    request.url.host == "gql.twitch.tv" && request.body.contains(operationName);

String _graphQlQuery(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return body["query"]! as String;
}

Map<String, Object?> _graphQlVariables(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return (body["variables"] as Map<String, Object?>?) ?? const <String, Object?>{};
}

Map<String, Object?> _userJson(String id) {
  final login = switch (id) {
    "user-123" => "flowtester",
    "creator-1" => "aussieantics",
    _ => id,
  };
  final displayName = switch (id) {
    "user-123" => "Flow Tester",
    "creator-1" => "AussieAntics",
    _ => id,
  };
  return {
    "id": id,
    "login": login,
    "displayName": displayName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$id.png",
    "broadcastSettings": null,
    "stream": null,
  };
}

Map<String, Object?> _streamJson({
  required String id,
  required String userId,
  required String userLogin,
  required String userName,
  required String gameName,
  required String title,
  required int viewerCount,
}) => {
  "id": id,
  "createdAt": "2026-07-01T00:00:00Z",
  "freeformTags": const <Object?>[],
  "game": {"id": "33214", "displayName": gameName},
  "previewImageURL":
      "https://static-cdn.jtvnw.net/previews-ttv/live_user_$userLogin-{width}x{height}.jpg",
  "viewersCount": viewerCount,
  "broadcaster": {
    "id": userId,
    "login": userLogin,
    "displayName": userName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$userId.png",
    "broadcastSettings": {"title": title},
  },
};

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

class _MemoryTwitchStore implements TwitchSecureStore {
  String? accessToken;
  String? pendingState;
  String? webSessionToken;

  @override
  Future<void> clearSession() async {
    accessToken = null;
    pendingState = null;
    webSessionToken = null;
  }

  @override
  Future<void> clearPendingState() async {
    pendingState = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readPendingState() async => pendingState;

  @override
  Future<String?> readWebSessionToken() async => webSessionToken;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> savePendingState(String state) async {
    pendingState = state;
  }

  @override
  Future<void> saveWebSessionToken(String token) async {
    webSessionToken = token;
  }
}

class _FailingClearTwitchStore extends _MemoryTwitchStore {
  @override
  Future<void> clearSession() => Future<void>.error(
    StateError("Secure storage is unavailable."),
  );
}

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}

class _CountingApiCache extends TwitchApiCache {
  _CountingApiCache()
    : super(
        clientLoader: () async => throw StateError("Unexpected API client load."),
      );

  int clearCalls = 0;

  @override
  void clear() {
    clearCalls++;
    super.clear();
  }
}

class _DelayedAuthController extends TwitchAuthController {
  _DelayedAuthController()
    : super(
        config: const TwitchAuthConfig(clientId: "client-123"),
        secureStore: _MemoryTwitchStore(),
        apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
          clientId: "client-123",
          accessToken: accessToken,
        ),
        cookieExtractor: const _StaticCookieExtractor(),
      );

  final restore = Completer<TwitchAuthConnection?>();
  final refreshedRestore = Completer<TwitchAuthConnection?>();
  int loadCalls = 0;

  @override
  Future<TwitchAuthConnection?> loadSavedConnection() {
    loadCalls++;
    if (loadCalls == 1) {
      return restore.future;
    }
    if (loadCalls == 2) {
      return refreshedRestore.future;
    }
    return Future.error(StateError("Unexpected saved connection load."));
  }
}
