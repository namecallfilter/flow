import "dart:async";
import "dart:ui";

import "package:flow/api/twitch_api.dart";
import "package:flow/api/twitch_auth.dart";
import "package:flow/app/radius.dart";
import "package:flow/app/routes.dart";
import "package:flow/app/spacing.dart";
import "package:flow/features/following/following_screen.dart";
import "package:flow/shared/widgets/app_bottom_nav.dart";
import "package:flow/shared/widgets/avatar_ring.dart";
import "package:flow/shared/widgets/page_header_title.dart";
import "package:flow/shared/widgets/pull_to_refresh.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class BrowseScreenStateStore {
  List<_BrowseCategory> _categories = const <_BrowseCategory>[];
  List<StreamChannel> _liveChannels = const <StreamChannel>[];
  _BrowseSection _selectedSection = _BrowseSection.categories;
  bool _categoriesLoaded = false;
  bool _liveChannelsLoaded = false;
  String? _categoriesCursor;
  String? _liveChannelsCursor;
  double _categoriesScrollOffset = 0;
  double _liveChannelsScrollOffset = 0;

  double _scrollOffsetFor(_BrowseSection section) => switch (section) {
    _BrowseSection.categories => _categoriesScrollOffset,
    _BrowseSection.liveChannels => _liveChannelsScrollOffset,
  };

  void _setScrollOffsetFor(_BrowseSection section, double offset) {
    switch (section) {
      case _BrowseSection.categories:
        _categoriesScrollOffset = offset;
      case _BrowseSection.liveChannels:
        _liveChannelsScrollOffset = offset;
    }
  }
}

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    this.authController,
    this.bottomNavigationBar,
    this.stateStore,
  });

  final TwitchAuthController? authController;
  final Widget? bottomNavigationBar;
  final BrowseScreenStateStore? stateStore;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController?>("authController", authController));
    properties.add(DiagnosticsProperty<Widget?>("bottomNavigationBar", bottomNavigationBar));
    properties.add(DiagnosticsProperty<BrowseScreenStateStore?>("stateStore", stateStore));
  }
}

