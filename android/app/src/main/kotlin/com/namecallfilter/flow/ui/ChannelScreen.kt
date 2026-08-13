package com.namecallfilter.flow.ui

import android.os.SystemClock
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.namecallfilter.flow.data.BrowseCategory
import com.namecallfilter.flow.data.ChannelRepository
import com.namecallfilter.flow.data.StreamChannel
import com.namecallfilter.flow.data.TwitchChannelDetails
import com.namecallfilter.flow.data.TwitchChannelLiveStream
import com.namecallfilter.flow.data.TwitchPastBroadcast
import com.namecallfilter.flow.data.colorsForText
import com.namecallfilter.flow.data.formatCompactCount
import com.namecallfilter.flow.data.initialsForName
import com.namecallfilter.flow.data.twitchThumbnailUrl
import com.namecallfilter.flow.ui.components.ScrollReactiveChrome
import com.namecallfilter.flow.ui.components.FlowPullToRefresh
import com.namecallfilter.flow.ui.components.FlowTooltipAction
import com.namecallfilter.flow.ui.components.LocalFlowVisualsActive
import com.namecallfilter.flow.ui.components.SectionHeader
import com.namecallfilter.flow.ui.components.SkeletonBox
import com.namecallfilter.flow.ui.components.SkeletonShimmerHost
import com.namecallfilter.flow.ui.components.StatusMessage
import com.namecallfilter.flow.ui.navigation.ChannelSeed
import com.namecallfilter.flow.ui.theme.FlowColors
import com.namecallfilter.flow.ui.theme.FlowLayout
import com.namecallfilter.flow.ui.theme.FlowRadius
import com.namecallfilter.flow.ui.theme.FlowSpacing
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.isActive
import java.time.Duration
import java.time.Instant

