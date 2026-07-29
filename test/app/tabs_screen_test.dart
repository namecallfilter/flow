import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/app/tabs_screen.dart";
import "package:flow/app/tabs_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

typedef _RequestObserver = void Function(http.Request request);

void main() {
  testWidgets("offers login on startup and allows guest access", (tester) async {
    var topStreamsRequests = 0;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: _MemoryTwitchStore(),
            onRequest: (request) {
              if (_isGraphQlOperation(request, "FlowTopStreams")) {
                topStreamsRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("login_offer_screen")), findsOneWidget);
    expect(find.byKey(const ValueKey("following_title")), findsNothing);
    expect(find.text("Log in with Twitch to see the channels you follow."), findsOneWidget);
    expect(find.textContaining("keep your session"), findsNothing);
    expect(find.byIcon(Icons.live_tv_rounded), findsNothing);
    final offerSize = tester.getSize(find.byKey(const ValueKey("login_offer_screen")));
    final titleRect = tester.getRect(find.text("Welcome to Flow"));
    final subtitleRect = tester.getRect(
      find.text("Log in with Twitch to see the channels you follow."),
    );
    expect(titleRect.center.dx, closeTo(offerSize.width / 2, 0.01));
    expect(
      subtitleRect.center.dx,
      closeTo(offerSize.width / 2, 0.01),
    );
    expect(
      (titleRect.top + subtitleRect.bottom) / 2,
      closeTo(offerSize.height / 2, 0.01),
    );

    await tester.tap(find.byKey(const ValueKey("login_offer_continue")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("following_title")),
        matching: find.text("Live Channels"),
      ),
      findsOneWidget,
    );
    expect(find.text("Streamer0"), findsOneWidget);
    expect(find.byKey(const ValueKey("following_offline_card")), findsNothing);
    expect(find.byKey(const ValueKey("offline_toggle")), findsNothing);
    final liveNavItem = find.byKey(const ValueKey("bottom_nav_item_Live Channels"));
    expect(liveNavItem, findsOneWidget);
    expect(find.byKey(const ValueKey("bottom_nav_item_Following")), findsNothing);
    expect(
      tester.widget<Icon>(find.descendant(of: liveNavItem, matching: find.byType(Icon))).icon,
      Icons.live_tv,
    );
    expect(topStreamsRequests, 1);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_segmented_control")), findsNothing);
    expect(find.byKey(const ValueKey("browse_segment_live_channels")), findsNothing);
    expect(find.byKey(const ValueKey("browse_categories_grid")), findsOneWidget);
    expect(topStreamsRequests, 1);

    await tester.tap(liveNavItem);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(topStreamsRequests, 2);
  });

  for (final brightness in Brightness.values) {
    testWidgets("uses a ${brightness.name} startup gate until Welcome is ready", (
      tester,
    ) async {
      final secureStore = _DelayedAccessTwitchStore();
      final theme = buildFlowTheme(brightness);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: FlowTabsScreen(
            authController: _authController(secureStore: secureStore),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey("startup_gate")), findsOneWidget);
      expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey("startup_gate"))).color,
        theme.scaffoldBackgroundColor,
      );
      expect(find.byKey(const ValueKey("following_title")), findsNothing);
      expect(find.byKey(const ValueKey("following_skeleton")), findsNothing);
      expect(find.byKey(const ValueKey("profile_auth_button")), findsNothing);
      expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
      expect(find.textContaining("Restoring your Twitch session"), findsNothing);

      secureStore.accessTokenRead.complete(null);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("startup_gate")), findsNothing);
      expect(find.byKey(const ValueKey("login_offer_screen")), findsOneWidget);
      expect(find.text("Welcome to Flow"), findsOneWidget);
    });
  }

  testWidgets("can bypass the startup gate when launch login is disabled", (tester) async {
    final secureStore = _DelayedAccessTwitchStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: secureStore),
          showLoginOnLaunch: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey("startup_gate")), findsNothing);
    expect(find.byKey(const ValueKey("following_title")), findsOneWidget);

    secureStore.accessTokenRead.complete(null);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("following_title")),
        matching: find.text("Live Channels"),
      ),
      findsOneWidget,
    );
  });

  testWidgets("waits for startup restoration before resolving Me", (tester) async {
    final secureStore = _DelayedAccessTwitchStore()..webSessionToken = "gql-token-123";
    final tabsStore = TabsStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: secureStore),
          tabsStore: tabsStore,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey("startup_gate")), findsOneWidget);
    expect(find.byKey(const ValueKey("profile_auth_button")), findsNothing);
    expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
    expect(tabsStore.currentRoute, FlowRoutes.following);

    secureStore.accessTokenRead.complete("token-123");
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("startup_gate")), findsNothing);
    expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("following_title")),
        matching: find.text("Following"),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    expect(tabsStore.currentRoute, FlowRoutes.settings);
    expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
  });

  testWidgets("does not offer startup login again after choosing guest access", (tester) async {
    final preferencesStore = _CountingPreferencesStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: _MemoryTwitchStore()),
          preferences: SharedPreferencesFlowPreferences(store: preferencesStore),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("login_offer_continue")));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final reopenedSecureStore = _DelayedAccessTwitchStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: reopenedSecureStore),
          preferences: SharedPreferencesFlowPreferences(store: preferencesStore),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey("startup_gate")), findsOneWidget);
    expect(find.byKey(const ValueKey("following_skeleton")), findsNothing);

    reopenedSecureStore.accessTokenRead.complete(null);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("startup_gate")), findsNothing);
    expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
    expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("following_title")),
        matching: find.text("Live Channels"),
      ),
      findsOneWidget,
    );
    expect(find.text("Streamer0"), findsOneWidget);
    expect(find.byKey(const ValueKey("following_offline_card")), findsNothing);
    expect(find.byKey(const ValueKey("offline_toggle")), findsNothing);
  });

  testWidgets("keeps the login offer open when the saved session cannot be cleared", (
    tester,
  ) async {
    final preferencesStore = _CountingPreferencesStore();
    final preferences = SharedPreferencesFlowPreferences(store: preferencesStore);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: _FailingGuestClearTwitchStore(),
          ),
          preferences: preferences,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("login_offer_continue")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("login_offer_screen")), findsOneWidget);
    expect(find.text("We couldn't clear your Twitch session. Try again."), findsOneWidget);
    expect(find.byKey(const ValueKey("following_title")), findsNothing);
    expect(await preferences.readLoginOfferDismissed(), isFalse);
  });

  testWidgets("does not start login while continuing as a guest", (tester) async {
    final secureStore = _DelayedGuestClearTwitchStore();
    var loginCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: secureStore),
          openTwitchLogin: (_, _) async {
            loginCalls++;
            return _sessionConnection();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("login_offer_continue")));
    await tester.pump();

    final loginButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey("login_offer_button")),
    );
    expect(loginButton.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey("login_offer_button")));
    expect(loginCalls, 0);

    secureStore.guestClear.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
    expect(loginCalls, 0);
  });

  testWidgets("restores a saved session and opens Settings from Me", (tester) async {
    var loginCalls = 0;
    final tabsStore = TabsStore();
    final secureStore = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: secureStore),
          openTwitchLogin: (_, _) async {
            loginCalls++;
            return null;
          },
          tabsStore: tabsStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    expect(tabsStore.currentRoute, FlowRoutes.settings);
    expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
    expect(
      find.byKey(const ValueKey("settings_twitch_account_group")),
      findsOneWidget,
    );
    expect(find.text("Flow Tester"), findsOneWidget);
    expect(find.text("@flowtester"), findsOneWidget);
    expect(find.text("Switch Twitch account"), findsOneWidget);
    expect(find.text("Sign out of Twitch"), findsOneWidget);
    expect(loginCalls, 0);
  });

  testWidgets("switches Twitch accounts from Settings", (tester) async {
    var loginCalls = 0;
    final secureStore = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: secureStore),
          openTwitchLogin: (_, _) async {
            loginCalls++;
            return _sessionConnection(
              id: "replacement-user",
              login: "replacement",
              displayName: "Replacement Tester",
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Switch Twitch account"));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("login_offer_screen")), findsOneWidget);
    expect(loginCalls, 0);

    await tester.tap(find.byKey(const ValueKey("login_offer_button")));
    await tester.pumpAndSettle();

    expect(loginCalls, 1);
    expect(find.byKey(const ValueKey("login_offer_screen")), findsNothing);
    expect(find.text("Replacement Tester"), findsOneWidget);
    expect(find.text("@replacement"), findsOneWidget);
  });

  testWidgets("signs out of Twitch from Settings", (tester) async {
    final secureStore = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: secureStore),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Sign out of Twitch"));
    await tester.pumpAndSettle();

    expect(secureStore.accessToken, isNull);
    expect(secureStore.webSessionToken, isNull);
    expect(
      find.byKey(const ValueKey("settings_twitch_account_group")),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey("bottom_nav_item_Live Channels")),
      findsOneWidget,
    );
    expect(find.text("Signed out of Twitch"), findsOneWidget);
  });

  testWidgets("Me offers login to guests before starting OAuth", (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    var loginCalls = 0;
    final tabsStore = TabsStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: _MemoryTwitchStore()),
          openTwitchLogin: (_, _) async {
            loginCalls++;
            return _sessionConnection();
          },
          tabsStore: tabsStore,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("login_offer_continue")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("bottom_nav_item_Live Channels")), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("browse_segmented_control")), findsNothing);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Live Channels")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("login_offer_screen")), findsOneWidget);
    expect(loginCalls, 0);
    final closeTopLeft = tester.getTopLeft(find.byKey(const ValueKey("login_offer_close")));
    expect(
      closeTopLeft,
      const Offset(AppSpacing.sm, 44 + AppSpacing.md),
    );

    await tester.tap(find.byKey(const ValueKey("login_offer_button")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("bottom_nav_item_Live Channels")), findsNothing);
    expect(find.byKey(const ValueKey("bottom_nav_item_Following")), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("browse_segmented_control")), findsOneWidget);
    expect(find.byKey(const ValueKey("browse_segment_live_channels")), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("profile_auth_button")));
    await tester.pumpAndSettle();

    expect(loginCalls, 1);
    expect(tabsStore.currentRoute, FlowRoutes.settings);
  });

  testWidgets("keeps Browse section and scroll state when switching tabs", (
    tester,
  ) async {
    var topCategoriesRequests = 0;
    var topLiveStreamsRequests = 0;
    var followedLiveRequests = 0;
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: store,
            onRequest: (request) {
              if (_isGraphQlOperation(request, "FlowTopGames") &&
                  _graphQlVariables(request)["after"] == null) {
                topCategoriesRequests++;
              }
              if (_isGraphQlOperation(request, "FlowTopStreams") &&
                  _graphQlVariables(request)["after"] == null) {
                topLiveStreamsRequests++;
              }
              if (_isGraphQlOperation(request, "FlowFollowedLiveUsers")) {
                followedLiveRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(followedLiveRequests, 1);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    expect(topCategoriesRequests, 1);

    await tester.tap(find.byKey(const ValueKey("browse_segment_live_channels")));
    await tester.pumpAndSettle();
    expect(topLiveStreamsRequests, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_live_channels")), findsOneWidget);
    expect(find.text("NextStreamer"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("browse_live_channels")), findsOneWidget);
    expect(find.text("NextStreamer"), findsOneWidget);
    expect(topCategoriesRequests, 1);
    expect(topLiveStreamsRequests, 1);
    expect(followedLiveRequests, 1);
  });

  testWidgets("keeps Browse category route when switching tabs", (tester) async {
    var categoryStreamsRequests = 0;
    final store = _MemoryTwitchStore()
      ..accessToken = "token-123"
      ..webSessionToken = "gql-token-123";

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(
            secureStore: store,
            onRequest: (request) {
              if (_isGraphQlOperation(request, "FlowGameStreams")) {
                categoryStreamsRequests++;
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("browse_category_card_Just Chatting")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    final categoryStreamsRequestsAfterOpen = categoryStreamsRequests;
    expect(categoryStreamsRequestsAfterOpen, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Following")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsNothing);

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    expect(categoryStreamsRequests, categoryStreamsRequestsAfterOpen);
  });

  testWidgets(
    "predictive back previews Following and leaves Following to Android",
    (
      tester,
    ) async {
      final store = _MemoryTwitchStore()
        ..accessToken = "token-123"
        ..webSessionToken = "gql-token-123";
      final tabsStore = TabsStore();
      final backPlatform = _BackPlatformSpy();
      await backPlatform.install(tester);
      addTearDown(backPlatform.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.light),
          home: FlowTabsScreen(
            authController: _authController(secureStore: store),
            tabsStore: tabsStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(backPlatform.frameworkHandlesBack, isFalse);

      for (final entry in {
        "Browse": const ValueKey("browse_title"),
        "Settings": const ValueKey("settings_title"),
      }.entries) {
        final tab = entry.key;
        await tester.tap(find.byKey(ValueKey("bottom_nav_item_$tab")));
        await tester.pumpAndSettle();

        final title = find.byKey(entry.value);
        final initialTitleX = tester.getTopLeft(title).dx;
        expect(backPlatform.frameworkHandlesBack, isTrue);
        expect(await _startBackGesture(tester), isTrue);
        await tester.pump();
        expect(find.byKey(const ValueKey("predictive_tab_back_transition")), findsOneWidget);

        await _updateBackGesture(tester, progress: 0.45);
        await tester.pump();
        expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
        expect(title, findsOneWidget);
        expect(tester.getTopLeft(title).dx, greaterThan(initialTitleX));

        await _sendBackGestureMessage(tester, const MethodCall("cancelBackGesture"));
        await tester.pump();
        expect(find.byKey(const ValueKey("predictive_tab_back_transition")), findsNothing);
        expect(title, findsOneWidget);
        expect(tester.getTopLeft(title).dx, closeTo(initialTitleX, 0.01));
        expect(backPlatform.frameworkHandlesBack, isTrue);

        expect(await _startBackGesture(tester), isTrue);
        await tester.pump();
        await _updateBackGesture(tester, progress: 0.08);
        await tester.pump();
        await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
        expect(tabsStore.currentRoute, FlowRoutes.following);
        await tester.pump();
        expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
        await tester.pumpAndSettle();
        expect(backPlatform.frameworkHandlesBack, isFalse);
      }

      expect(await _startBackGesture(tester), isFalse);
      backPlatform.systemPops = 0;
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pump();
      expect(backPlatform.systemPops, 1);
      expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    "predictive back only changes the active retained tab stack",
    (tester) async {
      final store = _MemoryTwitchStore()
        ..accessToken = "token-123"
        ..webSessionToken = "gql-token-123";
      final backPlatform = _BackPlatformSpy();
      await backPlatform.install(tester);
      addTearDown(backPlatform.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.light),
          home: FlowTabsScreen(
            authController: _authController(secureStore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey("stream_channel_identity_AussieAntics")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("browse_category_card_Just Chatting")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
      await tester.pumpAndSettle();
      expect(backPlatform.frameworkHandlesBack, isTrue);

      final hiddenFollowingChannel = find.byKey(
        const ValueKey("channel_page_aussieantics"),
        skipOffstage: false,
      );
      final hiddenBrowseCategory = find.byKey(
        const ValueKey("category_streams_page_Just Chatting"),
        skipOffstage: false,
      );
      final followingNavigator = Navigator.of(tester.element(hiddenFollowingChannel));
      final browseNavigator = Navigator.of(tester.element(hiddenBrowseCategory));

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      expect(followingNavigator.userGestureInProgress, isFalse);
      expect(browseNavigator.userGestureInProgress, isFalse);
      await _updateBackGesture(tester, progress: 0.4);
      await tester.pump();
      await _sendBackGestureMessage(tester, const MethodCall("cancelBackGesture"));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("settings_title")), findsOneWidget);
      expect(hiddenFollowingChannel, findsOneWidget);
      expect(hiddenBrowseCategory, findsOneWidget);

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      await _updateBackGesture(tester, progress: 0.4);
      await tester.pump();
      await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("channel_page_aussieantics")), findsOneWidget);
      expect(hiddenBrowseCategory, findsOneWidget);
      expect(backPlatform.frameworkHandlesBack, isTrue);

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      expect(followingNavigator.userGestureInProgress, isTrue);
      expect(browseNavigator.userGestureInProgress, isFalse);
      await _updateBackGesture(tester, progress: 0.4);
      await tester.pump();
      await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("following_title")), findsOneWidget);
      expect(hiddenFollowingChannel, findsNothing);
      expect(hiddenBrowseCategory, findsOneWidget);
      expect(backPlatform.frameworkHandlesBack, isFalse);

      await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Browse")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);

      expect(await _startBackGesture(tester), isTrue);
      await tester.pump();
      expect(browseNavigator.userGestureInProgress, isTrue);
      await _sendBackGestureMessage(tester, const MethodCall("commitBackGesture"));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("browse_title")), findsOneWidget);
      expect(backPlatform.frameworkHandlesBack, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets("does not reload settings preferences when navigating to Settings", (
    tester,
  ) async {
    final preferencesStore = _CountingPreferencesStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFlowTheme(Brightness.light),
        home: FlowTabsScreen(
          authController: _authController(secureStore: _MemoryTwitchStore()),
          settingsStore: AppSettingsStore(
            preferences: SharedPreferencesFlowPreferences(store: preferencesStore),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("login_offer_continue")));
    await tester.pumpAndSettle();
    final initialReadCount = preferencesStore.readCount;
    expect(initialReadCount, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey("bottom_nav_item_Settings")));
    await tester.pumpAndSettle();

    expect(preferencesStore.readCount, initialReadCount);
  });
}

TwitchAuthConnection _sessionConnection({
  String id = "user-123",
  String login = "flowtester",
  String displayName = "Flow Tester",
}) => TwitchAuthConnection(
  user: TwitchUser(id: id, login: login, displayName: displayName),
  followedStreams: [],
  followedChannels: [],
);

Future<Object?> _startBackGesture(WidgetTester tester) => _sendBackGestureMessage(
  tester,
  const MethodCall("startBackGesture", <String, dynamic>{
    "touchOffset": <double>[5, 300],
    "progress": 0.0,
    "swipeEdge": 0,
  }),
);

Future<Object?> _updateBackGesture(
  WidgetTester tester, {
  required double progress,
}) => _sendBackGestureMessage(
  tester,
  MethodCall("updateBackGestureProgress", <String, dynamic>{
    "touchOffset": const <double>[120, 300],
    "progress": progress,
    "swipeEdge": 0,
  }),
);

Future<Object?> _sendBackGestureMessage(
  WidgetTester tester,
  MethodCall methodCall,
) async {
  ByteData? response;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    "flutter/backgesture",
    const StandardMethodCodec().encodeMethodCall(methodCall),
    (data) => response = data,
  );
  return response == null ? null : const StandardMethodCodec().decodeEnvelope(response!);
}

class _BackPlatformSpy {
  final _frameworkHandlesBackValues = <bool>[];
  late final TestDefaultBinaryMessenger _messenger;
  int systemPops = 0;

  bool get frameworkHandlesBack => _frameworkHandlesBackValues.last;

  Future<void> install(WidgetTester tester) async {
    _messenger = tester.binding.defaultBinaryMessenger;
    _messenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) {
      switch (methodCall.method) {
        case "SystemNavigator.setFrameworkHandlesBack":
          _frameworkHandlesBackValues.add(methodCall.arguments! as bool);
          break;
        case "SystemNavigator.pop":
          systemPops++;
          break;
      }
      return Future<void>.value();
    });
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      "flutter/lifecycle",
      const StringCodec().encodeMessage("AppLifecycleState.resumed"),
      (_) {},
    );
  }

  void dispose() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  }
}

