package com.namecallfilter.flow.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.ui.draw.shadow
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.namecallfilter.flow.data.BrowseCategory
import com.namecallfilter.flow.data.BrowseRepository
import com.namecallfilter.flow.data.BrowseSearchRepository
import com.namecallfilter.flow.data.BrowseSection
import com.namecallfilter.flow.data.CategoryStreamsRepository
import com.namecallfilter.flow.data.StreamChannel
import com.namecallfilter.flow.data.TwitchSearchChannel
import com.namecallfilter.flow.data.browseCategoryFromStream
import com.namecallfilter.flow.data.colorsForText
import com.namecallfilter.flow.data.displayName
import com.namecallfilter.flow.data.initialsForName
import com.namecallfilter.flow.ui.components.AvatarRing
import com.namecallfilter.flow.ui.components.BackPageHeader
import com.namecallfilter.flow.ui.components.FlowPullToRefresh
import com.namecallfilter.flow.ui.components.FlowTooltipAction
import com.namecallfilter.flow.ui.components.GradientImageFallback
import com.namecallfilter.flow.ui.components.LiveDot
import com.namecallfilter.flow.ui.components.PageHeaderTitle
import com.namecallfilter.flow.ui.components.ScrollReactiveChrome
import com.namecallfilter.flow.ui.components.SkeletonBox
import com.namecallfilter.flow.ui.components.SkeletonShimmerHost
import com.namecallfilter.flow.ui.components.StatusMessage
import com.namecallfilter.flow.ui.components.StreamCard
import com.namecallfilter.flow.ui.components.StreamCardSkeleton
import com.namecallfilter.flow.ui.theme.FlowLayout
import com.namecallfilter.flow.ui.theme.FlowRadius
import com.namecallfilter.flow.ui.theme.FlowSpacing
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Composable
internal fun BrowseScreen(
    repository: BrowseRepository,
    showLiveChannelsSection: Boolean,
    onOpenSearch: () -> Unit,
    onOpenCategory: (BrowseCategory) -> Unit,
    onOpenPlayer: (StreamChannel) -> Unit,
    onOpenChannel: (String, String, String?, Boolean) -> Unit,
    onFooterHiddenChange: (Boolean) -> Unit,
) {
    val state by repository.state.collectAsStateWithLifecycle()
    val categoryListState = rememberLazyListState()
    val liveListState = rememberLazyListState()
    val visibleSection = if (showLiveChannelsSection) state.selectedSection else BrowseSection.CATEGORIES
    val listState = if (visibleSection == BrowseSection.CATEGORIES) categoryListState else liveListState
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navigationBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val layoutDirection = LocalLayoutDirection.current
    val latestState by rememberUpdatedState(state)
    val isShowingInitialSkeleton = when (visibleSection) {
        BrowseSection.CATEGORIES -> state.isLoadingCategories && state.categories.isEmpty()
        BrowseSection.LIVE_CHANNELS -> state.isLoadingLiveChannels && state.liveChannels.isEmpty()
    }

    LaunchedEffect(repository) {
        if (!state.categoriesLoaded) repository.loadCategories(reset = true)
    }
    LaunchedEffect(showLiveChannelsSection) {
        if (!showLiveChannelsSection && state.selectedSection != BrowseSection.CATEGORIES) {
            repository.selectSection(BrowseSection.CATEGORIES)
        }
    }
    LaunchedEffect(showLiveChannelsSection, state.selectedSection, state.liveChannelsLoaded) {
        if (
            showLiveChannelsSection &&
            state.selectedSection == BrowseSection.LIVE_CHANNELS &&
            !state.liveChannelsLoaded
        ) {
            repository.loadLiveChannels(reset = true)
        }
    }
    LaunchedEffect(listState, visibleSection) {
        snapshotFlow {
            val layout = listState.layoutInfo
            val nearEnd = (layout.visibleItemsInfo.lastOrNull()?.index ?: 0) >= layout.totalItemsCount - 3
            val currentSection = if (showLiveChannelsSection) {
                latestState.selectedSection
            } else {
                BrowseSection.CATEGORIES
            }
            val canLoad = when (currentSection) {
                BrowseSection.CATEGORIES -> latestState.categoriesLoaded &&
                    latestState.categoriesCursor != null && !latestState.isLoadingCategories
                BrowseSection.LIVE_CHANNELS -> latestState.liveChannelsLoaded &&
                    latestState.liveChannelsCursor != null && !latestState.isLoadingLiveChannels
            }
            nearEnd to canLoad
        }.distinctUntilChanged().collect { (nearEnd, canLoad) ->
            if (!nearEnd || !canLoad) return@collect
            when (if (showLiveChannelsSection) latestState.selectedSection else BrowseSection.CATEGORIES) {
                BrowseSection.CATEGORIES -> repository.loadCategories()
                BrowseSection.LIVE_CHANNELS -> repository.loadLiveChannels()
            }
        }
    }

    ScrollReactiveChrome(
        listState = listState,
        scrollStateKey = "browse-${visibleSection.name}",
        header = { BrowseHeader(onOpenSearch) },
        onFooterHiddenChange = onFooterHiddenChange,
    ) {
        FlowPullToRefresh(
            listState = listState,
            indicatorStartTop = statusTop + 156.dp,
            indicatorMaxTravel = 72.dp,
            onRefresh = {
                if (showLiveChannelsSection) repository.refreshActiveSection()
                else repository.loadCategories(reset = true, refresh = true)
            },
        ) {
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val safePadding = WindowInsets.safeDrawing.asPaddingValues()
                val safeHorizontalPadding = safePadding.calculateLeftPadding(layoutDirection) +
                    safePadding.calculateRightPadding(layoutDirection)
                val categoryTileWidth = (
                    maxWidth - safeHorizontalPadding - (FlowSpacing.Lg * 2) - 20.dp
                    ).coerceAtLeast(0.dp) / 3f
                val categoryRowExtent = (categoryTileWidth * 4f / 3f) + 68.dp + 16.dp
                val categorySkeletonRowCount = maxOf(
                    2,
                    kotlin.math.ceil((maxHeight / categoryRowExtent).toDouble()).toInt(),
                )
                val streamSkeletonCount = maxOf(
                    3,
                    kotlin.math.ceil((maxHeight / 93.dp).toDouble()).toInt(),
                )
                val skeletonLabel = if (visibleSection == BrowseSection.CATEGORIES) {
                    "Loading categories"
                } else {
                    "Loading live channels"
                }
                val listContent: @Composable () -> Unit = {
                    LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (isShowingInitialSkeleton) {
                            Modifier.semantics { contentDescription = skeletonLabel }
                        } else {
                            Modifier
                        },
                    ),
                contentPadding = PaddingValues(
                    start = FlowSpacing.Lg,
                    top = 140.dp + statusTop,
                    end = FlowSpacing.Lg,
                    bottom = FlowLayout.BottomNavigationScrollPadding,
                ),
            ) {
                if (showLiveChannelsSection) {
                    item(key = "browse-selector") {
                        BrowseSectionSelector(
                            selected = visibleSection,
                            onSelect = { next -> repository.selectSection(next) },
                        )
                        Spacer(Modifier.height(FlowSpacing.Md))
                    }
                }
                val visibleError = when (visibleSection) {
                    BrowseSection.CATEGORIES -> state.categoriesError
                    BrowseSection.LIVE_CHANNELS -> state.liveChannelsError
                }
                visibleError?.let { message ->
                    item(key = "browse-error") {
                        StatusMessage(message)
                        Spacer(Modifier.height(FlowSpacing.Md))
                    }
                }
                if (visibleSection == BrowseSection.CATEGORIES) {
                    if (state.isLoadingCategories && state.categories.isEmpty()) {
                        items(categorySkeletonRowCount, key = { "category-skeleton-$it" }) {
                            CategoryGridSkeletonRow()
                        }
                    } else if (state.categoriesLoaded && state.categories.isEmpty()) {
                        item { StatusMessage("No categories found.") }
                    } else {
                        items(
                            items = state.categories.chunked(3),
                            key = { row -> row.joinToString("|") { it.id } },
                        ) { row ->
                            CategoryGridRow(row, onOpenCategory)
                        }
                    }
                    if (state.isLoadingCategories && state.categories.isNotEmpty()) item { LoadingMore() }
                } else {
                    if (state.isLoadingLiveChannels && state.liveChannels.isEmpty()) {
                        items(streamSkeletonCount, key = { "browse-stream-skeleton-$it" }) {
                            StreamCardSkeleton()
                        }
                    } else if (state.liveChannelsLoaded && state.liveChannels.isEmpty()) {
                        item { StatusMessage("No live channels found.") }
                    } else {
                        items(
                            state.liveChannels,
                            key = { it.id.ifBlank { it.login.ifBlank { it.name } } },
                        ) { channel ->
                            StreamCard(
                                channel = channel,
                                onOpenStream = { onOpenPlayer(channel) },
                                onOpenChannel = {
                                    onOpenChannel(
                                        channel.login.ifBlank { channel.name },
                                        channel.name,
                                        channel.avatarImageUrl,
                                        true,
                                    )
                                },
                                onOpenCategory = browseCategoryFromStream(channel)?.let { category ->
                                    { onOpenCategory(category) }
                                },
                            )
                        }
                    }
                    if (state.isLoadingLiveChannels && state.liveChannels.isNotEmpty()) item { LoadingMore() }
                }
                    }
                }
                if (isShowingInitialSkeleton) {
                    SkeletonShimmerHost(content = listContent)
                } else {
                    listContent()
                }
            }
        }
    }
}

