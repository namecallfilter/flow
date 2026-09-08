import "dart:async";
import "dart:convert";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/api/twitch_vod_chat.dart";
import "package:flow/app/app_settings_store.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/media3_player_controller.dart";
import "package:flow/features/player/player_navigation.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/features/player/twitch_chat_panel.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/stream_sort.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  for (final (chatOnly, buttonKey, destinationKey) in [
    (true, "player_chat_category_button", "category_streams_page_Just Chatting"),
    (false, "player_category_button", "category_streams_page_Just Chatting"),
    (false, "player_profile_button", "channel_page_creator"),
  ]) {
    testWidgets("hosted $buttonKey reaches its destination when playback must close", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final search = Completer<void>();
      final chat = _TrackedChatController("creator");
      final host = await _pumpHostedPlayer(
        tester,
        player: _FakePlayerController(),
        apiCache: _navigationApiCache(beforeCategorySearch: search.future),
        chatControllerFactory: (_) => chat,
      );
      host.setMiniPlayerEnabled(enabled: chatOnly);
      await tester.pump();
      if (chatOnly) {
        await _toggleChatOnly(tester);
      }
      await tester.tap(find.byKey(ValueKey(buttonKey)));
      if (buttonKey.contains("category")) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(StreamPlayerScreen), findsOneWidget);
        expect(chat.disposed, isFalse);
      }
      search.complete();
      await _pumpNavigation(tester);
      expect(find.byKey(ValueKey(destinationKey)), findsOneWidget);
      expect(find.byType(StreamPlayerScreen), findsNothing);
      expect(chat.disposed, isTrue);
      await tester.pageBack();
      await _pumpNavigation(tester);
      expect(find.text("Flow"), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets("chat-only title and category holds reveal the full text", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const title = "A long stream title that does not fit in the chat-only header";
    const category = "A long category name that does not fit beside the live metadata";
    await tester.pumpWidget(
      _playerApp(player: _FakePlayerController(), title: title, category: category),
    );
    await tester.pump();
    await _toggleChatOnly(tester);
    for (final (key, text, count) in [
      ("player_chat_name_and_title", title, 1),
      ("player_chat_category_button", category, 2),
    ]) {
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey(key))));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text(text), findsNWidgets(count));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text(text), findsNWidgets(count));
      await gesture.up();
      Tooltip.dismissAllToolTips();
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("chat-only category tap opens its streams and Back preserves chat", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _FakePlayerController();
    final chat = _TrackedChatController("creator");
    await tester.pumpWidget(
      _playerApp(
        player: player,
        apiCache: _navigationApiCache(),
        chatControllerFactory: (_) => chat,
      ),
    );
    await tester.pump();
    await _toggleChatOnly(tester);
    final chatState = tester.state(find.byType(TwitchChatPanel));
    await tester.tap(find.byKey(const ValueKey("player_chat_category_button")));
    await _pumpNavigation(tester);
    expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
    expect(chat.disposed, isFalse);
    await tester.pageBack();
    await _pumpNavigation(tester);
    expect(find.byKey(const ValueKey("player_chat_header")), findsOneWidget);
    expect(tester.state(find.byType(TwitchChatPanel)), same(chatState));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("confirmed offline stops video and Check again requires a live response", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _FakePlayerController();
    final chat = _TrackedChatController("creator");
    var online = true;
    var playbackLoads = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        chatControllerFactory: (_) => chat,
        apiCache: _StreamStatusApiCache((_) async => _streamStatusPage(online: online)),
        useApiViewerLoader: true,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live.m3u8");
        },
      ),
    );
    await tester.pump();
    final chatState = tester.state(find.byType(TwitchChatPanel));
    online = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text("Stream ended"), findsOneWidget);
    expect(find.text("Check again"), findsOneWidget);
    expect(find.byKey(const ValueKey("player_live_duration")), findsNothing);
    expect(find.byKey(const ValueKey("player_viewers")), findsNothing);
    expect(find.byKey(const ValueKey("player_center_control")), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(player._stopCount, 1);
    expect(player._disposeCount, 0);
    expect(player._pictureInPictureEnabledValues.last, isFalse);
    expect(tester.state(find.byType(TwitchChatPanel)), same(chatState));
    expect(chat.disposed, isFalse);
    expect(tester.widget<TwitchChatPanel>(find.byType(TwitchChatPanel)).latencyMs, 0);

    player.emit(const TwitchPlaybackReloadEvent());
    player.emit(const TwitchPlayerErrorEvent("Stale native error"));
    player.emit(
      const TwitchPlaybackStateEvent(isPlaying: true, isBuffering: true, playWhenReady: true),
    );
    await tester.pump();
    await tester.tap(find.text("Check again"));
    await tester.pump();
    expect(find.text("Stream ended"), findsOneWidget);
    expect(playbackLoads, 1);

    online = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text("Stream ended"), findsOneWidget);
    expect(playbackLoads, 1);
    await tester.tap(find.text("Check again"));
    await tester.pump();
    await tester.pump();
    expect(find.text("Stream ended"), findsNothing);
    expect(playbackLoads, 2);
    expect(player._disposeCount, 1);
    expect(player._pictureInPictureEnabledValues.last, isTrue);
    expect(tester.state(find.byType(TwitchChatPanel)), same(chatState));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(chat.disposed, isTrue);
  });

  testWidgets("failed status requests preserve playback and injected null is unknown", (
    tester,
  ) async {
    var fail = false;
    final player = _FakePlayerController();
    await tester.pumpWidget(
      _playerApp(
        player: player,
        apiCache: _StreamStatusApiCache((_) async {
          if (fail) {
            throw StateError("Offline network");
          }
          return _streamStatusPage(online: true);
        }),
        useApiViewerLoader: true,
      ),
    );
    await tester.pump();
    fail = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text("Stream ended"), findsNothing);
    expect(player._stopCount, 0);
    await tester.pumpWidget(_playerApp(player: player, login: "other"));
    await tester.pump();
    expect(find.text("Stream ended"), findsNothing);
    expect(player._stopCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("an old channel offline response cannot end the current channel", (tester) async {
    final previousStatus = Completer<TwitchPage<TwitchFollowedStream>>();
    final api = _StreamStatusApiCache(
      (login) => login == "creator"
          ? previousStatus.future
          : Future.value(_streamStatusPage(online: true)),
    );
    final player = _FakePlayerController();
    await tester.pumpWidget(
      _playerApp(player: player, apiCache: api, useApiViewerLoader: true),
    );
    await tester.pump();
    await tester.pumpWidget(
      _playerApp(player: player, login: "other", apiCache: api, useApiViewerLoader: true),
    );
    await tester.pump();
    previousStatus.complete(_streamStatusPage(online: false));
    await tester.pump();
    expect(find.text("Stream ended"), findsNothing);
    expect(player._stopCount, 0);
    expect(find.byKey(const ValueKey("player_page_other")), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("an empty stream lookup needs matching channel confirmation", (tester) async {
    var response = 0;
    final player = _FakePlayerController();
    await tester.pumpWidget(
      _playerApp(
        player: player,
        useApiViewerLoader: true,
        apiCache: _StreamStatusApiCache(
          (_) async => _streamStatusPage(online: false),
          detailsLoader: (_) async {
            if (response == 0) {
              throw StateError("Channel unavailable");
            }
            return _offlineChannelDetails(response == 1 ? "unrelated" : "");
          },
        ),
      ),
    );
    for (response = 0; response < 3; response++) {
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.text("Stream ended"), findsNothing);
      expect(player._stopCount, 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("a late offline confirmation cannot end a replacement channel", (tester) async {
    final confirmation = Completer<TwitchChannelDetails>();
    final api = _StreamStatusApiCache(
      (login) async => _streamStatusPage(online: login != "creator"),
      detailsLoader: (_) => confirmation.future,
    );
    final player = _FakePlayerController();
    await tester.pumpWidget(
      _playerApp(player: player, apiCache: api, useApiViewerLoader: true),
    );
    await tester.pump();
    await tester.pumpWidget(
      _playerApp(player: player, login: "other", apiCache: api, useApiViewerLoader: true),
    );
    await tester.pump();
    confirmation.complete(_offlineChannelDetails("creator"));
    await tester.pump();
    expect(find.text("Stream ended"), findsNothing);
    expect(player._stopCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("ended playback keeps PiP return events and the mini-player dismissible", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _FakePlayerController();
    final chat = _TrackedChatController("creator");
    final host = await _pumpHostedPlayer(
      tester,
      player: player,
      chatControllerFactory: (_) => chat,
    );
    host.setPictureInPicture(active: true);
    await _pumpNavigation(tester);
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: true,
        isEnded: true,
      ),
    );
    await tester.pump();
    expect(find.text("Stream ended"), findsOneWidget);
    expect(player._stopCount, 1);
    expect(player._disposeCount, 0);
    expect(chat.disposed, isFalse);
    player.emit(const TwitchPictureInPictureEvent(active: false));
    await _pumpNavigation(tester);
    expect(host.mode, PlaybackMode.expanded);
    expect(find.text("Check again"), findsOneWidget);
    host.minimize();
    await _pumpNavigation(tester);
    expect(find.text("Stream ended"), findsOneWidget);
    expect(find.text("Check again"), findsNothing);
    await tester.tap(find.byKey(const ValueKey("player_mini")));
    await _pumpNavigation(tester);
    expect(host.mode, PlaybackMode.expanded);
    expect(find.text("Check again"), findsOneWidget);
    expect(chat.disposed, isFalse);
    host.dismiss();
    await _pumpNavigation(tester);
    expect(chat.disposed, isTrue);
  });

  testWidgets("native live end preserves chat-only status and cannot start video again", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _FakePlayerController();
    var playbackLoads = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live.m3u8");
        },
      ),
    );
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: true,
        isEnded: true,
      ),
    );
    await tester.pump();
    expect(player._stopCount, 1);
    expect(find.text("Stream ended"), findsOneWidget);
    await _toggleChatOnly(tester);
    expect(find.text("Stream ended"), findsOneWidget);
    expect(find.byKey(const ValueKey("player_live_dot")), findsNothing);
    expect(find.byKey(const ValueKey("player_live_duration")), findsNothing);
    expect(find.byKey(const ValueKey("player_viewers")), findsNothing);
    await _toggleChatOnly(tester);
    expect(find.text("Stream ended"), findsOneWidget);
    expect(playbackLoads, 1);
    await tester.tap(find.text("Check again"));
    await tester.pump();
    expect(find.text("Stream ended"), findsOneWidget);
    expect(playbackLoads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("recording completion remains replayable without a stream-ended state", (
    tester,
  ) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player, videoId: "123456"));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: true,
        isEnded: true,
        position: Duration(minutes: 1),
        duration: Duration(minutes: 1),
      ),
    );
    await tester.pump();
    expect(find.text("Stream ended"), findsNothing);
    expect(player._stopCount, 0);
    expect(find.byKey(const ValueKey("player_center_control")), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("playback presentation and app lifecycle preserve healthy live chat connections", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = _TrackedChatController("creator");
    final host = await _pumpHostedPlayer(
      tester,
      player: _FakePlayerController(),
      chatControllerFactory: (_) => chat,
    );
    for (final status in [
      TwitchChatStatus.connecting,
      TwitchChatStatus.connected,
      TwitchChatStatus.reconnecting,
    ]) {
      chat.connectionStatus = status;
      host.minimize();
      await _pumpNavigation(tester);
      host.restore();
      await _pumpNavigation(tester);
      host.setPictureInPicture(active: true);
      await _pumpNavigation(tester);
      host.setPictureInPicture(active: false);
      await _pumpNavigation(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(chat.reconnectCount, 0);
      expect(chat.disposed, isFalse);
      expect(tester.widget<TwitchChatPanel>(find.byType(TwitchChatPanel)).controller, same(chat));
    }
    chat.connectionStatus = TwitchChatStatus.disconnected;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(chat.reconnectCount, 1);
    host.minimize();
    await _pumpNavigation(tester);
    host.restore();
    await _pumpNavigation(tester);
    expect(chat.reconnectCount, 2);
    host.dismiss();
    await _pumpNavigation(tester);
    expect(chat.disposed, isTrue);
  });

  testWidgets("mini and PiP release keyboard focus and retain the chat draft through resizing", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _FakePlayerController();
    final host = await _pumpHostedPlayer(
      tester,
      player: player,
      chatControllerFactory: (channel) => _TrackedChatController(channel, writable: true),
    );
    final composer = find.byKey(const ValueKey("chat_message_input"));
    final input = tester.widget<EditableText>(
      find.descendant(of: composer, matching: find.byType(EditableText)),
    );
    final surface = tester.element(find.byType(_FakePlayerSurface));
    for (final mode in [PlaybackMode.mini, PlaybackMode.pip]) {
      await tester.enterText(composer, "Keep this draft");
      expect(input.focusNode.hasFocus, isTrue);
      if (mode == PlaybackMode.mini) {
        host.minimize();
      } else {
        host.setPictureInPicture(active: true);
      }
      await _pumpNavigation(tester);
      expect(input.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.physicalSize = mode == PlaybackMode.mini
          ? const Size(800, 400)
          : const Size(240, 135);
      await _pumpNavigation(tester);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(400, 800);
      if (mode == PlaybackMode.mini) {
        host.restore();
      } else {
        host.setPictureInPicture(active: false);
      }
      await _pumpNavigation(tester);
      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(composer).controller, same(input.controller));
      expect(input.controller.text, "Keep this draft");
      expect(tester.element(find.byType(_FakePlayerSurface)), same(surface));
    }
    host.dismiss();
    await _pumpNavigation(tester);
  });

  testWidgets("chat-only metadata matches the video values and typography", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_playerApp(player: _FakePlayerController()));
    await tester.pump();
    Text metric(String key) => tester.widget<Text>(
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text)),
    );
    final duration = metric("player_live_duration");
    final viewers = metric("player_viewers");
    final dotSize = tester.getSize(find.byKey(const ValueKey("player_live_dot")));
    expect(duration.data, "1:02:03");
    expect(viewers.data, "12.3K");
    await _toggleChatOnly(tester);
    expect(tester.widget<TwitchChatPanel>(find.byType(TwitchChatPanel)).latencyMs, 0);
    for (final pair in [
      (metric("player_live_duration"), duration),
      (metric("player_viewers"), viewers),
    ]) {
      expect(pair.$1.data, pair.$2.data);
      expect(pair.$1.style?.fontSize, pair.$2.style?.fontSize);
      expect(pair.$1.style?.fontWeight, pair.$2.style?.fontWeight);
      expect(pair.$1.style?.fontFeatures, pair.$2.style?.fontFeatures);
    }
    expect(tester.getSize(find.byKey(const ValueKey("player_live_dot"))), dotSize);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    "VOD replay follows playback and seeks, freezes in chat only, and changes with the video",
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final player = _FakePlayerController();
      final replays = <_TrackedReplayController>[];
      TwitchVodChatController createReplay(String videoId) {
        final replay = _TrackedReplayController(videoId);
        replays.add(replay);
        return replay;
      }

      await tester.pumpWidget(
        _playerApp(player: player, videoId: "123456", replayControllerFactory: createReplay),
      );
      await tester.pump();
      final replay = replays.single;
      player.emit(
        const TwitchPlaybackStateEvent(
          isPlaying: true,
          isBuffering: false,
          playWhenReady: true,
          position: Duration(seconds: 20),
          duration: Duration(minutes: 2),
        ),
      );
      await tester.pump();
      expect(replay.positions, [(position: const Duration(seconds: 20), seek: false)]);

      final timeline = tester.getRect(find.byKey(const ValueKey("player_vod_seek")));
      await tester.tapAt(Offset(timeline.left + timeline.width * .75, timeline.center.dy));
      await tester.pump();
      final sought = player._seekPositions.single;
      expect(replay.positions.last, (position: sought, seek: true));
      final surface = tester.getRect(find.byKey(const ValueKey("player_surface_tap_target")));
      final rewindPoint = Offset(surface.left + surface.width * .2, surface.center.dy);
      await tester.tapAt(rewindPoint);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(rewindPoint);
      await tester.pump();
      expect(player._seekPositions.last, sought - const Duration(seconds: 10));
      expect(replay.positions.last, (position: player._seekPositions.last, seek: true));

      await _toggleChatOnly(tester);
      await tester.pump();
      final frozenPositions = List.of(replay.positions);
      player.emit(
        const TwitchPlaybackStateEvent(
          isPlaying: true,
          isBuffering: false,
          playWhenReady: true,
          position: Duration(seconds: 90),
          duration: Duration(minutes: 2),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(replay.positions, frozenPositions);
      expect(replay.disposed, isFalse);
      expect(find.byType(_FakePlayerSurface), findsNothing);

      await tester.pumpWidget(
        _playerApp(player: player, videoId: "654321", replayControllerFactory: createReplay),
      );
      await tester.pump();
      expect(replays.map((value) => value.videoId), ["123456", "654321"]);
      expect(replay.disposed, isTrue);
      expect(replays.last.disposed, isFalse);
      expect(replays.last.positions, isEmpty);
      expect(find.byType(_FakePlayerSurface), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(replays.last.disposed, isTrue);
    },
  );

  for (final videoId in [null, "123456"]) {
    testWidgets("chat only fits a landscape keyboard (${videoId == null ? "live" : "VOD"})", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_playerApp(player: _FakePlayerController(), videoId: videoId));
      await tester.pump();
      await _toggleChatOnly(tester);
      await tester.pump();
      tester.view.physicalSize = const Size(800, 400);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey("player_chat_header")), findsOneWidget);
      expect(find.byKey(const ValueKey("chat_menu")).hitTestable(), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey("chat_messages"))).height, greaterThan(0));
      if (videoId == null) {
        final composer = find.byKey(const ValueKey("chat_message_input"));
        expect(composer.hitTestable(), findsOneWidget);
        expect(tester.getBottomLeft(composer).dy, lessThanOrEqualTo(160));
      }
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("player_chat_header")), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets("chat only releases playback, keeps chat and reloads watching", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final videoId in [null, "123456"]) {
      final player = _FakePlayerController();
      final chats = <_TrackedChatController>[];
      final replays = <_TrackedReplayController>[];
      var loads = 0;
      await tester.pumpWidget(
        _playerApp(
          player: player,
          videoId: videoId,
          chatControllerFactory: (channel) {
            final chat = _TrackedChatController(channel);
            chats.add(chat);
            return chat;
          },
          replayControllerFactory: (id) {
            final replay = _TrackedReplayController(id);
            replays.add(replay);
            return replay;
          },
          playbackUriLoader: (_) async {
            loads++;
            return Uri.parse("https://example.com/live.m3u8");
          },
        ),
      );
      await tester.pump();
      expect(find.byType(_FakePlayerSurface), findsOneWidget);
      await _toggleChatOnly(tester);
      await tester.pump();
      expect(find.byType(_FakePlayerSurface), findsNothing);
      expect(find.byKey(const ValueKey("player_chat_header")), findsOneWidget);
      expect(player._pauseCount, 1);
      expect(player._disposeCount, 1);
      expect(chats.length + replays.length, 1);
      expect(chats.firstOrNull?.disposed ?? replays.single.disposed, isFalse);
      expect(loads, 1);
      await _toggleChatOnly(tester);
      await tester.pump();
      await tester.pump();
      expect(find.byType(_FakePlayerSurface), findsOneWidget);
      expect(chats.length + replays.length, 1);
      expect(loads, 2);
      await tester.pumpWidget(const SizedBox());
      expect(chats.firstOrNull?.disposed ?? replays.single.disposed, isTrue);
    }
  });

  testWidgets("channel changes dispose old chat and invalidate pending playback", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _FakePlayerController();
    final chats = <_TrackedChatController>[];
    final pendingUri = Completer<Uri>();
    TwitchChatController createChat(String channel) {
      final chat = _TrackedChatController(channel);
      chats.add(chat);
      return chat;
    }

    await tester.pumpWidget(
      _playerApp(
        player: player,
        chatControllerFactory: createChat,
        playbackUriLoader: (_) => pendingUri.future,
      ),
    );
    await tester.pump();
    await _toggleChatOnly(tester);
    await tester.pump();
    pendingUri.complete(Uri.parse("https://example.com/stale.m3u8"));
    await tester.pump();
    expect(find.byType(_FakePlayerSurface), findsNothing);
    await tester.pumpWidget(
      _playerApp(
        player: player,
        login: "another_creator",
        chatControllerFactory: createChat,
      ),
    );
    await tester.pump();
    expect(chats.map((chat) => chat.channel), ["creator", "another_creator"]);
    expect(chats.first.disposed, isTrue);
    expect(chats.last.disposed, isFalse);
    expect(find.byType(_FakePlayerSurface), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("PiP preference applies at attachment and updates without restarting playback", (
    tester,
  ) async {
    final preferences = MemoryFlowPreferences();
    await preferences.savePictureInPictureEnabled(enabled: false);
    final settingsStore = AppSettingsStore(preferences: preferences);
    await settingsStore.load();
    final player = _FakePlayerController();
    var loads = 0;
    var surfaces = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        settingsStore: settingsStore,
        playbackUriLoader: (_) async {
          loads++;
          return Uri.parse("https://example.com/live.m3u8");
        },
        onSurfaceCreated: () => surfaces++,
      ),
    );
    await tester.pump();
    final surface = tester.element(find.byType(_FakePlayerSurface));
    expect(player._pictureInPictureEnabledValues, [false]);

    await settingsStore.setPictureInPictureEnabled(enabled: true);
    await tester.pump();
    expect(player._pictureInPictureEnabledValues, [false, true]);
    expect(tester.element(find.byType(_FakePlayerSurface)), same(surface));
    expect(loads, 1);
    expect(surfaces, 1);
    expect(player._disposeCount, 0);
    expect(player._pauseCount, 0);
    expect(player._playCount, 0);
  });

  testWidgets("VOD playback loads the video ID and seeks within its timeline", (tester) async {
    final player = _FakePlayerController();
    final loadedIds = <String>[];
    await tester.pumpWidget(
      _playerApp(
        player: player,
        videoId: "123456",
        playbackUriLoader: (id) async {
          loadedIds.add(id);
          return Uri.parse("https://example.com/vod.m3u8");
        },
      ),
    );
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
        position: Duration(seconds: 10),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pump();
    expect(loadedIds, ["123456"]);
    expect(find.byKey(const ValueKey("player_jump_live_button")), findsNothing);
    expect(find.byKey(const ValueKey("player_latency")), findsNothing);
    final timeline = find.byKey(const ValueKey("player_vod_seek"));
    final rect = tester.getRect(timeline);
    await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
    await tester.pump();
    expect(player._seekPositions, hasLength(1));
    expect(player._seekPositions.single.inSeconds, inInclusiveRange(70, 110));
    expect(player._jumpToLiveCount, 0);
  });

  testWidgets("an ongoing VOD timeline grows without resetting playback or its surface", (
    tester,
  ) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player, videoId: "123456"));
    await tester.pump();
    final surface = tester.element(find.byType(_FakePlayerSurface));
    final timeline = find.byKey(const ValueKey("player_vod_seek"));
    for (final (position, duration) in [(0, 60), (10, 70), (20, 90)]) {
      player.emit(
        TwitchPlaybackStateEvent(
          isPlaying: true,
          isBuffering: false,
          playWhenReady: true,
          position: Duration(seconds: position),
          duration: Duration(seconds: duration),
        ),
      );
      await tester.pump();
      expect(tester.widget<Slider>(timeline).max, duration * 1000);
      expect(tester.widget<Slider>(timeline).value, position * 1000);
      expect(tester.element(find.byType(_FakePlayerSurface)), same(surface));
    }
    final rect = tester.getRect(timeline);
    await tester.tapAt(Offset(rect.left + rect.width * .95, rect.center.dy));
    await tester.pump();
    expect(player._seekPositions, hasLength(1));
    expect(player._seekPositions.single.inSeconds, greaterThan(60));
    expect(player._disposeCount, 0);
    expect(player._pauseCount, 0);
    expect(player._playCount, 0);
  });

  testWidgets("a held VOD seek keeps its preview visible through buffering recovery", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final player = _FakePlayerController();
    await tester.pumpWidget(
      _playerApp(
        player: player,
        videoId: "123456",
        apiCache: TwitchApiCache(
          clientLoader: () async => TwitchApiClient(
            clientId: "client",
            accessToken: "token",
            httpClient: MockClient(
              (request) async => request.method == "POST"
                  ? _jsonResponse({
                      "data": {
                        "video": {
                          "seekPreviewsURL": "https://example.com/storyboard.json",
                          "muteInfo": null,
                        },
                      },
                    })
                  : http.Response(
                      jsonEncode([
                        {
                          "width": 160,
                          "height": 90,
                          "cols": 2,
                          "rows": 2,
                          "count": 4,
                          "interval": 30,
                          "images": ["sprite.jpg"],
                        },
                      ]),
                      200,
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
        position: Duration(seconds: 10),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pump();
    final timeline = find.byKey(const ValueKey("player_vod_seek"));
    final preview = find.byKey(const ValueKey("player_vod_seek_preview"));
    final centerControl = find.byKey(const ValueKey("player_center_control"));
    expect(centerControl, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(timeline));
    await tester.pump();
    expect(preview, findsOneWidget);
    expect(centerControl, findsNothing);
    final sought = Duration(milliseconds: tester.widget<Slider>(timeline).value.round());

    for (final isBuffering in [true, false]) {
      player.emit(
        TwitchPlaybackStateEvent(
          isPlaying: !isBuffering,
          isBuffering: isBuffering,
          playWhenReady: true,
          position: const Duration(seconds: 11),
          duration: const Duration(minutes: 2),
        ),
      );
      await tester.pump();
      expect(centerControl, findsNothing);
    }
    await tester.pump(const Duration(seconds: 4));
    expect(_controlsOpacity(tester), 1);
    expect(preview, findsOneWidget);
    expect(centerControl, findsNothing);
    expect(tester.widget<Slider>(timeline).value, sought.inMilliseconds);
    expect(player._seekPositions, isEmpty);

    await gesture.up();
    await tester.pump();
    expect(preview, findsNothing);
    expect(centerControl, findsOneWidget);
    expect(player._seekPositions, [sought]);
  });

  testWidgets("VOD double taps seek ten seconds, clamp endpoints and fade feedback", (
    tester,
  ) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player, videoId: "123456"));
    await tester.pump();
    for (final (start, fraction, expected, label, icon) in [
      (20, .2, 10, "-10", Icons.chevron_left_rounded),
      (20, .8, 30, "+10", Icons.chevron_right_rounded),
      (3, .2, 0, "-10", Icons.chevron_left_rounded),
      (57, .8, 60, "+10", Icons.chevron_right_rounded),
    ]) {
      player.emit(
        TwitchPlaybackStateEvent(
          isPlaying: true,
          isBuffering: false,
          playWhenReady: true,
          position: Duration(seconds: start),
          duration: const Duration(minutes: 1),
        ),
      );
      await tester.pump();
      final rect = tester.getRect(find.byKey(const ValueKey("player_surface_tap_target")));
      final point = Offset(rect.left + rect.width * fraction, rect.center.dy);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(point);
      await tester.pump();
      expect(player._seekPositions.last, Duration(seconds: expected));
      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
      expect(
        find.byIcon(fraction < .5 ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
        findsNothing,
      );
      expect(find.text("10 seconds"), findsNothing);
      final labelX = tester.getCenter(find.text(label)).dx;
      for (final arrow in find.byIcon(icon).evaluate()) {
        expect(
          (tester.getCenter(find.byWidget(arrow.widget)).dx - labelX) * (fraction < .5 ? -1 : 1),
          greaterThan(0),
        );
      }
      expect(_controlsOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        tester.widget<AnimatedOpacity>(find.byKey(const ValueKey("player_seek_feedback"))).opacity,
        0,
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byIcon(icon), findsNothing);
      expect(_controlsOpacity(tester), 1);
    }
    expect(player._seekPositions, hasLength(4));
    expect(player._playCount, 0);
    expect(player._pauseCount, 0);
    expect(player._toggleCount, 0);
  });

  for (final controlsVisible in [true, false]) {
    testWidgets("VOD seek taps stack while paused and restore controls=$controlsVisible", (
      tester,
    ) async {
      final player = _FakePlayerController();
      await tester.pumpWidget(_playerApp(player: player, videoId: "123456"));
      await tester.pump();
      player.emit(
        const TwitchPlaybackStateEvent(
          isPlaying: false,
          isBuffering: false,
          playWhenReady: false,
          position: Duration(seconds: 20),
          duration: Duration(minutes: 2),
        ),
      );
      await tester.pump();
      final target = tester.getRect(find.byKey(const ValueKey("player_surface_tap_target")));
      final point = Offset(target.left + target.width * .8, target.center.dy);
      if (!controlsVisible) {
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(_controlsOpacity(tester), controlsVisible ? 1 : 0);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(point);
      await tester.pump();
      expect(find.text("+10"), findsOneWidget);
      expect(_controlsOpacity(tester), 0);

      player.emit(
        const TwitchPlaybackStateEvent(
          isPlaying: false,
          isBuffering: true,
          playWhenReady: false,
          position: Duration(seconds: 20),
          duration: Duration(minutes: 2),
        ),
      );
      await tester.pump();
      expect(_controlsOpacity(tester), 0);
      final cancelledTap = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 150));
      await cancelledTap.moveBy(const Offset(0, 80));
      await cancelledTap.up();
      await tester.pump();
      expect(player._seekPositions, [const Duration(seconds: 30)]);

      for (var extraTap = 1; extraTap <= 3; extraTap++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(point);
        await tester.pump();
        expect(player._seekPositions, hasLength(extraTap + 1));
        expect(player._seekPositions.last, Duration(seconds: 30 + extraTap * 10));
        expect(find.text("+${10 + extraTap * 10}"), findsOneWidget);
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(_controlsOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byKey(const ValueKey("player_seek_feedback")), findsNothing);
      expect(_controlsOpacity(tester), controlsVisible ? 1 : 0);
      expect(player._playCount, 0);
      expect(player._pauseCount, 0);
      expect(player._toggleCount, 0);
    });
  }

  testWidgets("VOD seek direction resets its count and timeout requires a new double tap", (
    tester,
  ) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player, videoId: "123456"));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
        position: Duration(seconds: 40),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pump();
    final target = tester.getRect(find.byKey(const ValueKey("player_surface_tap_target")));
    final right = Offset(target.left + target.width * .8, target.center.dy);
    final left = Offset(target.left + target.width * .2, target.center.dy);
    await tester.tapAt(right);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(right);
    await tester.pump();
    for (final (point, label, expected) in [
      (left, "-10", 40),
      (left, "-20", 30),
      (right, "+10", 40),
    ]) {
      await tester.tapAt(point);
      await tester.pump();
      expect(find.text(label), findsOneWidget);
      expect(player._seekPositions.last, Duration(seconds: expected));
    }
    expect(player._seekPositions, hasLength(4));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tapAt(right);
    await tester.pump(const Duration(milliseconds: 350));
    expect(player._seekPositions, hasLength(4));
    expect(find.byKey(const ValueKey("player_seek_feedback")), findsNothing);
    await tester.tapAt(right);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(right);
    await tester.pump();
    expect(player._seekPositions, hasLength(5));
    expect(player._seekPositions.last, const Duration(seconds: 50));
    expect(find.text("+10"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets("every VOD seek tap pulses the text and slides one arrow in the seek direction", (
    tester,
  ) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player, videoId: "123456"));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
        position: Duration(seconds: 40),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pump();
    final target = tester.getRect(find.byKey(const ValueKey("player_surface_tap_target")));
    final right = Offset(target.left + target.width * .8, target.center.dy);
    final left = Offset(target.left + target.width * .2, target.center.dy);
    await tester.tapAt(right);
    await tester.pump(const Duration(milliseconds: 100));
    for (final (point, label) in [(right, "+10"), (right, "+20"), (left, "-10")]) {
      await tester.tapAt(point);
      await tester.pump();
      final text = find.text(label);
      expect(tester.widget<Text>(text).style?.fontSize, 20);
      final arrow = find.byIcon(
        label.startsWith("+") ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      );
      final height = (tester.getBottomRight(text) - tester.getTopLeft(text)).dy;
      final arrowHeight = (tester.getBottomRight(arrow) - tester.getTopLeft(arrow)).dy;
      final arrowStart = tester.getCenter(arrow).dx;
      final direction = label.startsWith("+") ? 1 : -1;
      await tester.pump(const Duration(milliseconds: 150));
      final pulsedHeight = (tester.getBottomRight(text) - tester.getTopLeft(text)).dy;
      expect(pulsedHeight, lessThan(height * .95));
      expect(
        (tester.getBottomRight(arrow) - tester.getTopLeft(arrow)).dy,
        closeTo(arrowHeight, .01),
      );
      final arrowMiddle = tester.getCenter(arrow).dx;
      expect((arrowMiddle - arrowStart) * direction, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        (tester.getBottomRight(text) - tester.getTopLeft(text)).dy,
        closeTo(height, .01),
      );
      expect(
        (tester.getBottomRight(arrow) - tester.getTopLeft(arrow)).dy,
        closeTo(arrowHeight, .01),
      );
      final arrowEnd = tester.getCenter(arrow).dx;
      expect((arrowEnd - arrowMiddle) * direction, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getCenter(arrow).dx, closeTo(arrowEnd, .01));
    }
    expect(player._seekPositions, [
      const Duration(seconds: 50),
      const Duration(seconds: 60),
      const Duration(seconds: 50),
    ]);
    await tester.pump(const Duration(milliseconds: 1000));
  });

  for (final (key, tooltip) in [
    ("player_settings_button", "Video quality"),
    ("player_name_and_title", "A precise stream title"),
    ("player_category_button", "Just Chatting"),
  ]) {
    testWidgets("holding $key keeps its tooltip open and release gives three seconds", (
      tester,
    ) async {
      final player = _FakePlayerController();
      await tester.pumpWidget(_playerApp(player: player));
      await tester.pump();
      final surface = tester.element(find.byType(_FakePlayerSurface));
      player.emit(
        const TwitchPlaybackStateEvent(
          isPlaying: true,
          isBuffering: false,
          playWhenReady: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2300));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey(key))));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_controlsOpacity(tester), 1);
      expect(find.text(tooltip), findsNWidgets(key == "player_category_button" ? 2 : 1));
      for (final isBuffering in [true, false]) {
        player.emit(
          TwitchPlaybackStateEvent(
            isPlaying: !isBuffering,
            isBuffering: isBuffering,
            playWhenReady: true,
          ),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 4));
      expect(_controlsOpacity(tester), 1);
      expect(find.text(tooltip), findsNWidgets(key == "player_category_button" ? 2 : 1));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 2999));
      expect(_controlsOpacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_controlsOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(tooltip), findsNWidgets(key == "player_category_button" ? 1 : 0));
      expect(tester.element(find.byType(_FakePlayerSurface)), same(surface));
    });
  }

  testWidgets("control taps and pointer cancellation restart the inactivity countdown", (
    tester,
  ) async {
    final player = _FakePlayerController();
    final displayMode = _FakeDisplayModeController();
    await tester.pumpWidget(_playerApp(player: player, displayMode: displayMode));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    for (final key in ["player_orientation_button", "player_name_and_title"]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 750));
      expect(_controlsOpacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 1750));
    }
    expect(displayMode._landscapeRequests, [false]);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey("player_settings_button"))),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(_controlsOpacity(tester), 1);
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 2999));
    expect(_controlsOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_controlsOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text("Video quality"), findsNothing);
  });

  testWidgets("an open title tooltip disappears when controls are hidden by a tap", (tester) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
      ),
    );
    await tester.pump();
    await tester.longPress(find.byKey(const ValueKey("player_name_and_title")));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text("A precise stream title"), findsOneWidget);
    final target = tester.getRect(find.byKey(const ValueKey("player_surface_tap_target")));
    await tester.tapAt(Offset(target.left + target.width * .8, target.center.dy));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controlsOpacity(tester), 0);
    expect(find.text("A precise stream title"), findsNothing);
  });

  testWidgets("frequent VOD progress updates let controls hide and EOF restores Play", (
    tester,
  ) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player, videoId: "123456"));
    await tester.pump();
    for (var tick = 0; tick < 8; tick++) {
      player.emit(
        TwitchPlaybackStateEvent(
          isPlaying: true,
          isBuffering: false,
          playWhenReady: true,
          position: Duration(milliseconds: tick * 500),
          duration: const Duration(minutes: 2),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(_controlsOpacity(tester), 0);
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: true,
        position: Duration(minutes: 2),
        duration: Duration(minutes: 2),
        isEnded: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controlsOpacity(tester), 1);
    expect(find.byTooltip("Play"), findsOneWidget);
    expect(find.byTooltip("Pause"), findsNothing);
    await tester.tap(find.byKey(const ValueKey("player_play_pause_button")));
    expect(player._toggleCount, 1);
  });

  testWidgets("Auto shows the current renderer quality and updates while the sheet is open", (
    tester,
  ) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();
    player.emit(
      const TwitchQualitiesEvent(
        qualities: [TwitchQualityOption(id: "video:1080:60", label: "1080p60")],
        selectedId: "auto",
        currentLabel: "1080p60",
      ),
    );
    await tester.pump();
    await tester.longPress(find.byKey(const ValueKey("player_settings_button")));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text("Video quality"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("player_settings_button")));
    await _pumpNavigation(tester);
    expect(tester.takeException(), isNull);
    expect(find.text("Auto · 1080p60"), findsOneWidget);
    player.emit(
      const TwitchQualitiesEvent(
        qualities: [TwitchQualityOption(id: "video:1080:60", label: "1080p60")],
        selectedId: "auto",
        currentLabel: "720p60",
      ),
    );
    await tester.pump();
    expect(find.text("Auto · 720p60"), findsOneWidget);
    expect(find.text("Auto · 1080p60"), findsNothing);
  });

  testWidgets("refresh retains the selected quality while replacing the surface", (tester) async {
    final player = _FakePlayerController();
    final refresh = Completer<Uri>();
    var loads = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        playbackUriLoader: (_) async =>
            ++loads == 1 ? Uri.parse("https://example.com/live.m3u8") : refresh.future,
      ),
    );
    await tester.pump();
    player.emit(
      const TwitchQualitiesEvent(
        qualities: [TwitchQualityOption(id: "video:1080:60", label: "1080p60")],
        selectedId: "video:1080:60",
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("player_refresh_button")));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("player_settings_button")));
    await _pumpNavigation(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_quality_auto")),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
    refresh.complete(Uri.parse("https://example.com/refreshed.m3u8"));
    await tester.pump();
    expect(loads, 2);
  });

  testWidgets("native recovery refreshes once and preserves a pause made while loading", (
    tester,
  ) async {
    final player = _FakePlayerController();
    final refresh = Completer<Uri>();
    var loads = 0;
    var surfaces = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        onSurfaceCreated: () => surfaces++,
        playbackUriLoader: (_) async =>
            ++loads == 1 ? Uri.parse("https://example.com/live.m3u8") : refresh.future,
      ),
    );
    await tester.pump();
    player.emit(const TwitchPlaybackReloadEvent());
    player.emit(const TwitchPlaybackReloadEvent());
    await tester.pump();
    expect(loads, 2);
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
    );
    await tester.pump();
    refresh.complete(Uri.parse("https://example.com/refreshed.m3u8"));
    await tester.pump();
    expect(surfaces, 2);
    expect(player._pauseCount, 1);
    expect(player._playCount, 0);
  });

  test("subscription sync preserves manual whitelist entries", () async {
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    await preferences.saveAdProxyWhitelistedChannels(["manual"]);

    await syncSubscriptionWhitelist(preferences, login: "Creator", isSubscribed: true);
    expect(await preferences.readAdProxySubscriptionChannels(), ["creator"]);
    expect(await preferences.readAdProxyWhitelistedChannels(), ["manual"]);

    await syncSubscriptionWhitelist(preferences, login: "creator", isSubscribed: false);
    expect(await preferences.readAdProxySubscriptionChannels(), isEmpty);
    expect(await preferences.readAdProxyWhitelistedChannels(), ["manual"]);
  });

  testWidgets("syncs subscriptions only while ad proxying is enabled", (tester) async {
    var subscriptionRequests = 0;
    var playbackRequests = 0;
    final apiCache = TwitchApiCache(
      clientLoader: () async => TwitchApiClient(
        clientId: "client",
        accessToken: "token",
        gqlAccessToken: "gql-token",
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final query = body["query"] as String? ?? "";
          if (query.contains("FlowChannelSubscription")) {
            subscriptionRequests++;
            return _jsonResponse({
              "data": {
                "user": {
                  "self": {
                    "subscriptionBenefit": {"id": "sub-1"},
                  },
                },
              },
            });
          }
          playbackRequests++;
          return _jsonResponse({
            "data": {
              "streamPlaybackAccessToken": {
                "value": "{\"expires\":1780000000}",
                "signature": "signature",
                "authorization": {
                  "isForbidden": false,
                  "forbiddenReasonCode": null,
                },
              },
            },
          });
        }),
      ),
    );
    final preferences = SharedPreferencesFlowPreferences(store: _MemoryPreferencesStore());
    final settingsStore = AppSettingsStore(preferences: preferences);
    await settingsStore.load();

    await tester.pumpWidget(
      _playerApp(
        player: _FakePlayerController(),
        apiCache: apiCache,
        settingsStore: settingsStore,
        useApiPlaybackLoader: true,
      ),
    );
    await _pumpNavigation(tester);

    expect(playbackRequests, 1);
    expect(subscriptionRequests, 0);

    await settingsStore.setAdProxyEnabled(enabled: true);
    await tester.tap(find.byKey(const ValueKey("player_refresh_button")));
    await _pumpNavigation(tester);

    expect(playbackRequests, 2);
    expect(subscriptionRequests, 1);
    expect(settingsStore.adProxySubscriptionChannels, ["creator"]);
    expect(await preferences.readAdProxySubscriptionChannels(), ["creator"]);
  });

  testWidgets("shows measured latency and keeps playback controls independent", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    final displayMode = _FakeDisplayModeController();
    var playbackLoads = 0;
    var surfaceCreations = 0;

    await tester.pumpWidget(
      _playerApp(
        player: player,
        displayMode: displayMode,
        onSurfaceCreated: () => surfaceCreations++,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live-$playbackLoads.m3u8");
        },
      ),
    );
    await tester.pump();

    expect(find.text("--"), findsOneWidget);
    player.emit(const TwitchLatencyEvent(2050));
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: true,
        playWhenReady: false,
      ),
    );
    await tester.pump();
    expect(find.text("2.05s"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("player_play_pause_button")));
    await tester.tap(find.byKey(const ValueKey("player_jump_live_button")));
    await tester.tap(find.byKey(const ValueKey("player_orientation_button")));
    await tester.pump();

    expect(player._toggleCount, 1);
    expect(player._jumpToLiveCount, 1);
    expect(displayMode._landscapeRequests, [true]);

    await tester.tap(find.byKey(const ValueKey("player_refresh_button")));
    await tester.pump();
    expect(find.text("--"), findsOneWidget);
    expect(playbackLoads, 2);
    expect(surfaceCreations, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(displayMode._restoreCount, 1);
  });

  testWidgets("shows unsupported playback without loading or buffering forever", (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var playbackLoads = 0;

    try {
      await tester.pumpWidget(
        _playerApp(
          player: _FakePlayerController(),
          useDefaultPlayerSurface: true,
          playbackUriLoader: (_) async {
            playbackLoads++;
            return Uri.parse("https://example.com/unused.m3u8");
          },
        ),
      );
      await tester.pump();

      expect(find.text("Playback is available on Android."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(playbackLoads, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets("refresh replaces a surface before its controller attaches", (
    tester,
  ) async {
    final currentPlayer = _FakePlayerController();
    final stalePlayer = _FakePlayerController();
    final sessions = <({Uri uri, ValueChanged<TwitchPlayerController> attachController})>[];
    var playbackLoads = 0;

    await tester.pumpWidget(
      _playerApp(
        player: currentPlayer,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live-$playbackLoads.m3u8");
        },
        playerSurfaceBuilder: (context, uri, onControllerCreated) => _DeferredPlayerSurface(
          uri: uri,
          onControllerCreated: onControllerCreated,
          onSurfaceCreated: (createdUri, attachController) {
            sessions.add((
              uri: createdUri,
              attachController: attachController,
            ));
          },
        ),
      ),
    );
    await tester.pump();
    expect(sessions.map((session) => session.uri.path), ["/live-1.m3u8"]);

    await tester.tap(find.byKey(const ValueKey("player_refresh_button")));
    await tester.pump();
    expect(
      sessions.map((session) => session.uri.path),
      ["/live-1.m3u8", "/live-2.m3u8"],
    );

    sessions.first.attachController(stalePlayer);
    sessions.last.attachController(currentPlayer);
    currentPlayer.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("player_play_pause_button")));

    expect(stalePlayer._toggleCount, 0);
    expect(currentPlayer._toggleCount, 1);
  });

  testWidgets("fills landscape and mirrors the largest cutout inset", (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(
      left: 44,
      right: 8,
      top: 3,
      bottom: 20,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
    );
    await tester.pump();

    final viewport = tester.getRect(find.byKey(const ValueKey("player_viewport")));
    final topRow = tester.getRect(find.byKey(const ValueKey("player_top_row")));
    final bottomRow = tester.getRect(find.byKey(const ValueKey("player_bottom_row")));

    expect(viewport, const Rect.fromLTWH(0, 0, 800, 400));
    expect(topRow.left, 44);
    expect(topRow.right, 756);
    expect(bottomRow.left, 44);
    expect(bottomRow.right, 756);
    expect(topRow.top, 20);
    expect(bottomRow.bottom, 380);
  });

  testWidgets("rotating preserves the platform player and playback session", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    var surfaceCreations = 0;
    var playbackLoads = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        onSurfaceCreated: () => surfaceCreations++,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live.m3u8");
        },
      ),
    );
    await tester.pump();
    expect(surfaceCreations, 1);
    expect(playbackLoads, 1);

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();

    expect(surfaceCreations, 1);
    expect(playbackLoads, 1);
    expect(find.byKey(const ValueKey("player_chrome_landscape")), findsOneWidget);
  });

  testWidgets("a hidden-overlay center tap reveals controls before pausing", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
      ),
    );
    await tester.pump();

    final viewport = tester.getRect(
      find.byKey(const ValueKey("player_viewport")),
    );
    await tester.tapAt(Offset(viewport.left + 100, viewport.center.dy));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controlsOpacity(tester), 0);

    await tester.tapAt(viewport.center);
    await tester.pump(const Duration(milliseconds: 200));

    expect(player._toggleCount, 0);
    expect(_controlsOpacity(tester), 1);

    await tester.tap(find.byKey(const ValueKey("player_play_pause_button")));
    await tester.pump();
    expect(player._toggleCount, 1);
  });

  testWidgets("hidden controls retain latency without rebuilding the video surface", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _FakePlayerController();
    var surfaceBuilds = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        playerSurfaceBuilder: (context, uri, onControllerCreated) {
          surfaceBuilds++;
          return _FakePlayerSurface(player: player, onControllerCreated: onControllerCreated);
        },
      ),
    );
    await tester.pump();
    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controlsOpacity(tester), 0);
    final hiddenSurfaceBuilds = surfaceBuilds;

    player.emit(const TwitchLatencyEvent(2300));
    await tester.pump(const Duration(seconds: 2));
    expect(surfaceBuilds, hiddenSurfaceBuilds);
    expect(tester.widget<TwitchChatPanel>(find.byType(TwitchChatPanel)).latencyMs, 2300);

    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey("player_viewport"))));
    await tester.pump();
    expect(_controlsOpacity(tester), 1);
    expect(find.text("2.30s"), findsOneWidget);
  });

  testWidgets("an open quality sheet populates when player tracks arrive", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    final playbackUri = Completer<Uri>();
    var surfaceCreations = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        playbackUriLoader: (_) => playbackUri.future,
        onSurfaceCreated: () => surfaceCreations++,
      ),
    );
    await tester.pump();
    expect(surfaceCreations, 0);

    await tester.tap(find.byKey(const ValueKey("player_settings_button")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey("player_quality_sheet")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_auto")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_loading")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_video:1080")), findsNothing);

    playbackUri.complete(Uri.parse("https://example.com/live.m3u8"));
    await tester.pump();
    expect(surfaceCreations, 1);

    player.emit(
      const TwitchQualitiesEvent(
        selectedId: "video:1080",
        qualities: [
          TwitchQualityOption(
            id: "video:1080",
            label: "1080p60",
          ),
          TwitchQualityOption(
            id: "video:720",
            label: "720p60",
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey("player_quality_loading")), findsNothing);
    expect(find.byKey(const ValueKey("player_quality_video:1080")), findsOneWidget);
    expect(find.byKey(const ValueKey("player_quality_video:720")), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_quality_video:1080")),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey("player_quality_auto")),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey("player_quality_video:720")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(player._selectedQualityIds, ["video:720"]);
  });

  for (final (buttonKey, destinationKey) in [
    ("player_profile_button", "channel_page_creator"),
    ("player_category_button", "category_streams_page_Just Chatting"),
  ]) {
    for (final wasPlaying in [true, false]) {
      testWidgets("opening $destinationKey without a host restores playing=$wasPlaying", (
        tester,
      ) async {
        final player = _FakePlayerController();
        await tester.pumpWidget(_playerApp(player: player, apiCache: _navigationApiCache()));
        await tester.pump();
        player.emit(
          TwitchPlaybackStateEvent(
            isPlaying: wasPlaying,
            isBuffering: false,
            playWhenReady: wasPlaying,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(ValueKey(buttonKey)));
        await _pumpNavigation(tester);
        expect(find.byKey(ValueKey(destinationKey)), findsOneWidget);
        expect(player._pauseCount, wasPlaying ? 1 : 0);
        expect(player._playCount, 0);
        expect(player._disposeCount, 0);

        await tester.pageBack();
        await _pumpNavigation(tester);
        expect(player._playCount, wasPlaying ? 1 : 0);
        expect(player._disposeCount, 0);
      });
    }

    testWidgets("opening $destinationKey minimizes playback without interrupting it", (
      tester,
    ) async {
      final player = _FakePlayerController();
      final host = await _pumpHostedPlayer(tester, player: player);
      await tester.longPress(find.byKey(const ValueKey("player_name_and_title")));
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text("A precise stream title"), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(buttonKey)));
      await _pumpNavigation(tester);
      expect(tester.takeException(), isNull);
      expect(host.mode, PlaybackMode.mini);
      expect(find.byKey(ValueKey(destinationKey)), findsOneWidget);
      expect(find.byKey(const ValueKey("player_mini")), findsOneWidget);
      expect(player._pauseCount, 0);
      expect(player._playCount, 0);
      expect(player._disposeCount, 0);
      await tester.tap(find.byKey(const ValueKey("player_mini")));
      await _pumpNavigation(tester);
      expect(host.mode, PlaybackMode.expanded);
      expect(player._pauseCount, 0);
      expect(player._playCount, 0);
      if (buttonKey == "player_profile_button") {
        await tester.tap(find.byKey(const ValueKey("player_category_button")));
        await _pumpNavigation(tester);
        expect(find.byKey(const ValueKey("category_streams_page_Just Chatting")), findsOneWidget);
        expect(host.mode, PlaybackMode.mini);
        expect(player._pauseCount, 0);
        expect(player._playCount, 0);
      }
      host.dismiss();
      await _pumpNavigation(tester);
    });
  }
  testWidgets("leaves background playback and automatic PiP to the native player", (tester) async {
    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();

    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(player._pauseCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player._playCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(player._pauseCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player._playCount, 0);
  });

  testWidgets("lifecycle changes preserve playback while browsing a destination", (
    tester,
  ) async {
    final player = _FakePlayerController();
    final host = await _pumpHostedPlayer(tester, player: player);

    await tester.tap(find.byKey(const ValueKey("player_profile_button")));
    await _pumpNavigation(tester);
    expect(find.byKey(const ValueKey("channel_page_creator")), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player._playCount, 0);

    await tester.pageBack();
    await _pumpNavigation(tester);
    expect(host.mode, PlaybackMode.mini);
    expect(player._pauseCount, 0);
    expect(player._playCount, 0);
    host.dismiss();
    await _pumpNavigation(tester);
  });

  testWidgets("minimizing for a destination releases forced landscape", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    final displayMode = _FakeDisplayModeController();
    final host = await _pumpHostedPlayer(tester, player: player, displayMode: displayMode);

    await tester.tap(find.byKey(const ValueKey("player_orientation_button")));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("player_profile_button")));
    await _pumpNavigation(tester);

    expect(find.byKey(const ValueKey("channel_page_creator")), findsOneWidget);
    expect(displayMode._operations, ["landscape:true", "restore"]);
    expect(player._playCount, 0);

    await tester.pageBack();
    await _pumpNavigation(tester);
    expect(displayMode._operations, ["landscape:true", "restore"]);
    expect(player._playCount, 0);
    expect(host.mode, PlaybackMode.mini);
    host.dismiss();
    await _pumpNavigation(tester);
  });

  testWidgets("dispose restores display mode after a pending transition", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final displayMode = _BlockingDisplayModeController();
    await tester.pumpWidget(
      _playerApp(
        player: _FakePlayerController(),
        displayMode: displayMode,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey("player_orientation_button")));
    await tester.pump();
    expect(displayMode._operations, ["landscape:true:start"]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(displayMode._operations, ["landscape:true:start"]);

    displayMode.completeLandscapeTransition();
    await tester.pump();
    await tester.pump();
    expect(
      displayMode._operations,
      ["landscape:true:start", "landscape:true:end", "restore"],
    );
  });

  testWidgets("a player attaching while browsing starts without an extra pause or resume", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    final playbackUri = Completer<Uri>();
    final host = await _pumpHostedPlayer(
      tester,
      player: player,
      playbackUriLoader: (_) => playbackUri.future,
    );

    await tester.tap(find.byKey(const ValueKey("player_profile_button")));
    await _pumpNavigation(tester);
    expect(find.byKey(const ValueKey("channel_page_creator")), findsOneWidget);
    expect(player._pauseCount, 0);

    playbackUri.complete(Uri.parse("https://example.com/late-live.m3u8"));
    await _pumpNavigation(tester);
    expect(player._pauseCount, 0);

    await tester.pageBack();
    await _pumpNavigation(tester);
    expect(player._playCount, 0);
    host.dismiss();
    await _pumpNavigation(tester);
  });

  testWidgets("a player attaching behind a destination without a host waits until return", (
    tester,
  ) async {
    final player = _FakePlayerController();
    final playbackUri = Completer<Uri>();
    await tester.pumpWidget(
      _playerApp(
        player: player,
        apiCache: _navigationApiCache(),
        playbackUriLoader: (_) => playbackUri.future,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("player_profile_button")));
    await _pumpNavigation(tester);

    playbackUri.complete(Uri.parse("https://example.com/late-live.m3u8"));
    await _pumpNavigation(tester);
    expect(find.byKey(const ValueKey("channel_page_creator")), findsOneWidget);
    expect(player._pauseCount, 1);
    expect(player._playCount, 0);

    await tester.pageBack();
    await _pumpNavigation(tester);
    expect(player._playCount, 1);
  });

  testWidgets("updates viewers separately and freezes latency while paused", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    var playbackLoads = 0;
    var viewerLoads = 0;
    await tester.pumpWidget(
      _playerApp(
        player: player,
        playbackUriLoader: (_) async {
          playbackLoads++;
          return Uri.parse("https://example.com/live.m3u8");
        },
        viewerCountLoader: (_) async {
          viewerLoads++;
          return viewerLoads == 1 ? 15000 : 20000;
        },
      ),
    );
    await tester.pump();
    expect(find.text("15K"), findsOneWidget);

    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: true,
        isBuffering: false,
        playWhenReady: true,
      ),
    );
    player.emit(const TwitchLatencyEvent(2000));
    await tester.pump();
    expect(find.text("2.00s"), findsOneWidget);

    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: false,
        playWhenReady: false,
      ),
    );
    player.emit(const TwitchLatencyEvent(9000));
    await tester.pump();
    expect(find.text("2.00s"), findsOneWidget);
    expect(find.text("9.00s"), findsNothing);
    expect(find.byTooltip("Play"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    player.emit(
      const TwitchPlaybackStateEvent(
        isPlaying: false,
        isBuffering: true,
        playWhenReady: true,
      ),
    );
    await tester.pump();
    player.emit(const TwitchLatencyEvent(1500));
    await tester.pump();
    expect(find.text("1.50s"), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text("20K"), findsOneWidget);
    expect(viewerLoads, 2);
    expect(playbackLoads, 1);
  });

  testWidgets("keeps stitched-ad progress visible through updates and rotation", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayerController();
    await tester.pumpWidget(_playerApp(player: player));
    await tester.pump();

    player.emit(const TwitchLatencyEvent(2100));
    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 1,
        total: 3,
        remainingMs: 24000,
      ),
    );
    await tester.pump();

    expect(find.text("2.10s"), findsOneWidget);
    expect(find.text("Ad 1 of 3 · 0:24"), findsOneWidget);
    expect(find.byKey(const ValueKey("player_ad_progress")), findsOneWidget);
    final portraitViewport = tester.getRect(
      find.byKey(const ValueKey("player_viewport")),
    );
    await tester.tapAt(
      Offset(portraitViewport.left + 100, portraitViewport.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text("Ad 1 of 3 · 0:24"), findsOneWidget);
    final controlsOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey("player_top_row")),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(controlsOpacity.opacity, 0);

    await tester.tapAt(
      Offset(portraitViewport.left + 100, portraitViewport.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(
      Offset(portraitViewport.left + 100, portraitViewport.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 2,
        total: 3,
        remainingMs: 12000,
      ),
    );
    await tester.pump();
    expect(find.text("Ad 2 of 3 · 0:12"), findsOneWidget);

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    final landscapeViewport = tester.getRect(
      find.byKey(const ValueKey("player_viewport")),
    );
    final adPill = tester.getRect(find.byKey(const ValueKey("player_ad_progress")));
    expect(find.text("Ad 2 of 3 · 0:12"), findsOneWidget);
    expect(landscapeViewport.contains(adPill.topLeft), isTrue);
    expect(landscapeViewport.contains(adPill.bottomRight), isTrue);

    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 0,
        total: 0,
        remainingMs: 6000,
      ),
    );
    await tester.pump();
    expect(find.text("Ad · 0:06"), findsOneWidget);

    player.emit(const TwitchPlayerErrorEvent("Playback failed"));
    await tester.pump();
    expect(find.byKey(const ValueKey("player_ad_progress")), findsNothing);

    player.emit(
      const TwitchAdEvent(
        active: true,
        current: 3,
        total: 3,
        remainingMs: 4000,
      ),
    );
    await tester.pump();

    player.emit(
      const TwitchAdEvent(
        active: false,
        current: 0,
        total: 0,
        remainingMs: 0,
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey("player_ad_progress")), findsNothing);
  });
}