class _BrowseScreenState extends State<BrowseScreen> {
  late final ScrollController _scrollController;
  late final TwitchAuthController _authController;
  late final BrowseScreenStateStore _stateStore;
  late List<_BrowseCategory> _categories;
  late List<StreamChannel> _liveChannels;
  late _BrowseSection _selectedSection;
  late bool _categoriesLoaded;
  late bool _liveChannelsLoaded;
  bool _isLoadingCategories = false;
  bool _isLoadingLiveChannels = false;
  late String? _categoriesCursor;
  late String? _liveChannelsCursor;
  String? _categoriesError;
  String? _liveChannelsError;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? _buildDefaultAuthController();
    _stateStore = widget.stateStore ?? BrowseScreenStateStore();
    _categories = _stateStore._categories;
    _liveChannels = _stateStore._liveChannels;
    _selectedSection = _stateStore._selectedSection;
    _categoriesLoaded = _stateStore._categoriesLoaded;
    _liveChannelsLoaded = _stateStore._liveChannelsLoaded;
    _categoriesCursor = _stateStore._categoriesCursor;
    _liveChannelsCursor = _stateStore._liveChannelsCursor;
    _scrollController = ScrollController(
      initialScrollOffset: _stateStore._scrollOffsetFor(_selectedSection),
    );
    _scrollController.addListener(_loadMoreWhenNearBottom);
    if (!_categoriesLoaded) {
      unawaited(_loadCategories(reset: true));
    }
    if (_selectedSection == _BrowseSection.liveChannels && !_liveChannelsLoaded) {
      unawaited(_loadLiveChannels(reset: true));
    }
  }

  @override
  void dispose() {
    _persistScrollOffset();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectSection(_BrowseSection? section) {
    if (section == null || section == _selectedSection) {
      return;
    }

    _persistScrollOffset();
    setState(() {
      _selectedSection = section;
      _stateStore._selectedSection = section;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollOffsetFor(section);
    });
    if (section == _BrowseSection.liveChannels && !_liveChannelsLoaded) {
      unawaited(_loadLiveChannels(reset: true));
    }
  }

  void _persistScrollOffset() {
    if (!_scrollController.hasClients) {
      return;
    }
    _stateStore._setScrollOffsetFor(_selectedSection, _scrollController.offset);
  }

  void _restoreScrollOffsetFor(_BrowseSection section) {
    if (!mounted || !_scrollController.hasClients || _selectedSection != section) {
      return;
    }

    final offset = _stateStore._scrollOffsetFor(section);
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

  Future<TwitchApiClient> _loadApiClient() => _loadBrowseApiClient(_authController);

  Future<void> _loadCategories({bool reset = false}) async {
    if (_isLoadingCategories || (!reset && _categoriesLoaded && _categoriesCursor == null)) {
      return;
    }

    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
      if (reset) {
        _categoriesCursor = null;
      }
    });

    try {
      final apiClient = await _loadApiClient();
      final page = await apiClient.fetchTopCategoriesPage(
        cursor: reset ? null : _categoriesCursor,
      );
      final nextCategories = await Future.wait([
        for (final category in page.data) _browseCategoryFromApi(apiClient, category),
      ]);

      if (!mounted) {
        return;
      }
      setState(() {
        _categories = reset ? nextCategories : [..._categories, ...nextCategories];
        _categoriesCursor = page.cursor;
        _categoriesLoaded = true;
        _isLoadingCategories = false;
        _stateStore
          .._categories = _categories
          .._categoriesCursor = _categoriesCursor
          .._categoriesLoaded = _categoriesLoaded;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categoriesError = _browseErrorMessage(error);
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadLiveChannels({bool reset = false}) async {
    if (_isLoadingLiveChannels || (!reset && _liveChannelsLoaded && _liveChannelsCursor == null)) {
      return;
    }

    setState(() {
      _isLoadingLiveChannels = true;
      _liveChannelsError = null;
      if (reset) {
        _liveChannelsCursor = null;
      }
    });

    try {
      final apiClient = await _loadApiClient();
      final page = await apiClient.fetchLiveStreamsPage(
        cursor: reset ? null : _liveChannelsCursor,
      );
      final usersById = await apiClient.fetchUsersByIds([
        for (final stream in page.data) stream.userId,
      ]);
      final nextChannels = [
        for (final stream in page.data)
          if (usersById.containsKey(stream.userId))
            _streamChannelFromStream(
              stream,
              avatarImageUrl: usersById[stream.userId]?.profileImageUrl,
            ),
      ];

      if (!mounted) {
        return;
      }
      setState(() {
        _liveChannels = reset ? nextChannels : [..._liveChannels, ...nextChannels];
        _liveChannelsCursor = page.cursor;
        _liveChannelsLoaded = true;
        _isLoadingLiveChannels = false;
        _stateStore
          .._liveChannels = _liveChannels
          .._liveChannelsCursor = _liveChannelsCursor
          .._liveChannelsLoaded = _liveChannelsLoaded;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveChannelsError = _browseErrorMessage(error);
        _isLoadingLiveChannels = false;
      });
    }
  }

  Future<_BrowseCategory> _browseCategoryFromApi(
    TwitchApiClient apiClient,
    TwitchCategory category,
  ) async {
    final streams = await apiClient.fetchLiveStreamsPage(
      first: 100,
      gameIds: [category.id],
    );
    final viewerCount = streams.data.fold<int>(
      0,
      (total, stream) => total + stream.viewerCount,
    );

    return _BrowseCategory(
      id: category.id,
      name: category.name,
      viewers: _formatCompactCount(viewerCount),
      imageUrl: _twitchBoxArtUrl(category.boxArtUrl),
      colors: _colorsForText(category.id),
    );
  }

  void _loadMoreWhenNearBottom() {
    _persistScrollOffset();
    if (!_scrollController.hasClients || _scrollController.position.extentAfter > 420) {
      return;
    }

    if (_selectedSection == _BrowseSection.categories) {
      unawaited(_loadCategories());
    } else {
      unawaited(_loadLiveChannels());
    }
  }

  Future<void> _refreshActiveSection() {
    if (_selectedSection == _BrowseSection.categories) {
      return _loadCategories(reset: true);
    }
    return _loadLiveChannels(reset: true);
  }

  void _openSearch() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BrowseSearchScreen(authController: _authController),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const topScrollPadding = 150.0;
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
                    selectedSection: _selectedSection,
                    onSectionSelected: _selectSection,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_activeLoading && _activeItemsEmpty) ...[
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_activeError != null)
                    _StatusMessage(message: _activeError!)
                  else if (_selectedSection == _BrowseSection.categories)
                    _CategoryGrid(categories: _categories)
                  else
                    _LiveChannelsList(channels: _liveChannels),
                  if (_activeLoading && !_activeItemsEmpty) ...[
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
  }

  bool get _activeLoading =>
      _selectedSection == _BrowseSection.categories ? _isLoadingCategories : _isLoadingLiveChannels;

  bool get _activeItemsEmpty =>
      _selectedSection == _BrowseSection.categories ? _categories.isEmpty : _liveChannels.isEmpty;

  String? get _activeError =>
      _selectedSection == _BrowseSection.categories ? _categoriesError : _liveChannelsError;
}

enum _BrowseSection { categories, liveChannels }

class BrowseSearchScreen extends StatefulWidget {
  const BrowseSearchScreen({
    required this.authController,
    super.key,
  });

  final TwitchAuthController authController;

  @override
  State<BrowseSearchScreen> createState() => _BrowseSearchScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TwitchAuthController>("authController", authController));
  }
}

