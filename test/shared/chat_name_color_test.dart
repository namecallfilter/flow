import "package:flow/shared/chat_name_color.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("matches Twitch's readable color examples", () {
    expect(readableChatNameColor(Colors.white, Brightness.light), const Color(0xFF717171));
    expect(readableChatNameColor(Colors.black, Brightness.dark), const Color(0xFF7A7A7A));
    expect(
      readableChatNameColor(const Color(0xFFFF0000), Brightness.light),
      const Color(0xFFDC0000),
    );
    expect(
      readableChatNameColor(const Color(0xFF0000FF), Brightness.dark),
      const Color(0xFF8B58FF),
    );
  });

  test("keeps colors that already meet the theme's contrast target", () {
    for (final color in [
      Colors.white,
      const Color(0xFFFF0000),
      const Color(0xFF00FF00),
      const Color(0xFF808080),
    ]) {
      expect(readableChatNameColor(color, Brightness.dark), color);
    }
    for (final color in [Colors.black, const Color(0xFF0000FF), const Color(0xFF123456)]) {
      expect(readableChatNameColor(color, Brightness.light), color);
    }
  });

  test("matches Twitch's LAB adjustments for other low-contrast colors", () {
    // Reference outputs from Twitch module 905961 and its color-convert dependencies.
    for (final entry in <int, (int, int)>{
      0xFFFFFEFE: (0xFF727171, 0xFFFFFEFE),
      0xFFFFFAFA: (0xFF736F6F, 0xFFFFFAFA),
      0xFF00FF00: (0xFF007B00, 0xFF00FF00),
      0xFFFFFFE0: (0xFF727258, 0xFFFFFFE0),
      0xFFFFFF00: (0xFF6A7500, 0xFFFFFF00),
      0xFFFF00FF: (0xFFCB00CE, 0xFFFF00FF),
      0xFF9146FF: (0xFF8238F1, 0xFFA053FF),
      0xFF123456: (0xFF123456, 0xFF6A84AC),
    }.entries) {
      expect(readableChatNameColor(Color(entry.key), Brightness.light), Color(entry.value.$1));
      expect(readableChatNameColor(Color(entry.key), Brightness.dark), Color(entry.value.$2));
    }
  });

  test("uses Twitch's near-black fallback only below the channel threshold", () {
    expect(
      readableChatNameColor(const Color(0xFF232323), Brightness.dark),
      const Color(0xFF7A7A7A),
    );
    expect(
      readableChatNameColor(const Color(0xFF242424), Brightness.dark),
      const Color(0xFF818181),
    );
  });
}