@Composable
private fun BrowseHeader(onSearch: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(
            start = FlowSpacing.Lg,
            top = FlowSpacing.Lg,
            end = FlowSpacing.Lg,
            bottom = 20.5.dp,
        ),
    ) {
        PageHeaderTitle("Browse")
        Spacer(Modifier.height(FlowSpacing.Md))
        Box(Modifier.fillMaxWidth().height(48.dp)) {
            ExactSearchField(
                value = "",
                onValueChange = {},
                placeholder = "Search Twitch",
                readOnly = true,
                modifier = Modifier.fillMaxSize(),
            )
            Box(
                Modifier
                    .matchParentSize()
                    .semantics {
                        contentDescription = "Search Twitch"
                        role = Role.Button
                    }
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = onSearch,
                    ),
            )
        }
    }
}

@Composable
private fun BrowseSectionSelector(selected: BrowseSection, onSelect: (BrowseSection) -> Unit) {
    ExactSlidingSegmentedControl(
        options = BrowseSection.entries.map { section ->
            section to if (section == BrowseSection.CATEGORIES) "Categories" else "Live Channels"
        },
        selected = selected,
        onSelect = onSelect,
    )
}

@Composable
internal fun <T> ExactSlidingSegmentedControl(
    options: List<Pair<T, String>>,
    selected: T,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (options.isEmpty()) return
    val selectedIndex = options.indexOfFirst { it.first == selected }.coerceAtLeast(0)
    val outerShape = RoundedCornerShape(9.dp)
    val thumbShape = RoundedCornerShape(FlowRadius.Small)
    val platformViewConfiguration = LocalViewConfiguration.current
    val exactViewConfiguration = remember(platformViewConfiguration) {
        object : ViewConfiguration by platformViewConfiguration {
            override val minimumTouchTargetSize: DpSize = DpSize.Zero
        }
    }

    CompositionLocalProvider(LocalViewConfiguration provides exactViewConfiguration) {
        BoxWithConstraints(
            modifier = modifier
                .fillMaxWidth()
                .height(36.dp)
                .background(
                    MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.72f),
                    outerShape,
                ),
        ) {
        val segmentWidth = (maxWidth - 6.dp) / options.size
        val thumbX by animateDpAsState(
            targetValue = 2.dp + (segmentWidth * selectedIndex),
            animationSpec = spring(dampingRatio = 1f, stiffness = 503.551f),
            label = "flow_segmented_thumb",
        )
        Box(
            Modifier
                .offset { IntOffset(thumbX.roundToPx(), 2.dp.roundToPx()) }
                .width(segmentWidth + 2.dp)
                .height(32.dp)
                .shadow(
                    elevation = 3.dp,
                    shape = thumbShape,
                    ambientColor = Color.Black.copy(alpha = 0.12f),
                    spotColor = Color.Black.copy(alpha = 0.12f),
                )
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.34f), thumbShape)
                // Cupertino's two translucent shadows remain visible through its
                // translucent thumb. Compose clips its elevation shadow outside the
                // shape, so reproduce that in-shape darkening explicitly.
                .background(Color.Black.copy(alpha = 0.12f), thumbShape)
                .border(0.5.dp, Color.Black.copy(alpha = 0.04f), thumbShape),
        )
        for (index in 0 until options.lastIndex) {
            if (selectedIndex != index && selectedIndex != index + 1) {
                Box(
                    Modifier
                        .offset(x = 3.dp + segmentWidth * (index + 1) - 0.5.dp, y = 7.dp)
                        .width(1.dp)
                        .height(22.dp)
                        .background(Color(0x4D8E8E93)),
                )
            }
        }
            Row(Modifier.fillMaxSize().padding(horizontal = 3.dp)) {
                options.forEach { (value, label) ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxSize()
                            .pointerInput(value, onSelect) {
                                detectTapGestures(onTap = { onSelect(value) })
                            }
                            .clearAndSetSemantics {
                                contentDescription = label
                                role = Role.Button
                                // See BottomBarItem: stateDescription matches Flutter's spoken
                                // "Selected, Button" without Compose exposing a toggle role.
                                if (value == selected) stateDescription = "Selected"
                                onClick {
                                    onSelect(value)
                                    true
                                }
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.ExtraBold,
                            style = MaterialTheme.typography.labelMedium,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ExactSearchField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "Search channels or categories",
    readOnly: Boolean = false,
    onClear: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val focused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(100.dp)
    val colors = TextFieldDefaults.colors(
        focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.6f),
        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.6f),
        disabledContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.6f),
        focusedIndicatorColor = Color.Transparent,
        unfocusedIndicatorColor = Color.Transparent,
        disabledIndicatorColor = Color.Transparent,
        cursorColor = MaterialTheme.colorScheme.primary,
    )
    CompositionLocalProvider(LocalTextSelectionColors provides colors.textSelectionColors) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier
                .height(48.dp)
                .border(
                    width = 1.5.dp,
                    color = if (focused) {
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.8f)
                    } else {
                        Color.Transparent
                    },
                    shape = shape,
                ),
            singleLine = true,
            readOnly = readOnly,
            textStyle = MaterialTheme.typography.bodyLarge.copy(
                color = MaterialTheme.colorScheme.onSurface,
                platformStyle = PlatformTextStyle(includeFontPadding = false),
            ),
            keyboardOptions = KeyboardOptions(
                autoCorrectEnabled = false,
                imeAction = ImeAction.Search,
            ),
            interactionSource = interactionSource,
            cursorBrush = SolidColor(colors.cursorColor),
            decorationBox = { innerTextField ->
                TextFieldDefaults.DecorationBox(
                    value = value,
                    innerTextField = innerTextField,
                    enabled = true,
                    singleLine = true,
                    visualTransformation = VisualTransformation.None,
                    interactionSource = interactionSource,
                    placeholder = {
                        Text(
                            text = placeholder,
                            maxLines = 1,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = FontWeight.Normal,
                            style = MaterialTheme.typography.bodyLarge.copy(
                                platformStyle = PlatformTextStyle(includeFontPadding = false),
                            ),
                        )
                    },
                    leadingIcon = {
                        Icon(
                            Icons.Default.Search,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    },
                    trailingIcon = if (value.isNotEmpty() && onClear != null) {
                        {
                            FlowTooltipAction(
                                label = "Clear search",
                                onClick = onClear,
                                modifier = Modifier.size(48.dp),
                            ) {
                                Icon(Icons.Default.Close, contentDescription = null)
                            }
                        }
                    } else {
                        null
                    },
                    shape = shape,
                    colors = colors,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                )
            },
        )
    }
}

