package com.namecallfilter.flow.ui

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.namecallfilter.flow.data.BrowseCategory
import com.namecallfilter.flow.data.BrowseRepository
import com.namecallfilter.flow.data.FollowingRepository
import com.namecallfilter.flow.data.OfflineChannel
import com.namecallfilter.flow.data.StreamChannel
import com.namecallfilter.flow.data.TwitchSessionStatus
import com.namecallfilter.flow.data.browseCategoryFromStream
import com.namecallfilter.flow.data.initialsForName
import com.namecallfilter.flow.ui.components.AvatarRing
import com.namecallfilter.flow.ui.components.ErrorBanner
import com.namecallfilter.flow.ui.components.FlowPullToRefresh
import com.namecallfilter.flow.ui.components.FlowTooltipAction
import com.namecallfilter.flow.ui.components.PageHeaderTitle
import com.namecallfilter.flow.ui.components.ScrollReactiveChrome
import com.namecallfilter.flow.ui.components.SectionHeader
import com.namecallfilter.flow.ui.components.SkeletonBox
import com.namecallfilter.flow.ui.components.SkeletonShimmerHost
import com.namecallfilter.flow.ui.components.StatusMessage
import com.namecallfilter.flow.ui.components.StreamCard
import com.namecallfilter.flow.ui.components.StreamCardSkeleton
import com.namecallfilter.flow.ui.theme.FlowLayout
import com.namecallfilter.flow.ui.theme.FlowRadius
import com.namecallfilter.flow.ui.theme.FlowSpacing
import kotlinx.coroutines.flow.distinctUntilChanged

