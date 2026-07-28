import "dart:async";
import "dart:math" as math;
import "dart:ui";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/spacing.dart";
import "package:flow/features/channel/channel_store.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flow/shared/widgets/section_header.dart";
import "package:flow/shared/widgets/skeleton.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_mobx/flutter_mobx.dart";

class ChannelPreview {
  const ChannelPreview({
    required this.login,
    required this.displayName,
    this.avatarImageUrl,
    this.isLive = false,
  });

  final String login;
  final String displayName;
  final String? avatarImageUrl;
  final bool isLive;
}

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({
    required this.apiCache,
    required this.initialChannel,
    super.key,
    this.channelStore,
  });

  final TwitchApiCache apiCache;
  final ChannelPreview initialChannel;
  final ChannelStore? channelStore;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchApiCache>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<ChannelPreview>("initialChannel", initialChannel));
    properties.add(DiagnosticsProperty<ChannelStore?>("channelStore", channelStore));
  }
}

class _ChannelScreenState extends State<ChannelScreen> {
  late final ChannelStore _store;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _store =
        widget.channelStore ??
        ChannelStore(
          apiCache: widget.apiCache,
          login: widget.initialChannel.login,
        );
    _scrollController.addListener(_loadMoreWhenNearBottom);
    if (_store.channel == null) {
      unawaited(_store.load());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _store.load(refresh: true);

  void _openLiveStream(StreamChannel channel) {
    if (channel.login.trim().isEmpty) {
      return;
    }

    unawaited(
      Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StreamPlayerScreen(
            apiCache: widget.apiCache,
            channel: channel,
          ),
        ),
      ),
    );
  }

  void _loadMoreWhenNearBottom() {
    if (!_scrollController.hasClients || _scrollController.position.extentAfter > 420) {
      return;
    }
    unawaited(_store.loadMorePastBroadcasts());
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      final channel = _store.channel;
      final livePlayerChannel = _livePlayerChannel(channel, widget.initialChannel);
      final bottomScrollPadding = 24 + MediaQuery.of(context).padding.bottom;

      return Scaffold(
        key: ValueKey("channel_page_${widget.initialChannel.login}"),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                FlowPullToRefresh(
                  scrollController: _scrollController,
                  onRefresh: _refresh,
                  indicatorStartTop: PageHeaderLayout.backButtonRefreshIndicatorStartTop,
                  indicatorMaxTravel: 52,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: PageHeaderLayout.scrollPadding(
                      top: PageHeaderLayout.backButtonContentTopPadding,
                      bottom: bottomScrollPadding,
                    ),
                    children: [
                      if (_store.isInitialLoading)
                        _ChannelSkeleton(viewportHeight: constraints.maxHeight)
                      else if (_store.errorMessage != null && channel == null)
                        _StatusMessage(message: _store.errorMessage!)
                      else ...[
                        _ChannelHeader(
                          channel: channel,
                          initialChannel: widget.initialChannel,
                          onProfileTap: livePlayerChannel == null
                              ? null
                              : () => _openLiveStream(livePlayerChannel),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        const SectionHeader(title: "Past broadcasts"),
                        const SizedBox(height: AppSpacing.sm),
                        if (channel == null || channel.pastBroadcasts.isEmpty)
                          const _StatusMessage(message: "No past broadcasts.")
                        else ...[
                          for (final broadcast in channel.pastBroadcasts)
                            _PastBroadcastCard(broadcast: broadcast),
                          if (_store.pastBroadcastsError != null)
                            _StatusMessage(message: _store.pastBroadcastsError!)
                          else if (_store.isLoadingPastBroadcasts) ...[
                            const SizedBox(height: AppSpacing.sm),
                            const Center(
                              child: SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _ChannelTopBar(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

const _channelHeaderSkeletonExtent = 174.0;
const _pastBroadcastSkeletonExtent = 94.0;
const _channelSkeletonFixedContentExtent =
    _channelHeaderSkeletonExtent + AppSpacing.xxl + 32 + AppSpacing.sm;

class _ChannelSkeleton extends StatelessWidget {
  const _ChannelSkeleton({required this.viewportHeight});

  final double viewportHeight;

  @override
  Widget build(BuildContext context) {
    final availableHeight = math.max(
      0.0,
      viewportHeight -
          PageHeaderLayout.backButtonContentTopPadding -
          _channelSkeletonFixedContentExtent,
    );
    final broadcastCount = (availableHeight / _pastBroadcastSkeletonExtent).ceil();

    return SkeletonShimmer(
      child: Semantics(
        key: const ValueKey("channel_skeleton"),
        label: "Loading channel",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ChannelHeaderSkeleton(),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(title: "Past broadcasts"),
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < broadcastCount; index++)
              _PastBroadcastSkeleton(index: index),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty("viewportHeight", viewportHeight));
  }
}

class _ChannelHeaderSkeleton extends StatelessWidget {
  const _ChannelHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      key: const ValueKey("channel_header_skeleton"),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.14 : 0.42,
          ),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(
                  key: ValueKey("channel_header_skeleton_avatar"),
                  width: 70,
                  height: 70,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonBox(
                            key: ValueKey("channel_header_skeleton_name"),
                            width: 132,
                            height: 20,
                          ),
                          SizedBox(width: 6),
                          SkeletonBox(
                            key: ValueKey("channel_header_skeleton_verified"),
                            width: 18,
                            height: 18,
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(
                        key: ValueKey("channel_header_skeleton_status"),
                        width: 72,
                        height: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 22,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SkeletonBox(
                  key: ValueKey("channel_header_skeleton_description"),
                  width: 220,
                  height: 13,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 22,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SkeletonBox(
                  key: ValueKey("channel_header_skeleton_followers"),
                  width: 104,
                  height: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastBroadcastSkeleton extends StatelessWidget {
  const _PastBroadcastSkeleton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey("channel_broadcast_skeleton_$index"),
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          key: ValueKey("channel_broadcast_skeleton_thumbnail_$index"),
          width: 132,
          height: 74.25,
          child: Stack(
            children: [
              const Positioned.fill(child: SkeletonBox(height: 1)),
              Positioned(
                left: 6,
                bottom: 5,
                child: SkeletonBox(
                  key: ValueKey("channel_broadcast_skeleton_duration_$index"),
                  width: 49,
                  height: 17,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            key: ValueKey("channel_broadcast_skeleton_text_$index"),
            height: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PastBroadcastSkeletonLine(
                  key: ValueKey("channel_broadcast_skeleton_title_1_$index"),
                  slotHeight: 22,
                  widthFactor: 0.96,
                  barHeight: 14,
                ),
                _PastBroadcastSkeletonLine(
                  key: ValueKey("channel_broadcast_skeleton_title_2_$index"),
                  slotHeight: 22,
                  widthFactor: 0.82,
                  barHeight: 14,
                ),
                _PastBroadcastSkeletonLine(
                  key: ValueKey("channel_broadcast_skeleton_metadata_$index"),
                  slotHeight: 18,
                  widthFactor: 0.72,
                  barHeight: 13,
                ),
                const SizedBox(height: 2),
                _PastBroadcastSkeletonLine(
                  key: ValueKey("channel_broadcast_skeleton_views_$index"),
                  slotHeight: 18,
                  widthFactor: 0.42,
                  barHeight: 13,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty("index", index));
  }
}

class _PastBroadcastSkeletonLine extends StatelessWidget {
  const _PastBroadcastSkeletonLine({
    required this.slotHeight,
    required this.widthFactor,
    required this.barHeight,
    super.key,
  });

  final double slotHeight;
  final double widthFactor;
  final double barHeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: slotHeight,
    child: Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: SkeletonBox(height: barHeight),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty("slotHeight", slotHeight));
    properties.add(DoubleProperty("widthFactor", widthFactor));
    properties.add(DoubleProperty("barHeight", barHeight));
  }
}

class _ChannelTopBar extends StatelessWidget {
  const _ChannelTopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerSurface = theme.scaffoldBackgroundColor;
    final topAlpha = theme.brightness == Brightness.dark ? 0.92 : 0.94;
    final bottomAlpha = theme.brightness == Brightness.dark ? 0.30 : 0.42;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                headerSurface.withValues(alpha: topAlpha),
                headerSurface.withValues(alpha: bottomAlpha),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
                width: 0.5,
              ),
            ),
          ),
          padding: PageHeaderLayout.backButtonTopBarPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                height: 32,
                child: IconButton(
                  key: const ValueKey("channel_back_button"),
                  tooltip: "Back",
                  onPressed: Navigator.of(context).maybePop,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 40, height: 32),
                  alignment: Alignment.centerLeft,
                  icon: Icon(Icons.adaptive.arrow_back),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.channel,
    required this.initialChannel,
    required this.onProfileTap,
  });

  final TwitchChannelDetails? channel;
  final ChannelPreview initialChannel;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _displayName(channel, initialChannel);
    final avatarImageUrl = channel?.profileImageUrl ?? initialChannel.avatarImageUrl;
    final liveStream = channel?.liveStream;
    final isLive = channel == null ? initialChannel.isLive : liveStream != null;
    final description = channel?.description.trim() ?? "";
    final followers = channel == null
        ? null
        : "${formatCompactCount(channel!.followers)} followers";
    final liveSummary = liveStream == null
        ? "Live now"
        : "${liveStream.category} with ${formatCompactCount(liveStream.viewerCount)} viewers";

    return DecoratedBox(
      key: const ValueKey("channel_header_card"),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.14 : 0.42,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PlainChannelAvatar(
                  key: const ValueKey("channel_profile_avatar"),
                  initials: initialsForName(displayName),
                  size: 70,
                  imageUrl: avatarImageUrl,
                  isLive: isLive,
                  onTap: onProfileTap,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            size: 18,
                            color: theme.colorScheme.primary.withValues(alpha: 0.72),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (isLive)
                        Text(
                          key: const ValueKey("channel_live_metadata"),
                          liveSummary,
                          softWrap: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          "Offline",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w500,
                  height: 1.32,
                ),
              ),
            ],
            if (followers != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                followers,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchChannelDetails?>("channel", channel));
    properties.add(DiagnosticsProperty<ChannelPreview>("initialChannel", initialChannel));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onProfileTap", onProfileTap));
  }
}

class _PlainChannelAvatar extends StatelessWidget {
  const _PlainChannelAvatar({
    required this.initials,
    required this.size,
    required this.imageUrl,
    required this.isLive,
    required this.onTap,
    super.key,
  });

  final String initials;
  final double size;
  final String? imageUrl;
  final bool isLive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: size * 0.28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
    final url = imageUrl;

    final avatar = SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: url == null || url.isEmpty
                  ? fallback
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          if (isLive) const Positioned(bottom: -6, child: _LiveBadge()),
        ],
      ),
    );

    final handleTap = onTap;
    if (handleTap == null) {
      return avatar;
    }

    return Semantics(
      button: true,
      label: "Watch live stream",
      child: InkResponse(
        onTap: handleTap,
        customBorder: const CircleBorder(),
        child: avatar,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("initials", initials));
    properties.add(DoubleProperty("size", size));
    properties.add(StringProperty("imageUrl", imageUrl));
    properties.add(DiagnosticsProperty<bool>("isLive", isLive));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onTap", onTap));
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey("channel_live_badge"),
    decoration: BoxDecoration(
      color: const Color(0xFFE91916),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        "LIVE",
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    ),
  );
}

class _PastBroadcastCard extends StatelessWidget {
  const _PastBroadcastCard({required this.broadcast});

  final TwitchPastBroadcast broadcast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final metadata = _broadcastMetadata(broadcast);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        key: ValueKey("past_broadcast_${broadcast.id}"),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: ValueKey("past_broadcast_thumbnail_${broadcast.id}"),
            width: 132,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: _BroadcastThumbnail(broadcast: broadcast),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 5,
                    child: _DurationBadge(
                      key: ValueKey("past_broadcast_duration_${broadcast.id}"),
                      duration: broadcast.duration,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              key: ValueKey("past_broadcast_text_${broadcast.id}"),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  broadcast.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  metadata,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${formatCompactCount(broadcast.viewCount)} views",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchPastBroadcast>("broadcast", broadcast));
  }
}

class _BroadcastThumbnail extends StatelessWidget {
  const _BroadcastThumbnail({required this.broadcast});

  final TwitchPastBroadcast broadcast;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colorsForText(broadcast.id, count: 3),
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white.withValues(alpha: 0.86),
          size: 30,
        ),
      ),
    );
    final url = broadcast.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return fallback;
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchPastBroadcast>("broadcast", broadcast));
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({
    required this.duration,
    super.key,
  });

  final Duration duration;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Text(
        _durationText(duration),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
        ),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>("duration", duration));
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("message", message));
  }
}