@Composable
private fun CategoryGridRow(categories: List<BrowseCategory>, onOpen: (BrowseCategory) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth().padding(bottom = FlowSpacing.Lg)) {
        val tileWidth = (maxWidth - 20.dp) / 3f
        val tileExtent = (tileWidth * 4f / 3f) + 68.dp
        Row(
            Modifier.fillMaxWidth().height(tileExtent),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            repeat(3) { index ->
                Box(Modifier.weight(1f).fillMaxHeight()) {
                    categories.getOrNull(index)?.let {
                        CategoryGridCard(
                            category = it,
                            onClick = { onOpen(it) },
                            modifier = Modifier.fillMaxHeight(),
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun CategoryGridCard(
    category: BrowseCategory,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(FlowRadius.Small))
            .clickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = "${category.name}\n${category.viewers}"
                this.onClick {
                    onClick()
                    true
                }
            },
    ) {
        CategoryThumbnail(
            category = category,
            contentDescription = category.name,
            modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(FlowRadius.Small)),
        )
        Spacer(Modifier.height(6.dp))
        Text(
            category.name,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.86f),
            fontWeight = FontWeight.ExtraBold,
            style = MaterialTheme.typography.labelMedium,
        )
        Spacer(Modifier.height(4.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            LiveDot(size = 8.dp)
            Spacer(Modifier.width(5.dp))
            Text(
                category.viewers,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.72f),
                fontWeight = FontWeight.ExtraBold,
                style = MaterialTheme.typography.labelMedium.copy(fontFeatureSettings = "tnum"),
            )
        }
    }
}

@Composable
private fun CategoryThumbnail(
    category: BrowseCategory,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
) {
    var imageFailed by remember(category.imageUrl) { mutableStateOf(false) }
    Box(modifier) {
        if (category.imageUrl.isNullOrBlank() || imageFailed) {
            GradientImageFallback(
                colors = category.colors,
                diagonalPattern = true,
                modifier = Modifier.fillMaxSize(),
            )
            Text(
                text = category.name,
                modifier = Modifier.align(Alignment.Center).padding(FlowSpacing.Sm),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                color = Color.White,
                fontWeight = FontWeight.ExtraBold,
                style = MaterialTheme.typography.labelMedium,
            )
        } else {
            AsyncImage(
                model = category.imageUrl,
                contentDescription = contentDescription,
                contentScale = ContentScale.Crop,
                filterQuality = FilterQuality.High,
                modifier = Modifier.fillMaxSize(),
                onError = { imageFailed = true },
            )
        }
    }
}

@Composable
private fun CategoryGridSkeletonRow() {
    BoxWithConstraints(Modifier.fillMaxWidth().padding(bottom = FlowSpacing.Lg)) {
        val tileWidth = (maxWidth - 20.dp) / 3f
        val tileExtent = (tileWidth * 4f / 3f) + 68.dp
        Row(
            Modifier.fillMaxWidth().height(tileExtent),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            repeat(3) {
                Column(Modifier.weight(1f).fillMaxHeight()) {
                    SkeletonBox(Modifier.fillMaxWidth().aspectRatio(3f / 4f))
                    Spacer(Modifier.height(7.dp))
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        SkeletonBox(Modifier.fillMaxWidth(0.82f).height(12.dp))
                    }
                    Spacer(Modifier.height(7.dp))
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        SkeletonBox(Modifier.fillMaxWidth(0.58f).height(10.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun LoadingMore() {
    Box(Modifier.fillMaxWidth().padding(FlowSpacing.Md), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.4.dp)
    }
}

@Composable
internal fun BrowseSearchScreen(
    repository: BrowseSearchRepository,
    searchScope: CoroutineScope,
    isRouteActive: Boolean,
    onBack: () -> Unit,
    onOpenCategory: (BrowseCategory) -> Unit,
    onOpenPlayer: (StreamChannel) -> Unit,
    onOpenChannel: (String, String, String?, Boolean) -> Unit,
    onFooterHiddenChange: (Boolean) -> Unit,
) {
    val state by repository.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val emptyHistoryChromeState = rememberLazyListState()
    val routeScope = rememberCoroutineScope()
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navigationBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    val searchInput = remember(repository, routeScope, searchScope) {
        BrowseSearchInputCoordinator(
            repository = repository,
            debounceScope = routeScope,
            requestScope = searchScope,
        )
    }
    val query = searchInput.query

    LaunchedEffect(repository, searchScope) {
        // The Flutter screen starts this unawaited. Keep it in the app-lived scope too, so popping
        // the route only cancels its pending query debounce rather than an already-started read.
        searchScope.launch {
            try {
                repository.loadSearchHistory()
            } catch (error: CancellationException) {
                throw error
            } catch (_: Throwable) {
                // Search remains available even if persisted history cannot be read.
            }
        }
    }
    LaunchedEffect(isRouteActive) {
        if (isRouteActive) {
            focusRequester.requestFocus()
            keyboard?.show()
        } else {
            focusManager.clearFocus(force = true)
            keyboard?.hide()
        }
    }
    DisposableEffect(searchInput) {
        onDispose(searchInput::dispose)
    }
    val isShowingSearchSkeleton = searchInput.showsLoading(state)
    val isShowingEmptyHistory = query.isBlank() && state.searchHistory.isEmpty()

    ScrollReactiveChrome(
        listState = if (isShowingEmptyHistory) emptyHistoryChromeState else listState,
        scrollStateKey = if (isShowingEmptyHistory) "browse-search-empty" else "browse-search-list",
        header = {
            SearchHeader(
                query = query,
                onQueryChange = searchInput::updateQuery,
                onClear = { searchInput.updateQuery("") },
                onBack = onBack,
                modifier = Modifier.focusRequester(focusRequester),
            )
        },
        onFooterHiddenChange = onFooterHiddenChange,
    ) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val fixedResultsExtent = 35.dp + (72.dp * 7) + FlowSpacing.Md + 35.dp
            val availableCategoryHeight = (
                maxHeight - (FlowLayout.SearchContentTop + statusTop) - fixedResultsExtent
                ).coerceAtLeast(0.dp)
            val searchCategorySkeletonCount = maxOf(
                1,
                kotlin.math.ceil((availableCategoryHeight.value / 144f).toDouble()).toInt(),
            )
            if (isShowingEmptyHistory) {
                EmptySearchHistory(
                    Modifier
                        .fillMaxSize()
                        .padding(top = statusTop),
                )
            } else {
            val listContent: @Composable () -> Unit = {
                LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .then(
                    if (isShowingSearchSkeleton) {
                        Modifier.semantics { contentDescription = "Loading search results" }
                    } else {
                        Modifier
                    },
                ),
            contentPadding = PaddingValues(
                start = FlowSpacing.Lg,
                top = FlowLayout.SearchContentTop + statusTop,
                end = FlowSpacing.Lg,
                bottom = 96.dp + navigationBottom,
            ),
        ) {
            if (query.isBlank()) {
                item {
                    Row(
                        Modifier.fillMaxWidth().padding(top = FlowSpacing.Sm, bottom = FlowSpacing.Xs),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "History",
                            Modifier.weight(1f),
                            color = MaterialTheme.colorScheme.onSurface,
                            style = MaterialTheme.typography.titleSmall.copy(
                                fontWeight = FontWeight.Black,
                                letterSpacing = 0.sp,
                            ),
                        )
                        Text(
                            text = "Clear",
                            modifier = Modifier.clickable {
                                searchScope.launch { repository.clearSearchHistory() }
                            },
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.labelLarge,
                        )
                    }
                }
                items(state.searchHistory, key = { "history-$it" }) { item ->
                    Row(
                        Modifier.fillMaxWidth().height(56.dp).clickable {
                            searchInput.updateQuery(item)
                        },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Default.History, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.width(FlowSpacing.Lg))
                        Text(
                            item,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.ExtraBold,
                            style = MaterialTheme.typography.titleMedium,
                        )
                    }
                }
            } else if (isShowingSearchSkeleton) {
                item { SearchSectionTitleSkeleton(68.dp) }
                items(7) { SearchChannelSkeleton() }
                item { Spacer(Modifier.height(FlowSpacing.Md)); SearchSectionTitleSkeleton(82.dp) }
                items(searchCategorySkeletonCount) { SearchCategorySkeleton() }
            } else {
                if (state.errorMessage != null) {
                    item { StatusMessage(requireNotNull(state.errorMessage)) }
                } else if (state.channels.isEmpty() && state.categories.isEmpty()) {
                    item { StatusMessage("No matching channels.") }
                } else {
                    if (state.channels.isNotEmpty()) {
                        item { SearchSectionTitle("Channels") }
                        items(state.channels, key = { "search-channel-${it.id}" }) { channel ->
                            SearchChannelRow(
                                channel = channel,
                                onOpenChannel = {
                                    onOpenChannel(
                                        channel.broadcasterLogin,
                                        displayName(channel.displayName, channel.broadcasterLogin),
                                        channel.thumbnailUrl,
                                        channel.isLive,
                                    )
                                },
                                onOpenPlayer = { onOpenPlayer(channel.toStreamChannel()) },
                            )
                        }
                    }
                    if (state.categories.isNotEmpty()) {
                        item {
                            if (state.channels.isNotEmpty()) Spacer(Modifier.height(FlowSpacing.Md))
                            SearchSectionTitle("Categories")
                        }
                        items(state.categories, key = { "search-category-${it.id}" }) { category ->
                            SearchCategoryRow(category, onClick = { onOpenCategory(category) })
                        }
                    }
                }
            }
                }
            }
            if (isShowingSearchSkeleton) {
                SkeletonShimmerHost(content = listContent)
            } else {
                listContent()
            }
            }
        }
    }
}

@Composable
private fun SearchHeader(
    query: String,
    onQueryChange: (String) -> Unit,
    onClear: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        Modifier.fillMaxWidth().padding(
            start = FlowSpacing.Sm,
            top = FlowSpacing.Md,
            end = FlowSpacing.Lg,
            bottom = FlowSpacing.Md,
        ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FlowTooltipAction(
            label = "Back",
            onClick = onBack,
            modifier = Modifier.size(48.dp),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface,
            )
        }
        Spacer(Modifier.width(FlowSpacing.Xs))
        ExactSearchField(
            value = query,
            onValueChange = onQueryChange,
            onClear = onClear,
            modifier = modifier.weight(1f),
        )
    }
}

