import "dart:async";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/features/player/twitch_chat_panel.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  testWidgets("fallback color stays with the login across rebuilds and panels", (tester) async {
    final controller = _ColorController();
    addTearDown(controller.dispose);
    controller.message = _message("first", "session_viewer");
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    final original = _nameColor(tester);

    controller.message = _message("second", "SESSION_VIEWER");
    controller.notifyListeners();
    await tester.pump();
    expect(_nameColor(tester), original);
    await tester.pumpWidget(_panel(controller, brightness: Brightness.dark));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    expect(_nameColor(tester), original);

    await tester.pumpWidget(const SizedBox.shrink());
    final next = _ColorController(channel: "another_channel");
    addTearDown(next.dispose);
    next.message = _message("third", "session_viewer");
    await tester.pumpWidget(_panel(next));
    await tester.pumpAndSettle();
    expect(_nameColor(tester), original);
  });

  testWidgets("explicit black and very dark colors override a cached fallback", (tester) async {
    final controller = _ColorController();
    addTearDown(controller.dispose);
    controller.message = _message("fallback", "color_viewer");
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    final fallback = _nameColor(tester);

    for (final raw in ["#000000", "#000020"]) {
      controller.message = _message(raw, "color_viewer", color: raw);
      controller.notifyListeners();
      await tester.pumpWidget(_panel(controller));
      await tester.pumpAndSettle();
      expect(_nameColor(tester), raw == "#000000" ? Colors.black : const Color(0xFF000020));
      await tester.pumpWidget(_panel(controller, brightness: Brightness.dark));
      await tester.pumpAndSettle();
      expect(_nameColor(tester), const Color(0xFF7A7A7A));
    }

    controller.message = _message("fallback-again", "COLOR_VIEWER");
    controller.notifyListeners();
    await tester.pumpWidget(_panel(controller));
    await tester.pumpAndSettle();
    expect(_nameColor(tester), fallback);
  });

  testWidgets("channel assets color black broadcaster mentions before any broadcaster message", (
    tester,
  ) async {
    final native = Completer<TwitchNativeChatAssets>();
    final client = _BroadcasterClient(native.future);
    final assets = TwitchChatAssets(
      clientLoader: () async => client,
      channelLogin: "hivise",
      autoLoad: false,
      httpClient: MockClient((_) async => http.Response("missing", 404)),
    );
    final controller = _ColorController(channel: "hivise")
      ..message = const TwitchChatMessage(
        id: "mention",
        login: "viewer",
        displayName: "Viewer",
        text: "Hi @hivise",
      );
    addTearDown(assets.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_panel(controller, assets: assets));
    await tester.pumpAndSettle();
    final loading = assets.refresh();
    await tester.pump();
    native.complete(
      const TwitchNativeChatAssets(
        channelId: "123",
        broadcaster: TwitchUser(
          id: "123",
          login: "hivise",
          displayName: "Hivise",
          chatColor: "#000000",
        ),
        badgeUrls: {},
        emoteIdsByName: {},
      ),
    );
    await tester.pumpAndSettle();
    await loading;
    final text = tester.widget<RichText>(find.textContaining("Hi @hivise", findRichText: true));
    Color? color;
    text.text.visitChildren((span) {
      if (span is TextSpan && span.text == "@hivise") {
        color = span.style?.color;
      }
      return true;
    });
    expect(color, Colors.black);
    expect(controller.recentHistory.single.login, "viewer");
    expect(client.calls, 1);
  });
}

TwitchChatMessage _message(String id, String login, {String? color}) => TwitchChatMessage(
  id: id,
  login: login,
  displayName: "Viewer",
  text: "hello",
  color: color,
);

Widget _panel(
  _ColorController controller, {
  Brightness brightness = Brightness.light,
  TwitchChatAssets? assets,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: Scaffold(
    body: TwitchChatPanel(
      controller: controller,
      assets: assets,
      chatOnly: true,
      isLive: false,
      preferences: MemoryFlowPreferences(),
      onToggleChatOnly: () {},
    ),
  ),
);

Color? _nameColor(WidgetTester tester) {
  final text = tester.widget<RichText>(find.text("Viewer: hello", findRichText: true));
  Color? color;
  text.text.visitChildren((span) {
    if (span is TextSpan && span.text == "Viewer: ") {
      color = span.style?.color;
    }
    return true;
  });
  expect(color, isNotNull);
  return color;
}

class _ColorController extends TwitchChatController {
  _ColorController({super.channel = "testchannel"})
    : super(autoConnect: false, clientLoader: () async => throw StateError("Unused"));

  late TwitchChatMessage message;

  @override
  List<TwitchChatMessage> get recentHistory => [message];

  @override
  TwitchChatStatus get status => TwitchChatStatus.connected;
}

class _BroadcasterClient extends TwitchApiClient {
  _BroadcasterClient(this.native) : super(clientId: "test", accessToken: "");

  final Future<TwitchNativeChatAssets> native;
  int calls = 0;

  @override
  Future<TwitchNativeChatAssets> fetchChatAssets(String login) {
    calls++;
    return native;
  }
}