@Composable
internal fun ChannelScreen(
    repository: ChannelRepository,
    initialChannel: ChannelSeed,
    isRouteActive: Boolean,
    onBack: () -> Unit,
    onOpenPlayer: (StreamChannel) -> Unit,
    onOpenCategory: (BrowseCategory) -> Unit,
    onFooterHiddenChange: (Boolean) -> Unit,
) {
    val state by repository.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val lifecycleOwner = LocalLifecycleOwner.current
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navigationBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val latestState by rememberUpdatedState(state)
    var refreshInFlight by remember { mutableStateOf(false) }

    suspend fun refreshRoute() {
        if (refreshInFlight || repository.state.value.isLoading) return
        refreshInFlight = true
        try {
            repository.load(refresh = true)
        } finally {
            refreshInFlight = false
        }
    }

    LaunchedEffect(repository) {
        if (state.channel == null) repository.load(refresh = true)
    }
    LaunchedEffect(listState, repository) {
        snapshotFlow {
            val layout = listState.layoutInfo
            val nearEnd = (layout.visibleItemsInfo.lastOrNull()?.index ?: 0) >= layout.totalItemsCount - 4
            nearEnd to (latestState.canLoadMorePastBroadcasts && !latestState.isLoadingPastBroadcasts)
        }.distinctUntilChanged().collect { (nearEnd, canLoad) ->
            if (nearEnd && canLoad) {
                repository.loadMorePastBroadcasts()
            }
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
        header = { ChannelBackHeader(onBack) },
        onFooterHiddenChange = onFooterHiddenChange,
    ) {
        FlowPullToRefresh(
            listState = listState,
            indicatorStartTop = statusTop + FlowLayout.BackButtonRefreshStart,
            indicatorMaxTravel = 52.dp,
            onRefresh = { refreshRoute() },
        ) {
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val fixedSkeletonContentExtent = 174.dp + FlowSpacing.Xxl + 32.dp + FlowSpacing.Sm
                val availableBroadcastHeight = (
                    maxHeight - statusTop - FlowLayout.BackButtonContentTop - fixedSkeletonContentExtent
                    ).coerceAtLeast(0.dp)
                val broadcastSkeletonCount = kotlin.math.ceil(
                    (availableBroadcastHeight / 94.dp).toDouble(),
                ).toInt()
                val listContent: @Composable () -> Unit = {
                    LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (state.isInitialLoading) {
                            Modifier.semantics { contentDescription = "Loading channel" }
                        } else {
                            Modifier
                        },
                    ),
                contentPadding = PaddingValues(
                    start = FlowSpacing.Lg,
                    top = FlowLayout.BackButtonContentTop + statusTop,
                    end = FlowSpacing.Lg,
                    bottom = FlowSpacing.Xxl + navigationBottom,
                ),
            ) {
                if (state.isInitialLoading) {
                    item { ChannelHeaderSkeleton() }
                    item {
                        Spacer(Modifier.height(FlowSpacing.Xxl))
                        SectionHeader("Past broadcasts")
                        Spacer(Modifier.height(FlowSpacing.Sm))
                    }
                    items(broadcastSkeletonCount) { PastBroadcastSkeleton() }
                } else if (state.channel == null && state.errorMessage != null) {
                    item { StatusMessage(requireNotNull(state.errorMessage)) }
                } else {
                    item {
                        ChannelHeaderCard(
                            channel = state.channel,
                            initialChannel = initialChannel,
                            onOpenPlayer = onOpenPlayer,
                            onOpenCategory = onOpenCategory,
                        )
                    }
                    item {
                        Spacer(Modifier.height(FlowSpacing.Xxl))
                        SectionHeader("Past broadcasts")
                        Spacer(Modifier.height(FlowSpacing.Sm))
                    }
                    val broadcasts = state.channel?.pastBroadcasts.orEmpty()
                    if (broadcasts.isEmpty()) {
                        item { StatusMessage("No past broadcasts.") }
                    } else {
                        itemsIndexed(
                            items = broadcasts,
                            key = { _, broadcast -> broadcast.id },
                        ) { index, broadcast ->
                            PastBroadcastCard(
                                broadcast = broadcast,
                                isLive = index == 0 && isLivePastBroadcast(
                                    state.channel?.liveStream,
                                    broadcast,
                                ),
                                onOpenCategory = if (
                                    broadcast.categoryId.isBlank() || broadcast.category.isBlank()
                                ) null else {
                                    {
                                        onOpenCategory(
                                            BrowseCategory(
                                                id = broadcast.categoryId,
                                                name = broadcast.category,
                                                viewerCount = 0,
                                                viewers = "",
                                                imageUrl = null,
                                                colors = colorsForText(broadcast.categoryId),
                                            ),
                                        )
                                    }
                                },
                            )
                        }
                        if (state.pastBroadcastsError != null) {
                            item { StatusMessage(requireNotNull(state.pastBroadcastsError)) }
                        } else if (state.isLoadingPastBroadcasts) {
                            item { LoadingBroadcasts() }
                        }
                    }
                }
                    }
                }
                if (state.isInitialLoading) {
                    SkeletonShimmerHost(content = listContent)
                } else {
                    listContent()
                }
            }
        }
    }
}

