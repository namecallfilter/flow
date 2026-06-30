import "dart:async";
import "dart:ui";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/following/twitch_login_screen.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_title.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flow/shared/widgets/section_header.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

typedef TwitchLoginOpener =
    Future<TwitchAuthConnection?> Function(
      BuildContext context,
      TwitchAuthController authController,
    );

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    super.key,
    this.authController,
    this.openTwitchLogin,
    this.bottomNavigationBar,
  });

  final TwitchAuthController? authController;
  final TwitchLoginOpener? openTwitchLogin;
  final Widget? bottomNavigationBar;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController?>("authController", authController));
    properties.add(ObjectFlagProperty<TwitchLoginOpener?>.has("openTwitchLogin", openTwitchLogin));
    properties.add(DiagnosticsProperty<Widget?>("bottomNavigationBar", bottomNavigationBar));
  }
}

class _FollowingScreenState extends State<FollowingScreen> {
  late final TwitchAuthController _authController;
  final ScrollController _scrollController = ScrollController();
  bool? _offlineExpandedOverride;
  bool _isLoadingFollowing = false;
  String? _followingError;
  TwitchAuthConnection? _connection;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? _buildDefaultAuthController();
    unawaited(_loadSavedConnection());
  }

  TwitchAuthController _buildDefaultAuthController() {
    const config = TwitchAuthConfig.fromEnvironment();
    return TwitchAuthController(
      config: config,
      secureStore: const SecureTwitchStore(),
      cookieExtractor: const MethodChannelTwitchCookieExtractor(),
      apiClientFactory: (accessToken) => TwitchApiClient(
        clientId: config.clientId,
        accessToken: accessToken,
      ),
    );
  }

  Future<void> _startTwitchAuth() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (!_authController.config.isConfigured) {
        throw TwitchAuthException(
          "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to start Twitch auth.",
        );
      }
      final opener = widget.openTwitchLogin ?? openTwitchLoginScreen;
      final connection = await opener(context, _authController);
      if (!mounted || connection == null) {
        return;
      }
      _applyConnection(connection);
      messenger.showSnackBar(
        SnackBar(content: Text("Connected as ${connection.user.displayName}")),
      );
    } on TwitchAuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadSavedConnection() async {
    if (!_authController.config.isConfigured) {
      return;
    }

    setState(() {
      _isLoadingFollowing = true;
      _followingError = null;
    });

    try {
      final connection = await _authController.loadSavedConnection();
      if (!mounted) {
        return;
      }
      setState(() {
        if (connection != null) {
          _connection = connection;
        }
        _isLoadingFollowing = false;
        _followingError = null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFollowing = false;
        _followingError = error.toString();
      });
    }
  }

  void _applyConnection(TwitchAuthConnection connection) {
    setState(() {
      _connection = connection;
      _followingError = null;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connection = _connection;
    final liveChannels = connection == null
        ? <StreamChannel>[]
        : _liveChannelsFromConnection(connection);
    final offlineChannels = connection == null
        ? <OfflineChannel>[]
        : _offlineChannelsFromConnection(connection);
    final profileUser = connection == null
        ? null
        : connection.usersById[connection.user.id] ?? connection.user;
    final offlineExpanded = _offlineExpandedOverride ?? liveChannels.isEmpty;
    final showLiveEmptyState = liveChannels.isEmpty && offlineChannels.isEmpty;
    const topScrollPadding = 80.0;
    const bottomScrollPadding = 114.0;

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar:
          widget.bottomNavigationBar ?? const AppBottomNav(currentRoute: FlowRoutes.following),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            FlowPullToRefresh(
              scrollController: _scrollController,
              onRefresh: _loadSavedConnection,
              indicatorStartTop: topScrollPadding - 28,
              indicatorMaxTravel: 52,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  topScrollPadding,
                  AppSpacing.lg,
                  0,
                ).copyWith(bottom: bottomScrollPadding),
                children: [
                  if (_isLoadingFollowing) ...[
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (_followingError != null) ...[
                    _StatusBanner(message: _followingError!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (showLiveEmptyState)
                    const _EmptyState(
                      message: "No followed channels are live now.",
                    )
                  else
                    for (final channel in liveChannels) StreamCard(channel: channel),
                  const SizedBox(height: AppSpacing.sm),
                  _OfflineCard(
                    channels: offlineChannels,
                    expanded: offlineExpanded,
                    onToggle: () {
                      setState(() {
                        _offlineExpandedOverride = !offlineExpanded;
                      });
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _FrostedTopBar(
                onProfilePressed: _startTwitchAuth,
                profileInitials: _initialsForName(
                  profileUser?.displayName ?? "Me",
                ),
                profileImageUrl: profileUser?.profileImageUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StreamChannel {
  const StreamChannel({
    required this.name,
    required this.initials,
    required this.title,
    required this.category,
    required this.viewers,
    required this.avatarColors,
    required this.thumbnailColors,
    this.avatarImageUrl,
    this.thumbnailUrl,
  });

  final String name;
  final String initials;
  final String title;
  final String category;
  final String viewers;
  final List<Color> avatarColors;
  final List<Color> thumbnailColors;
  final String? avatarImageUrl;
  final String? thumbnailUrl;
}

class OfflineChannel {
  const OfflineChannel({
    required this.name,
    required this.initials,
    required this.lastLive,
    required this.category,
    required this.avatarColors,
    this.avatarImageUrl,
  });

  final String name;
  final String initials;
  final String lastLive;
  final String category;
  final List<Color> avatarColors;
  final String? avatarImageUrl;
}

class _FrostedTopBar extends StatelessWidget {
  const _FrostedTopBar({
    required this.onProfilePressed,
    required this.profileInitials,
    required this.profileImageUrl,
  });

  final VoidCallback onProfilePressed;
  final String profileInitials;
  final String? profileImageUrl;

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
          key: const ValueKey("frosted_top_bar"),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _TopBarContent(
            onProfilePressed: onProfilePressed,
            profileInitials: profileInitials,
            profileImageUrl: profileImageUrl,
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<VoidCallback>.has("onProfilePressed", onProfilePressed));
    properties.add(StringProperty("profileInitials", profileInitials));
    properties.add(StringProperty("profileImageUrl", profileImageUrl));
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent({
    required this.onProfilePressed,
    required this.profileInitials,
    required this.profileImageUrl,
  });

  final VoidCallback onProfilePressed;
  final String profileInitials;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Expanded(
        child: PageHeaderTitle(
          key: ValueKey("following_title"),
          title: "Following",
        ),
      ),
      IconButton(
        key: const ValueKey("profile_auth_button"),
        tooltip: "Me",
        onPressed: onProfilePressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        alignment: Alignment.topRight,
        icon: AvatarRing(
          key: const ValueKey("profile_avatar"),
          initials: profileInitials,
          size: 36,
          avatarColors: const [Color(0xFF2C203F), Color(0xFFFFA3B1)],
          imageUrl: profileImageUrl,
        ),
      ),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<VoidCallback>.has("onProfilePressed", onProfilePressed));
    properties.add(StringProperty("profileInitials", profileInitials));
    properties.add(StringProperty("profileImageUrl", profileImageUrl));
  }
}

class StreamCard extends StatelessWidget {
  const StreamCard({required this.channel, super.key});

  final StreamChannel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final borderRadius = BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.14 : 0.34,
            ),
            width: 0.8,
          ),
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 86),
            child: Padding(
              key: ValueKey("stream_card_content_padding_${channel.name}"),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 350;
                  final thumbnailWidth = compact ? 116.0 : 124.0;

                  return Row(
                    key: ValueKey("stream_card_content_row_${channel.name}"),
                    children: [
                      _StreamThumbnail(
                        channelName: channel.name,
                        width: thumbnailWidth,
                        colors: channel.thumbnailColors,
                        imageUrl: channel.thumbnailUrl,
                        viewers: channel.viewers,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AvatarRing(
                                  initials: channel.initials,
                                  size: 28,
                                  avatarColors: channel.avatarColors,
                                  imageUrl: channel.avatarImageUrl,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    channel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: primaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.verified,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: isDark ? 0.72 : 0.66,
                                  ),
                                  size: 14,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              channel.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.18,
                                color: primaryColor.withValues(alpha: 0.86),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _metadataFor(channel),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                color: mutedColor,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StreamChannel>("channel", channel));
  }
}

String _metadataFor(StreamChannel channel) => channel.category;

class _StreamThumbnail extends StatelessWidget {
  const _StreamThumbnail({
    required this.channelName,
    required this.width,
    required this.colors,
    required this.imageUrl,
    required this.viewers,
  });

  final String channelName;
  final double width;
  final List<Color> colors;
  final String? imageUrl;
  final String viewers;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey("stream_thumbnail_$channelName"),
    width: width,
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: _ThumbnailBackground(colors: colors, imageUrl: imageUrl),
            ),
          ),
          Positioned(
            key: ValueKey("viewer_badge_position_$channelName"),
            left: 6,
            bottom: 3,
            child: _ViewerBadge(viewers: viewers),
          ),
        ],
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("channelName", channelName));
    properties.add(DoubleProperty("width", width));
    properties.add(IterableProperty<Color>("colors", colors));
    properties.add(StringProperty("imageUrl", imageUrl));
    properties.add(StringProperty("viewers", viewers));
  }
}

class _ViewerBadge extends StatelessWidget {
  const _ViewerBadge({required this.viewers});

  final String viewers;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LiveDot(),
          const SizedBox(width: 5),
          Text(
            viewers,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("viewers", viewers));
  }
}

class _ThumbnailBackground extends StatelessWidget {
  const _ThumbnailBackground({required this.colors, required this.imageUrl});

  final List<Color> colors;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ThumbnailPatternPainter(
              lineColor: Colors.white.withValues(alpha: 0.16),
            ),
          ),
        ),
      ],
    );
    final url = imageUrl;
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
    properties.add(IterableProperty<Color>("colors", colors));
    properties.add(StringProperty("imageUrl", imageUrl));
  }
}