@Composable
private fun EmptySearchHistory(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Default.History,
                contentDescription = null,
                modifier = Modifier.size(42.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.42f),
            )
            Spacer(Modifier.height(FlowSpacing.Sm))
            Text(
                "No recent searches",
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                fontWeight = FontWeight.ExtraBold,
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}

@Composable
private fun SearchSectionTitle(title: String) {
    Text(
        title,
        modifier = Modifier.padding(top = FlowSpacing.Sm, bottom = FlowSpacing.Xs),
        color = MaterialTheme.colorScheme.onSurface,
        fontWeight = FontWeight.Black,
        style = MaterialTheme.typography.titleSmall,
    )
}

@Composable
private fun SearchChannelRow(
    channel: TwitchSearchChannel,
    onOpenChannel: () -> Unit,
    onOpenPlayer: () -> Unit,
) {
    val name = displayName(channel.displayName, channel.broadcasterLogin)
    Row(
        Modifier.fillMaxWidth().height(72.dp).clickable(onClick = if (channel.isLive) onOpenPlayer else onOpenChannel),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AvatarRing(
            initials = initialsForName(name),
            colors = colorsForText(channel.id),
            imageUrl = channel.thumbnailUrl,
            size = 42.dp,
            modifier = Modifier.clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onOpenChannel,
            ),
        )
        Spacer(Modifier.width(FlowSpacing.Lg))
        Column(Modifier.weight(1f)) {
            Text(
                name,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.ExtraBold,
                style = MaterialTheme.typography.titleMedium,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (channel.isLive) {
                    LiveDot(size = 7.dp)
                    Spacer(Modifier.width(5.dp))
                }
                Text(
                    if (channel.gameName.isNotBlank()) channel.gameName else if (channel.isLive) "Live now" else "Offline",
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.bodyMedium.copy(fontFeatureSettings = "tnum"),
                )
            }
        }
    }
}

