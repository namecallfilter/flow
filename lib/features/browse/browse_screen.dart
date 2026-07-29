import "dart:async";
import "dart:math" as math;
import "dart:ui";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_api_cache.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/features/browse/browse_search_store.dart";
import "package:flow/features/browse/browse_store.dart";
import "package:flow/features/browse/category_streams_store.dart";
import "package:flow/features/channel/channel_screen.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/features/player/player_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_layout.dart";
import "package:flow/shared/widgets/page_header_title.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flow/shared/widgets/skeleton.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_mobx/flutter_mobx.dart";

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    this.authController,
    this.apiCache,
    this.bottomNavigationBar,
    this.browseStore,
    this.preferences,
    this.showLiveChannelsSection = true,
  });

  final TwitchAuthController? authController;
  final TwitchApiCache? apiCache;
  final Widget? bottomNavigationBar;
  final BrowseStore? browseStore;
  final FlowPreferences? preferences;
  final bool showLiveChannelsSection;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController?>("authController", authController));
    properties.add(DiagnosticsProperty<TwitchApiCache?>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<Widget?>("bottomNavigationBar", bottomNavigationBar));
    properties.add(DiagnosticsProperty<BrowseStore?>("browseStore", browseStore));
    properties.add(DiagnosticsProperty<FlowPreferences?>("preferences", preferences));
    properties.add(
      DiagnosticsProperty<bool>("showLiveChannelsSection", showLiveChannelsSection),
    );
  }
}

