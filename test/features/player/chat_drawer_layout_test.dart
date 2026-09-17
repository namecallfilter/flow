import "package:flow/api/twitch_chat.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/player/twitch_chat_panel.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  for (final layout in [
    (name: "portrait", size: const Size(400, 900), left: 0.0, right: 0.0),
    (name: "landscape left cutout", size: const Size(900, 400), left: 64.0, right: 0.0),
    (name: "landscape right cutout", size: const Size(900, 400), left: 0.0, right: 64.0),
  ]) {
    testWidgets("chat drawer stays compact with centered content in ${layout.name}", (
      tester,
    ) async {
      tester.view.physicalSize = layout.size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(left: layout.left, right: layout.right, bottom: 20);
      tester.view.viewPadding = tester.view.padding;
      addTearDown(tester.view.reset);
      final controller = TwitchChatController(
        channel: "testchannel",
        clientLoader: () async => throw StateError("Network unused in layout tests"),
        autoConnect: false,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFlowTheme(Brightness.light),
          home: Scaffold(
            body: TwitchChatPanel(
              controller: controller,
              chatOnly: false,
              isLive: true,
              onToggleChatOnly: () {},
              preferences: MemoryFlowPreferences(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Chat options"));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      final surface = tester.getRect(
        find.descendant(of: sheet, matching: find.byType(Material)).first,
      );
      final action = tester.getRect(find.byKey(const ValueKey("chat_only_toggle")));
      final handle = find
          .descendant(
            of: sheet,
            matching: find.byWidgetPredicate(
              (widget) => widget is Semantics && widget.properties.onTap != null,
            ),
          )
          .first;
      final safeWidth = layout.size.width - layout.left - layout.right;
      expect(surface.width, safeWidth.clamp(0, 640));
      expect(surface.center.dx, layout.left + safeWidth / 2);
      expect(action.center.dx, tester.getCenter(handle).dx);
      expect(tester.getTopLeft(find.byIcon(Icons.chat)).dx - surface.left, 16);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