private fun TwitchSearchChannel.toStreamChannel(): StreamChannel {
    val name = displayName(displayName, broadcasterLogin)
    return StreamChannel(
        id = id,
        login = broadcasterLogin.trim(),
        name = name,
        initials = initialsForName(name),
        title = title.ifBlank { "Live now" },
        category = gameName.ifBlank { "Live" },
        viewers = "--",
        avatarColors = colorsForText(id),
        thumbnailColors = colorsForText(id, 3),
        avatarImageUrl = thumbnailUrl,
        startedAt = startedAt,
    )
}

@Composable
private fun SearchCategoryRow(category: BrowseCategory, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = FlowSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CategoryThumbnail(
            category = category,
            contentDescription = category.name,
            modifier = Modifier.width(96.dp).aspectRatio(3f / 4f).clip(RoundedCornerShape(FlowRadius.Small)),
        )
        Spacer(Modifier.width(FlowSpacing.Md))
        Column(Modifier.weight(1f)) {
            Text(
                category.name,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.ExtraBold,
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(Modifier.height(FlowSpacing.Xs))
            Row(verticalAlignment = Alignment.CenterVertically) {
                LiveDot(size = 8.dp)
                Spacer(Modifier.width(5.dp))
                Text(
                    category.viewers,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.bodyMedium.copy(fontFeatureSettings = "tnum"),
                )
            }
        }
    }
}

