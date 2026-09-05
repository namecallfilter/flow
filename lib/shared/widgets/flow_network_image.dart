import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

enum FlowImageKind { avatar, thumbnail, boxArt }

/// Estimate from real image transfers, including the initial response delay.
class FlowImagePolicy {
  static final FlowImagePolicy instance = FlowImagePolicy();
  double? _bytesPerSecond;
  final _sizes = <(String, FlowImageKind, double, double), ({int width, int height})>{};

  ({int width, int height}) _sizeFor(
    String url,
    FlowImageKind kind,
    double logicalWidth,
    double density,
  ) {
    final key = (url, kind, logicalWidth, density);
    // Reuse prefetched image dimensions even if speed changes before display.
    final size =
        _sizes.remove(key) ??
        flowImageSize(
          kind: kind,
          logicalWidth: logicalWidth,
          devicePixelRatio: density,
          pixelRatioLimit: pixelRatioLimit,
        );
    if (_sizes.length >= 128) {
      _sizes.remove(_sizes.keys.first);
    }
    return _sizes[key] = size;
  }

  double get pixelRatioLimit {
    final rate = _bytesPerSecond;
    if (rate == null || rate >= 500 * 1024) {
      return double.infinity;
    }
    return rate < 100 * 1024 ? 1.5 : 2;
  }

  void recordDownload({required int bytes, required Duration elapsed}) {
    // Small icons and synchronous cache hits aren't useful speed samples.
    if (bytes < 16 * 1024 || elapsed.inMilliseconds < 20) {
      return;
    }
    final rate = bytes * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
    final previous = _bytesPerSecond;
    _bytesPerSecond = previous == null ? rate : previous * 0.7 + rate * 0.3;
  }
}

/// Buckets reuse cache entries across similar layouts, with a readable floor.
({int width, int height}) flowImageSize({
  required FlowImageKind kind,
  required double logicalWidth,
  required double devicePixelRatio,
  double pixelRatioLimit = double.infinity,
}) {
  final density = devicePixelRatio.isFinite && devicePixelRatio > 0 ? devicePixelRatio : 1.0;
  final width = logicalWidth.isFinite && logicalWidth > 0 ? logicalWidth : 150.0;
  final requested = width * math.min(density, pixelRatioLimit);
  final pixels = switch (kind) {
    FlowImageKind.avatar =>
      requested <= 70
          ? 70
          : requested <= 150
          ? 150
          : 300,
    FlowImageKind.thumbnail => ((requested / 64).ceil() * 64).clamp(256, 1280),
    FlowImageKind.boxArt => ((requested / 50).ceil() * 50).clamp(150, 600),
  };
  return (
    width: pixels,
    height: switch (kind) {
      FlowImageKind.avatar => pixels,
      FlowImageKind.thumbnail => (pixels * 9 / 16).round(),
      FlowImageKind.boxArt => (pixels * 4 / 3).round(),
    },
  );
}

String flowImageUrl(String url, {required int width, required int height}) {
  final templated = url
      .replaceAll("%{width}", "$width")
      .replaceAll("%{height}", "$height")
      .replaceAll("{width}", "$width")
      .replaceAll("{height}", "$height");
  if (templated != url) {
    return templated;
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.host == "jtvnw.net" || uri.host.endsWith(".jtvnw.net"))) {
    return url;
  }
  return url.replaceFirstMapped(
    RegExp(r"-\d+x\d+(\.[^/?#]+)([?#].*)?$"),
    (match) => "-${width}x$height${match[1]}${match[2] ?? ""}",
  );
}

ImageProvider<Object> flowImageProvider(
  String url, {
  required FlowImageKind kind,
  required double logicalWidth,
  required double devicePixelRatio,
}) {
  final size = FlowImagePolicy.instance._sizeFor(
    url,
    kind,
    logicalWidth,
    devicePixelRatio,
  );
  return ResizeImage.resizeIfNeeded(
    size.width,
    size.height,
    NetworkImage(flowImageUrl(url, width: size.width, height: size.height)),
  );
}

class _ImageDownloadSample {
  _ImageDownloadSample(ImageProvider<Object> provider, BuildContext context) {
    final elapsed = Stopwatch()..start();
    var bytes = 0;
    _stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!synchronousCall) {
          FlowImagePolicy.instance.recordDownload(bytes: bytes, elapsed: elapsed.elapsed);
        }
        image.dispose();
        dispose();
      },
      onChunk: (event) => bytes = event.cumulativeBytesLoaded,
      onError: (_, _) => dispose(),
    );
    _stream.addListener(_listener);
  }

  late final ImageStream _stream;
  late final ImageStreamListener _listener;
  bool _disposed = false;

  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _stream.removeListener(_listener);
    }
  }
}

/// Warm a small batch in Flutter's bounded image cache, using the row's key.
Future<void> precacheFlowAvatars(BuildContext context, Iterable<String?> urls) async {
  final limit = FlowImagePolicy.instance.pixelRatioLimit <= 1.5 ? 8 : 24;
  final uniqueUrls = urls.whereType<String>().where((url) => url.isNotEmpty).toSet();
  for (final url in uniqueUrls.take(limit)) {
    if (!context.mounted) {
      return;
    }
    await precacheFlowImage(
      context,
      url,
      kind: FlowImageKind.avatar,
      logicalWidth: 54,
    );
  }
}

Future<void> precacheFlowImage(
  BuildContext context,
  String? url, {
  required FlowImageKind kind,
  required double logicalWidth,
}) async {
  if (!context.mounted || url == null || url.isEmpty) {
    return;
  }
  final provider = flowImageProvider(
    url,
    kind: kind,
    logicalWidth: logicalWidth,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
  );
  final sample = _ImageDownloadSample(provider, context);
  try {
    await precacheImage(provider, context, onError: (_, _) {});
  } finally {
    sample.dispose();
  }
}

class FlowNetworkImage extends StatefulWidget {
  const FlowNetworkImage({
    required this.imageUrl,
    required this.kind,
    required this.fallback,
    super.key,
  });

  final String? imageUrl;
  final FlowImageKind kind;
  final Widget fallback;

  @override
  State<FlowNetworkImage> createState() => _FlowNetworkImageState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("imageUrl", imageUrl));
    properties.add(EnumProperty<FlowImageKind>("kind", kind));
  }
}

class _FlowNetworkImageState extends State<FlowNetworkImage> {
  (String, FlowImageKind, double, double)? _request;
  ImageProvider<Object>? _provider;
  _ImageDownloadSample? _sample;

  @override
  void dispose() {
    _sample?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      _sample?.dispose();
      _request = null;
      return widget.fallback;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final density = MediaQuery.devicePixelRatioOf(context);
        final request = (url, widget.kind, constraints.maxWidth, density);
        // Apply speed changes to new requests without reloading visible images.
        if (_request != request) {
          _sample?.dispose();
          _request = request;
          final provider = flowImageProvider(
            url,
            kind: widget.kind,
            logicalWidth: constraints.maxWidth,
            devicePixelRatio: density,
          );
          _provider = provider;
          _sample = _ImageDownloadSample(provider, context);
        }
        return Image(
          image: _provider!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }
}
