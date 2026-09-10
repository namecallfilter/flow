import "dart:async";
import "dart:math" as math;

import "package:flow/api/twitch_api.dart";
import "package:flow/app/theme.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class VodPlayerFooter extends StatelessWidget {
  const VodPlayerFooter({
    required this.position,
    required this.duration,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onToggleFullscreen,
    this.onChangeStart,
    this.metadata,
    this.seeking = false,
    this.onToggleSideChat,
    this.sideChatVisible = false,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration> onChangeEnd;
  final ValueChanged<Duration>? onChangeStart;
  final VoidCallback onToggleFullscreen;
  final TwitchVodSeekMetadata? metadata;
  final bool seeking;
  final VoidCallback? onToggleSideChat;
  final bool sideChatVisible;

  @override
  Widget build(BuildContext context) {
    final max = math.max(1, duration.inMilliseconds).toDouble();
    final value = duration > Duration.zero ? position.inMilliseconds.clamp(0, max).toDouble() : 0.0;
    final storyboard = metadata?.storyboard;
    final frame = seeking ? storyboard?.frameAt(position) : null;
    return Row(
      children: [
        Text(_formatTime(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewWidth = math.min(160.0, constraints.maxWidth);
              final previewHeight = storyboard == null
                  ? 0.0
                  : previewWidth * storyboard.height / storyboard.width;
              final fraction = Directionality.of(context) == TextDirection.rtl
                  ? 1 - value / max
                  : value / max;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      trackShape: _MutedTrackShape(metadata?.mutedSegments ?? const [], duration),
                    ),
                    child: Slider(
                      key: const ValueKey("player_vod_seek"),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      value: value,
                      max: max,
                      semanticFormatterCallback: (value) =>
                          _formatTime(Duration(milliseconds: value.round())),
                      onChangeStart: onChangeStart == null
                          ? null
                          : (value) => onChangeStart!(Duration(milliseconds: value.round())),
                      onChanged: duration > Duration.zero
                          ? (value) => onChanged(Duration(milliseconds: value.round()))
                          : null,
                      onChangeEnd: (value) => onChangeEnd(Duration(milliseconds: value.round())),
                    ),
                  ),
                  if (frame != null && storyboard != null)
                    Positioned(
                      bottom: 42,
                      left: (12 + (constraints.maxWidth - 24) * fraction - previewWidth / 2).clamp(
                        0.0,
                        constraints.maxWidth - previewWidth,
                      ),
                      child: IgnorePointer(
                        child: Container(
                          key: const ValueKey("player_vod_seek_preview"),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SizedBox(
                            width: previewWidth,
                            height: previewHeight,
                            child: ClipRect(
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: -frame.column * previewWidth,
                                    top: -frame.row * previewHeight,
                                    width: storyboard.columns * previewWidth,
                                    height: storyboard.rows * previewHeight,
                                    child: Image.network(
                                      frame.imageUrl,
                                      fit: BoxFit.fill,
                                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Text(_formatTime(duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
        if (onToggleSideChat != null)
          IconButton(
            key: const ValueKey("player_side_chat_button"),
            tooltip: sideChatVisible ? "Hide chat" : "Show chat",
            onPressed: onToggleSideChat,
            color: Colors.white,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(40),
              maximumSize: const Size.square(40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(sideChatVisible ? Icons.chat_bubble : Icons.chat_bubble_outline),
          ),
        IconButton(
          key: const ValueKey("player_orientation_button"),
          tooltip: "Toggle full screen",
          onPressed: () {
            unawaited(HapticFeedback.selectionClick());
            onToggleFullscreen();
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(40),
            maximumSize: const Size.square(40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          color: Colors.white,
          iconSize: 27,
          icon: const Icon(Icons.fullscreen_rounded),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>("position", position));
    properties.add(DiagnosticsProperty<Duration>("duration", duration));
    properties.add(DiagnosticsProperty<TwitchVodSeekMetadata?>("metadata", metadata));
    properties.add(FlagProperty("seeking", value: seeking, ifTrue: "seeking"));
    properties.add(ObjectFlagProperty<ValueChanged<Duration>>.has("onChanged", onChanged));
    properties.add(ObjectFlagProperty<ValueChanged<Duration>>.has("onChangeEnd", onChangeEnd));
    properties.add(ObjectFlagProperty<ValueChanged<Duration>?>.has("onChangeStart", onChangeStart));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onToggleFullscreen", onToggleFullscreen));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onToggleSideChat", onToggleSideChat));
    properties.add(DiagnosticsProperty<bool>("sideChatVisible", sideChatVisible));
  }
}

class _MutedTrackShape extends RoundedRectSliderTrackShape {
  const _MutedTrackShape(this.segments, this.duration);

  final List<TwitchMutedSegment> segments;
  final Duration duration;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
    if (duration <= Duration.zero || segments.isEmpty) {
      return;
    }
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final paint = Paint()..color = AppColors.liveRed;
    for (final segment in segments) {
      final start = (segment.offset.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      final end = (segment.end.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      if (end <= start) {
        continue;
      }
      context.canvas.drawRect(
        Rect.fromLTRB(
          track.left + track.width * (textDirection == TextDirection.ltr ? start : 1 - end),
          track.top,
          track.left + track.width * (textDirection == TextDirection.ltr ? end : 1 - start),
          track.bottom,
        ),
        paint,
      );
    }
  }
}

String _formatTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
  return hours > 0 ? "$hours:$minutes:$seconds" : "${duration.inMinutes}:$seconds";
}
