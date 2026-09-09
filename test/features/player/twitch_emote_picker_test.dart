import "dart:async";
import "dart:convert";
import "dart:ui" as ui;

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_chat_assets.dart";
import "package:flow/features/player/twitch_emote_picker.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("wide emote previews use the larger cell without cropping", (tester) async {
    final assets = _Assets();
    addTearDown(assets.dispose);
    final emote = assets.emotesFor(ChatEmoteProvider.twitch, ChatEmoteScope.channel).single;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(160, 40);
      picture.dispose();
      PaintingBinding.instance.imageCache.putIfAbsent(
        NetworkImage(emote.urlForBrightness(Brightness.light)),
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
      );
    });
    addTearDown(PaintingBinding.instance.imageCache.clear);
    final selected = <ChatAssetEmote>[];
    await tester.pumpWidget(_picker(assets, MemoryFlowPreferences(), onSelected: selected.add));
    await tester.tap(find.text("Twitch"));
    await tester.pumpAndSettle();
    final preview = tester.renderObject<RenderImage>(find.byType(RawImage));
    final painted = applyBoxFit(preview.fit!, const Size(160, 40), preview.size).destination;
    expect(painted.width, greaterThanOrEqualTo(75));
    expect(painted.width / painted.height, 4);
    expect(painted.height, greaterThanOrEqualTo(18.75));
    await tester.tap(find.byTooltip(emote.name));
    await tester.pumpAndSettle();
    expect(selected.single.name, emote.name);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the final emote row scrolls above the system gesture area", (tester) async {
    tester.view.viewPadding = FakeViewPadding(bottom: 24 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    final assets = _Assets()..count = 30;
    addTearDown(assets.dispose);
    await tester.pumpWidget(_picker(assets, MemoryFlowPreferences()));
    await tester.tap(find.text("Twitch"));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();
    final finalEmote = find.byTooltip("twitch-channel-29");
    expect(finalEmote, findsOneWidget);
    expect(
      tester.getBottomRight(finalEmote).dy,
      lessThanOrEqualTo(tester.getBottomRight(find.byType(TwitchEmotePicker)).dy - 24),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets("short viewports keep emotes and retry messages scrollable without overflowing", (
    tester,
  ) async {
    final assets = _Assets();
    final preferences = MemoryFlowPreferences();
    addTearDown(assets.dispose);
    await tester.pumpWidget(_picker(assets, preferences));
    await tester.tap(find.text("Twitch"));
    await tester.pumpAndSettle();
    for (final height in [140.0, 80.0, 40.0, 0.0]) {
      await tester.pumpWidget(_picker(assets, preferences, height: height));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: "loaded picker at height $height");
    }
    assets.failed = true;
    for (final height in [140.0, 80.0, 40.0, 0.0]) {
      await tester.pumpWidget(_picker(assets, preferences, height: height));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: "failed picker at height $height");
    }
    await tester.pumpWidget(_picker(assets, preferences, height: 140));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("Retry"));
    await tester.pumpAndSettle();
    expect(find.text("Retry").hitTestable(), findsOneWidget);
  });
  testWidgets("a selection before recents finish loading preserves stored history after closing", (
    tester,
  ) async {
    final assets = _Assets();
    final preferences = _SlowPreferences();
    addTearDown(assets.dispose);
    await tester.pumpWidget(_picker(assets, preferences));
    await tester.tap(find.text("Twitch"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("twitch-channel"));
    await tester.pumpWidget(const SizedBox());
    expect(preferences.saved, isEmpty);
    preferences.pending.complete([
      jsonEncode({
        "provider": "twitch",
        "id": "old",
        "name": "old",
        "url": "https://example.com/old.png",
      }),
    ]);
    await tester.pumpAndSettle();
    expect(preferences.saved.map((value) => (jsonDecode(value) as Map<String, Object?>)["name"]), [
      "twitch-channel",
      "old",
    ]);
    expect(tester.takeException(), isNull);
  });
  testWidgets("provider tabs keep channel, global, and lazy unlocked catalogues separate", (
    tester,
  ) async {
    final assets = _Assets();
    addTearDown(assets.dispose);
    await tester.pumpWidget(_picker(assets, MemoryFlowPreferences()));
    await tester.pumpAndSettle();
    expect(find.text("Emotes you use will appear here."), findsOneWidget);
    expect(assets.unlockedLoads, 0);
    await tester.tap(find.text("Twitch"));
    await tester.pumpAndSettle();
    expect(find.byTooltip("twitch-channel"), findsOneWidget);
    expect(find.byTooltip("twitch-global"), findsNothing);
    expect(find.text("Unlocked"), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, endsWith("/light/2.0"));
    await tester.tap(find.text("Global"));
    await tester.pumpAndSettle();
    expect(find.byTooltip("twitch-global"), findsOneWidget);
    expect(assets.unlockedLoads, 0);
    await tester.tap(find.text("Unlocked"));
    await tester.pumpAndSettle();
    expect(assets.unlockedLoads, 1);
    expect(find.byTooltip("twitch-unlocked"), findsOneWidget);
    for (final entry in {"7TV": "sevenTv", "BTTV": "bttv", "FFZ": "ffz"}.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text("Unlocked"), findsNothing);
      expect(find.text("${entry.value}-channel"), findsOneWidget);
      await tester.tap(find.text("Global"));
      await tester.pumpAndSettle();
      expect(find.text("${entry.value}-global"), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "selection persists deduplicated recent emotes and metadata across picker instances",
    (tester) async {
      final assets = _Assets();
      final preferences = MemoryFlowPreferences();
      final selected = <ChatAssetEmote>[];
      addTearDown(assets.dispose);
      await tester.pumpWidget(_picker(assets, preferences, onSelected: selected.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Twitch"));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("twitch-channel"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("7TV"));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("sevenTv-channel\nOriginal name: Original"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Recent"));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("twitch-channel"));
      await tester.pumpAndSettle();
      expect(selected.map((emote) => emote.name), [
        "twitch-channel",
        "sevenTv-channel",
        "twitch-channel",
      ]);
      final stored = (await preferences.readRecentChatEmotes())
          .map((value) => jsonDecode(value) as Map<String, Object?>)
          .toList();
      expect(stored.map((value) => value["name"]), ["twitch-channel", "sevenTv-channel"]);
      expect(stored.last["originalName"], "Original");
      expect(stored.last["author"], "Artist");
      expect(stored.last["zeroWidth"], isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_picker(assets, preferences));
      await tester.pumpAndSettle();
      expect(find.byTooltip("twitch-channel"), findsOneWidget);
      expect(find.byTooltip("sevenTv-channel\nOriginal name: Original"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("recents ignore malformed entries and retain only the latest forty selections", (
    tester,
  ) async {
    final assets = _Assets();
    final preferences = MemoryFlowPreferences();
    addTearDown(assets.dispose);
    await preferences.saveRecentChatEmotes([
      for (var index = 0; index < 40; index++)
        jsonEncode({
          "provider": "twitch",
          "id": "$index",
          "name": "old-$index",
          "url": "https://example.com/$index.png",
        }),
    ]);
    await tester.pumpWidget(_picker(assets, preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Twitch"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("twitch-channel"));
    await tester.pumpAndSettle();
    final stored = await preferences.readRecentChatEmotes();
    expect(stored, hasLength(40));
    expect(stored.first, contains("twitch-channel"));
    expect(stored.any((value) => value.contains("old-39")), isFalse);
    await tester.pumpWidget(const SizedBox());
    await preferences.saveRecentChatEmotes(["not json", "{}", stored.first]);
    await tester.pumpWidget(_picker(assets, preferences));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byTooltip("twitch-channel"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _picker(
  _Assets assets,
  FlowPreferences preferences, {
  ValueChanged<ChatAssetEmote>? onSelected,
  double height = 260,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 360,
        height: height,
        child: TwitchEmotePicker(
          assets: assets,
          preferences: preferences,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  ),
);

class _Assets extends TwitchChatAssets {
  _Assets()
    : super(
        clientLoader: () async => TwitchApiClient(clientId: "test", accessToken: ""),
        channelLogin: "creator",
        autoLoad: false,
      );

  int unlockedLoads = 0;
  int count = 1;
  bool failed = false;

  @override
  List<String> get errors => failed ? const ["Emotes could not be loaded. Try again."] : const [];

  @override
  Future<void> loadUnlockedEmotes() async {
    unlockedLoads++;
    notifyListeners();
  }

  @override
  List<ChatAssetEmote> emotesFor(ChatEmoteProvider provider, ChatEmoteScope scope) => failed
      ? []
      : [
          for (var index = 0; index < count; index++)
            ChatAssetEmote(
              name: "${provider.name}-${scope.name}${count == 1 ? "" : "-$index"}",
              id: "${provider.name}-${scope.name}",
              provider: provider,
              url: provider == ChatEmoteProvider.twitch
                  ? "https://static-cdn.jtvnw.net/emoticons/v2/${scope.name}/default/dark/2.0"
                  : "https://example.com/${provider.name}/${scope.name}.webp",
              originalName: provider == ChatEmoteProvider.sevenTv ? "Original" : null,
              author: provider == ChatEmoteProvider.sevenTv ? "Artist" : null,
              zeroWidth: provider == ChatEmoteProvider.sevenTv,
            ),
        ];
}

class _SlowPreferences extends MemoryFlowPreferences {
  final pending = Completer<List<String>>();
  List<String> saved = [];

  @override
  Future<List<String>> readRecentChatEmotes() => pending.future;

  @override
  Future<void> saveRecentChatEmotes(List<String> emotes) async => saved = List.of(emotes);
}
