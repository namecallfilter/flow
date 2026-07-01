import "dart:async";
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
import "package:flow/features/following/following_screen.dart";
import "package:flow/shared/preferences/preferences.dart";
import "package:flow/shared/twitch/twitch_display_mappers.dart";
import "package:flow/shared/twitch/twitch_display_models.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_title.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
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
  });

  final TwitchAuthController? authController;
  final TwitchApiCache? apiCache;
  final Widget? bottomNavigationBar;
  final BrowseStore? browseStore;
  final FlowPreferences? preferences;

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
  }
}

class _BrowseScreenState extends State<BrowseScreen> {
  late final ScrollController _scrollController;
  late final TwitchAuthController _authController;
  late final TwitchApiCache _apiCache;
  late final BrowseStore _store;
  late final FlowPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? _buildDefaultAuthController();
    _apiCache = widget.apiCache ?? TwitchApiCache(clientLoader: _loadApiClient);
    _store = widget.browseStore ?? BrowseStore(apiCache: _apiCache);
    _preferences = widget.preferences ?? _MemoryFlowPreferences();
    _scrollController = ScrollController(
      initialScrollOffset: _store.scrollOffsetFor(_store.selectedSection),
    );
    _scrollController.addListener(_loadMoreWhenNearBottom);
    if (!_store.categoriesLoaded) {
      unawaited(_store.loadCategories(reset: true));
    }
    if (_store.selectedSection == BrowseSection.liveChannels && !_store.liveChannelsLoaded) {
      unawaited(_store.loadLiveChannels(reset: true));
    }
  }

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
    _store.setScrollOffsetFor(_store.selectedSection, _scrollController.offset);
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
    _scrollController.jumpTo(clampedOffset);
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

  void _loadMoreWhenNearBottom() {
    _persistScrollOffset();
    if (!_scrollController.hasClients || _scrollController.position.extentAfter > 420) {
      return;
    }

    if (_store.selectedSection == BrowseSection.categories) {
      unawaited(_store.loadCategories());
    } else {
      unawaited(_store.loadLiveChannels());
    }
  }

  Future<void> _refreshActiveSection() => _store.refreshActiveSection();

  void _openCategory(BrowseCategory category) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _CategoryStreamsScreen(
            authController: _authController,
            apiCache: _apiCache,
            category: category,
          ),
        ),
      ),
    );
  }

  void _openSearch() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BrowseSearchScreen(
            authController: _authController,
            apiCache: _apiCache,
            preferences: _preferences,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      const topScrollPadding = 140.0;
      const bottomScrollPadding = 114.0;

      return Scaffold(
        extendBody: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar:
            widget.bottomNavigationBar ?? const AppBottomNav(currentRoute: FlowRoutes.browse),
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
                    _BrowseSectionSelector(
                      selectedSection: _store.selectedSection,
                      onSectionSelected: _selectSection,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_store.activeLoading && _store.activeItemsEmpty) ...[
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_store.activeError != null)
                      _StatusMessage(message: _store.activeError!)
                    else if (_store.selectedSection == BrowseSection.categories)
                      _CategoryGrid(
                        categories: _store.categories,
                        onCategorySelected: _openCategory,
                      )
                    else
                      _LiveChannelsList(channels: _store.liveChannels),
                    if (_store.activeLoading && !_store.activeItemsEmpty) ...[
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

  @override
  void initState() {
    super.initState();
    _store =
        widget.searchStore ??
        BrowseSearchStore(
          apiCache: widget.apiCache,
          preferences: widget.preferences,
        );
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
      _store.clearSearch();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_store.search(trimmedQuery));
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
      const topScrollPadding = 64.0;

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
                        isSearching: _store.isSearching,
                        topPadding: topScrollPadding,
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
                  isSearching: _store.isSearching,
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
          builder: (_) => _CategoryStreamsScreen(
            authController: widget.authController,
            apiCache: widget.apiCache,
            category: category,
          ),
        ),
      ),
    );
  }
}