@Composable
private fun SearchSectionTitleSkeleton(width: androidx.compose.ui.unit.Dp) {
    Box(
        Modifier.height(35.dp).padding(top = FlowSpacing.Sm, bottom = FlowSpacing.Xs),
        contentAlignment = Alignment.CenterStart,
    ) {
        SkeletonBox(Modifier.width(width).height(14.dp))
    }
}

@Composable
private fun SearchChannelSkeleton() {
    Row(Modifier.fillMaxWidth().height(72.dp), verticalAlignment = Alignment.CenterVertically) {
        SkeletonBox(Modifier.size(42.dp), radius = 50.dp)
        Spacer(Modifier.width(FlowSpacing.Lg))
        Column(Modifier.weight(1f)) {
            SkeletonBox(Modifier.fillMaxWidth(0.62f).height(16.dp))
            Spacer(Modifier.height(FlowSpacing.Sm))
            SkeletonBox(Modifier.fillMaxWidth(0.34f).height(13.dp))
        }
    }
}

@Composable
private fun SearchCategorySkeleton() {
    Row(Modifier.fillMaxWidth().padding(vertical = FlowSpacing.Sm), verticalAlignment = Alignment.CenterVertically) {
        SkeletonBox(Modifier.width(96.dp).aspectRatio(3f / 4f))
        Spacer(Modifier.width(FlowSpacing.Md))
        Column(Modifier.weight(1f)) {
            SkeletonBox(Modifier.fillMaxWidth(0.82f).height(16.dp))
            Spacer(Modifier.height(FlowSpacing.Sm))
            Row(verticalAlignment = Alignment.CenterVertically) {
                SkeletonBox(Modifier.size(7.dp), radius = 50.dp)
                Spacer(Modifier.width(5.dp))
                SkeletonBox(Modifier.width(52.dp).height(12.dp))
            }
        }
    }
}