double _controlsOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey("player_top_row")),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

Future<void> _toggleChatOnly(WidgetTester tester) async {
  final wasChatOnly = find.byKey(const ValueKey("player_chat_header")).evaluate().isNotEmpty;
  expect(find.byKey(const ValueKey("chat_only_toggle")), findsNothing);
  await tester.tap(find.byKey(const ValueKey("chat_menu")));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(find.text(wasChatOnly ? "Show video" : "Chat only"), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey("chat_only_toggle")));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pumpNavigation(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<PlaybackHost> _pumpHostedPlayer(
  WidgetTester tester, {
  required _FakePlayerController player,
  PlayerDisplayModeController? displayMode,
  PlaybackUriLoader? playbackUriLoader,
  TwitchApiCache? apiCache,
  TwitchChatController Function(String)? chatControllerFactory,
}) async {
  final app =
      _playerApp(
            player: player,
            displayMode: displayMode,
            playbackUriLoader: playbackUriLoader,
            chatControllerFactory: chatControllerFactory,
            apiCache: apiCache ?? _navigationApiCache(),
          )
          as MaterialApp;
  final host = PlaybackHost();
  await tester.pumpWidget(
    MaterialApp(
      theme: app.theme,
      navigatorObservers: [host],
      home: const Scaffold(body: Text("Flow")),
    ),
  );
  await _pumpNavigation(tester);
  await openStreamPlayer(tester.element(find.text("Flow")), builder: (_) => app.home!);
  await _pumpNavigation(tester);
  return host;
}

Widget _playerApp({
  required _FakePlayerController player,
  String login = "creator",
  String title = "A precise stream title",
  String category = "Just Chatting",
  TwitchChatController Function(String)? chatControllerFactory,
  TwitchVodChatController Function(String)? replayControllerFactory,
  String? videoId,
  TwitchApiCache? apiCache,
  PlayerDisplayModeController? displayMode,
  PlaybackUriLoader? playbackUriLoader,
  ViewerCountLoader? viewerCountLoader,
  VoidCallback? onSurfaceCreated,
  PlayerSurfaceBuilder? playerSurfaceBuilder,
  bool useDefaultPlayerSurface = false,
  bool useApiPlaybackLoader = false,
  bool useApiViewerLoader = false,
  AppSettingsStore? settingsStore,
}) {
  final app = MaterialApp(
    theme: buildFlowTheme(Brightness.dark),
    home: StreamPlayerScreen(
      chatControllerFactory: chatControllerFactory ?? _TrackedChatController.new,
      replayControllerFactory: replayControllerFactory ?? _TrackedReplayController.new,
      preferences: settingsStore == null ? MemoryFlowPreferences() : null,
      chatAssetsFactory: (channel) => TwitchChatAssets(
        channelLogin: channel,
        clientLoader: () async => throw StateError("Chat assets are offline in widget tests"),
        autoLoad: false,
      ),
      videoId: videoId,
      apiCache:
          apiCache ??
          TwitchApiCache(
            clientLoader: () async => TwitchApiClient(
              clientId: "client",
              accessToken: "token",
            ),
          ),
      channel: StreamChannel(
        id: "creator-1",
        login: login,
        name: "Creator",
        initials: "CR",
        title: title,
        category: category,
        viewers: "12.3K",
        startedAt: DateTime(2026, 7, 9, 19),
        avatarColors: const [Colors.purple, Colors.pink],
        thumbnailColors: const [Colors.black, Colors.grey],
      ),
      playbackUriLoader: useApiPlaybackLoader
          ? null
          : playbackUriLoader ?? (_) async => Uri.parse("https://example.com/live.m3u8"),
      viewerCountLoader: useApiViewerLoader ? null : viewerCountLoader ?? (_) async => null,
      displayModeController: displayMode ?? _FakeDisplayModeController(),
      clock: () => DateTime(2026, 7, 9, 20, 2, 3),
      playerSurfaceBuilder: useDefaultPlayerSurface
          ? null
          : playerSurfaceBuilder ??
                (context, uri, onControllerCreated) => _FakePlayerSurface(
                  player: player,
                  onControllerCreated: onControllerCreated,
                  onSurfaceCreated: onSurfaceCreated,
                ),
    ),
  );
  return settingsStore == null ? app : AppSettingsScope(settingsStore: settingsStore, child: app);
}

class _StreamStatusApiCache extends TwitchApiCache {
  _StreamStatusApiCache(this._load, {this.detailsLoader})
    : super(clientLoader: () async => throw StateError("Only stream status is available"));

  final Future<TwitchPage<TwitchFollowedStream>> Function(String login) _load;
  final Future<TwitchChannelDetails> Function(String login)? detailsLoader;

  @override
  Future<TwitchChannelDetails> fetchChannelDetails(
    String login, {
    int videosFirst = 30,
    String? videosCursor,
    bool refresh = false,
  }) async => detailsLoader != null ? detailsLoader!(login) : _offlineChannelDetails(login);

  @override
  Future<TwitchPage<TwitchFollowedStream>> fetchLiveStreamsPage({
    int first = 20,
    List<String> gameIds = const [],
    List<String> userLogins = const [],
    String? cursor,
    bool refresh = false,
    StreamSort sort = StreamSort.viewersHighToLow,
  }) => _load(userLogins.single);
}

TwitchChannelDetails _offlineChannelDetails(String login) => TwitchChannelDetails(
  id: "creator-1",
  login: login,
  displayName: "Creator",
  description: "",
  followers: 1,
  pastBroadcasts: const [],
  pastBroadcastsCursor: null,
);

TwitchPage<TwitchFollowedStream> _streamStatusPage({required bool online}) => TwitchPage(
  data: [
    if (online)
      TwitchFollowedStream(
        id: "stream-1",
        userId: "creator-1",
        userLogin: "creator",
        userName: "Creator",
        gameName: "Just Chatting",
        title: "Live stream",
        viewerCount: 12345,
        startedAt: DateTime(2026, 7, 9, 19),
      ),
  ],
  cursor: null,
);

TwitchApiCache _navigationApiCache({Future<void>? beforeCategorySearch}) => TwitchApiCache(
  clientLoader: () async => TwitchApiClient(
    clientId: "client",
    accessToken: "token",
    httpClient: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final query = body["query"] as String? ?? "";
      if (query.contains("FlowChannelDetails")) {
        return _jsonResponse({
          "data": {
            "user": {
              "id": "creator-1",
              "login": "creator",
              "displayName": "Creator",
              "description": "",
              "profileImageURL": null,
              "followers": {"totalCount": 0},
              "stream": null,
              "videos": {
                "edges": const <Object?>[],
                "pageInfo": {"hasNextPage": false},
              },
            },
          },
        });
      }
      if (query.contains("FlowSearchCategories")) {
        await beforeCategorySearch;
        return _jsonResponse({
          "data": {
            "searchCategories": {
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
        return _jsonResponse({
          "data": {
            "game": {
              "streams": {
                "edges": const <Object?>[],
                "pageInfo": {"hasNextPage": false},
              },
            },
          },
        });
      }
      throw StateError("Unexpected GraphQL request: $query");
    }),
  ),
);

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {"content-type": "application/json"},
);

class _FakePlayerSurface extends StatefulWidget {
  const _FakePlayerSurface({
    required this._player,
    required this._onControllerCreated,
    this._onSurfaceCreated,
  });

  final TwitchPlayerController _player;
  final ValueChanged<TwitchPlayerController> _onControllerCreated;
  final VoidCallback? _onSurfaceCreated;

  @override
  State<_FakePlayerSurface> createState() => _FakePlayerSurfaceState();
}

class _FakePlayerSurfaceState extends State<_FakePlayerSurface> {
  @override
  void initState() {
    super.initState();
    widget._onSurfaceCreated?.call();
    widget._onControllerCreated(widget._player);
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

class _DeferredPlayerSurface extends StatefulWidget {
  const _DeferredPlayerSurface({
    required this.uri,
    required this.onControllerCreated,
    required this.onSurfaceCreated,
  });

  final Uri uri;
  final ValueChanged<TwitchPlayerController> onControllerCreated;
  final void Function(Uri, ValueChanged<TwitchPlayerController>) onSurfaceCreated;

  @override
  State<_DeferredPlayerSurface> createState() => _DeferredPlayerSurfaceState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Uri>("uri", uri));
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchPlayerController>>.has(
        "onControllerCreated",
        onControllerCreated,
      ),
    );
    properties.add(
      ObjectFlagProperty<void Function(Uri, ValueChanged<TwitchPlayerController>)>.has(
        "onSurfaceCreated",
        onSurfaceCreated,
      ),
    );
  }
}

class _DeferredPlayerSurfaceState extends State<_DeferredPlayerSurface> {
  @override
  void initState() {
    super.initState();
    widget.onSurfaceCreated(widget.uri, widget.onControllerCreated);
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

class _TrackedReplayController extends TwitchVodChatController {
  _TrackedReplayController(String videoId)
    : super(
        videoId: videoId,
        clientLoader: () async => throw StateError("Replay is offline in widget tests"),
        autoLoad: false,
      );

  bool disposed = false;
  final positions = <({Duration position, bool seek})>[];

  @override
  void updatePosition(Duration position, {bool seek = false}) {
    positions.add((position: position, seek: seek));
  }

  @override
  void reconnect() {}

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _TrackedChatController extends TwitchChatController {
  _TrackedChatController(String channel, {this.writable = false})
    : super(
        channel: channel,
        clientLoader: () async => throw StateError("Chat is offline in widget tests"),
        autoConnect: false,
      );

  bool disposed = false;
  final bool writable;
  int reconnectCount = 0;
  TwitchChatStatus connectionStatus = TwitchChatStatus.connecting;

  @override
  TwitchChatStatus get status => connectionStatus;

  @override
  bool get canSend => writable;

  @override
  void reconnect() => reconnectCount++;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _FakePlayerController implements TwitchPlayerController {
  @override
  Future<void> setPictureInPictureEnabled({required bool enabled}) async {
    _pictureInPictureEnabledValues.add(enabled);
  }

  final _events = StreamController<TwitchPlayerEvent>.broadcast();
  int _jumpToLiveCount = 0;
  int _toggleCount = 0;
  int _pauseCount = 0;
  int _stopCount = 0;
  int _playCount = 0;
  int _disposeCount = 0;
  final _seekPositions = <Duration>[];
  final _pictureInPictureEnabledValues = <bool>[];

  @override
  Stream<TwitchPlayerEvent> get events => _events.stream;

  @override
  void dispose() {
    _disposeCount++;
  }

  void emit(TwitchPlayerEvent event) => _events.add(event);

  @override
  Future<void> jumpToLive() async {
    _jumpToLiveCount++;
  }

  @override
  Future<void> seekTo(Duration position) async {
    _seekPositions.add(position);
  }

  @override
  Future<void> pause() async {
    _pauseCount++;
  }

  @override
  Future<void> stop() async {
    _stopCount++;
  }

  @override
  Future<void> play() async {
    _playCount++;
  }

  @override
  Future<void> setQuality(String id) async {
    _selectedQualityIds.add(id);
  }

  @override
  Future<void> togglePlayback() async {
    _toggleCount++;
  }

  final _selectedQualityIds = <String>[];
}

class _FakeDisplayModeController implements PlayerDisplayModeController {
  final _landscapeRequests = <bool>[];
  final _operations = <String>[];
  int _restoreCount = 0;

  @override
  Future<void> restore() async {
    _restoreCount++;
    _operations.add("restore");
  }

  @override
  Future<void> setLandscape({required bool landscape}) async {
    _landscapeRequests.add(landscape);
    _operations.add("landscape:$landscape");
  }
}

class _BlockingDisplayModeController implements PlayerDisplayModeController {
  final _landscapeTransition = Completer<void>();
  final _operations = <String>[];

  void completeLandscapeTransition() => _landscapeTransition.complete();

  @override
  Future<void> restore() async {
    _operations.add("restore");
  }

  @override
  Future<void> setLandscape({required bool landscape}) async {
    _operations.add("landscape:$landscape:start");
    await _landscapeTransition.future;
    _operations.add("landscape:$landscape:end");
  }
}

class _MemoryPreferencesStore implements FlowPreferencesStore {
  final strings = <String, String>{};
  final stringLists = <String, List<String>>{};

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<List<String>?> getStringList(String key) async => stringLists[key];

  @override
  Future<void> remove(String key) async {
    strings.remove(key);
    stringLists.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async => strings[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      stringLists[key] = List.of(value);
}