class _BrowseScreenState extends State<BrowseScreen> {
  late final ScrollController _scrollController;
  late final TwitchAuthController _authController;
  late final TwitchApiCache _apiCache;
  late final BrowseStore _store;
  late final BrowseSearchStore _searchStore;
  late final FlowPreferences _preferences;
  final _categoryStores = <String, CategoryStreamsStore>{};
  bool _isRestoringScrollOffset = false;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? _buildDefaultAuthController();
    _apiCache = widget.apiCache ?? TwitchApiCache(clientLoader: _loadApiClient);
    _store = widget.browseStore ?? BrowseStore(apiCache: _apiCache);
    if (!widget.showLiveChannelsSection) {
      _store.selectSection(BrowseSection.categories);
    }
    _preferences = widget.preferences ?? _MemoryFlowPreferences();
    _searchStore = BrowseSearchStore(
      apiCache: _apiCache,
      preferences: _preferences,
    );
    _scrollController = ScrollController(
      initialScrollOffset: _store.scrollOffsetFor(_visibleSection),
    );
    _scrollController.addListener(_loadMoreWhenNearBottom);
    if (!_store.categoriesLoaded) {
      unawaited(_store.loadCategories(reset: true));
    }
    if (widget.showLiveChannelsSection &&
        _store.selectedSection == BrowseSection.liveChannels &&
        !_store.liveChannelsLoaded) {
      unawaited(_store.loadLiveChannels(reset: true));
    }
  }

  @override
  void didUpdateWidget(BrowseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showLiveChannelsSection && !widget.showLiveChannelsSection) {
      if (_scrollController.hasClients) {
        _store.setScrollOffsetFor(_store.selectedSection, _scrollController.offset);
      }
      _store.selectSection(BrowseSection.categories);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollOffsetFor(BrowseSection.categories);
      });
    }
  }

  BrowseSection get _visibleSection =>
      widget.showLiveChannelsSection ? _store.selectedSection : BrowseSection.categories;

  @override
  void dispose() {
    _persistScrollOffset();
    _scrollController.dispose();
    super.dispose();
  }

  Future<TwitchApiClient> _loadApiClient() => _loadBrowseApiClient(_authController);

  void _selectSection(BrowseSection? section) {
    if (section == null || section == _store.selectedSection) {
      return;
    }

    _persistScrollOffset();
    _store.selectSection(section);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollOffsetFor(section);
    });
    if (section == BrowseSection.liveChannels && !_store.liveChannelsLoaded) {
      unawaited(_store.loadLiveChannels(reset: true));
    }
  }

  void _persistScrollOffset() {
    if (!_scrollController.hasClients) {
      return;
    }
    _store.setScrollOffsetFor(_visibleSection, _scrollController.offset);
  }

  void _restoreScrollOffsetFor(BrowseSection section) {
    if (!mounted || !_scrollController.hasClients || _store.selectedSection != section) {
      return;
    }

    final offset = _store.scrollOffsetFor(section);
    final clampedOffset = offset.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _isRestoringScrollOffset = true;
    try {
      _scrollController.jumpTo(clampedOffset);
    } finally {
      _isRestoringScrollOffset = false;
    }
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

  void _loadMoreWhenNearBottom() {
    if (_isRestoringScrollOffset) {
      return;
    }
    _persistScrollOffset();
    if (!_scrollController.hasClients || _scrollController.position.extentAfter > 420) {
      return;
    }

    if (_visibleSection == BrowseSection.categories) {
      if (!_store.categoriesLoaded || _store.categoriesCursor == null) {
        return;
      }
      unawaited(_store.loadCategories());
    } else {
      if (!_store.liveChannelsLoaded || _store.liveChannelsCursor == null) {
        return;
      }
      unawaited(_store.loadLiveChannels());
    }
  }

  Future<void> _refreshActiveSection() => widget.showLiveChannelsSection
      ? _store.refreshActiveSection()
      : _store.loadCategories(reset: true, refresh: true);

  void _openCategory(BrowseCategory category) {
    final store = _categoryStores.putIfAbsent(
      category.id,
      () => CategoryStreamsStore(
        apiCache: _apiCache,
        category: category,
      ),
    );
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CategoryStreamsScreen(
            authController: _authController,
            apiCache: _apiCache,
            category: category,
            categoryStreamsStore: store,
          ),
        ),
      ),
    );
  }

  void _openLiveChannel(StreamChannel channel) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChannelScreen(
            apiCache: _apiCache,
            initialChannel: _channelPreviewFromStreamChannel(channel),
          ),
        ),
      ),
    );
  }

  void _openPlayer(StreamChannel channel) {
    _openStreamPlayer(context, _apiCache, channel);
  }

  void _openSearch() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BrowseSearchScreen(
            authController: _authController,
            apiCache: _apiCache,
            preferences: _preferences,
            searchStore: _searchStore,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      final selectedSection = _visibleSection;
      final activeLoading = selectedSection == BrowseSection.categories
          ? _store.isLoadingCategories
          : _store.isLoadingLiveChannels;
      final activeItemsEmpty = selectedSection == BrowseSection.categories
          ? _store.categories.isEmpty
          : _store.liveChannels.isEmpty;
      final activeError = selectedSection == BrowseSection.categories
          ? _store.categoriesError
          : _store.liveChannelsError;
      const topScrollPadding = 140.0;
      const bottomScrollPadding = 114.0;

      return Scaffold(
        extendBody: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar:
            widget.bottomNavigationBar ??
            AppBottomNav(
              currentRoute: FlowRoutes.browse,
              showLiveChannels: !widget.showLiveChannelsSection,
            ),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              FlowPullToRefresh(
                scrollController: _scrollController,
                onRefresh: _refreshActiveSection,
                indicatorStartTop: topScrollPadding + 16,
                indicatorMaxTravel: 72,
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
                    if (widget.showLiveChannelsSection) ...[
                      _BrowseSectionSelector(
                        selectedSection: selectedSection,
                        onSectionSelected: _selectSection,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (activeLoading && activeItemsEmpty)
                      switch (selectedSection) {
                        BrowseSection.categories => const _CategoryGridSkeleton(),
                        BrowseSection.liveChannels => const _StreamListSkeleton(
                          key: ValueKey("browse_live_channels_skeleton"),
                          semanticLabel: "Loading live channels",
                        ),
                      }
                    else if (activeError != null)
                      _StatusMessage(message: activeError)
                    else if (selectedSection == BrowseSection.categories)
                      _CategoryGrid(
                        categories: _store.categories,
                        onCategorySelected: _openCategory,
                      )
                    else
                      _LiveChannelsList(
                        channels: _store.liveChannels,
                        onChannelSelected: _openLiveChannel,
                        onStreamSelected: _openPlayer,
                      ),
                    if (activeLoading && !activeItemsEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _BrowseTopBar(
                  onSearchPressed: _openSearch,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class BrowseSearchScreen extends StatefulWidget {
  const BrowseSearchScreen({
    required this.authController,
    required this.apiCache,
    required this.preferences,
    this.searchStore,
    super.key,
  });

  final TwitchAuthController authController;
  final TwitchApiCache apiCache;
  final FlowPreferences preferences;
  final BrowseSearchStore? searchStore;

  @override
  State<BrowseSearchScreen> createState() => _BrowseSearchScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController>("authController", authController));
    properties.add(DiagnosticsProperty<TwitchApiCache>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<FlowPreferences>("preferences", preferences));
    properties.add(DiagnosticsProperty<BrowseSearchStore?>("searchStore", searchStore));
  }
}

class _BrowseSearchScreenState extends State<BrowseSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  late final BrowseSearchStore _store;
  bool _isDebouncing = false;

  @override
  void initState() {
    super.initState();
    _store =
        widget.searchStore ??
        BrowseSearchStore(
          apiCache: widget.apiCache,
          preferences: widget.preferences,
        );
    if (_store.query.isNotEmpty) {
      _searchController
        ..text = _store.query
        ..selection = TextSelection.collapsed(offset: _store.query.length);
    }
    unawaited(_store.loadSearchHistory());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() => _isDebouncing = false);
      _store.clearSearch();
      return;
    }

    _store.invalidatePendingSearch();
    if (!_isDebouncing) {
      setState(() => _isDebouncing = true);
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final search = _store.search(trimmedQuery);
      if (mounted) {
        setState(() => _isDebouncing = false);
      }
      unawaited(search);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _handleQueryChanged("");
  }

  void _clearSearchHistory() {
    unawaited(_store.clearSearchHistory());
  }

  void _searchFromHistory(String query) {
    _searchController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _handleQueryChanged(query);
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      final query = _searchController.text.trim();
      const topScrollPadding = PageHeaderLayout.searchContentTopPadding;

      return Scaffold(
        key: const ValueKey("browse_search_page"),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: query.isEmpty
                    ? _SearchHistoryView(
                        history: _store.searchHistory,
                        topPadding: topScrollPadding,
                        onHistorySelected: _searchFromHistory,
                        onClearHistory: _clearSearchHistory,
                      )
                    : _SearchResults(
                        channels: _store.channels,
                        categories: _store.categories,
                        errorMessage: _store.errorMessage,
                        isSearching: _isDebouncing || _store.isSearching,
                        topPadding: topScrollPadding,
                        onChannelSelected: _openChannel,
                        onStreamSelected: _openPlayer,
                        onCategorySelected: _openCategory,
                      ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SearchPageTopBar(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: _handleQueryChanged,
                  onClear: _clearSearch,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _openCategory(BrowseCategory category) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CategoryStreamsScreen(
            authController: widget.authController,
            apiCache: widget.apiCache,
            category: category,
          ),
        ),
      ),
    );
  }

  void _openChannel(TwitchSearchChannel channel) {
    final channelName = displayName(channel.displayName, channel.broadcasterLogin);
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChannelScreen(
            apiCache: widget.apiCache,
            initialChannel: ChannelPreview(
              login: channel.broadcasterLogin,
              displayName: channelName,
              avatarImageUrl: channel.thumbnailUrl,
              isLive: channel.isLive,
            ),
          ),
        ),
      ),
    );
  }

  void _openPlayer(TwitchSearchChannel channel) {
    final login = channel.broadcasterLogin.trim();
    if (!channel.isLive || login.isEmpty) {
      return;
    }

    final channelName = displayName(channel.displayName, login);
    final streamChannel = StreamChannel(
      id: channel.id,
      login: login,
      name: channelName,
      initials: initialsForName(channelName),
      title: channel.title.isEmpty ? "Live now" : channel.title,
      category: channel.gameName.isEmpty ? "Live" : channel.gameName,
      viewers: "--",
      avatarColors: colorsForText(channel.id),
      thumbnailColors: colorsForText(channel.id, count: 3),
      avatarImageUrl: channel.thumbnailUrl,
      startedAt: channel.startedAt,
    );
    _openStreamPlayer(context, widget.apiCache, streamChannel);
  }
}

