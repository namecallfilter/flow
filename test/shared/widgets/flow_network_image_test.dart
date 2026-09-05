import "package:flow/shared/widgets/flow_network_image.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("download speed selects image density with a quality floor and size cap", () {
    ({int width, int height}) thumbnail(double limit, {double width = 200}) => flowImageSize(
      kind: FlowImageKind.thumbnail,
      logicalWidth: width,
      devicePixelRatio: 3,
      pixelRatioLimit: limit,
    );
    final slow = FlowImagePolicy()
      ..recordDownload(bytes: 32 * 1024, elapsed: const Duration(seconds: 1));
    final medium = FlowImagePolicy()
      ..recordDownload(bytes: 200 * 1024, elapsed: const Duration(seconds: 1));
    final fast = FlowImagePolicy()
      ..recordDownload(bytes: 1024 * 1024, elapsed: const Duration(seconds: 1));

    expect(thumbnail(slow.pixelRatioLimit), (width: 320, height: 180));
    expect(thumbnail(medium.pixelRatioLimit), (width: 448, height: 252));
    expect(thumbnail(fast.pixelRatioLimit), (width: 640, height: 360));
    expect(thumbnail(slow.pixelRatioLimit, width: 20), (width: 256, height: 144));
    expect(thumbnail(fast.pixelRatioLimit, width: 2000), (width: 1280, height: 720));

    // Small icons and cache hits must not skew a useful network estimate.
    slow
      ..recordDownload(bytes: 1000, elapsed: const Duration(seconds: 3))
      ..recordDownload(bytes: 1024 * 1024, elapsed: Duration.zero);
    expect(slow.pixelRatioLimit, 1.5);
    // A single slow response doesn't immediately degrade a fast connection.
    fast.recordDownload(bytes: 32 * 1024, elapsed: const Duration(seconds: 1));
    expect(fast.pixelRatioLimit, double.infinity);
  });

  test("sizes Twitch CDN images without rewriting unrelated image URLs", () {
    expect(
      flowImageUrl(
        "https://static-cdn.jtvnw.net/creator-profile_image-300x300.png?version=1",
        width: 150,
        height: 150,
      ),
      "https://static-cdn.jtvnw.net/creator-profile_image-150x150.png?version=1",
    );
    expect(
      flowImageUrl("https://example.com/vod-%{width}x%{height}.jpg", width: 384, height: 216),
      "https://example.com/vod-384x216.jpg",
    );
    expect(
      flowImageUrl("https://example.com/photo-300x300.png", width: 150, height: 150),
      "https://example.com/photo-300x300.png",
    );
    expect(
      flowImageSize(kind: FlowImageKind.avatar, logicalWidth: 54, devicePixelRatio: 2.625),
      (width: 150, height: 150),
    );
    expect(
      flowImageSize(kind: FlowImageKind.boxArt, logicalWidth: 20, devicePixelRatio: 1),
      (width: 150, height: 200),
    );
  });
}