@Composable
internal fun FollowingScreen(
    followingRepository: FollowingRepository,
    browseRepository: BrowseRepository,
    onLogin: () -> Unit,
    onOpenPlayer: (StreamChannel) -> Unit,
    onOpenChannel: (String, String, String?, Boolean) -> Unit,
    onOpenCategory: (BrowseCategory) -> Unit,
    onFooterHiddenChange: (Boolean) -> Unit,
) {
    val following by followingRepository.state.collectAsStateWithLifecycle()
    val browse by browseRepository.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val anonymous = !following.isLoggedIn && following.sessionStatus in setOf(
        TwitchSessionStatus.LOGGED_OUT,
        TwitchSessionStatus.RESTORE_FAILED,
    )
    val channels = if (anonymous) browse.liveChannels else following.liveChannels
    val loading = if (anonymous) browse.isLoadingLiveChannels else following.isLoadingFollowing
    val showLiveEmptyState = if (anonymous) {
        browse.liveChannelsLoaded && channels.isEmpty()
    } else {
        channels.isEmpty() && following.offlineChannels.isEmpty()
    }
    val initialLoading = when {
        following.sessionStatus in setOf(
            TwitchSessionStatus.UNINITIALIZED,
            TwitchSessionStatus.RESTORING,
        ) -> true
        anonymous -> loading && channels.isEmpty()
        else -> following.isLoadingFollowing && following.connection == null
    }
    val error = if (anonymous) browse.liveChannelsError else following.followingError
    val latestAnonymous by rememberUpdatedState(anonymous)
    val latestBrowse by rememberUpdatedState(browse)

    LaunchedEffect(followingRepository) {
        followingRepository.loadSavedConnection()
    }
    LaunchedEffect(anonymous, browse.liveChannelsLoaded) {
        if (anonymous && !browse.liveChannelsLoaded) {
            browseRepository.loadLiveChannels(reset = true)
        }
    }
    LaunchedEffect(listState, anonymous) {
        snapshotFlow {
            val info = listState.layoutInfo
            val last = info.visibleItemsInfo.lastOrNull()?.index ?: 0
            val nearEnd = last >= info.totalItemsCount - 4
            nearEnd to (
                latestAnonymous && latestBrowse.liveChannelsLoaded &&
                    latestBrowse.liveChannelsCursor != null && !latestBrowse.isLoadingLiveChannels
                )
        }.distinctUntilChanged().collect { (nearEnd, canLoad) ->
            if (nearEnd && canLoad) {
                browseRepository.loadLiveChannels()
            }
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val skeletonFixedExtent =
            FlowLayout.LargeTitleContentTop +
                FlowLayout.BottomNavigationScrollPadding +
                if (anonymous) 0.dp else FlowSpacing.Sm + 72.dp
        val skeletonViewportHeight = (maxHeight - statusTop).coerceAtLeast(0.dp)
        val skeletonStreamCount =
            ((skeletonViewportHeight - skeletonFixedExtent).coerceAtLeast(0.dp) / 93.dp)
                .toInt()

        ScrollReactiveChrome(
            listState = listState,
            header = {
                FollowingHeader(
                    title = if (anonymous) "Live Channels" else "Following",
                    userName = following.profileUser?.displayName,
                    userImageUrl = following.profileUser?.profileImageUrl,
                    onProfileClick = onLogin,
                )
            },
            onFooterHiddenChange = onFooterHiddenChange,
        ) {
            FlowPullToRefresh(
                listState = listState,
                indicatorStartTop = statusTop + FlowLayout.LargeTitleRefreshStart,
                indicatorMaxTravel = 52.dp,
                onRefresh = {
                    if (anonymous) browseRepository.loadLiveChannels(reset = true, refresh = true)
                    else followingRepository.loadSavedConnection(refresh = true)
                },
            ) {
                val listContent: @Composable () -> Unit = {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .fillMaxSize()
                            .then(
                                if (initialLoading) {
                                    Modifier.semantics {
                                        contentDescription = if (anonymous) {
                                            "Loading live channels"
                                        } else {
                                            "Loading following channels"
                                        }
                                    }
                                } else {
                                    Modifier
                                },
                            ),
                        contentPadding = PaddingValues(
                            start = FlowSpacing.Lg,
                            top = FlowLayout.LargeTitleContentTop + statusTop,
                            end = FlowSpacing.Lg,
                            bottom = FlowLayout.BottomNavigationScrollPadding,
                        ),
                    ) {
                        if (initialLoading) {
                            items(skeletonStreamCount, key = { "following-skeleton-$it" }) { StreamCardSkeleton() }
                            if (!anonymous) {
                                item { Spacer(Modifier.height(FlowSpacing.Sm)) }
                                item { OfflineCardSkeleton() }
                            }
                        } else {
                            if (error != null) {
                                item { ErrorBanner(error) }
                                item { Spacer(Modifier.height(FlowSpacing.Md)) }
                            }
                            if (showLiveEmptyState) {
                                item {
                                    StatusMessage(
                                        if (anonymous) "No live channels are available right now."
                                        else "No followed channels are live now.",
                                    )
                                }
                            }
                            items(
                                items = channels,
                                key = { channel -> channel.id.ifBlank { channel.login.ifBlank { channel.name } } },
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
                            if (!anonymous) {
                                item { Spacer(Modifier.height(FlowSpacing.Sm)) }
                                item {
                                    OfflineCard(
                                        channels = following.offlineChannels,
                                        expanded = following.offlineExpanded,
                                        onToggle = followingRepository::toggleOfflineExpanded,
                                        onOpenChannel = { channel ->
                                            onOpenChannel(
                                                channel.login.ifBlank { channel.name },
                                                channel.name,
                                                channel.avatarImageUrl,
                                                false,
                                            )
                                        },
                                    )
                                }
                            }
                        }
                    }
                }
                if (initialLoading) {
                    SkeletonShimmerHost(content = listContent)
                } else {
                    listContent()
                }
            }
        }
    }
}

@Composable
private fun FollowingHeader(
    title: String,
    userName: String?,
    userImageUrl: String?,
    onProfileClick: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(
            start = FlowSpacing.Lg,
            top = FlowSpacing.Lg,
            end = FlowSpacing.Lg,
            bottom = 16.5.dp,
        ),
        verticalAlignment = Alignment.Top,
    ) {
        PageHeaderTitle(title, Modifier.weight(1f))
        FlowTooltipAction(
            label = "Me",
            onClick = onProfileClick,
        ) {
            FollowingMeAvatarVisual(userName, userImageUrl)
        }
    }
}

@Composable
internal fun FollowingMeAvatarVisual(
    userName: String?,
    userImageUrl: String?,
    modifier: Modifier = Modifier,
    avatarModifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier.size(48.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier.size(40.dp),
            contentAlignment = Alignment.TopEnd,
        ) {
            AvatarRing(
                initials = initialsForName(userName ?: "Me"),
                colors = listOf(0xFF2C203F.toInt(), 0xFFFFA3B1.toInt()),
                modifier = avatarModifier,
                imageUrl = userImageUrl,
                size = 36.dp,
            )
        }
    }
}