class _SearchPageTopBar extends StatelessWidget {
  const _SearchPageTopBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerSurface = theme.scaffoldBackgroundColor;
    final topAlpha = theme.brightness == Brightness.dark ? 0.92 : 0.94;
    final bottomAlpha = theme.brightness == Brightness.dark ? 0.30 : 0.42;

    return ClipRect(
      key: const ValueKey("browse_search_top_bar"),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: PageHeaderLayout.searchFieldHeight,
                  child: IconButton(
                    tooltip: "Back",
                    onPressed: Navigator.of(context).pop,
                    icon: Icon(Icons.adaptive.arrow_back),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: SizedBox(
                    height: PageHeaderLayout.searchFieldHeight,
                    child: TextField(
                      key: const ValueKey("browse_search_page_field"),
                      controller: controller,
                      focusNode: focusNode,
                      autocorrect: false,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        hintText: "Search channels or categories",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: controller.text.isEmpty
                            ? null
                            : IconButton(
                                key: const ValueKey("browse_search_clear_button"),
                                tooltip: "Clear search",
                                onPressed: onClear,
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextEditingController>("controller", controller));
    properties.add(DiagnosticsProperty<FocusNode>("focusNode", focusNode));
    properties.add(ObjectFlagProperty<ValueChanged<String>>.has("onChanged", onChanged));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onClear", onClear));
  }
}

class _SearchHistoryView extends StatelessWidget {
  const _SearchHistoryView({
    required this.history,
    required this.topPadding,
    required this.onHistorySelected,
    required this.onClearHistory,
  });

  final List<String> history;
  final double topPadding;
  final ValueChanged<String> onHistorySelected;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              key: const ValueKey("browse_search_empty_history_icon"),
              size: 42,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "No recent searches",
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        top: topPadding,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: 96 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Padding(
          key: const ValueKey("browse_search_history_header"),
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "History",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey("browse_search_clear_history_button"),
                onPressed: onClearHistory,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Clear"),
              ),
            ],
          ),
        ),
        for (final item in history)
          ListTile(
            key: ValueKey("browse_search_history_$item"),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            onTap: () => onHistorySelected(item),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<String>("history", history));
    properties.add(DoubleProperty("topPadding", topPadding));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>>.has(
        "onHistorySelected",
        onHistorySelected,
      ),
    );
    properties.add(ObjectFlagProperty<VoidCallback>.has("onClearHistory", onClearHistory));
  }
}