@Composable
private fun ChannelBackHeader(onBack: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(
            start = FlowSpacing.Lg,
            top = FlowSpacing.Lg,
            end = FlowSpacing.Lg,
            bottom = 16.5.dp,
        ),
    ) {
        FlowTooltipAction(
            label = "Back",
            onClick = onBack,
            modifier = Modifier.size(width = 40.dp, height = 32.dp),
        ) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.CenterStart) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChannelHeaderCard(
    channel: TwitchChannelDetails?,
    initialChannel: ChannelSeed,
    onOpenPlayer: (StreamChannel) -> Unit,
    onOpenCategory: (BrowseCategory) -> Unit,
) {
    val displayName = channel?.displayName?.takeIf(String::isNotBlank)
        ?: initialChannel.displayName.ifBlank { initialChannel.login }
    val liveStream = channel?.liveStream
    val isLive = if (channel == null) initialChannel.isLive else liveStream != null
    val playerChannel = channel?.toLivePlayerChannel(initialChannel)
    val isDark = MaterialTheme.colorScheme.background == Color.Black

    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(FlowRadius.Large),
        border = BorderStroke(
            1.dp,
            MaterialTheme.colorScheme.outlineVariant.copy(alpha = if (isDark) 0.14f else 0.42f),
        ),
    ) {
        Column(Modifier.padding(FlowSpacing.Lg)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                PlainChannelAvatar(
                    initials = initialsForName(displayName),
                    imageUrl = channel?.profileImageUrl ?: initialChannel.avatarImageUrl,
                    isLive = isLive,
                    onClick = playerChannel?.let { stream -> ({ onOpenPlayer(stream) }) },
                )
                Spacer(Modifier.width(FlowSpacing.Md))
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            displayName,
                            modifier = Modifier.weight(1f, fill = false),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.Black,
                            style = MaterialTheme.typography.titleLarge,
                        )
                        Spacer(Modifier.width(6.dp))
                        Icon(
                            Icons.Default.Verified,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.72f),
                        )
                    }
                    Spacer(Modifier.height(FlowSpacing.Xs))
                    if (liveStream == null) {
                        Text(
                            if (isLive) "Live now" else "Offline",
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    } else {
                        val category = liveStream.category.trim()
                        val categoryEnabled = category.isNotEmpty() && liveStream.categoryId.trim().isNotEmpty()
                        val openCategory = {
                            onOpenCategory(
                                BrowseCategory(
                                    id = liveStream.categoryId.trim(),
                                    name = category,
                                    viewerCount = liveStream.viewerCount,
                                    viewers = formatCompactCount(liveStream.viewerCount),
                                    imageUrl = null,
                                    colors = colorsForText(liveStream.categoryId),
                                ),
                            )
                        }
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                        ) {
                            Text(
                                category,
                                modifier = Modifier
                                    .clickable(enabled = categoryEnabled, onClick = openCategory)
                                    .clearAndSetSemantics {
                                        contentDescription = "Open $category category"
                                        if (categoryEnabled) {
                                            role = Role.Button
                                            onClick {
                                                openCategory()
                                                true
                                            }
                                        }
                                    },
                                color = if (categoryEnabled) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.74f),
                                fontWeight = FontWeight.Bold,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            Text(
                                "with ${formatCompactCount(liveStream.viewerCount)} viewers",
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.74f),
                                fontWeight = FontWeight.Bold,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
            }
            val description = channel?.description?.trim().orEmpty()
            if (description.isNotEmpty()) {
                Spacer(Modifier.height(FlowSpacing.Lg))
                Text(
                    description.replace("-", "‑"),
                    modifier = Modifier.clearAndSetSemantics {
                        contentDescription = description
                    },
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.78f),
                    fontWeight = FontWeight.Medium,
                    style = MaterialTheme.typography.bodyLarge.copy(lineHeight = 21.12.sp),
                )
            }
            channel?.let {
                Spacer(Modifier.height(FlowSpacing.Md))
                Text(
                    "${formatCompactCount(it.followers)} followers",
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.Black,
                    style = MaterialTheme.typography.titleSmall,
                )
            }
        }
    }
}

@Composable
private fun PlainChannelAvatar(
    initials: String,
    imageUrl: String?,
    isLive: Boolean,
    onClick: (() -> Unit)?,
) {
    val resolvedImageUrl = imageUrl?.takeIf { it.isNotBlank() }
    var imageFailed by remember(resolvedImageUrl) { mutableStateOf(false) }
    Box(modifier = Modifier.size(70.dp)) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(CircleShape)
                .then(
                    if (onClick != null) {
                        Modifier
                            .clickable(onClick = onClick)
                            .clearAndSetSemantics {
                                contentDescription = "Watch live stream"
                                role = Role.Button
                                onClick {
                                    onClick()
                                    true
                                }
                            }
                    } else {
                        Modifier
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (resolvedImageUrl == null || imageFailed) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.surfaceContainerHighest),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = initials,
                        color = MaterialTheme.colorScheme.onSurface,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontSize = 19.6.sp,
                            lineHeight = 28.028.sp,
                            fontWeight = FontWeight.Black,
                        ),
                    )
                }
            }
            if (resolvedImageUrl != null) {
                AsyncImage(
                    model = resolvedImageUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    filterQuality = FilterQuality.High,
                    modifier = Modifier.fillMaxSize(),
                    onLoading = { imageFailed = false },
                    onSuccess = { imageFailed = false },
                    onError = { imageFailed = true },
                )
            }
        }
        if (isLive) {
            Text(
                text = "LIVE",
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .offset(y = 6.dp)
                    .background(FlowColors.LiveBadge, RoundedCornerShape(4.dp))
                    .padding(horizontal = 6.dp, vertical = 3.dp),
                color = Color.White,
                fontSize = 11.sp,
                lineHeight = 11.sp,
                fontWeight = FontWeight.Black,
            )
        }
    }
}

