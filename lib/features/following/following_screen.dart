import "dart:async";
import "dart:math" as math;
import "dart:ui";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/app/theme.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flow/features/channel/channel_screen.dart";
import "package:flow/features/following/following_store.dart";
import "package:flow/features/following/twitch_login_offer_screen.dart";
import "package:flow/features/following/twitch_login_screen.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flow/shared/widgets/page_header_title.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flow/shared/widgets/section_header.dart";
import "package:flow/shared/widgets/skeleton.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_mobx/flutter_mobx.dart";
import "package:mobx/mobx.dart";

export "package:flow/features/following/twitch_login_screen.dart" show TwitchLoginOpener;

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    super.key,
    this.authController,
    this.apiCache,
    this.followingStore,
    this.browseStore,
    this.openTwitchLogin,
    this.onMeRequested,
    this.bottomNavigationBar,
  });

  final TwitchAuthController? authController;
  final TwitchApiCache? apiCache;
  final FollowingStore? followingStore;
  final BrowseStore? browseStore;
  final TwitchLoginOpener? openTwitchLogin;
  final AsyncCallback? onMeRequested;
  final Widget? bottomNavigationBar;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController?>("authController", authController));
    properties.add(DiagnosticsProperty<TwitchApiCache?>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<FollowingStore?>("followingStore", followingStore));
    properties.add(DiagnosticsProperty<BrowseStore?>("browseStore", browseStore));
    properties.add(ObjectFlagProperty<TwitchLoginOpener?>.has("openTwitchLogin", openTwitchLogin));
    properties.add(ObjectFlagProperty<AsyncCallback?>.has("onMeRequested", onMeRequested));
    properties.add(DiagnosticsProperty<Widget?>("bottomNavigationBar", bottomNavigationBar));
  }
}

