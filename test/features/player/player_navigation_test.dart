import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_vod_chat.dart";
import "package:flow/features/player/media3_player_controller.dart";
import "package:flow/features/player/player_navigation.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/features/player/twitch_chat_panel.dart";
import "package:flow/features/settings/settings_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  for (final aboveSettings in [false, true]) {
    testWidgets("nested chat sheets stay above their parent (settings: $aboveSettings)", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final host = PlaybackHost();
      final player = _PlaybackProbe();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [host],
          home: const Scaffold(body: Text("Browse Flow")),
        ),
      );
      await openStreamPlayer(
        tester.element(find.text("Browse Flow")),
        builder: (_) => player.screen("creator"),
      );
      await tester.pumpAndSettle();
      final playerContext = tester.element(find.byType(StreamPlayerScreen));
      final surface = tester.element(find.byType(_PlayerSurface));
      if (aboveSettings) {
        unawaited(
          host.openOverlayPage(builder: (_) => const Scaffold(body: Text("Player settings"))),
        );
        await tester.pumpAndSettle();
      }
      Future<void> showSheet(String name, double height, {VoidCallback? onNext}) =>
          showModalBottomSheet<void>(
            context: playerContext,
            isScrollControlled: true,
            builder: (_) => SizedBox(
              key: ValueKey(name),
              height: height,
              child: Column(
                children: [
                  Text(name),
                  if (onNext != null) TextButton(onPressed: onNext, child: Text("More from $name")),
                ],
              ),
            ),
          );
      unawaited(
        showSheet(
          "History",
          500,
          onNext: () => unawaited(
            showSheet(
              "Options",
              160,
              onNext: () {
                Navigator.of(playerContext).pop();
                unawaited(showSheet("Confirm", 220));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final history = find.byKey(const ValueKey("History"));
      final historyElement = tester.element(history);
      final underlying = aboveSettings ? find.text("Player settings") : find.byType(_PlayerSurface);
      _expectPaintsAbove(tester, history, underlying);
      await tester.tap(find.text("More from History"));
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(Duration(milliseconds: frame == 0 ? 0 : 16));
        _expectPaintsAbove(tester, find.byKey(const ValueKey("Options")), history);
        _expectPaintsAbove(tester, history, underlying);
      }
      await tester.tap(find.text("More from Options"));
      final options = find.byKey(const ValueKey("Options"));
      final confirm = find.byKey(const ValueKey("Confirm"));
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(Duration(milliseconds: frame == 0 ? 0 : 16));
        _expectPaintsAbove(tester, confirm, history);
        if (options.evaluate().isNotEmpty) {
          _expectPaintsAbove(tester, confirm, options);
          _expectPaintsAbove(tester, options, history);
        }
        _expectPaintsAbove(tester, history, underlying);
      }
      expect(options, findsNothing);
      Navigator.of(playerContext).pop();
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (confirm.evaluate().isNotEmpty) {
          _expectPaintsAbove(tester, confirm, history);
        }
        _expectPaintsAbove(tester, history, underlying);
      }
      expect(find.text("More from History").hitTestable(), findsOneWidget);
      expect(tester.element(history), same(historyElement));
      unawaited(
        host.openOverlayPage(
          builder: (_) => const Scaffold(
            key: ValueKey("Report page"),
            body: Text("Report user"),
          ),
        ),
      );
      final report = find.byKey(const ValueKey("Report page"));
      final coveredHistory = find.byKey(const ValueKey("History"), skipOffstage: false);
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(Duration(milliseconds: frame == 0 ? 0 : 16));
        _expectPaintsAbove(tester, report, coveredHistory);
      }
      expect(find.text("Report user").hitTestable(), findsOneWidget);
      expect(host.mode, PlaybackMode.expanded);
      Navigator.of(playerContext).pop();
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (report.evaluate().isNotEmpty) {
          _expectPaintsAbove(tester, report, coveredHistory);
        }
      }
      expect(report, findsNothing);
      expect(history, findsOneWidget);
      expect(find.text("More from History").hitTestable(), findsOneWidget);
      expect(tester.element(history), same(historyElement));
      Navigator.of(playerContext).removeRoute(ModalRoute.of(tester.element(history))!);
      await tester.pumpAndSettle();
      expect(history, findsNothing);
      if (aboveSettings) {
        expect(find.text("Player settings").hitTestable(), findsOneWidget);
        Navigator.of(playerContext).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.element(find.byType(_PlayerSurface)), same(surface));
      expect(player.loads, 1);
      expect(player.pauses, 0);
      expect(player.disposals, 0);
      host.dismiss();
      await tester.pumpAndSettle();
    });
  }

  testWidgets("a trailing tap cannot restore a mini-player being swiped away", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = PlaybackHost();
    final player = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [host],
        home: const Scaffold(body: Text("Browse Flow")),
      ),
    );
    await openStreamPlayer(
      tester.element(find.text("Browse Flow")),
      builder: (_) => player.screen("creator"),
    );
    await tester.pumpAndSettle();
    host.minimize();
    await tester.pumpAndSettle();
    final page = find.byKey(const ValueKey("player_page_creator"));
    final drag = await tester.startGesture(tester.getCenter(page));
    await drag.moveBy(const Offset(-30, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-100, 0));
    await tester.pump();
    await drag.up();
    await tester.pump();
    await tester.tapAt(tester.getCenter(page));
    await tester.pump();
    expect(host.mode, PlaybackMode.mini);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (page.evaluate().isNotEmpty) {
        expect(
          tester.widget<PlaybackPresentation>(find.byType(PlaybackPresentation)).mode,
          PlaybackMode.mini,
        );
        expect(tester.getSize(page), const Size(200, 112.5));
      }
    }
    expect(find.byType(_PlayerSurface), findsNothing);
    expect(find.text("Browse Flow").hitTestable(), findsOneWidget);
    expect(player.disposals, 1);
  });

  for (final miniEnabled in [true, false]) {
    testWidgets(
      "expanded chat stays above the keyboard and chat drags do not minimize playback (mini: $miniEnabled)",
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        final host = PlaybackHost()..setMiniPlayerEnabled(enabled: miniEnabled);
        final player = _PlaybackProbe();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [host],
            home: const Scaffold(body: Text("Browse Flow")),
          ),
        );
        await openStreamPlayer(
          tester.element(find.text("Browse Flow")),
          builder: (_) => player.screen("creator"),
        );
        await tester.pumpAndSettle();
        final surface = tester.element(find.byType(_PlayerSurface));
        final composer = find.byKey(const ValueKey("chat_message_input"));
        expect(tester.getBottomLeft(find.byKey(const ValueKey("player_page_creator"))).dy, 800);
        expect(composer.hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(composer).dy, greaterThan(249));

        await tester.dragFrom(const Offset(200, 400), const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(host.mode, PlaybackMode.expanded);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.getBottomLeft(composer).dy, lessThanOrEqualTo(500));
        expect(composer.hitTestable(), findsOneWidget);
        expect(tester.getSize(find.byType(_PlayerSurface)), const Size(400, 225));
        expect(tester.element(find.byType(_PlayerSurface)), same(surface));
        expect(player.loads, 1);
        host.dismiss();
        await tester.pumpAndSettle();
      },
    );
  }

  for (final videoId in <String?>[null, "123456"]) {
    testWidgets(
      "chat-only swipe translates and dismisses ${videoId == null ? "live" : "VOD"}",
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final host = PlaybackHost();
        final player = _PlaybackProbe();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [host],
            home: const Scaffold(body: Text("Browse Flow")),
          ),
        );
        await openStreamPlayer(
          tester.element(find.text("Browse Flow")),
          builder: (_) => player.screen("creator", videoId: videoId),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey("chat_menu")));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey("chat_only_toggle")));
        await tester.pumpAndSettle();
        final page = find.byKey(const ValueKey("player_page_creator"));
        final chat = tester.element(find.byType(TwitchChatPanel));
        final drag = await tester.startGesture(const Offset(220, 32));
        await drag.moveBy(const Offset(0, 40));
        await tester.pump();
        await drag.moveBy(const Offset(0, 120));
        await tester.pump();
        final heldTop = tester.getTopLeft(page).dy;
        expect(heldTop, greaterThan(0));
        expect(tester.getSize(page), const Size(400, 800));
        expect(tester.element(find.byType(TwitchChatPanel)), same(chat));
        await drag.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        expect(tester.getTopLeft(page).dy, greaterThan(heldTop));
        expect(tester.getSize(page), const Size(400, 800));
        expect(host.mode, PlaybackMode.expanded);
        expect(find.byKey(const ValueKey("player_mini")), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byType(StreamPlayerScreen), findsNothing);
        expect(find.text("Browse Flow").hitTestable(), findsOneWidget);
      },
    );

    for (final chatOnly in [false, true]) {
      testWidgets(
        "chat settings returns to the same ${videoId == null ? "live" : "VOD"} session (chat only: $chatOnly)",
        (tester) async {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final host = PlaybackHost();
          final player = _PlaybackProbe();
          await tester.pumpWidget(
            MaterialApp(
              navigatorObservers: [host],
              home: const Scaffold(body: Text("Browse Flow")),
            ),
          );
          await openStreamPlayer(
            tester.element(find.text("Browse Flow")),
            builder: (_) => player.screen("creator", videoId: videoId),
          );
          await tester.pumpAndSettle();
          if (chatOnly) {
            await tester.tap(find.byKey(const ValueKey("chat_menu")));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey("chat_only_toggle")));
            await tester.pumpAndSettle();
          }
          final screen = tester.element(find.byType(StreamPlayerScreen));
          final panel = tester.element(find.byType(TwitchChatPanel));
          final surface = chatOnly ? null : tester.element(find.byType(_PlayerSurface));
          final store = tester.widget<TwitchChatPanel>(find.byType(TwitchChatPanel)).settingsStore;
          final input = find.byKey(const ValueKey("chat_message_input"));
          final draft = videoId == null ? tester.widget<TextField>(input).controller! : null;
          draft?.text = "Unsent draft";
          final pauses = player.pauses;
          final disposals = player.disposals;
          await tester.tap(find.byKey(const ValueKey("chat_menu")));
          await tester.pumpAndSettle();
          await tester.tap(find.text("Settings"));
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(find.byKey(const ValueKey("settings_back")).hitTestable(), findsOneWidget);
          expect(
            tester.widget<SettingsScreen>(find.byType(SettingsScreen)).settingsStore,
            same(store),
          );
          expect(host.mode, PlaybackMode.expanded);
          expect(player.pauses, pauses);
          expect(player.disposals, disposals);
          await tester.tap(find.byKey(const ValueKey("settings_back")));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(SettingsScreen), findsOneWidget);
          _expectPaintsAbove(
            tester,
            find.byType(SettingsScreen),
            find.byType(StreamPlayerScreen),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsNothing);
          expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
          expect(tester.element(find.byType(TwitchChatPanel)), same(panel));
          if (surface != null) {
            expect(tester.element(find.byType(_PlayerSurface)), same(surface));
          }
          if (draft != null) {
            expect(tester.widget<TextField>(input).controller, same(draft));
            expect(draft.text, "Unsent draft");
          }
          expect(find.byKey(const ValueKey("chat_menu")).hitTestable(), findsOneWidget);
          expect(player.loads, 1);
          expect(player.surfaces, 1);
          expect(player.pauses, pauses);
          expect(player.disposals, disposals);
          host.dismiss();
          await tester.pumpAndSettle();
        },
      );
    }

    testWidgets(
      "chat-only back closes ${videoId == null ? "live" : "VOD"} without mini-player or PiP",
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.reset);
        final host = PlaybackHost();
        final player = _PlaybackProbe();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [host],
            home: const Scaffold(body: Text("Browse Flow")),
          ),
        );
        await openStreamPlayer(
          tester.element(find.text("Browse Flow")),
          builder: (_) => player.screen("creator", videoId: videoId),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(const ValueKey("player_page_background"))).dy, 0);
        expect(find.byKey(const ValueKey("chat_only_toggle")), findsNothing);
        await tester.tap(find.byKey(const ValueKey("chat_menu")));
        await tester.pumpAndSettle();
        expect(find.text("Chat only"), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey("chat_only_toggle")));
        await tester.pumpAndSettle();
        expect(find.byType(_PlayerSurface), findsNothing);
        expect(player.disposals, 1);
        expect(player.pauses, 1);
        expect(
          tester.getRect(find.byKey(const ValueKey("player_page_creator"))),
          const Rect.fromLTWH(0, 0, 400, 800),
        );
        expect(tester.getTopLeft(find.byKey(const ValueKey("player_chat_header"))).dy, 24);
        player.eventsController.add(const TwitchPictureInPictureEvent(active: true));
        await tester.pumpAndSettle();
        expect(host.mode, PlaybackMode.expanded);
        await tester.tap(find.byTooltip("Back"));
        await tester.pumpAndSettle();
        expect(find.byType(StreamPlayerScreen), findsNothing);
        expect(find.byKey(const ValueKey("player_mini")), findsNothing);
        expect(find.byKey(const ValueKey("player_chat_mini")), findsNothing);
        expect(find.text("Browse Flow").hitTestable(), findsOneWidget);
        expect(player.disposals, 1);
      },
    );
  }

  testWidgets("a newer stream selection wins while an earlier tooltip is closing", (
    tester,
  ) async {
    final host = PlaybackHost();
    final first = _PlaybackProbe();
    final latest = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [host],
        home: const Scaffold(
          body: Tooltip(message: "Stream preview", child: Text("Browse Flow")),
        ),
      ),
    );
    final browse = tester.element(find.text("Browse Flow"));
    await tester.longPress(find.text("Browse Flow"));
    await tester.pumpAndSettle();
    expect(find.text("Stream preview"), findsOneWidget);

    final earlier = openStreamPlayer(browse, builder: (_) => first.screen("first"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 76));
    await tester.pump();
    expect(find.text("Stream preview"), findsNothing);
    await openStreamPlayer(browse, builder: (_) => latest.screen("latest"));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    await earlier;

    expect(find.byKey(const ValueKey("player_page_latest")), findsOneWidget);
    expect(first.loads, 0);
    expect(latest.loads, 1);
    host.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets("leaving PiP dismisses a saved mini-player when mini-player was disabled", (
    tester,
  ) async {
    final host = PlaybackHost();
    final player = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [host],
        home: const Scaffold(body: Text("Browse Flow")),
      ),
    );
    await openStreamPlayer(
      tester.element(find.text("Browse Flow")),
      builder: (_) => player.screen("creator"),
    );
    await tester.pumpAndSettle();
    host.minimize();
    await tester.pumpAndSettle();
    host.setPictureInPicture(active: true);
    host.setMiniPlayerEnabled(enabled: false);
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.pip);
    expect(player.disposals, 0);

    host.setPictureInPicture(active: false);
    await tester.pumpAndSettle();
    expect(find.byType(_PlayerSurface), findsNothing);
    expect(find.byKey(const ValueKey("player_mini")), findsNothing);
    expect(player.disposals, 1);
    expect(player.pauses, 1);
  });

  for (final videoId in <String?>[null, "123456"]) {
    testWidgets(
      "${videoId == null ? "Live" : "VOD"} quality scrim stays above playback through every animation frame",
      (tester) async {
        final host = PlaybackHost();
        final player = _PlaybackProbe();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [host],
            home: const Scaffold(body: Text("Browse Flow")),
          ),
        );
        await tester.pumpAndSettle();
        await openStreamPlayer(
          tester.element(find.text("Browse Flow")),
          builder: (_) => player.screen("creator", videoId: videoId),
        );
        await tester.pumpAndSettle();
        player.emitQuality("auto");
        await tester.pump();
        final surface = tester.element(find.byType(_PlayerSurface));
        final barrier = find.byType(AnimatedModalBarrier);

        await tester.tap(find.byKey(const ValueKey("player_settings_button")));
        for (var frame = 0; frame < 25; frame++) {
          await tester.pump(Duration(milliseconds: frame == 0 ? 0 : 16));
          expect(barrier, findsOneWidget);
          _expectPaintsAbove(tester, barrier, find.byType(_PlayerSurface));
          expect(
            find
                .byKey(const ValueKey("player_surface_tap_target"))
                .hitTestable(at: const Alignment(0, -0.6)),
            findsNothing,
          );
        }

        await tester.tap(find.byKey(const ValueKey("player_quality_video:720")));
        var closingFrames = 0;
        for (var frame = 0; frame < 25; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (barrier.evaluate().isNotEmpty) {
            closingFrames++;
            _expectPaintsAbove(tester, barrier, find.byType(_PlayerSurface));
          }
        }
        expect(closingFrames, greaterThan(0));
        expect(barrier, findsNothing);
        expect(player.selectedQualities, ["video:720"]);
        expect(tester.element(find.byType(_PlayerSurface)), same(surface));
        expect(player.loads, 1);
        expect(player.surfaces, 1);
        expect(player.pauses, 0);
        expect(player.plays, 0);
        host.dismiss();
        await tester.pumpAndSettle();
      },
    );
  }

  for (final videoId in <String?>[null, "123456"]) {
    testWidgets(
      "${videoId == null ? "Live" : "VOD"} loading stays visible through a swipe to mini",
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final uri = Completer<Uri>();
        final host = PlaybackHost();
        final player = _PlaybackProbe()
          ..pendingUri = uri.future
          ..startsBuffering = true;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [host],
            home: const Scaffold(body: Text("Browse Flow")),
          ),
        );
        await openStreamPlayer(
          tester.element(find.text("Browse Flow")),
          builder: (_) => player.screen("creator", videoId: videoId),
        );
        await tester.pump();
        final screen = tester.element(find.byType(StreamPlayerScreen));
        final viewport = find.byKey(const ValueKey("player_viewport"));
        final spinner = find.byType(CircularProgressIndicator);
        expect(spinner, findsOneWidget);
        expect(find.byType(_PlayerSurface), findsNothing);

        final gesture = await tester.startGesture(tester.getCenter(viewport));
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        expect(spinner, findsOneWidget);
        await gesture.moveBy(const Offset(0, 140));
        await tester.pump(const Duration(milliseconds: 300));
        expect(spinner, findsOneWidget);
        expect(tester.getSize(viewport).width, allOf(greaterThan(200), lessThan(400)));
        expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));

        uri.complete(Uri.parse("https://example.com/late.m3u8"));
        await tester.pump();
        await tester.pump();
        final surface = tester.element(find.byType(_PlayerSurface));
        expect(spinner, findsOneWidget);
        expect(player.surfaces, 1);
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(host.mode, PlaybackMode.mini);
        expect(tester.getSize(viewport), const Size(200, 112.5));
        expect(spinner, findsOneWidget);
        expect(find.byKey(const ValueKey("player_mini")).hitTestable(), findsOneWidget);
        expect(find.byKey(const ValueKey("player_play_pause_button")), findsNothing);

        player.eventsController.add(
          const TwitchPlaybackStateEvent(
            isPlaying: true,
            isBuffering: false,
            playWhenReady: true,
          ),
        );
        await tester.pump();
        expect(spinner, findsNothing);
        expect(tester.element(find.byType(_PlayerSurface)), same(surface));
        await tester.tap(find.byKey(const ValueKey("player_mini")));
        await tester.pumpAndSettle();
        expect(host.mode, PlaybackMode.expanded);
        expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
        expect(tester.element(find.byType(_PlayerSurface)), same(surface));
        expect(player.loads, 1);
        expect(player.surfaces, 1);
        expect(player.pauses, 0);
        expect(player.plays, 0);
        expect(player.disposals, 0);
        host.dismiss();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets("swiping down dismisses playback smoothly when mini-player is disabled", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = PlaybackHost()..setMiniPlayerEnabled(enabled: false);
    final player = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [host],
        home: const Scaffold(body: Text("Browse Flow")),
      ),
    );
    await tester.pumpAndSettle();
    await openStreamPlayer(
      tester.element(find.text("Browse Flow")),
      builder: (_) => player.screen("creator"),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey("player_back_button")))
          .getSemanticsData()
          .tooltip,
      "Back",
    );
    expect(find.byTooltip("Minimize player"), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_back_button")),
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsOneWidget,
    );
    final surface = tester.element(find.byType(_PlayerSurface));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey("player_surface_tap_target"))),
    );
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey("player_page_creator"))).dy, greaterThan(0));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("player_page_background"))).dy,
      tester.getTopLeft(find.byKey(const ValueKey("player_page_creator"))).dy,
    );
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    expect(player.disposals, 0);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.byType(_PlayerSurface), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(_PlayerSurface), findsNothing);
    expect(find.byKey(const ValueKey("player_mini")), findsNothing);
    expect(find.text("Browse Flow"), findsOneWidget);
    expect(player.loads, 1);
    expect(player.disposals, 1);
    expect(player.pauses, 1);
    semantics.dispose();
  });

  testWidgets("short downward drags restore and completed swipes minimize the same player", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final host = PlaybackHost();
    final player = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [host],
        home: const Scaffold(body: Text("Browse Flow")),
      ),
    );
    await tester.pumpAndSettle();
    await openStreamPlayer(
      tester.element(find.text("Browse Flow")),
      builder: (_) => player.screen("creator"),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip("Minimize player"), findsOneWidget);
    final page = find.byKey(const ValueKey("player_page_creator"));
    final background = find.byKey(const ValueKey("player_page_background"));
    final target = find.byKey(const ValueKey("player_surface_tap_target"));
    final screen = tester.element(find.byType(StreamPlayerScreen));
    final surface = tester.element(find.byType(_PlayerSurface));
    expect(tester.getSize(background), const Size(400, 800));
    expect(tester.getSize(page), const Size(400, 776));
    expect(tester.getSize(find.byType(_PlayerSurface)), const Size(400, 225));
    final chat = tester.element(find.byType(TwitchChatPanel));
    final chatSize = tester.getSize(find.byType(TwitchChatPanel));
    final chatClip = find.byKey(const ValueKey("player_chat_clip"));
    expect(tester.getTopLeft(background).dy, 0);
    final shortDrag = await tester.startGesture(tester.getCenter(target));
    await shortDrag.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(background, findsOneWidget);
    await shortDrag.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(page).dy, greaterThan(0));
    expect(tester.getSize(page).width, lessThan(400));
    expect(tester.element(find.byType(TwitchChatPanel)), same(chat));
    expect(tester.getSize(find.byType(TwitchChatPanel)), chatSize);
    expect(tester.getSize(chatClip).height, allOf(greaterThan(0), lessThan(chatSize.height)));
    expect(tester.getTopLeft(background).dy, greaterThan(0));
    expect(tester.getTopLeft(background).dx, tester.getTopLeft(page).dx);
    expect(tester.getSize(background).width, tester.getSize(page).width);
    expect(tester.getTopLeft(background), tester.getTopLeft(page));
    expect(tester.getBottomLeft(background).dy, lessThan(800));
    final heldBackgroundTop = tester.getTopLeft(background).dy;
    final heldBackgroundBottom = tester.getBottomLeft(background).dy;
    await shortDrag.up();
    await tester.pump();
    expect(tester.getTopLeft(background).dy, heldBackgroundTop);
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.getTopLeft(background).dy, allOf(greaterThan(24), lessThan(heldBackgroundTop)));
    expect(tester.getTopLeft(background), tester.getTopLeft(page));
    expect(tester.getBottomLeft(background).dy, greaterThan(heldBackgroundBottom));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(tester.getTopLeft(page).dy, 24);
    expect(tester.getSize(background), const Size(400, 800));
    expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));

    final completedDrag = await tester.startGesture(tester.getCenter(target));
    await completedDrag.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 16));
    await completedDrag.moveBy(const Offset(0, 140));
    await tester.pump(const Duration(milliseconds: 16));
    final heldWidth = tester.getSize(page).width;
    final heldChatHeight = tester.getSize(chatClip).height;
    expect(heldWidth, allOf(greaterThan(200), lessThan(400)));
    expect(tester.getSize(find.byType(_PlayerSurface)).height, closeTo(heldWidth * 9 / 16, .01));
    expect(tester.getTopLeft(background).dy, greaterThan(0));
    await completedDrag.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(tester.getSize(page).width, lessThan(heldWidth));
    expect(tester.getSize(chatClip).height, lessThan(heldChatHeight));
    expect(tester.getSize(find.byType(TwitchChatPanel)), chatSize);
    expect(tester.element(find.byType(TwitchChatPanel)), same(chat));
    expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    await completedDrag.moveBy(const Offset(0, 250));
    await tester.pump();
    expect(tester.getTopLeft(background), tester.getTopLeft(page));
    final panelClip = tester.widget<ClipRRect>(
      find.ancestor(of: background, matching: find.byType(ClipRRect)).first,
    );
    final videoClip = tester.widget<ClipRRect>(
      find.ancestor(of: page, matching: find.byType(ClipRRect)).first,
    );
    expect(panelClip.borderRadius, BorderRadius.circular(10));
    expect(panelClip.borderRadius, videoClip.borderRadius);
    expect(tester.getBottomLeft(background).dy, lessThan(heldBackgroundBottom));
    expect(
      tester.getBottomLeft(background).dy,
      greaterThan(tester.getBottomLeft(find.byType(_PlayerSurface)).dy),
    );
    await completedDrag.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(host.mode, PlaybackMode.mini);
    expect(tester.getSize(page).width, allOf(greaterThan(200), lessThan(400)));
    expect(tester.getTopLeft(background).dy, allOf(greaterThan(0), lessThan(800)));
    await tester.pumpAndSettle();
    expect(tester.getSize(page).width, 200);
    expect(tester.getSize(chatClip).height, 0);
    expect(tester.getSize(find.byType(TwitchChatPanel)), chatSize);
    expect(tester.element(find.byType(TwitchChatPanel)), same(chat));
    final miniBottom = tester.getBottomLeft(page).dy;
    expect(tester.getRect(background), tester.getRect(page));
    expect(background.hitTestable(), findsNothing);
    expect(find.text("Browse Flow"), findsOneWidget);
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    await tester.tap(find.byKey(const ValueKey("player_mini")));
    await tester.pump();
    expect(tester.getRect(background), tester.getRect(page));
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.getSize(chatClip).height, allOf(greaterThan(0), lessThan(chatSize.height)));
    expect(tester.getSize(find.byType(TwitchChatPanel)), chatSize);
    expect(tester.element(find.byType(TwitchChatPanel)), same(chat));
    expect(tester.getTopLeft(background).dy, allOf(greaterThan(0), lessThan(800)));
    expect(
      tester.getSize(background).height,
      greaterThan(tester.getSize(find.byType(_PlayerSurface)).height),
    );
    expect(tester.getBottomLeft(background).dy, allOf(greaterThan(miniBottom), lessThan(800)));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(tester.getSize(page).width, 400);
    expect(tester.getSize(background), const Size(400, 800));
    expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    expect(player.loads, 1);
    expect(player.surfaces, 1);
    expect(player.pauses, 0);
    expect(player.plays, 0);
    expect(player.disposals, 0);
    host.dismiss();
    await tester.pumpAndSettle();
  });

  for (final direction in [-1.0, 1.0]) {
    testWidgets("mini-player follows horizontal drags and dismisses toward $direction", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final host = PlaybackHost();
      final player = _PlaybackProbe();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [host],
          home: const Scaffold(body: Text("Browse Flow")),
        ),
      );
      await tester.pumpAndSettle();
      await openStreamPlayer(
        tester.element(find.text("Browse Flow")),
        builder: (_) => player.screen("creator"),
      );
      await tester.pumpAndSettle();
      host.minimize();
      await tester.pumpAndSettle();
      final mini = find.byKey(const ValueKey("player_mini"));
      final page = find.byKey(const ValueKey("player_page_creator"));
      final rest = tester.getRect(page);
      final screen = tester.element(find.byType(StreamPlayerScreen));
      final surface = tester.element(find.byType(_PlayerSurface));

      final shortDrag = await tester.startGesture(tester.getCenter(mini));
      await shortDrag.moveBy(const Offset(-30, 0));
      await tester.pump();
      final beforeMove = tester.getRect(page);
      await shortDrag.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(page), beforeMove.shift(const Offset(-30, 0)));
      await shortDrag.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(page), rest);
      expect(host.mode, PlaybackMode.mini);

      final cancelledDrag = await tester.startGesture(tester.getCenter(mini));
      await cancelledDrag.moveBy(const Offset(30, 0));
      await tester.pump();
      await cancelledDrag.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(tester.getTopLeft(page).dx, greaterThan(rest.left));
      await cancelledDrag.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(page), rest);

      final verticalDrag = await tester.startGesture(tester.getCenter(mini));
      await verticalDrag.moveBy(const Offset(0, -60));
      await tester.pump();
      await verticalDrag.moveBy(const Offset(0, -100));
      await tester.pump();
      expect(tester.getRect(page), rest);
      await verticalDrag.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(page), rest);
      expect(host.mode, PlaybackMode.mini);
      expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
      expect(tester.element(find.byType(_PlayerSurface)), same(surface));

      final dismissDrag = await tester.startGesture(tester.getCenter(mini));
      await dismissDrag.moveBy(Offset(40 * direction, 0));
      await tester.pump();
      await dismissDrag.moveBy(Offset(220 * direction, 0));
      await tester.pump();
      final heldLeft = tester.getTopLeft(page).dx;
      expect((heldLeft - rest.left) * direction, greaterThan(80));
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(of: page, matching: find.byType(AnimatedOpacity)).first,
            )
            .opacity,
        1,
      );
      expect(player.disposals, 0);
      await dismissDrag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect((tester.getTopLeft(page).dx - heldLeft) * direction, greaterThan(0));
      final panelFade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey("player_page_background")),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      final videoFade = tester.widget<FadeTransition>(
        find.ancestor(of: page, matching: find.byType(FadeTransition)).first,
      );
      expect(panelFade.opacity.value, allOf(greaterThan(0), lessThan(1)));
      expect(panelFade.opacity.value, videoFade.opacity.value);
      expect(tester.element(find.byType(_PlayerSurface)), same(surface));
      expect(player.disposals, 0);
      await tester.pumpAndSettle();
      expect(find.byType(_PlayerSurface), findsNothing);
      expect(player.loads, 1);
      expect(player.surfaces, 1);
      expect(player.disposals, 1);
      expect(player.pauses, 1);
    });
  }

  for (final miniEnabled in [true, false]) {
    for (final videoId in <String?>[null, "123456"]) {
      testWidgets(
        "reopening ${videoId == null ? "live" : "VOD"} after swipe dismissal restores the page (mini: $miniEnabled)",
        (
          tester,
        ) async {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final host = PlaybackHost()..setMiniPlayerEnabled(enabled: miniEnabled);
          final first = _PlaybackProbe();
          final reopened = _PlaybackProbe();
          await tester.pumpWidget(
            MaterialApp(
              navigatorObservers: [host],
              home: const Scaffold(body: Text("Browse Flow")),
            ),
          );
          await tester.pumpAndSettle();
          final browse = tester.element(find.text("Browse Flow"));
          await openStreamPlayer(browse, builder: (_) => first.screen("creator", videoId: videoId));
          await tester.pumpAndSettle();
          if (miniEnabled) {
            host.minimize();
            await tester.pumpAndSettle();
            await tester.drag(find.byKey(const ValueKey("player_mini")), const Offset(-200, 0));
          } else {
            await tester.dragFrom(
              tester.getRect(find.byKey(const ValueKey("player_surface_tap_target"))).centerLeft +
                  const Offset(50, 0),
              const Offset(0, 200),
            );
          }
          await tester.pumpAndSettle();
          expect(find.byType(_PlayerSurface), findsNothing);
          expect(first.disposals, 1);

          await openStreamPlayer(
            browse,
            builder: (_) => reopened.screen("creator", videoId: videoId),
          );
          await tester.pumpAndSettle();
          expect(host.mode, PlaybackMode.expanded);
          expect(find.byKey(const ValueKey("player_page_background")), findsOneWidget);
          expect(
            find.byKey(const ValueKey("player_settings_button")).hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.getSize(find.byKey(const ValueKey("player_page_creator"))),
            const Size(400, 800),
          );
          expect(find.text("Browse Flow").hitTestable(), findsNothing);
          expect(reopened.loads, 1);
          expect(reopened.surfaces, 1);
          expect(reopened.disposals, 0);
          expect(reopened.pauses, 0);
          host.dismiss();
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets("browsing, restoring and PiP preserve one player and its audio quality", (
    tester,
  ) async {
    final host = PlaybackHost();
    final navigator = GlobalKey<NavigatorState>();
    final player = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [host],
        home: const Scaffold(body: Text("Browse Flow")),
      ),
    );
    await tester.pumpAndSettle();
    await openStreamPlayer(
      tester.element(find.text("Browse Flow")),
      builder: (_) => player.screen("creator"),
    );
    await tester.pumpAndSettle();
    player.emitQuality("video:720");
    await tester.pump();
    final surface = tester.element(find.byType(_PlayerSurface));

    await tester.tap(find.byKey(const ValueKey("player_settings_button")));
    await tester.pumpAndSettle();
    player.eventsController.add(const TwitchPictureInPictureEvent(active: true));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.pip);
    expect(find.byKey(const ValueKey("player_quality_audio_only")).hitTestable(), findsNothing);
    player.eventsController.add(const TwitchPictureInPictureEvent(active: false));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(find.byKey(const ValueKey("player_quality_audio_only")).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("player_quality_audio_only")));
    await tester.pumpAndSettle();
    expect(player.selectedQualities, ["audio_only"]);

    await tester.tap(find.byKey(const ValueKey("player_back_button")));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.mini);
    expect(find.byKey(const ValueKey("player_mini")), findsOneWidget);
    expect(find.byType(IconButton).hitTestable(), findsNothing);
    expect(find.text("Browse Flow"), findsOneWidget);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text("Another channel")),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Another channel"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("player_mini")));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);

    player.eventsController.add(const TwitchPictureInPictureEvent(active: true));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.pip);
    expect(find.byType(IconButton).hitTestable(), findsNothing);
    player.eventsController.add(const TwitchPictureInPictureEvent(active: false));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    expect(player.loads, 1);
    expect(player.surfaces, 1);
    expect(player.pauses, 0);
    expect(player.plays, 0);
    expect(player.disposals, 0);

    await tester.tap(find.byKey(const ValueKey("player_settings_button")));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_quality_audio_only")),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey("player_quality_video:720")));
    await tester.pumpAndSettle();
    expect(player.selectedQualities, ["audio_only", "video:720"]);
    expect(player.loads, 1);
    expect(player.surfaces, 1);

    host.minimize();
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey("player_mini")), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.byType(_PlayerSurface), findsNothing);
    expect(find.text("Another channel"), findsOneWidget);
    expect(player.disposals, 1);
    expect(player.pauses, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("PiP hides chrome before entry and resizes the same player without animation", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = PlaybackHost();
    final player = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [host],
        home: const Scaffold(body: Text("Browse Flow")),
      ),
    );
    await tester.pumpAndSettle();
    await openStreamPlayer(
      tester.element(find.text("Browse Flow")),
      builder: (_) => player.screen("creator"),
    );
    await tester.pumpAndSettle();
    final page = find.byKey(const ValueKey("player_page_creator"));
    final background = find.byKey(const ValueKey("player_page_background"));
    final screen = tester.element(find.byType(StreamPlayerScreen));
    final surface = tester.element(find.byType(_PlayerSurface));
    expect(find.byKey(const ValueKey("player_settings_button")), findsOneWidget);

    for (final mode in [PlaybackMode.expanded, PlaybackMode.mini]) {
      if (mode == PlaybackMode.mini) {
        host.minimize();
        await tester.pumpAndSettle();
      }
      final beforePip = tester.getRect(page);
      final beforePipVideo = tester.getRect(find.byType(_PlayerSurface));
      player.eventsController.add(const TwitchPictureInPictureTransitionEvent(active: true));
      await tester.idle();
      await tester.pump();
      expect(host.mode, mode);
      expect(tester.getRect(page), beforePip);
      if (mode == PlaybackMode.expanded) {
        expect(tester.getSize(background), const Size(400, 800));
      }
      expect(find.byType(IconButton).hitTestable(), findsNothing);
      expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
      expect(tester.element(find.byType(_PlayerSurface)), same(surface));

      player.eventsController.add(const TwitchPictureInPictureEvent(active: true));
      await tester.idle();
      await tester.pump();
      expect(host.mode, PlaybackMode.pip);
      expect(tester.getRect(page), beforePipVideo);
      expect(tester.getRect(find.byType(_PlayerSurface)), beforePipVideo);
      expect(background, findsNothing);
      tester.view.physicalSize = const Size(240, 135);
      await tester.pump();
      expect(tester.getRect(page), const Rect.fromLTWH(0, 0, 240, 135));
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.getRect(page), const Rect.fromLTWH(0, 0, 240, 135));

      tester.view.physicalSize = const Size(400, 800);
      player.eventsController.add(const TwitchPictureInPictureEvent(active: false));
      await tester.idle();
      await tester.pump();
      expect(host.mode, mode);
      expect(tester.getRect(page), beforePip);
      if (mode == PlaybackMode.expanded) {
        expect(tester.getSize(background), const Size(400, 800));
        expect(find.byKey(const ValueKey("player_settings_button")), findsOneWidget);
      }
      expect(tester.element(find.byType(StreamPlayerScreen)), same(screen));
      expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    }
    expect(player.loads, 1);
    expect(player.surfaces, 1);
    expect(player.disposals, 0);
    expect(player.pauses, 0);
    expect(player.plays, 0);
    host.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets("reopening the active stream retains it and switching disposes only that stream", (
    tester,
  ) async {
    final host = PlaybackHost();
    final navigator = GlobalKey<NavigatorState>();
    final tabNavigator = GlobalKey<NavigatorState>();
    final first = _PlaybackProbe();
    final reopened = _PlaybackProbe();
    final next = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [host],
        home: Navigator(
          key: tabNavigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text("Tab root")),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      tabNavigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text("Category")),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final category = tester.element(find.text("Category"));
    await openStreamPlayer(category, builder: (_) => first.screen("creator"));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.mini);
    expect(tester.element(find.text("Category")), same(category));
    await openStreamPlayer(category, builder: (_) => reopened.screen("Creator"));
    await tester.pumpAndSettle();
    expect(first.loads, 1);
    expect(first.disposals, 0);
    expect(reopened.loads, 0);
    await openStreamPlayer(category, builder: (_) => next.screen("another"));
    await tester.pumpAndSettle();
    expect(first.disposals, 1);
    expect(first.pauses, 1);
    expect(next.loads, 1);
    expect(next.surfaces, 1);
    expect(find.byType(_PlayerSurface), findsOneWidget);
    host.dismiss();
    await tester.pumpAndSettle();
    expect(next.disposals, 1);
    expect(tester.element(find.text("Category")), same(category));
    expect(tabNavigator.currentState!.canPop(), isTrue);
    expect(navigator.currentState!.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("VOD opens a full player page and keeps its surface across playback modes", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = PlaybackHost();
    final navigator = GlobalKey<NavigatorState>();
    final player = _PlaybackProbe();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [host],
        home: const Scaffold(body: Text("Channel VOD")),
      ),
    );
    await tester.pumpAndSettle();
    final channel = tester.element(find.text("Channel VOD"));
    await openStreamPlayer(channel, builder: (_) => player.screen("creator", videoId: "123456"));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(
      tester.getSize(find.byKey(const ValueKey("player_page_background"))),
      const Size(400, 800),
    );
    expect(tester.getSize(find.byKey(const ValueKey("player_page_creator"))), const Size(400, 800));
    expect(tester.getSize(find.byType(_PlayerSurface)), const Size(400, 225));
    expect(find.text("Channel VOD").hitTestable(), findsNothing);
    expect(player.loadedIds, ["123456"]);
    final surface = tester.element(find.byType(_PlayerSurface));
    await tester.tap(find.byKey(const ValueKey("player_back_button")));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.mini);
    expect(tester.element(find.text("Channel VOD")), same(channel));
    await tester.tap(find.byKey(const ValueKey("player_mini")));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    host.minimize();
    await tester.pumpAndSettle();
    host.setPictureInPicture(active: true);
    await tester.pumpAndSettle();
    host.setPictureInPicture(active: false);
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.mini);
    await openStreamPlayer(channel, builder: (_) => player.screen("creator", videoId: "123456"));
    await tester.pumpAndSettle();
    expect(host.mode, PlaybackMode.expanded);
    expect(tester.element(find.byType(_PlayerSurface)), same(surface));
    expect(player.loads, 1);
    expect(player.surfaces, 1);
    expect(player.pauses, 0);
    expect(player.plays, 0);
    player.eventsController.add(const TwitchPlaybackDismissedEvent());
    await tester.pumpAndSettle();
    expect(find.byType(_PlayerSurface), findsNothing);
    expect(player.disposals, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _expectPaintsAbove(WidgetTester tester, Finder above, Finder below) {
  List<RenderObject> ancestors(RenderObject object) {
    final result = <RenderObject>[];
    for (RenderObject? current = object; current != null; current = current.parent) {
      result.add(current);
    }
    return result;
  }

  final upper = ancestors(tester.renderObject(above));
  final lower = ancestors(tester.renderObject(below));
  final common = upper.firstWhere(lower.contains);
  final siblings = <RenderObject>[];
  common.visitChildren(siblings.add);
  expect(
    siblings.indexOf(upper[upper.indexOf(common) - 1]),
    greaterThan(siblings.indexOf(lower[lower.indexOf(common) - 1])),
    reason: "The popup must paint above playback, including during reverse animation.",
  );
}

class _PlaybackProbe implements TwitchPlayerController {
  @override
  Future<void> stop() async {}

  final eventsController = StreamController<TwitchPlayerEvent>.broadcast();
  final selectedQualities = <String>[];
  final loadedIds = <String>[];
  Future<Uri>? pendingUri;
  bool startsBuffering = false;
  int loads = 0;
  int surfaces = 0;
  int pauses = 0;
  int plays = 0;
  int disposals = 0;

  StreamPlayerScreen screen(String login, {String? videoId}) => StreamPlayerScreen(
    preferences: MemoryFlowPreferences(),
    apiCache: TwitchApiCache(
      clientLoader: () async => TwitchApiClient(clientId: "client", accessToken: "token"),
    ),
    channel: StreamChannel(
      login: login,
      name: login,
      initials: "CR",
      title: "Stream title",
      category: "Just Chatting",
      viewers: "12K",
      avatarColors: const [Colors.purple, Colors.pink],
      thumbnailColors: const [Colors.black, Colors.grey],
    ),
    videoId: videoId,
    chatControllerFactory: (channel) => TwitchChatController(
      channel: channel,
      clientLoader: () async => TwitchApiClient(clientId: "client", accessToken: "token"),
      autoConnect: false,
    ),
    replayControllerFactory: (id) => TwitchVodChatController(
      videoId: id,
      clientLoader: () async => throw StateError("Replay is offline in widget tests"),
      autoLoad: false,
    ),
    chatAssetsFactory: (channel) => TwitchChatAssets(
      channelLogin: channel,
      clientLoader: () async => throw StateError("Chat assets are offline in widget tests"),
      autoLoad: false,
    ),
    playbackUriLoader: (id) async {
      loads++;
      loadedIds.add(id);
      return pendingUri ?? Uri.parse("https://example.com/$id.m3u8");
    },
    viewerCountLoader: (_) async => null,
    playerSurfaceBuilder: (_, _, onCreated) => _PlayerSurface(this, onCreated),
  );

  void emitQuality(String id) => eventsController.add(
    TwitchQualitiesEvent(
      qualities: const [
        TwitchQualityOption(id: "video:720", label: "720p"),
        TwitchQualityOption(id: "audio_only", label: "Audio only"),
      ],
      selectedId: id,
    ),
  );

  @override
  Stream<TwitchPlayerEvent> get events => eventsController.stream;
  @override
  void dispose() => disposals++;
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> setQuality(String id) async {
    selectedQualities.add(id);
    emitQuality(id);
  }

  @override
  Future<void> setPictureInPictureEnabled({required bool enabled}) async {}

  @override
  Future<void> jumpToLive() async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> togglePlayback() async {}
}

class _PlayerSurface extends StatefulWidget {
  const _PlayerSurface(this._player, this._onCreated);
  final _PlaybackProbe _player;
  final ValueChanged<TwitchPlayerController> _onCreated;
  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface> {
  @override
  void initState() {
    super.initState();
    widget._player.surfaces++;
    widget._onCreated(widget._player);
    widget._player.eventsController.add(
      TwitchPlaybackStateEvent(
        isPlaying: !widget._player.startsBuffering,
        isBuffering: widget._player.startsBuffering,
        playWhenReady: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