class _SearchResultsSkeleton extends StatelessWidget {
  const _SearchResultsSkeleton({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const channelCount = 7;
      const sectionHeaderExtent = 35.0;
      const channelRowExtent = 72.0;
      const categoryRowExtent = 144.0;
      const fixedResultsExtent =
          sectionHeaderExtent +
          (channelCount * channelRowExtent) +
          AppSpacing.md +
          sectionHeaderExtent;
      final availableCategoryHeight = math.max(
        0.0,
        constraints.maxHeight - topPadding - fixedResultsExtent,
      );
      final categoryCount = math.max(
        1,
        (availableCategoryHeight / categoryRowExtent).ceil(),
      );

      return SkeletonShimmer(
        child: Semantics(
          key: const ValueKey("browse_search_skeleton"),
          label: "Loading search results",
          child: ListView(
            padding: EdgeInsets.only(
              top: topPadding,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: 96 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              const _SearchSectionHeaderSkeleton(
                key: ValueKey("browse_search_channels_skeleton_header"),
                width: 68,
              ),
              for (var index = 0; index < channelCount; index++)
                _SearchChannelRowSkeleton(
                  key: ValueKey("browse_search_channel_skeleton_$index"),
                ),
              const SizedBox(height: AppSpacing.md),
              const _SearchSectionHeaderSkeleton(
                key: ValueKey("browse_search_categories_skeleton_header"),
                width: 82,
              ),
              for (var index = 0; index < categoryCount; index++)
                _SearchCategoryRowSkeleton(
                  key: ValueKey("browse_search_category_skeleton_$index"),
                ),
            ],
          ),
        ),
      );
    },
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty("topPadding", topPadding));
  }
}

class _SearchSectionHeaderSkeleton extends StatelessWidget {
  const _SearchSectionHeaderSkeleton({
    required this.width,
    super.key,
  });

  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
    child: SizedBox(
      height: 23,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SkeletonBox(width: width, height: 14),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty("width", width));
  }
}

class _SearchChannelRowSkeleton extends StatelessWidget {
  const _SearchChannelRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 72,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SkeletonBox(
        width: 42,
        height: 42,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      title: FractionallySizedBox(
        widthFactor: 0.62,
        alignment: Alignment.centerLeft,
        child: SkeletonBox(height: 16),
      ),
      subtitle: FractionallySizedBox(
        widthFactor: 0.34,
        alignment: Alignment.centerLeft,
        child: SkeletonBox(height: 13),
      ),
    ),
  );
}