@Composable
private fun OfflineCard(
    channels: List<OfflineChannel>,
    expanded: Boolean,
    onToggle: () -> Unit,
    onOpenChannel: (OfflineChannel) -> Unit,
) {
    OfflineCardShell {
        Column(
            Modifier
                .fillMaxWidth()
                .animateContentSize(
                    animationSpec = tween(
                        durationMillis = 180,
                        easing = CubicBezierEasing(0f, 0f, 0.58f, 1f),
                    ),
                    alignment = Alignment.TopStart,
                ),
        ) {
            SectionHeader(
                title = "Offline",
                expanded = expanded,
                onToggle = onToggle,
            )
            if (expanded) {
                if (channels.isEmpty()) {
                    StatusMessage(
                        "No offline followed channels.",
                        modifier = Modifier.padding(vertical = FlowSpacing.Lg),
                    )
                } else {
                    Spacer(Modifier.height(FlowSpacing.Sm))
                    channels.forEachIndexed { index, channel ->
                        OfflineRow(
                            channel = channel,
                            showDivider = index != channels.lastIndex,
                            onClick = { onOpenChannel(channel) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun OfflineRow(channel: OfflineChannel, showDivider: Boolean, onClick: () -> Unit) {
    val interactionSource = remember { MutableInteractionSource() }
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .clearAndSetSemantics {
                contentDescription = "${channel.name}\n${channel.lastLive}\n${channel.category}"
                this.onClick {
                    onClick()
                    true
                }
            },
    ) {
        Row(
            Modifier.fillMaxWidth().padding(vertical = FlowSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AvatarRing(
                initials = channel.initials,
                colors = channel.avatarColors,
                imageUrl = channel.avatarImageUrl,
                size = 54.dp,
            )
            Spacer(Modifier.width(14.dp))
            OfflineChannelIdentity(channel, Modifier.weight(1f))
        }
        if (showDivider) {
            HorizontalDivider(
                modifier = Modifier.height(1.dp),
                thickness = 0.5.dp,
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f),
            )
        }
    }
}

@Composable
internal fun OfflineChannelIdentity(
    channel: OfflineChannel,
    modifier: Modifier = Modifier,
) {
    // These three line boxes and compact gaps measure exactly like the 54dp avatar, so the name
    // starts at its top edge and the category ends at its bottom edge.
    Column(modifier) {
        Text(
            channel.name,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.ExtraBold,
            style = MaterialTheme.typography.titleMedium.copy(
                fontSize = 16.sp,
                lineHeight = 17.6.sp,
            ),
        )
        Spacer(Modifier.height(2.dp))
        Text(
            channel.lastLive,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
            style = MaterialTheme.typography.bodyMedium.copy(
                fontSize = 14.sp,
                lineHeight = 16.52.sp,
            ),
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(1.5.dp))
        Text(
            channel.category,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
            style = MaterialTheme.typography.bodyMedium.copy(
                fontSize = 13.sp,
                lineHeight = 14.95.sp,
            ),
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun OfflineCardSkeleton() {
    OfflineCardShell {
        Row(
            Modifier.fillMaxWidth().height(48.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SkeletonBox(Modifier.width(82.dp).height(18.dp))
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                SkeletonBox(Modifier.width(10.dp).height(18.dp))
            }
        }
    }
}

@Composable
private fun OfflineCardShell(content: @Composable () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val isDark = colors.background == Color.Black
    val shape = RoundedCornerShape(FlowRadius.Large)
    val shadowColor = Color.Black.copy(alpha = if (isDark) 0.20f else 0.05f)
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 12.dp,
                shape = shape,
                ambientColor = shadowColor,
                spotColor = shadowColor,
            ),
        color = colors.surface,
        shape = shape,
        border = BorderStroke(
            1.dp,
            colors.outlineVariant.copy(alpha = if (isDark) 0.14f else 0.42f),
        ),
    ) {
        Box(Modifier.padding(horizontal = 18.dp, vertical = 11.dp)) {
            content()
        }
    }
}