private fun TwitchChannelDetails.toLivePlayerChannel(seed: ChannelSeed): StreamChannel? {
    val stream = liveStream ?: return null
    val channelLogin = login.ifBlank { seed.login }
    if (channelLogin.isBlank()) return null
    val name = displayName.ifBlank { seed.displayName.ifBlank { channelLogin } }
    return StreamChannel(
        id = id,
        login = channelLogin,
        name = name,
        initials = initialsForName(name),
        title = stream.title.ifBlank { "Live now" },
        category = stream.category.ifBlank { "Live" },
        viewers = formatCompactCount(stream.viewerCount),
        avatarColors = colorsForText(id.ifBlank { channelLogin }),
        thumbnailColors = colorsForText(stream.id.ifBlank { id.ifBlank { channelLogin } }, 3),
        avatarImageUrl = profileImageUrl ?: seed.avatarImageUrl,
        thumbnailUrl = twitchThumbnailUrl(stream.thumbnailUrl),
        startedAt = stream.startedAt,
    )
}

@Composable
private fun PastBroadcastCard(
    broadcast: TwitchPastBroadcast,
    isLive: Boolean,
    onOpenCategory: (() -> Unit)?,
) {
    val thumbnailUrl = twitchThumbnailUrl(broadcast.thumbnailUrl)?.takeIf { it.isNotBlank() }
    var thumbnailFailed by remember(thumbnailUrl) { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().padding(bottom = FlowSpacing.Md),
        verticalAlignment = Alignment.Top,
    ) {
        Box(Modifier.width(132.dp).aspectRatio(16f / 9f).clip(RoundedCornerShape(FlowRadius.Small))) {
            if (thumbnailUrl == null || thumbnailFailed) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Brush.linearGradient(colorsForText(broadcast.id, 3).map(::Color))),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Rounded.PlayArrow,
                        contentDescription = null,
                        modifier = Modifier.size(30.dp),
                        tint = Color.White.copy(alpha = 0.86f),
                    )
                }
            }
            if (thumbnailUrl != null) {
                AsyncImage(
                    model = thumbnailUrl,
                    contentDescription = broadcast.title,
                    contentScale = ContentScale.Crop,
                    filterQuality = FilterQuality.High,
                    modifier = Modifier.fillMaxSize(),
                    onLoading = { thumbnailFailed = false },
                    onSuccess = { thumbnailFailed = false },
                    onError = { thumbnailFailed = true },
                )
            }
            DurationBadge(
                durationSeconds = broadcast.durationSeconds,
                isLive = isLive,
                modifier = Modifier.align(Alignment.BottomStart).padding(start = 6.dp, bottom = 5.dp)
            )
        }
        Spacer(Modifier.width(FlowSpacing.Md))
        Column(Modifier.weight(1f)) {
            Text(
                broadcast.title,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.Black,
                style = MaterialTheme.typography.titleSmall.copy(lineHeight = 18.4.sp),
            )
            Spacer(Modifier.height(FlowSpacing.Xs))
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val ageMaxWidth = if (broadcast.category.isBlank()) maxWidth else maxWidth * 0.65f
                Row(Modifier.fillMaxWidth()) {
                    val instant = broadcast.publishedAt ?: broadcast.createdAt
                    if (instant != null) {
                        Text(
                            "${channelRelativeTime(instant)}${if (broadcast.category.isNotBlank()) " | " else ""}",
                            modifier = Modifier.widthIn(max = ageMaxWidth),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                    if (broadcast.category.isNotBlank()) {
                        val openCategory = onOpenCategory
                        Text(
                            broadcast.category,
                            modifier = Modifier
                                .weight(1f)
                                .clickable(enabled = openCategory != null) { openCategory?.invoke() }
                                .clearAndSetSemantics {
                                    contentDescription = "Open ${broadcast.category} category"
                                    if (openCategory != null) {
                                        role = Role.Button
                                        onClick {
                                            openCategory()
                                            true
                                        }
                                    }
                                },
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = if (onOpenCategory != null) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }
            Spacer(Modifier.height(2.dp))
            Text(
                "${formatCompactCount(broadcast.viewCount)} views",
                maxLines = 1,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun DurationBadge(
    durationSeconds: Long,
    isLive: Boolean,
    modifier: Modifier = Modifier,
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val visualsActive = LocalFlowVisualsActive.current
    val serverDuration = durationSeconds.coerceAtLeast(0L)
    var displayedDuration by rememberSaveable { mutableLongStateOf(serverDuration) }
    var baselineDuration by rememberSaveable { mutableLongStateOf(serverDuration) }
    var baselineRealtime by rememberSaveable { mutableLongStateOf(SystemClock.elapsedRealtime()) }
    var wasLive by rememberSaveable { mutableStateOf(isLive) }

    LaunchedEffect(serverDuration, isLive) {
        val now = SystemClock.elapsedRealtime()
        val elapsedSeconds = ((now - baselineRealtime).coerceAtLeast(0L) / 1_000L)
        val localDuration = baselineDuration + elapsedSeconds
        displayedDuration = if (isLive && wasLive) {
            maxOf(displayedDuration, localDuration, serverDuration)
        } else {
            serverDuration
        }
        baselineDuration = displayedDuration
        baselineRealtime = now
        wasLive = isLive
    }
    LaunchedEffect(isLive, lifecycleOwner, visualsActive) {
        if (!isLive || !visualsActive) return@LaunchedEffect
        lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (isActive) {
                val elapsedSeconds = (
                    (SystemClock.elapsedRealtime() - baselineRealtime).coerceAtLeast(0L) / 1_000L
                )
                displayedDuration = maxOf(displayedDuration, baselineDuration + elapsedSeconds)
                delay(1_000)
            }
        }
    }

    Text(
        durationText(displayedDuration),
        modifier = modifier
            .background(Color.Black.copy(alpha = 0.52f), RoundedCornerShape(FlowRadius.Small))
            .padding(horizontal = 5.dp, vertical = 2.dp),
        color = Color.White,
        fontSize = 10.5.sp,
        lineHeight = 10.5.sp,
        fontWeight = FontWeight.ExtraBold,
        style = MaterialTheme.typography.labelSmall.copy(fontFeatureSettings = "tnum"),
    )
}

private fun isLivePastBroadcast(
    liveStream: TwitchChannelLiveStream?,
    broadcast: TwitchPastBroadcast,
): Boolean {
    if (liveStream == null) return false
    val streamId = liveStream.id.trim()
    if (streamId.isNotEmpty() && streamId == broadcast.id.trim()) return true
    val streamStartedAt = liveStream.startedAt ?: return false
    val broadcastStartedAt = broadcast.createdAt ?: broadcast.publishedAt ?: return false
    return Duration.between(streamStartedAt, broadcastStartedAt).abs() <= Duration.ofMinutes(5)
}

internal fun channelRelativeTime(timestamp: Instant, now: Instant = Instant.now()): String {
    val elapsed = Duration.between(timestamp, now)
    val days = elapsed.toDays()
    if (days >= 365) {
        val years = days / 365
        return "$years ${if (years == 1L) "year" else "years"} ago"
    }
    if (days >= 30) {
        val months = days / 30
        return "$months ${if (months == 1L) "month" else "months"} ago"
    }
    if (days >= 1) return "$days ${if (days == 1L) "day" else "days"} ago"

    val hours = elapsed.toHours()
    if (hours >= 1) return "$hours ${if (hours == 1L) "hour" else "hours"} ago"

    val minutes = elapsed.toMinutes()
    if (minutes >= 1) return "$minutes ${if (minutes == 1L) "minute" else "minutes"} ago"
    return "just now"
}

private fun durationText(seconds: Long): String {
    val hours = seconds / 3600
    val minutes = (seconds % 3600) / 60
    val remainingSeconds = seconds % 60
    return if (hours > 0) "$hours:${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}"
    else "$minutes:${remainingSeconds.toString().padStart(2, '0')}"
}

@Composable
private fun ChannelHeaderSkeleton() {
    val isDark = MaterialTheme.colorScheme.background == Color.Black
    Surface(
        modifier = Modifier.fillMaxWidth().height(174.dp),
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(FlowRadius.Large),
        border = BorderStroke(
            1.dp,
            MaterialTheme.colorScheme.outlineVariant.copy(alpha = if (isDark) 0.14f else 0.42f),
        ),
    ) {
        Column(Modifier.padding(FlowSpacing.Lg)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SkeletonBox(Modifier.size(70.dp), radius = 50.dp)
                Spacer(Modifier.width(FlowSpacing.Md))
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        SkeletonBox(Modifier.width(132.dp).height(20.dp))
                        Spacer(Modifier.width(6.dp))
                        SkeletonBox(Modifier.size(18.dp))
                    }
                    Spacer(Modifier.height(FlowSpacing.Xs))
                    SkeletonBox(Modifier.width(72.dp).height(12.dp))
                }
            }
            Spacer(Modifier.height(FlowSpacing.Lg))
            Box(Modifier.height(22.dp), contentAlignment = Alignment.CenterStart) {
                SkeletonBox(Modifier.width(220.dp).height(13.dp))
            }
            Spacer(Modifier.height(FlowSpacing.Md))
            Box(Modifier.height(22.dp), contentAlignment = Alignment.CenterStart) {
                SkeletonBox(Modifier.width(104.dp).height(14.dp))
            }
        }
    }
}

@Composable
private fun PastBroadcastSkeleton() {
    Row(
        Modifier.fillMaxWidth().padding(bottom = FlowSpacing.Md),
        verticalAlignment = Alignment.Top,
    ) {
        Box(Modifier.width(132.dp).height(74.25.dp)) {
            SkeletonBox(Modifier.fillMaxSize())
            SkeletonBox(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 6.dp, bottom = 5.dp)
                    .size(width = 49.dp, height = 17.dp),
            )
        }
        Spacer(Modifier.width(FlowSpacing.Md))
        Column(Modifier.weight(1f).height(82.dp)) {
            SkeletonLine(slotHeight = 22.dp, widthFraction = 0.96f, barHeight = 14.dp)
            SkeletonLine(slotHeight = 22.dp, widthFraction = 0.82f, barHeight = 14.dp)
            SkeletonLine(slotHeight = 18.dp, widthFraction = 0.72f, barHeight = 13.dp)
            Spacer(Modifier.height(2.dp))
            SkeletonLine(slotHeight = 18.dp, widthFraction = 0.42f, barHeight = 13.dp)
        }
    }
}

@Composable
private fun SkeletonLine(
    slotHeight: androidx.compose.ui.unit.Dp,
    widthFraction: Float,
    barHeight: androidx.compose.ui.unit.Dp,
) {
    Box(Modifier.fillMaxWidth().height(slotHeight), contentAlignment = Alignment.CenterStart) {
        SkeletonBox(Modifier.fillMaxWidth(widthFraction).height(barHeight))
    }
}

@Composable
private fun LoadingBroadcasts() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(FlowSpacing.Sm))
        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.4.dp)
    }
}