class _SearchCategoryRowSkeleton extends StatelessWidget {
  const _SearchCategoryRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: SkeletonBox(height: 1),
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: 0.82,
                alignment: Alignment.centerLeft,
                child: SkeletonBox(height: 16),
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  SkeletonBox(
                    width: 7,
                    height: 7,
                    borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
                  ),
                  SizedBox(width: 5),
                  SkeletonBox(width: 52, height: 12),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.channels,
    required this.categories,
    required this.errorMessage,
    required this.isSearching,
    required this.topPadding,
    required this.onChannelSelected,
    required this.onStreamSelected,
    required this.onCategorySelected,
  });

  final List<TwitchSearchChannel> channels;
  final List<BrowseCategory> categories;
  final String? errorMessage;
  final bool isSearching;
  final double topPadding;
  final ValueChanged<TwitchSearchChannel> onChannelSelected;
  final ValueChanged<TwitchSearchChannel> onStreamSelected;
  final ValueChanged<BrowseCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return _SearchResultsSkeleton(topPadding: topPadding);
    }

    final error = errorMessage;
    if (error != null) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: _StatusMessage(message: error),
      );
    }
    if (channels.isEmpty && categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: const _StatusMessage(message: "No matching channels."),
      );
    }

    final children = <Widget>[
      if (channels.isNotEmpty) ...[
        const _SearchSectionHeader(
          key: ValueKey("browse_search_channels_header"),
          title: "Channels",
        ),
        for (final channel in channels)
          _SearchChannelRow(
            channel: channel,
            onChannelSelected: onChannelSelected,
            onStreamSelected: onStreamSelected,
          ),
      ],
      if (categories.isNotEmpty) ...[
        if (channels.isNotEmpty) const SizedBox(height: AppSpacing.md),
        const _SearchSectionHeader(
          key: ValueKey("browse_search_categories_header"),
          title: "Categories",
        ),
        for (final category in categories)
          _SearchCategoryRow(
            category: category,
            onTap: () => onCategorySelected(category),
          ),
      ],
    ];

    return ListView(
      padding: EdgeInsets.only(
        top: topPadding,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: 96 + MediaQuery.of(context).padding.bottom,
      ),
      children: children,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<TwitchSearchChannel>("channels", channels));
    properties.add(IterableProperty<BrowseCategory>("categories", categories));
    properties.add(StringProperty("errorMessage", errorMessage));
    properties.add(DiagnosticsProperty<bool>("isSearching", isSearching));
    properties.add(DoubleProperty("topPadding", topPadding));
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchSearchChannel>>.has(
        "onChannelSelected",
        onChannelSelected,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchSearchChannel>>.has(
        "onStreamSelected",
        onStreamSelected,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<BrowseCategory>>.has(
        "onCategorySelected",
        onCategorySelected,
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("title", title));
  }
}

class _SearchChannelRow extends StatelessWidget {
  const _SearchChannelRow({
    required this.channel,
    required this.onChannelSelected,
    required this.onStreamSelected,
  });

  final TwitchSearchChannel channel;
  final ValueChanged<TwitchSearchChannel> onChannelSelected;
  final ValueChanged<TwitchSearchChannel> onStreamSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final channelName = displayName(channel.displayName, channel.broadcasterLogin);
    final subtitle = channel.isLive
        ? (channel.gameName.isEmpty ? "Live now" : channel.gameName)
        : (channel.gameName.isEmpty ? "Offline" : channel.gameName);