class _BrowseSearchScreenState extends State<BrowseSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  List<TwitchSearchChannel> _channels = const <TwitchSearchChannel>[];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _channels = const <TwitchSearchChannel>[];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_searchChannels(trimmedQuery));
    });
  }

  Future<void> _searchChannels(String query) async {
    try {
      final apiClient = await _loadBrowseApiClient(widget.authController);
      final page = await apiClient.searchChannelsPage(query, first: 8);
      final validUsersById = await apiClient.fetchUsersByIds([
        for (final channel in page.data) channel.id,
      ]);
      final channels =
          [
            for (final channel in page.data)
              if (validUsersById.containsKey(channel.id)) channel,
          ]..sort((left, right) {
            if (left.isLive == right.isLive) {
              return left.displayName.toLowerCase().compareTo(
                right.displayName.toLowerCase(),
              );
            }
            return left.isLive ? -1 : 1;
          });

      if (!mounted || _searchController.text.trim() != query) {
        return;
      }
      setState(() {
        _channels = channels;
        _isSearching = false;
      });
    } on Object catch (error) {
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }
      setState(() {
        _errorMessage = _browseErrorMessage(error);
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();

    return Scaffold(
      key: const ValueKey("browse_search_page"),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SearchPageTopBar(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _handleQueryChanged,
            ),
            if (_isSearching) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: query.isEmpty
                  ? const _StatusMessage(message: "Search channels")
                  : _SearchChannelResults(
                      channels: _channels,
                      errorMessage: _errorMessage,
                      isSearching: _isSearching,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPageTopBar extends StatelessWidget {
  const _SearchPageTopBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
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
              hintText: "Search channels",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: "Clear",
                      onPressed: () {
                        controller.clear();
                        onChanged("");
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextEditingController>("controller", controller));
    properties.add(DiagnosticsProperty<FocusNode>("focusNode", focusNode));
    properties.add(ObjectFlagProperty<ValueChanged<String>>.has("onChanged", onChanged));
  }
}

class _SearchChannelResults extends StatelessWidget {
  const _SearchChannelResults({
    required this.channels,
    required this.errorMessage,
    required this.isSearching,
  });

  final List<TwitchSearchChannel> channels;
  final String? errorMessage;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final error = errorMessage;
    if (error != null) {
      return _StatusMessage(message: error);
    }
    if (channels.isEmpty && !isSearching) {
      return const _StatusMessage(message: "No matching channels.");
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: 96 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) => _SearchChannelRow(channel: channels[index]),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<TwitchSearchChannel>("channels", channels));
    properties.add(StringProperty("errorMessage", errorMessage));
    properties.add(DiagnosticsProperty<bool>("isSearching", isSearching));
  }
}

class _SearchChannelRow extends StatelessWidget {
  const _SearchChannelRow({required this.channel});

  final TwitchSearchChannel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final displayName = _displayName(channel.displayName, channel.broadcasterLogin);
    final subtitle = channel.isLive
        ? (channel.gameName.isEmpty ? "Live now" : channel.gameName)
        : (channel.gameName.isEmpty ? "Offline" : channel.gameName);

    return ListTile(
      key: ValueKey("browse_search_channel_$displayName"),
      contentPadding: EdgeInsets.zero,
      leading: AvatarRing(
        initials: _initialsForName(displayName),
        size: 42,
        avatarColors: _colorsForText(channel.id),
        imageUrl: channel.thumbnailUrl,
        statusColor: channel.isLive ? null : mutedColor,
      ),
      title: Text(
        displayName,
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

  final _BrowseSection selectedSection;
  final ValueChanged<_BrowseSection?> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );

    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<_BrowseSection>(
        key: const ValueKey("browse_segmented_control"),
        groupValue: selectedSection,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        thumbColor: theme.colorScheme.primary.withValues(alpha: 0.34),
        onValueChanged: onSectionSelected,
        children: <_BrowseSection, Widget>{
          _BrowseSection.categories: Padding(
            key: const ValueKey("browse_segment_categories"),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Categories", style: labelStyle),
          ),
          _BrowseSection.liveChannels: Padding(
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
    properties.add(EnumProperty<_BrowseSection>("selectedSection", selectedSection));
    properties.add(
      ObjectFlagProperty<ValueChanged<_BrowseSection?>>.has(
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
  const _CategoryGrid({required this.categories});

  final List<_BrowseCategory> categories;

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
      itemBuilder: (context, index) => _CategoryCard(category: categories[index]),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<_BrowseCategory>("categories", categories));
  }
}

double _categoryTileExtent(BuildContext context) {
  final horizontalPadding = MediaQuery.of(context).padding.horizontal + (AppSpacing.lg * 2);
  final availableWidth = MediaQuery.sizeOf(context).width - horizontalPadding - 20;
  final tileWidth = availableWidth / 3;
  return (tileWidth * 4 / 3) + 68;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final _BrowseCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: ValueKey("browse_category_card_${category.name}"),
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
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<_BrowseCategory>("category", category));
  }
}

class _CategoryThumbnail extends StatelessWidget {
  const _CategoryThumbnail({required this.category});

  final _BrowseCategory category;

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
      errorBuilder: (_, _, _) => fallback,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<_BrowseCategory>("category", category));
  }
}

class _CategoryThumbnailFallback extends StatelessWidget {
  const _CategoryThumbnailFallback({required this.category});

  final _BrowseCategory category;

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
    properties.add(DiagnosticsProperty<_BrowseCategory>("category", category));
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

class _BrowseCategory {
  const _BrowseCategory({
    required this.id,
    required this.name,
    required this.viewers,
    required this.imageUrl,
    required this.colors,
  });

  final String id;
  final String name;
  final String viewers;
  final String? imageUrl;
  final List<Color> colors;
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

StreamChannel _streamChannelFromStream(
  TwitchFollowedStream stream, {
  String? avatarImageUrl,
}) {
  final name = _displayName(stream.userName, stream.userLogin);
  return StreamChannel(
    name: name,
    initials: _initialsForName(name),
    title: stream.title.isEmpty ? "Live now" : stream.title,
    category: stream.gameName.isEmpty ? "Live" : stream.gameName,
    viewers: _formatCompactCount(stream.viewerCount),
    avatarColors: _colorsForText(stream.userId),
    thumbnailColors: _colorsForText(stream.id, count: 3),
    avatarImageUrl: avatarImageUrl,
    thumbnailUrl: _twitchThumbnailUrl(stream.thumbnailUrl),
  );
}

String _browseErrorMessage(Object error) {
  if (error is TwitchApiException) {
    return error.message;
  }
  if (error is TwitchAuthException) {
    return error.message;
  }
  return error.toString();
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

String? _twitchThumbnailUrl(String? template) {
  if (template == null || template.isEmpty) {
    return null;
  }
  return template.replaceAll("{width}", "320").replaceAll("{height}", "180");
}

String? _twitchBoxArtUrl(String? template) {
  if (template == null || template.isEmpty) {
    return null;
  }
  return template.replaceAll("{width}", "285").replaceAll("{height}", "380");
}