TwitchAuthController _authController({
  required _MemoryTwitchStore secureStore,
  _RequestObserver? onRequest,
}) => TwitchAuthController(
  config: const TwitchAuthConfig(clientId: "client-123"),
  secureStore: secureStore,
  apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
    clientId: "client-123",
    accessToken: accessToken,
    gqlAccessToken: gqlAccessToken,
    httpClient: _flowHttpClient(onRequest: onRequest),
  ),
  cookieExtractor: const _StaticCookieExtractor(),
);

MockClient _flowHttpClient({_RequestObserver? onRequest}) => MockClient((request) async {
  onRequest?.call(request);

  if (request.url.host == "id.twitch.tv" && request.url.path == "/oauth2/validate") {
    return _jsonResponse({"client_id": "client-123", "user_id": "user-123"});
  }

  if (request.url.host == "gql.twitch.tv") {
    final query = _graphQlQuery(request);
    final variables = _graphQlVariables(request);

    if (query.contains("FlowCurrentUser")) {
      return _jsonResponse({
        "data": {"currentUser": _userJson("user-123")},
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
                      id: "followed-stream",
                      userId: "creator-1",
                      userLogin: "aussieantics",
                      userName: "AussieAntics",
                      gameName: "Fortnite",
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

    if (query.contains("FlowTopGames")) {
      return _jsonResponse({
        "data": {
          "games": {
            "edges": [
              {
                "cursor": null,
                "node": {
                  "id": "509658",
                  "displayName": "Just Chatting",
                  "boxArtURL":
                      "https://static-cdn.jtvnw.net/ttv-boxart/509658-{width}x{height}.jpg",
                },
              },
            ],
            "pageInfo": {"hasNextPage": false},
          },
        },
      });
    }

    if (query.contains("FlowGameStreams")) {
      return _gameStreamsResponse(const <Map<String, Object?>>[]);
    }

    if (query.contains("FlowTopStreams")) {
      if (variables["after"] == "stream-page-2") {
        return _streamConnectionResponse([
          _streamJson(
            id: "stream-124",
            userId: "creator-5",
            userLogin: "nextstreamer",
            userName: "NextStreamer",
            gameName: "VALORANT",
            viewerCount: 1900,
          ),
        ]);
      }
      return _streamConnectionResponse(
        [
          for (var index = 0; index < 20; index++)
            _streamJson(
              id: "stream-$index",
              userId: "creator-$index",
              userLogin: "streamer$index",
              userName: "Streamer$index",
              gameName: "Just Chatting",
              viewerCount: 9000 - index,
            ),
        ],
        cursor: "stream-page-2",
      );
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
    "creator-5" => "nextstreamer",
    _ => "aussieantics",
  };
  final displayName = switch (id) {
    "user-123" => "Flow Tester",
    "creator-5" => "NextStreamer",
    _ => "AussieAntics",
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
  required int viewerCount,
}) => {
  "id": id,
  "broadcaster": {
    "id": userId,
    "login": userLogin,
    "displayName": userName,
    "profileImageURL": "https://static-cdn.jtvnw.net/$userId.png",
    "broadcastSettings": {"title": "Live from GraphQL"},
  },
  "createdAt": "2026-07-01T00:00:00Z",
  "freeformTags": const <Object?>[],
  "game": {"id": "game-$gameName", "displayName": gameName},
  "previewImageURL":
      "https://static-cdn.jtvnw.net/previews-ttv/live_user_$userLogin-{width}x{height}.jpg",
  "viewersCount": viewerCount,
};

http.Response _streamConnectionResponse(
  List<Map<String, Object?>> streams, {
  String? cursor,
}) => _jsonResponse({
  "data": {
    "streams": {
      "edges": [
        for (final stream in streams) {"cursor": cursor, "node": stream},
      ],
      "pageInfo": {"hasNextPage": cursor != null},
    },
  },
});

http.Response _gameStreamsResponse(
  List<Map<String, Object?>> streams,
) => _jsonResponse({
  "data": {
    "game": {
      "streams": {
        "edges": [
          for (final stream in streams) {"cursor": null, "node": stream},
        ],
        "pageInfo": {"hasNextPage": false},
      },
    },
  },
});

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

class _DelayedAccessTwitchStore extends _MemoryTwitchStore {
  final accessTokenRead = Completer<String?>();

  @override
  Future<String?> readAccessToken() => accessTokenRead.future;
}

class _FailingGuestClearTwitchStore extends _MemoryTwitchStore {
  var _clearCalls = 0;

  @override
  Future<void> clearSession() async {
    _clearCalls++;
    if (_clearCalls > 1) {
      throw StateError("Secure storage is unavailable.");
    }
    await super.clearSession();
  }
}

class _DelayedGuestClearTwitchStore extends _MemoryTwitchStore {
  final guestClear = Completer<void>();
  var _clearCalls = 0;

  @override
  Future<void> clearSession() async {
    _clearCalls++;
    if (_clearCalls > 1) {
      await guestClear.future;
    }
    await super.clearSession();
  }
}

class _CountingPreferencesStore implements FlowPreferencesStore {
  int readCount = 0;
  final strings = <String, String>{};
  final stringLists = <String, List<String>>{};

  @override
  Future<String?> getString(String key) async {
    readCount++;
    return strings[key];
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    readCount++;
    final value = stringLists[key];
    return value == null ? null : List<String>.of(value);
  }

  @override
  Future<void> remove(String key) async {
    strings.remove(key);
    stringLists.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    strings[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    stringLists[key] = List<String>.of(value);
  }
}

class _StaticCookieExtractor implements TwitchCookieExtractor {
  const _StaticCookieExtractor();

  @override
  Future<String?> extractTwitchAuthToken() async => null;
}