    return ListTile(
      key: ValueKey("browse_search_channel_$channelName"),
      contentPadding: EdgeInsets.zero,
      onTap: () {
        if (channel.isLive) {
          onStreamSelected(channel);
        } else {
          onChannelSelected(channel);
        }
      },
      leading: GestureDetector(
        key: ValueKey("browse_search_channel_avatar_$channelName"),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChannelSelected(channel),
        child: AvatarRing(
          initials: initialsForName(channelName),
          size: 42,
          avatarColors: colorsForText(channel.id),
          imageUrl: channel.thumbnailUrl,
        ),
      ),
      title: Text(
        channelName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Row(
        children: [
          if (channel.isLive) ...[
            const _SmallLiveDot(),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchSearchChannel>("channel", channel));
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchSearchChannel>>.has(
        "onChannelSelected",
        onChannelSelected,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<TwitchSearchChannel>>.has(
        "onStreamSelected",
        onStreamSelected,
      ),
    );
  }
}

class _SearchCategoryRow extends StatelessWidget {
  const _SearchCategoryRow({
    required this.category,
    required this.onTap,
  });

  final BrowseCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final borderRadius = BorderRadius.circular(AppRadius.sm);

    return InkWell(
      key: ValueKey("browse_search_category_${category.name}"),
      borderRadius: borderRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              key: ValueKey("browse_search_category_thumbnail_${category.name}"),
              width: 96,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: _CategoryThumbnail(category: category),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const _SmallLiveDot(),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          category.viewers,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BrowseCategory>("category", category));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onTap", onTap));
  }
}

class CategoryStreamsScreen extends StatefulWidget {
  const CategoryStreamsScreen({
    required this.apiCache,
    required this.category,
    super.key,
    this.authController,
    this.categoryStreamsStore,
  });

  final TwitchAuthController? authController;
  final TwitchApiCache apiCache;
  final BrowseCategory category;
  final CategoryStreamsStore? categoryStreamsStore;

  @override
  State<CategoryStreamsScreen> createState() => _CategoryStreamsScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController?>("authController", authController));
    properties.add(DiagnosticsProperty<TwitchApiCache>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<BrowseCategory>("category", category));
    properties.add(
      DiagnosticsProperty<CategoryStreamsStore?>(
        "categoryStreamsStore",
        categoryStreamsStore,
      ),
    );
  }
}