@Composable
internal fun CategoryStreamsScreen(
    repository: CategoryStreamsRepository,
    isRouteActive: Boolean,
    onBack: () -> Unit,
    onOpenPlayer: (StreamChannel) -> Unit,
    onOpenChannel: (String, String, String?, Boolean) -> Unit,
    onFooterHiddenChange: (Boolean) -> Unit,
) {
    val state by repository.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val lifecycleOwner = LocalLifecycleOwner.current
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navigationBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val latestState by rememberUpdatedState(state)
    var refreshInFlight by remember { mutableStateOf(false) }
    val isShowingInitialSkeleton = state.isInitialLoading

    suspend fun refreshRoute() {
        if (refreshInFlight || repository.state.value.isLoading) return
        refreshInFlight = true
        try {
            repository.loadStreams(reset = true, refresh = true)
        } finally {
            refreshInFlight = false
        }
    }

    LaunchedEffect(repository) {
        if (!state.loaded) repository.loadStreams(reset = true)
    }
    LaunchedEffect(listState, repository) {
        snapshotFlow {
            val layout = listState.layoutInfo
            val nearEnd = (layout.visibleItemsInfo.lastOrNull()?.index ?: 0) >= layout.totalItemsCount - 4
            nearEnd to (latestState.loaded && latestState.cursor != null && !latestState.isLoading)
        }.distinctUntilChanged().collect { (nearEnd, canLoad) ->
            if (nearEnd && canLoad) repository.loadStreams()
        }
    }
    LaunchedEffect(repository, lifecycleOwner, isRouteActive) {
        if (!isRouteActive) return@LaunchedEffect
        var wasResumed = lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
        lifecycleOwner.lifecycle.currentStateFlow.collect { lifecycleState ->
            val resumed = lifecycleState.isAtLeast(Lifecycle.State.RESUMED)
            if (
                resumed && !wasResumed &&
                listState.firstVisibleItemIndex == 0 && listState.firstVisibleItemScrollOffset == 0
            ) {
                refreshRoute()
            }
            wasResumed = resumed
        }
    }
    LaunchedEffect(repository, lifecycleOwner, isRouteActive) {
        if (!isRouteActive) return@LaunchedEffect
        while (isActive) {
            delay(30_000)
            if (
                lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) &&
                listState.firstVisibleItemIndex == 0 && listState.firstVisibleItemScrollOffset == 0
            ) {
                refreshRoute()
            }
        }
    }

    ScrollReactiveChrome(
        listState = listState,
        header = { BackPageHeader(repository.category.name, onBack) },
        onFooterHiddenChange = onFooterHiddenChange,
    ) {
        FlowPullToRefresh(
            listState = listState,
            indicatorStartTop = statusTop + FlowLayout.BackButtonRefreshStart,
            indicatorMaxTravel = 52.dp,
            onRefresh = { refreshRoute() },
        ) {
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val streamSkeletonCount = maxOf(
                    3,
                    kotlin.math.ceil((maxHeight / 93.dp).toDouble()).toInt(),
                )
                val listContent: @Composable () -> Unit = {
                    LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (isShowingInitialSkeleton) {
                            Modifier.semantics { contentDescription = "Loading category streams" }
                        } else {
                            Modifier
                        },
                    ),
                contentPadding = PaddingValues(
                    start = FlowSpacing.Lg,
                    top = FlowLayout.BackButtonContentTop + statusTop,
                    end = FlowSpacing.Lg,
                    bottom = 24.dp + navigationBottom,
                ),
            ) {
                if (state.isInitialLoading) {
                    items(streamSkeletonCount) { StreamCardSkeleton(showCategory = false) }
                } else if (state.errorMessage != null) {
                    item { StatusMessage(requireNotNull(state.errorMessage)) }
                } else if (state.loaded && state.channels.isEmpty()) {
                    item { StatusMessage("No live channels streaming ${repository.category.name}.") }
                } else {
                    items(state.channels, key = { it.id.ifBlank { it.login } }) { channel ->
                        StreamCard(
                            channel = channel,
                            showCategory = false,
                            onOpenStream = { onOpenPlayer(channel) },
                            onOpenChannel = {
                                onOpenChannel(channel.login, channel.name, channel.avatarImageUrl, true)
                            },
                        )
                    }
                }
                if (state.isLoading && state.channels.isNotEmpty()) item { LoadingMore() }
                    }
                }
                if (isShowingInitialSkeleton) {
                    SkeletonShimmerHost(content = listContent)
                } else {
                    listContent()
                }
            }
        }
    }
}