String _displayName(
  TwitchChannelDetails? channel,
  ChannelPreview initialChannel,
) {
  final loadedName = channel?.displayName.trim() ?? "";
  if (loadedName.isNotEmpty) {
    return loadedName;
  }
  final initialName = initialChannel.displayName.trim();
  return initialName.isEmpty ? initialChannel.login : initialName;
}

StreamChannel? _livePlayerChannel(
  TwitchChannelDetails? channel,
  ChannelPreview initialChannel,
) {
  final liveStream = channel?.liveStream;
  if (channel == null || liveStream == null) {
    return null;
  }
  final login = channel.login.trim();
  if (login.isEmpty) {
    return null;
  }

  final id = channel.id.trim();
  final name = _displayName(channel, initialChannel);
  final streamId = liveStream.id.trim();
  final title = liveStream.title.trim();
  final category = liveStream.category.trim();
  final viewerCount = liveStream.viewerCount;

  return StreamChannel(
    id: id,
    login: login,
    name: name,
    initials: initialsForName(name),
    title: title.isEmpty ? "Live now" : title,
    category: category.isEmpty ? "Live" : category,
    viewers: formatCompactCount(viewerCount),
    avatarColors: colorsForText(id.isEmpty ? login : id),
    thumbnailColors: colorsForText(
      streamId.isEmpty ? (id.isEmpty ? login : id) : streamId,
      count: 3,
    ),
    avatarImageUrl: channel.profileImageUrl ?? initialChannel.avatarImageUrl,
    thumbnailUrl: twitchThumbnailUrl(liveStream.thumbnailUrl),
    startedAt: liveStream.startedAt,
  );
}