class _CategoryStreamsScreenState extends State<CategoryStreamsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final CategoryStreamsStore _store;

  @override
  void initState() {
    super.initState();
    _store =
        widget.categoryStreamsStore ??
        CategoryStreamsStore(
          apiCache: widget.apiCache,
          category: widget.category,
        );
    _scrollController.addListener(_loadMoreWhenNearBottom);
    if (!_store.loaded) {
      unawaited(_store.loadStreams(reset: true));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreWhenNearBottom() {
    if (!_scrollController.hasClients || _scrollController.position.extentAfter > 420) {
      return;
    }
    if (!_store.loaded || _store.cursor == null) {
      return;
    }
    unawaited(_store.loadStreams());
  }

  void _openLiveChannel(StreamChannel channel) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChannelScreen(
            apiCache: widget.apiCache,
            initialChannel: _channelPreviewFromStreamChannel(channel),
          ),
        ),
      ),
    );
  }

  void _openPlayer(StreamChannel channel) {
    _openStreamPlayer(context, widget.apiCache, channel);
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      final bottomScrollPadding = 24 + MediaQuery.of(context).padding.bottom;

      return Scaffold(
        key: ValueKey("category_streams_page_${widget.category.name}"),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              FlowPullToRefresh(
                scrollController: _scrollController,
                onRefresh: () => _store.loadStreams(reset: true, refresh: true),
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
                    if (_store.isLoading && _store.channels.isEmpty)
                      const _StreamListSkeleton(
                        key: ValueKey("category_streams_skeleton"),
                        semanticLabel: "Loading category streams",
                        showCategories: false,
                      )
                    else if (_store.errorMessage != null)
                      _StatusMessage(message: _store.errorMessage!)
                    else if (_store.channels.isEmpty)
                      _StatusMessage(
                        message: "No live channels streaming ${widget.category.name}.",
                      )
                    else
                      _LiveChannelsList(
                        channels: _store.channels,
                        onChannelSelected: _openLiveChannel,
                        onStreamSelected: _openPlayer,
                        showCategories: false,
                      ),
                    if (_store.isLoading && _store.channels.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _CategoryStreamsTopBar(category: widget.category),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CategoryStreamsTopBar extends StatelessWidget {
  const _CategoryStreamsTopBar({required this.category});

  final BrowseCategory category;

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
                height: PageHeaderTitle.fontSize * PageHeaderTitle.lineHeight,
                child: IconButton(
                  tooltip: "Back",
                  onPressed: Navigator.of(context).pop,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: Icon(Icons.adaptive.arrow_back),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: PageHeaderTitle(
                    key: ValueKey("category_streams_title_${category.name}"),
                    title: category.name,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BrowseCategory>("category", category));
  }
}

class _SmallLiveDot extends StatelessWidget {
  const _SmallLiveDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: Color(0xFFF44336),
      shape: BoxShape.circle,
    ),
  );
}

Future<TwitchApiClient> _loadBrowseApiClient(
  TwitchAuthController authController,
) async {
  final savedTokens = await authController.readSavedTokens();
  return authController.apiClientFactory(
    savedTokens.accessToken ?? "",
    gqlAccessToken: savedTokens.webSessionToken,
  );
}

class _BrowseTopBar extends StatelessWidget {
  const _BrowseTopBar({required this.onSearchPressed});

  final VoidCallback onSearchPressed;

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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeaderTitle(
                key: ValueKey("browse_title"),
                title: "Browse",
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey("browse_search_field"),
                readOnly: true,
                onTap: onSearchPressed,
                decoration: const InputDecoration(
                  hintText: "Search Twitch",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<VoidCallback>.has("onSearchPressed", onSearchPressed));
  }
}

class _BrowseSectionSelector extends StatelessWidget {
  const _BrowseSectionSelector({
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final BrowseSection selectedSection;
  final ValueChanged<BrowseSection?> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );

    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<BrowseSection>(
        key: const ValueKey("browse_segmented_control"),
        groupValue: selectedSection,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        thumbColor: theme.colorScheme.primary.withValues(alpha: 0.34),
        onValueChanged: onSectionSelected,
        children: <BrowseSection, Widget>{
          BrowseSection.categories: Padding(
            key: const ValueKey("browse_segment_categories"),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Categories", style: labelStyle),
          ),
          BrowseSection.liveChannels: Padding(
            key: const ValueKey("browse_segment_live_channels"),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Live Channels", style: labelStyle),
          ),
        },
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<BrowseSection>("selectedSection", selectedSection));
    properties.add(
      ObjectFlagProperty<ValueChanged<BrowseSection?>>.has(
        "onSectionSelected",
        onSectionSelected,
      ),
    );
  }
}

class _LiveChannelsList extends StatelessWidget {
  const _LiveChannelsList({
    required this.channels,
    required this.onChannelSelected,
    required this.onStreamSelected,
    this.showCategories = true,
  });

  final List<StreamChannel> channels;
  final ValueChanged<StreamChannel> onChannelSelected;
  final ValueChanged<StreamChannel> onStreamSelected;
  final bool showCategories;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const _StatusMessage(message: "No live channels found.");
    }

    return Column(
      key: const ValueKey("browse_live_channels"),
      children: [
        for (final channel in channels)
          StreamCard(
            channel: channel,
            onChannelSelected: onChannelSelected,
            onStreamSelected: onStreamSelected,
            showCategory: showCategories,
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<StreamChannel>("channels", channels));
    properties.add(
      ObjectFlagProperty<ValueChanged<StreamChannel>>.has(
        "onChannelSelected",
        onChannelSelected,
      ),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<StreamChannel>>.has(
        "onStreamSelected",
        onStreamSelected,
      ),
    );
    properties.add(DiagnosticsProperty<bool>("showCategories", showCategories));
  }
}

ChannelPreview _channelPreviewFromStreamChannel(StreamChannel channel) => ChannelPreview(
  login: channel.login.isEmpty ? channel.name : channel.login,
  displayName: channel.name,
  avatarImageUrl: channel.avatarImageUrl,
  isLive: true,
);

void _openStreamPlayer(
  BuildContext context,
  TwitchApiCache apiCache,
  StreamChannel channel,
) {
  if (channel.login.trim().isEmpty) {
    return;
  }
  unawaited(
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StreamPlayerScreen(apiCache: apiCache, channel: channel),
      ),
    ),
  );
}

class _StreamListSkeleton extends StatelessWidget {
  const _StreamListSkeleton({
    required this.semanticLabel,
    super.key,
    this.showCategories = true,
  });

  final String semanticLabel;
  final bool showCategories;

  @override
  Widget build(BuildContext context) {
    const streamCardExtent = 93.0;
    final itemCount = math.max(
      3,
      (MediaQuery.sizeOf(context).height / streamCardExtent).ceil(),
    );

    return SkeletonShimmer(
      child: Semantics(
        label: semanticLabel,
        child: Column(
          children: [
            for (var index = 0; index < itemCount; index++)
              StreamCardSkeleton(showCategory: showCategories),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty("semanticLabel", semanticLabel));
    properties.add(DiagnosticsProperty<bool>("showCategories", showCategories));
  }
}

class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final rowExtent = _categoryTileExtent(context) + 16;
    final rowCount = math.max(
      2,
      (MediaQuery.sizeOf(context).height / rowExtent).ceil(),
    );

    return SkeletonShimmer(
      child: Semantics(
        key: const ValueKey("browse_categories_skeleton"),
        label: "Loading categories",
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rowCount * 3,
          gridDelegate: _categoryGridDelegate(context),
          itemBuilder: (context, index) => const _CategoryCardSkeleton(),
        ),
      ),
    );
  }
}

