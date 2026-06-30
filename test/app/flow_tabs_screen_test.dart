import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/flow_tabs_screen.dart";
import "package:flow/app/theme.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

import "../helpers/twitch_fakes.dart";

void main() {
  testWidgets("switches tabs instantly without reloading following data", (
    tester,
  ) async {
    var followedStreamsRequests = 0;
    final store = FakeTwitchSecureStore()..accessToken = "token-123";
    final navigationSpy = _NavigationSpy();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          navigatorObservers: [navigationSpy],
          authController: _authController(
            secureStore: store,
            onRequest: (request) {
              if (request.url.path == "/helix/streams/followed") {
                followedStreamsRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigationSpy.reset();

    expect(find.text("AussieAntics"), findsOneWidget);
    expect(followedStreamsRequests, 1);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
    expect(find.byKey(const ValueKey("app_bottom_nav_bar")), findsOneWidget);
    expect(navigationSpy.pushes, 1);
    expect(navigationSpy.lastPushedRoute?.settings.name, "/settings");
    final settingsRoute = navigationSpy.lastPushedRoute;
    expect(settingsRoute, isA<MaterialPageRoute<void>>());
    final settingsPageRoute = settingsRoute! as PageRoute<void>;
    expect(settingsPageRoute.transitionDuration, Duration.zero);
    expect(settingsPageRoute.reverseTransitionDuration, Duration.zero);
    expect(settingsPageRoute.popGestureEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pump();

    expect(find.text("AussieAntics"), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(followedStreamsRequests, 1);
    expect(navigationSpy.pops, 1);
  });

  testWidgets("system back from settings returns to following", (tester) async {
    final navigationSpy = _NavigationSpy();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(),
          navigatorObservers: [navigationSpy],
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigationSpy.reset();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
    await tester.pump();

    expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
    expect(navigationSpy.pushes, 1);
    expect(navigationSpy.lastPushedRoute?.settings.name, "/settings");

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue);
    expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    expect(find.byKey(const ValueKey("settings_title")), findsNothing);
    expect(navigationSpy.pops, 1);
  });

  testWidgets(
    "predictive back from settings previews following",
    (tester) async {
      final navigationSpy = _NavigationSpy();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.light),
          home: FlowTabsScreen(
            authController: _authController(),
            navigatorObservers: [navigationSpy],
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigationSpy.reset();

      await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
      final settingsPageRoute = navigationSpy.lastPushedRoute! as PageRoute<void>;
      expect(settingsPageRoute.popGestureEnabled, isTrue);

      await _sendBackGestureMessage(
        tester,
        const MethodCall("startBackGesture", <String, dynamic>{
          "touchOffset": <double>[5.0, 300.0],
          "progress": 0.0,
          "swipeEdge": 0,
        }),
      );
      await tester.pump();

      expect(settingsPageRoute.popGestureInProgress, isTrue);
      expect(find.byKey(const ValueKey("app_bottom_nav_bar")), findsOneWidget);

      await _sendBackGestureMessage(
        tester,
        const MethodCall("updateBackGestureProgress", <String, dynamic>{
          "x": 120.0,
          "y": 300.0,
          "progress": 0.35,
          "swipeEdge": 0,
        }),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
      expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
      expect(find.byKey(const ValueKey("app_bottom_nav_bar")), findsOneWidget);

      await _sendBackGestureMessage(
        tester,
        const MethodCall("commitBackGesture"),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
      expect(find.byKey(const ValueKey("settings_title")), findsNothing);
      expect(navigationSpy.pops, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Future<void> _sendBackGestureMessage(
  WidgetTester tester,
  MethodCall methodCall,
) async {
  final ByteData message = const StandardMethodCodec().encodeMethodCall(methodCall);
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    "flutter/backgesture",
    message,
    (ByteData? _) {},
  );
}

class _NavigationSpy extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;
  int pops = 0;
  int pushes = 0;

  void reset() {
    lastPushedRoute = null;
    pops = 0;
    pushes = 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}

TwitchAuthController _authController({
  FakeTwitchSecureStore? secureStore,
  RequestObserver? onRequest,
}) => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: secureStore ?? FakeTwitchSecureStore(),
  apiClientFactory: (accessToken) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    httpClient: fakeTwitchApiClient(onRequest: onRequest),
  ),
  cookieExtractor: const FakeCookieExtractor(),
);
