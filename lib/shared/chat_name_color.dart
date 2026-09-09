import "dart:math" as math;

import "package:flutter/material.dart";

final _readableColors = <(Color, Brightness), Color>{};

Color readableChatNameColor(Color original, Brightness brightness) {
  if (_readableColors.length > 512) {
    _readableColors.remove(_readableColors.keys.first);
  }
  return _readableColors.putIfAbsent((original, brightness), () {
    var rgb = [original.r * 255, original.g * 255, original.b * 255];
    final light = brightness == Brightness.light;
    if (!light && rgb.every((channel) => channel < 36)) {
      return const Color(0xFF7A7A7A);
    }
    final background = _luminance(light ? [250, 249, 250] : [15, 14, 17]);
    for (var attempt = 0; attempt <= 50; attempt++) {
      final foreground = _luminance(rgb);
      final contrast =
          (math.max(foreground, background) + 0.05) / (math.min(foreground, background) + 0.05);
      if (contrast >= 4.5) {
        break;
      }
      rgb = _changeLabLightness(rgb, light ? 0.9 : 1.1);
    }
    return Color.fromARGB(255, rgb[0].round(), rgb[1].round(), rgb[2].round());
  });
}

double _luminance(List<num> rgb) {
  final linear = rgb.map((channel) {
    final value = channel / 255;
    return value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4);
  }).toList();
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

List<double> _changeLabLightness(List<double> rgb, double factor) {
  final linear = rgb.map((channel) {
    final value = channel / 255;
    return value > 0.04045 ? math.pow((value + 0.055) / 1.055, 2.4) : value / 12.92;
  }).toList();
  final [r, g, b] = linear;
  double labAxis(num value) =>
      value > 0.008856 ? math.pow(value, 1 / 3).toDouble() : 7.787 * value + 16 / 116;
  final x = labAxis((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
  final y = labAxis(0.2126 * r + 0.7152 * g + 0.0722 * b);
  final z = labAxis((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
  final lightness = (116 * y - 16) * factor;
  final labA = 500 * (x - y);
  final labB = 200 * (y - z);
  final luminance = lightness <= 8 ? lightness / 903.3 : math.pow((lightness + 16) / 116, 3);
  final axis = lightness <= 8 ? luminance * 7.787 + 16 / 116 : math.pow(luminance, 1 / 3);
  final nextX = 0.95047 * math.pow(labA / 500 + axis, 3);
  final nextZ = 1.08883 * math.pow(axis - labB / 200, 3);
  return [
    3.2406 * nextX - 1.5372 * luminance - 0.4986 * nextZ,
    -0.9689 * nextX + 1.8758 * luminance + 0.0415 * nextZ,
    0.0557 * nextX - 0.2040 * luminance + 1.0570 * nextZ,
  ].map((value) {
    final channel = value > 0.0031308 ? 1.055 * math.pow(value, 1 / 2.4) - 0.055 : value * 12.92;
    return channel.clamp(0.0, 1.0) * 255;
  }).toList();
}