class _SearchPageTopBar extends StatelessWidget {
  const _SearchPageTopBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: "Back",
                      onPressed: Navigator.of(context).pop,
                      icon: Icon(Icons.adaptive.arrow_back),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TextField(
                        key: const ValueKey("browse_search_page_field"),
                        controller: controller,
                        focusNode: focusNode,
                        autocorrect: false,
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
                  ],
                ),
              ),
              if (isSearching) const LinearProgressIndicator(minHeight: 3),
            ],
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
    properties.add(DiagnosticsProperty<bool>("isSearching", isSearching));
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

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.channels,
    required this.categories,
    required this.errorMessage,
    required this.isSearching,
    required this.topPadding,
    required this.onCategorySelected,
  });

  final List<TwitchSearchChannel> channels;
  final List<BrowseCategory> categories;
  final String? errorMessage;
  final bool isSearching;
  final double topPadding;
  final ValueChanged<BrowseCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final error = errorMessage;
    if (error != null) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: _StatusMessage(message: error),
      );
    }
    if (channels.isEmpty && categories.isEmpty && !isSearching) {
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
        for (final channel in channels) _SearchChannelRow(channel: channel),
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
  const _SearchChannelRow({required this.channel});

  final TwitchSearchChannel channel;

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
      leading: AvatarRing(
        initials: initialsForName(channelName),
        size: 42,
        avatarColors: colorsForText(channel.id),
        imageUrl: channel.thumbnailUrl,
        statusColor: channel.isLive ? null : mutedColor,
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

class _CategoryStreamsScreen extends StatefulWidget {
  const _CategoryStreamsScreen({
    required this.authController,
    required this.apiCache,
    required this.category,
  });

  final TwitchAuthController authController;
  final TwitchApiCache apiCache;
  final BrowseCategory category;

  @override
  State<_CategoryStreamsScreen> createState() => _CategoryStreamsScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController>("authController", authController));
    properties.add(DiagnosticsProperty<TwitchApiCache>("apiCache", apiCache));
    properties.add(DiagnosticsProperty<BrowseCategory>("category", category));
  }
}

class _CategoryStreamsScreenState extends State<_CategoryStreamsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final CategoryStreamsStore _store;

  @override
  void initState() {
    super.initState();
    _store = CategoryStreamsStore(
      apiCache: widget.apiCache,
      category: widget.category,
    );
    _scrollController.addListener(_loadMoreWhenNearBottom);
    unawaited(_store.loadStreams(reset: true));
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
    unawaited(_store.loadStreams());
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (_) {
      final theme = Theme.of(context);
      const topScrollPadding = 84.0;
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
                    if (_store.isLoading && _store.channels.isEmpty) ...[
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_store.errorMessage != null)
                      _StatusMessage(message: _store.errorMessage!)
                    else if (_store.channels.isEmpty && !_store.isLoading)
                      _StatusMessage(
                        message: "No live channels streaming ${widget.category.name}.",
                      )
                    else
                      _LiveChannelsList(channels: _store.channels),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
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
  if (!authController.config.isConfigured) {
    throw TwitchAuthException(
      "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to browse Twitch.",
    );
  }

  final accessToken = await authController.secureStore.readAccessToken();
  if (accessToken == null || accessToken.isEmpty) {
    throw TwitchAuthException("Connect Twitch from Following to browse live data.");
  }

  return authController.apiClientFactory(accessToken);
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
  const _LiveChannelsList({required this.channels});

  final List<StreamChannel> channels;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const _StatusMessage(message: "No live channels found.");
    }

    return Column(
      key: const ValueKey("browse_live_channels"),
      children: [
        for (final channel in channels) StreamCard(channel: channel),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<StreamChannel>("channels", channels));
  }
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
        mainAxisExtent: _categoryTileExtent(context),
      ),
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
  Future<void> clearBrowseSearchHistory() async {
    searchHistory = const <String>[];
  }

  @override
  Future<List<String>> readBrowseSearchHistory() async => searchHistory;

  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.system;

  @override
  Future<void> saveBrowseSearchHistory(List<String> history) async {
    searchHistory = List<String>.of(history);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