class _ThumbnailPatternPainter extends CustomPainter {
  const _ThumbnailPatternPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var x = -size.width; x < size.width * 1.5; x += 18) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPatternPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: AppColors.liveRed,
      shape: BoxShape.circle,
    ),
  );
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({
    required this.channels,
    required this.expanded,
    required this.onToggle,
  });

  final List<OfflineChannel> channels;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.14 : 0.42,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          SectionHeader(
            title: "Offline",
            collapsible: true,
            expanded: expanded,
            onToggle: onToggle,
            toggleKey: const ValueKey("offline_toggle"),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: expanded
                ? channels.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: _EmptyState(
                            message: "No offline followed channels.",
                          ),
                        )
                      : Column(
                          children: [
                            const SizedBox(height: AppSpacing.sm),
                            for (var index = 0; index < channels.length; index++)
                              OfflineChannelRow(
                                channel: channels[index],
                                showDivider: index != channels.length - 1,
                              ),
                          ],
                        )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<OfflineChannel>("channels", channels));
    properties.add(DiagnosticsProperty<bool>("expanded", expanded));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onToggle", onToggle));
  }
}

class OfflineChannelRow extends StatelessWidget {
  const OfflineChannelRow({
    required this.channel,
    super.key,
    this.showDivider = true,
  });