class _CategoryCardSkeleton extends StatelessWidget {
  const _CategoryCardSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: SkeletonBox(height: 1),
      ),
      SizedBox(height: 7),
      Align(
        child: FractionallySizedBox(
          widthFactor: 0.82,
          child: SkeletonBox(height: 12),
        ),
      ),
      SizedBox(height: 7),
      Align(
        child: FractionallySizedBox(
          widthFactor: 0.58,
          child: SkeletonBox(height: 10),
        ),
      ),
    ],
  );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.onCategorySelected,
  });

  final List<BrowseCategory> categories;
  final ValueChanged<BrowseCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _StatusMessage(message: "No categories found.");
    }

    return GridView.builder(
      key: const ValueKey("browse_categories_grid"),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: _categoryGridDelegate(context),
      itemBuilder: (context, index) => _CategoryCard(
        category: categories[index],
        onTap: () => onCategorySelected(categories[index]),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<BrowseCategory>("categories", categories));
    properties.add(
      ObjectFlagProperty<ValueChanged<BrowseCategory>>.has(
        "onCategorySelected",
        onCategorySelected,
      ),
    );
  }
}

SliverGridDelegateWithFixedCrossAxisCount _categoryGridDelegate(BuildContext context) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 16,
      mainAxisExtent: _categoryTileExtent(context),
    );

double _categoryTileExtent(BuildContext context) {
  final horizontalPadding = MediaQuery.of(context).padding.horizontal + (AppSpacing.lg * 2);
  final availableWidth = MediaQuery.sizeOf(context).width - horizontalPadding - 20;
  final tileWidth = availableWidth / 3;
  return (tileWidth * 4 / 3) + 68;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final BrowseCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      key: ValueKey("browse_category_card_${category.name}"),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: _CategoryThumbnail(category: category),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.name,
            key: ValueKey("browse_category_name_${category.name}"),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.86),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            key: ValueKey("browse_category_viewers_${category.name}"),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _SmallLiveDot(),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  category.viewers,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BrowseCategory>("category", category));
    properties.add(ObjectFlagProperty<VoidCallback>.has("onTap", onTap));
  }
}

class _CategoryThumbnail extends StatelessWidget {
  const _CategoryThumbnail({required this.category});

  final BrowseCategory category;

  @override
  Widget build(BuildContext context) {
    final fallback = _CategoryThumbnailFallback(category: category);
    final imageUrl = category.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return fallback;
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BrowseCategory>("category", category));
  }
}

class _CategoryThumbnailFallback extends StatelessWidget {
  const _CategoryThumbnailFallback({required this.category});

  final BrowseCategory category;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: category.colors,
          ),
        ),
      ),
      Positioned.fill(
        child: CustomPaint(
          painter: _CategoryPatternPainter(
            lineColor: Colors.white.withValues(alpha: 0.16),
          ),
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BrowseCategory>("category", category));
  }
}

class _CategoryPatternPainter extends CustomPainter {
  const _CategoryPatternPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (var x = -size.height; x < size.width * 1.7; x += 16) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryPatternPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
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
        key: ValueKey("browse_status_$message"),
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

class _MemoryFlowPreferences implements FlowPreferences {
  List<String> searchHistory = const <String>[];

  @override
  Future<bool> readAdProxyEnabled() async => false;

  @override
  Future<List<String>> readAdProxyUrls() async => const [];

  @override
  Future<List<String>> readAdProxyWhitelistedChannels() async => const [];

  @override
  Future<List<String>> readAdProxySubscriptionChannels() async => const [];

  @override
  Future<void> saveAdProxyEnabled({required bool enabled}) async {}

  @override
  Future<void> saveAdProxyUrls(List<String> urls) async {}

  @override
  Future<void> saveAdProxyWhitelistedChannels(List<String> channels) async {}

  @override
  Future<void> saveAdProxySubscriptionChannels(List<String> channels) async {}

  @override
  Future<void> clearBrowseSearchHistory() async {
    searchHistory = const <String>[];
  }

  @override
  Future<List<String>> readBrowseSearchHistory() async => searchHistory;

  @override
  Future<bool> readLoginOfferDismissed() async => false;

  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.system;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    searchHistory = List<String>.of(history);
  }

  @override
  Future<void> saveLoginOfferDismissed({required bool dismissed}) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