class _FollowingScreenState extends State<FollowingScreen> {
  late final TwitchAuthController _authController;
  late final TwitchApiCache _apiCache;
  late final FollowingStore _store;
  late final BrowseStore? _browseStore;
  late final ReactionDisposer _sessionReaction;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _authController =
        widget.followingStore?.authController ??
        widget.authController ??
        _buildDefaultAuthController();
    _apiCache =
        widget.apiCache ??
        widget.followingStore?.apiCache ??
        TwitchApiCache(clientLoader: () => _loadFollowingApiClient(_authController));
    _store =
        widget.followingStore ??
        FollowingStore(
          authController: _authController,
          apiCache: _apiCache,
        );
    _browseStore = widget.browseStore;
    _scrollController.addListener(_loadMoreAnonymousChannels);
    _sessionReaction = reaction(
      (_) => _store.sessionStatus,
      (_) {
        if (_showsAnonymousChannels) {
          unawaited(_loadAnonymousChannels());
        }
      },
      fireImmediately: true,
    );
    unawaited(_store.loadSavedConnection());
  }

  bool get _showsAnonymousChannels =>
      _browseStore != null &&
      !_store.isLoggedIn &&
      (_store.sessionStatus == TwitchSessionStatus.loggedOut ||
          _store.sessionStatus == TwitchSessionStatus.restoreFailed);

  Future<void> _loadAnonymousChannels({bool refresh = false}) async {
    final browseStore = _browseStore;
    if (browseStore == null ||
        !_showsAnonymousChannels ||
        (!refresh && browseStore.liveChannelsLoaded)) {
      return;
    }
    await browseStore.loadLiveChannels(reset: true, refresh: refresh);
  }

  void _loadMoreAnonymousChannels() {
    final browseStore = _browseStore;
    if (!_showsAnonymousChannels ||
        browseStore == null ||
        !_scrollController.hasClients ||
        _scrollController.position.extentAfter > 420 ||
        !browseStore.liveChannelsLoaded ||
        browseStore.liveChannelsCursor == null) {
      return;
    }
    unawaited(browseStore.loadLiveChannels());
  }

  TwitchAuthController _buildDefaultAuthController() {
    const config = TwitchAuthConfig.fromEnvironment();
    return TwitchAuthController(
      config: config,
      secureStore: const SecureTwitchStore(),
      cookieExtractor: const MethodChannelTwitchCookieExtractor(),
      apiClientFactory: (accessToken, {gqlAccessToken}) => TwitchApiClient(
        clientId: config.clientId,
        graphQlClientId: config.graphQlClientId,
        accessToken: accessToken,
        gqlAccessToken: gqlAccessToken,
      ),
    );
  }

  Future<void> _offerTwitchAuth() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final connection = await openTwitchLoginOfferScreen(
        context,
        _authController,
        openTwitchLogin: widget.openTwitchLogin,
      );
      if (!mounted || connection == null) {
        return;
      }
      _store.applyConnection(connection);
      messenger.showSnackBar(
        SnackBar(content: Text("Connected as ${connection.user.displayName}")),
      );
    } on TwitchAuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openMe() async {
    final onMeRequested = widget.onMeRequested;
    if (onMeRequested != null) {
      await onMeRequested();
      return;
    }
    await _store.loadSavedConnection();
    if (!mounted) {
      return;
    }
    if (_store.isLoggedIn) {
      return;
    }
    unawaited(_offerTwitchAuth());
  }

  Future<void> _refreshFollowing() => _showsAnonymousChannels
      ? _loadAnonymousChannels(refresh: true)
      : _store.loadSavedConnection(refresh: true);

  void _openChannel(ChannelPreview channel) {
    if (channel.login.trim().isEmpty) {
      return;
    }

    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChannelScreen(
            apiCache: _apiCache,
            initialChannel: channel,
          ),
        ),
      ),
    );
  }

  void _openLiveChannel(StreamChannel channel) {
    _openChannel(
      ChannelPreview(
        login: channel.login.isEmpty ? channel.name : channel.login,
        displayName: channel.name,
        avatarImageUrl: channel.avatarImageUrl,
        isLive: true,
      ),
    );
  }

  void _openPlayer(StreamChannel channel) {
    if (channel.login.trim().isEmpty) {
      return;
    }
    unawaited(
      Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StreamPlayerScreen(apiCache: _apiCache, channel: channel),
        ),
      ),
    );
  }

  void _openOfflineChannel(OfflineChannel channel) {
    _openChannel(
      ChannelPreview(
        login: channel.login.isEmpty ? channel.name : channel.login,
        displayName: channel.name,
        avatarImageUrl: channel.avatarImageUrl,
      ),
    );
  }

  @override
  void dispose() {
    _sessionReaction();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      final browseStore = _browseStore;
      final showsAnonymousChannels = _showsAnonymousChannels;
      final liveChannels = showsAnonymousChannels ? browseStore!.liveChannels : _store.liveChannels;
      final offlineChannels = _store.offlineChannels;
      final profileUser = _store.profileUser;
      final offlineExpanded = _store.offlineExpanded;
      final showLiveEmptyState = showsAnonymousChannels
          ? browseStore!.liveChannelsLoaded && liveChannels.isEmpty
          : _store.showLiveEmptyState;
      final isLoadingInitialChannels = showsAnonymousChannels
          ? browseStore!.isLoadingLiveChannels && liveChannels.isEmpty
          : _store.isLoadingFollowing && _store.connection == null;
      final channelsError = showsAnonymousChannels
          ? browseStore!.liveChannelsError
          : _store.followingError;
      const bottomScrollPadding = PageHeaderLayout.bottomNavigationScrollPadding;

      return Scaffold(
        extendBody: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar:
            widget.bottomNavigationBar ??
            AppBottomNav(
              currentRoute: FlowRoutes.following,
              showLiveChannels: showsAnonymousChannels,
            ),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                FlowPullToRefresh(
                  scrollController: _scrollController,
                  onRefresh: _refreshFollowing,
                  indicatorStartTop: PageHeaderLayout.largeTitleRefreshIndicatorStartTop,
                  indicatorMaxTravel: 52,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: PageHeaderLayout.scrollPadding(
                      top: PageHeaderLayout.largeTitleContentTopPadding,
                      bottom: bottomScrollPadding,
                    ),
                    children: [
                      if (isLoadingInitialChannels)
                        _FollowingSkeleton(
                          viewportHeight: constraints.maxHeight,
                          showOfflineCard: !showsAnonymousChannels,
                          semanticLabel: showsAnonymousChannels
                              ? "Loading live channels"
                              : "Loading following channels",
                        )
                      else ...[
                        if (channelsError != null) ...[
                          _StatusBanner(message: channelsError),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (showLiveEmptyState)
                          _EmptyState(
                            message: showsAnonymousChannels
                                ? "No live channels are available right now."
                                : "No followed channels are live now.",
                          )
                        else
                          for (final channel in liveChannels)
                            StreamCard(
                              channel: channel,
                              onChannelSelected: _openLiveChannel,
                              onStreamSelected: _openPlayer,
                            ),
                        if (!showsAnonymousChannels) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _OfflineCard(
                            channels: offlineChannels,
                            expanded: offlineExpanded,
                            onToggle: _store.toggleOfflineExpanded,
                            onChannelSelected: _openOfflineChannel,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _FrostedTopBar(
                    title: showsAnonymousChannels ? "Live Channels" : "Following",
                    onProfilePressed: _openMe,
                    profileInitials: initialsForName(
                      profileUser?.displayName ?? "Me",
                    ),
                    profileImageUrl: profileUser?.profileImageUrl,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

const _streamCardExtent = 93.0;
const _offlineCardExtent = 72.0;
const _offlineCardPadding = EdgeInsets.fromLTRB(18, 11, 18, 11);

class _FollowingSkeleton extends StatelessWidget {
  const _FollowingSkeleton({
    required this.viewportHeight,
    required this.semanticLabel,
    required this.showOfflineCard,
  });

  final double viewportHeight;
  final String semanticLabel;
  final bool showOfflineCard;

  @override
  Widget build(BuildContext context) {
    final fixedExtent =
        PageHeaderLayout.largeTitleContentTopPadding +
        PageHeaderLayout.bottomNavigationScrollPadding +
        (showOfflineCard ? AppSpacing.sm + _offlineCardExtent : 0);
    final availableHeight = math.max(0.0, viewportHeight - fixedExtent);
    final streamCount = (availableHeight / _streamCardExtent).floor();

    return SkeletonShimmer(
      child: Semantics(
        key: const ValueKey("following_skeleton"),
        label: semanticLabel,
        child: Column(
          children: [
            for (var index = 0; index < streamCount; index++)
              StreamCardSkeleton(key: ValueKey("following_stream_skeleton_$index")),
            if (showOfflineCard) ...[
              const SizedBox(height: AppSpacing.sm),
              const _OfflineCardSkeleton(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty("viewportHeight", viewportHeight));
    properties.add(StringProperty("semanticLabel", semanticLabel));
    properties.add(DiagnosticsProperty<bool>("showOfflineCard", showOfflineCard));
  }
}

class _OfflineCardSkeleton extends StatelessWidget {
  const _OfflineCardSkeleton();

  @override
  Widget build(BuildContext context) => const _OfflineCardShell(
    key: ValueKey("following_offline_skeleton"),
    child: SizedBox(
      height: 48,
      child: Row(
        children: [
          SkeletonBox(
            key: ValueKey("following_offline_skeleton_title"),
            width: 82,
            height: 18,
          ),
          Spacer(),
          SizedBox.square(
            dimension: 48,
            child: Center(
              child: SkeletonBox(
                key: ValueKey("following_offline_skeleton_control"),
                width: 10,
                height: 18,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OfflineCardShell extends StatelessWidget {
  const _OfflineCardShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: _offlineCardPadding,
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
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Widget>("child", child));
  }
}

class _FrostedTopBar extends StatelessWidget {
  const _FrostedTopBar({
    required this.title,
    required this.onProfilePressed,
    required this.profileInitials,
    required this.profileImageUrl,
  });

  final String title;
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
          padding: PageHeaderLayout.largeTitleTopBarPadding,
          child: _TopBarContent(
            title: title,
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
    properties.add(StringProperty("title", title));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onProfilePressed", onProfilePressed));
    properties.add(StringProperty("profileInitials", profileInitials));
    properties.add(StringProperty("profileImageUrl", profileImageUrl));
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent({
    required this.title,
    required this.onProfilePressed,
    required this.profileInitials,
    required this.profileImageUrl,
  });

  final String title;
  final VoidCallback onProfilePressed;
  final String profileInitials;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: PageHeaderTitle(
          key: const ValueKey("following_title"),
          title: title,
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
    properties.add(StringProperty("title", title));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onProfilePressed", onProfilePressed));
    properties.add(StringProperty("profileInitials", profileInitials));
    properties.add(StringProperty("profileImageUrl", profileImageUrl));
  }
}

const double _streamTitleAreaHeight = 37;

double _streamThumbnailWidth(double availableWidth) => availableWidth < 350 ? 116 : 124;

class StreamCard extends StatelessWidget {
  const StreamCard({
    required this.channel,
    super.key,
    this.onChannelSelected,
    this.onStreamSelected,
    this.showCategory = true,
  });

  final StreamChannel channel;
  final ValueChanged<StreamChannel>? onChannelSelected;
  final ValueChanged<StreamChannel>? onStreamSelected;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final borderRadius = BorderRadius.circular(12);
    final VoidCallback? onChannelTap = onChannelSelected == null
        ? null
        : () => onChannelSelected!(channel);

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
          onTap: onStreamSelected == null ? null : () => onStreamSelected!(channel),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 86),
            child: Padding(
              key: ValueKey("stream_card_content_padding_${channel.name}"),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final thumbnailWidth = _streamThumbnailWidth(constraints.maxWidth);

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
                                GestureDetector(
                                  key: ValueKey("stream_channel_avatar_${channel.name}"),
                                  onTap: onChannelTap,
                                  child: AvatarRing(
                                    initials: channel.initials,
                                    size: 28,
                                    avatarColors: channel.avatarColors,
                                    imageUrl: channel.avatarImageUrl,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: GestureDetector(
                                    key: ValueKey("stream_channel_identity_${channel.name}"),
                                    onTap: onChannelTap,
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
                                ),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  key: ValueKey("stream_channel_badge_${channel.name}"),
                                  onTap: onChannelTap,
                                  child: Icon(
                                    Icons.verified,
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.72 : 0.66,
                                    ),
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: showCategory ? 0 : _streamTitleAreaHeight,
                              ),
                              child: Text(
                                channel.title,
                                key: ValueKey("stream_title_${channel.name}"),
                                maxLines: showCategory ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.18,
                                  color: primaryColor.withValues(alpha: 0.86),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (showCategory) ...[
                              const SizedBox(height: 5),
                              Text(
                                channel.category,
                                key: ValueKey("stream_category_${channel.name}"),
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
    properties.add(
      ObjectFlagProperty<ValueChanged<StreamChannel>?>.has(
        "onChannelSelected",
        onChannelSelected,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<StreamChannel>?>.has(
        "onStreamSelected",
        onStreamSelected,
      ),
    );
    properties.add(DiagnosticsProperty<bool>("showCategory", showCategory));
  }
}

class StreamCardSkeleton extends StatelessWidget {
  const StreamCardSkeleton({
    super.key,
    this.showCategory = true,
  });

  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.14 : 0.34,
            ),
            width: 0.8,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 86),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final thumbnailWidth = _streamThumbnailWidth(constraints.maxWidth);
                final detailsWidth = constraints.maxWidth - thumbnailWidth - 12;
                final nameWidth = math.min(116.0, math.max(0.0, detailsWidth - 55));

                return Row(
                  children: [
                    SizedBox(
                      key: const ValueKey("stream_skeleton_thumbnail"),
                      width: thumbnailWidth,
                      height: thumbnailWidth * 9 / 16,
                      child: const Stack(
                        children: [
                          Positioned.fill(child: SkeletonBox(height: 1)),
                          Positioned(
                            left: 6,
                            bottom: 3,
                            child: SkeletonBox(
                              key: ValueKey("stream_skeleton_viewers"),
                              width: 49,
                              height: 17,
                              borderRadius: BorderRadius.all(
                                Radius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SkeletonBox(
                                key: ValueKey("stream_skeleton_avatar"),
                                width: 28,
                                height: 28,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(AppRadius.pill),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SkeletonBox(
                                key: const ValueKey("stream_skeleton_name"),
                                width: nameWidth,
                                height: 18,
                              ),
                              const SizedBox(width: 5),
                              const SkeletonBox(
                                key: ValueKey("stream_skeleton_verified"),
                                width: 14,
                                height: 14,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SkeletonBox(
                            key: const ValueKey("stream_skeleton_title"),
                            width: detailsWidth * 0.92,
                            height: 17,
                          ),
                          const SizedBox(height: 5),
                          if (showCategory)
                            const SkeletonBox(
                              key: ValueKey("stream_skeleton_metadata"),
                              width: 104,
                              height: 15,
                            )
                          else
                            SkeletonBox(
                              key: const ValueKey("stream_skeleton_title_second_line"),
                              width: detailsWidth * 0.92,
                              height: 15,
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
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>("showCategory", showCategory));
  }
}

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
            child: _ViewerBadge(
              key: ValueKey("viewer_badge_$channelName"),
              viewers: viewers,
            ),
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
  const _ViewerBadge({
    required this.viewers,
    super.key,
  });

  final String viewers;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
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
    width: 7,
    height: 7,
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
    required this.onChannelSelected,
  });

  final List<OfflineChannel> channels;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<OfflineChannel> onChannelSelected;

  @override
  Widget build(BuildContext context) => _OfflineCardShell(
    key: const ValueKey("following_offline_card"),
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
                              onTap: () => onChannelSelected(channels[index]),
                            ),
                        ],
                      )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<OfflineChannel>("channels", channels));
    properties.add(DiagnosticsProperty<bool>("expanded", expanded));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onToggle", onToggle));
    properties.add(
      ObjectFlagProperty<ValueChanged<OfflineChannel>>.has(
        "onChannelSelected",
        onChannelSelected,
      ),
    );
  }
}

class OfflineChannelRow extends StatelessWidget {
  const OfflineChannelRow({
    required this.channel,
    super.key,
    this.showDivider = true,
    this.onTap,
  });

  final OfflineChannel channel;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);

    return GestureDetector(
      key: ValueKey("offline_channel_row_${channel.name}"),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                AvatarRing(
                  initials: channel.initials,
                  size: 54,
                  avatarColors: channel.avatarColors,
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
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OfflineChannel>("channel", channel));
    properties.add(DiagnosticsProperty<bool>("showDivider", showDivider));
    properties.add(ObjectFlagProperty<VoidCallback?>.has("onTap", onTap));
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

Future<TwitchApiClient> _loadFollowingApiClient(
  TwitchAuthController authController,
) async {
  final savedTokens = await authController.readSavedTokens();
  return authController.apiClientFactory(
    savedTokens.accessToken ?? "",
    gqlAccessToken: savedTokens.webSessionToken,
  );
}