  final OfflineChannel channel;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              AvatarRing(
                initials: channel.initials,
                size: 54,
                avatarColors: channel.avatarColors,
                statusColor: const Color(0xFF9EA0B4),
                imageUrl: channel.avatarImageUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      channel.lastLive,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OfflineChannel>("channel", channel));
    properties.add(DiagnosticsProperty<bool>("showDivider", showDivider));
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

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

List<StreamChannel> _liveChannelsFromConnection(
  TwitchAuthConnection connection,
) => [
  for (final stream in connection.followedStreams)
    StreamChannel(
      name: _displayName(stream.userName, stream.userLogin),
      initials: _initialsForName(
        _displayName(stream.userName, stream.userLogin),
      ),
      title: stream.title.isEmpty ? "Live now" : stream.title,
      category: stream.gameName.isEmpty ? "Live" : stream.gameName,
      viewers: _formatCompactCount(stream.viewerCount),
      avatarColors: _colorsForText(stream.userId),
      thumbnailColors: _colorsForText(stream.id, count: 3),
      avatarImageUrl: connection.usersById[stream.userId]?.profileImageUrl,
      thumbnailUrl: _twitchThumbnailUrl(stream.thumbnailUrl),
    ),
];

List<OfflineChannel> _offlineChannelsFromConnection(
  TwitchAuthConnection connection,
) {
  final liveUserIds = {
    for (final stream in connection.followedStreams) stream.userId,
  };

  return [
    for (final channel in connection.followedChannels)
      if (!liveUserIds.contains(channel.broadcasterId))
        OfflineChannel(
          name: _displayName(channel.broadcasterName, channel.broadcasterLogin),
          initials: _initialsForName(
            _displayName(channel.broadcasterName, channel.broadcasterLogin),
          ),
          lastLive: channel.followedAt == null
              ? "Offline"
              : "Followed ${_relativeTime(channel.followedAt!)}",
          category: _offlineCategory(connection, channel),
          avatarColors: _colorsForText(channel.broadcasterId),
          avatarImageUrl: connection.usersById[channel.broadcasterId]?.profileImageUrl,
        ),
  ];
}

String _offlineCategory(
  TwitchAuthConnection connection,
  TwitchFollowedChannel channel,
) {
  final info = connection.channelInfoByBroadcasterId[channel.broadcasterId];
  if (info != null && info.gameName.isNotEmpty) {
    return info.gameName;
  }
  if (info != null && info.title.isNotEmpty) {
    return info.title;
  }
  return channel.broadcasterLogin.isEmpty ? "Channel" : channel.broadcasterLogin;
}

String _displayName(String primary, String fallback) {
  if (primary.isNotEmpty) {
    return primary;
  }
  return fallback.isEmpty ? "Channel" : fallback;
}

String _initialsForName(String name) {
  final words = name.trim().split(RegExp(r"\s+"));
  final initials = [
    for (final word in words)
      if (word.isNotEmpty) word.substring(0, 1).toUpperCase(),
  ].take(2).join();
  return initials.isEmpty ? "CH" : initials;
}

List<Color> _colorsForText(String seed, {int count = 2}) {
  final hash = seed.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return [
    for (var index = 0; index < count; index++)
      HSLColor.fromAHSL(
        1,
        ((hash * 37) + (index * 52)) % 360,
        0.72,
        index.isEven ? 0.42 : 0.58,
      ).toColor(),
  ];
}

String _formatCompactCount(int value) {
  if (value >= 1000000) {
    return "${_compactDecimal(value / 1000000)}M";
  }
  if (value >= 1000) {
    return "${_compactDecimal(value / 1000)}K";
  }
  return value.toString();
}

String _compactDecimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith(".0") ? text.substring(0, text.length - 2) : text;
}

String _relativeTime(DateTime date) {
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inDays <= 0) {
    return "today";
  }
  if (elapsed.inDays == 1) {
    return "1 day ago";
  }
  if (elapsed.inDays < 7) {
    return "${elapsed.inDays} days ago";
  }
  if (elapsed.inDays < 30) {
    final weeks = (elapsed.inDays / 7).floor();
    return weeks == 1 ? "1 week ago" : "$weeks weeks ago";
  }
  final months = (elapsed.inDays / 30).floor();
  return months == 1 ? "1 month ago" : "$months months ago";
}

String? _twitchThumbnailUrl(String? template) {
  if (template == null || template.isEmpty) {
    return null;
  }
  return template.replaceAll("{width}", "320").replaceAll("{height}", "180");
}