String _durationText(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
  if (hours > 0) {
    return "$hours:$minutes:$seconds";
  }
  return "${duration.inMinutes}:$seconds";
}

String? _broadcastAgeText(TwitchPastBroadcast broadcast) {
  final timestamp = broadcast.publishedAt ?? broadcast.createdAt;
  if (timestamp == null) {
    return null;
  }

  return _relativeTimeText(timestamp, DateTime.now());
}

String _broadcastMetadata(TwitchPastBroadcast broadcast) {
  final ageText = _broadcastAgeText(broadcast);
  final category = broadcast.category.trim();
  if (ageText == null) {
    return category;
  }
  if (category.isEmpty) {
    return ageText;
  }
  return "$ageText | $category";
}

String _relativeTimeText(DateTime timestamp, DateTime now) {
  final elapsed = now.difference(timestamp);
  if (elapsed.inDays >= 365) {
    final years = elapsed.inDays ~/ 365;
    return "$years ${years == 1 ? "year" : "years"} ago";
  }
  if (elapsed.inDays >= 30) {
    final months = elapsed.inDays ~/ 30;
    return "$months ${months == 1 ? "month" : "months"} ago";
  }
  if (elapsed.inDays >= 1) {
    return "${elapsed.inDays} ${elapsed.inDays == 1 ? "day" : "days"} ago";
  }
  if (elapsed.inHours >= 1) {
    return "${elapsed.inHours} ${elapsed.inHours == 1 ? "hour" : "hours"} ago";
  }
  if (elapsed.inMinutes >= 1) {
    return "${elapsed.inMinutes} ${elapsed.inMinutes == 1 ? "minute" : "minutes"} ago";
  }
  return "just now";
}
