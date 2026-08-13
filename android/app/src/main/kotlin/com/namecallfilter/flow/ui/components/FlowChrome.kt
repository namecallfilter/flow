package com.namecallfilter.flow.ui.components

import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.absolutePadding
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyLayoutScrollScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Explore as FilledExplore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LiveTv as FilledLiveTv
import androidx.compose.material.icons.filled.Settings as FilledSettings
import androidx.compose.material.icons.outlined.Explore as OutlinedExplore
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LiveTv as OutlinedLiveTv
import androidx.compose.material.icons.outlined.Settings as OutlinedSettings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RenderEffect
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.namecallfilter.flow.ui.navigation.FlowTab
import com.namecallfilter.flow.ui.theme.FlowColors
import com.namecallfilter.flow.ui.theme.FlowRadius
import com.namecallfilter.flow.ui.theme.FlowSpacing
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

private val FlowEaseOutCubic = CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f)
// Flutter's strongest chrome stop is 50%. Apply it uniformly so neither bar fades to a more
// transparent edge while retaining the same frosted material strength as the reference app.
internal const val FlowChromeTintAlpha = 0.50f

internal fun resolveFlowChromeColor(background: Color): Color =
    (if (background == Color.Black) FlowColors.DarkChrome else background)
        .copy(alpha = FlowChromeTintAlpha)

private val ScrollDistanceMapSaver = Saver<MutableMap<String, Float>, Bundle>(
    save = { distances ->
        Bundle().apply {
            distances.forEach { (key, distance) -> putFloat(key, distance) }
        }
    },
    restore = { saved ->
        saved.keySet().associateWithTo(mutableMapOf()) { key -> saved.getFloat(key) }
    },
)

/** Records this composable so translucent chrome can redraw and blur what is physically behind it. */
fun Modifier.captureFlowBackdrop(layer: GraphicsLayer): Modifier = drawWithContent {
    layer.record {
        this@drawWithContent.drawContent()
    }
    drawLayer(layer)
}

private fun Modifier.flowBackdropBlur(
    source: GraphicsLayer?,
    blurred: GraphicsLayer,
    radiusPx: Float,
    sourceOffsetY: () -> Float = { 0f },
): Modifier = drawWithContent {
    if (source != null && source.size.width > 0 && source.size.height > 0) {
        // BackdropFilter only needs pixels near the chrome. Recording the old full-screen source
        // into another full-screen blur layer for both bars cost tens of MiB and repeated all draw
        // commands on every scroll frame. Keep enough overscan for the blur kernel, but crop the
        // intermediate layer to the visible chrome bounds.
        val overscan = ceil(radiusPx * 2f).toInt().coerceAtLeast(1)
        val layerSize = IntSize(
            width = size.width.roundToInt() + overscan * 2,
            height = size.height.roundToInt() + overscan * 2,
        )
        blurred.record(this, layoutDirection, layerSize) {
            withTransform({
                translate(
                    left = overscan.toFloat(),
                    top = overscan - sourceOffsetY(),
                )
            }) {
                drawLayer(source)
            }
        }
        withTransform({ translate(-overscan.toFloat(), -overscan.toFloat()) }) {
            drawLayer(blurred)
        }
    }
    drawContent()
}

private fun Modifier.flowChromeHeight(
    statusBarHeightPx: Int,
    minimumVisibleHeaderPx: Int,
    headerHeightPx: () -> Int,
    headerOffsetPx: () -> Float,
): Modifier = layout { measurable, constraints ->
    val preferredHeight = statusBarHeightPx +
        (headerHeightPx() + headerOffsetPx()).coerceAtLeast(0f).roundToInt()
    val height = max(statusBarHeightPx + minimumVisibleHeaderPx, preferredHeight)
        .coerceIn(constraints.minHeight, constraints.maxHeight)
    val placeable = measurable.measure(
        constraints.copy(minHeight = height, maxHeight = height),
    )
    layout(placeable.width, height) { placeable.placeRelative(0, 0) }
}

@Composable
fun ScrollReactiveChrome(
    listState: LazyListState,
    header: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    scrollStateKey: String = "default",
    onFooterHiddenChange: (Boolean) -> Unit = {},
    content: @Composable BoxScope.() -> Unit,
) {
    // Flutter keeps one chrome state while Browse swaps the attached ScrollController. Preserve
    // the header/footer latch across Compose LazyListState swaps for the same behavior.
    val headerHeightPx = remember { mutableIntStateOf(0) }
    val headerOffsetPx = remember { mutableFloatStateOf(0f) }
    var savedHeaderHiddenFraction by rememberSaveable {
        mutableFloatStateOf(0f)
    }
    var footerHidden by remember { mutableStateOf(false) }
    val density = LocalDensity.current
    val context = LocalContext.current
    val layoutDirection = LocalLayoutDirection.current
    val safeDrawingPadding = WindowInsets.safeDrawing.asPaddingValues()
    val visualsActive = LocalFlowVisualsActive.current
    val scope = key(listState, scrollStateKey, visualsActive) { rememberCoroutineScope() }
    val statusBarHeight = safeDrawingPadding.calculateTopPadding()
    val safeLeft = safeDrawingPadding.calculateLeftPadding(layoutDirection)
    val safeRight = safeDrawingPadding.calculateRightPadding(layoutDirection)
    val statusBarHeightPx = with(density) { statusBarHeight.roundToPx() }
    val contentBackdrop = rememberGraphicsLayer()
    val headerBackdrop = rememberGraphicsLayer()
    val headerBlurRadiusPx = with(density) { 14.dp.toPx() }
    val headerBlurEffect: RenderEffect? = remember(headerBlurRadiusPx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            BlurEffect(headerBlurRadiusPx, headerBlurRadiusPx, TileMode.Clamp)
        } else {
            null
        }
    }
    SideEffect { headerBackdrop.renderEffect = headerBlurEffect }
    val currentFooterHiddenChange by rememberUpdatedState(onFooterHiddenChange)
    val showTopThresholdPx = with(density) { 600.dp.toPx() }
    val hideTopThresholdPx = with(density) { 80.dp.toPx() }
    val animationsDisabled = remember(context) {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) == 0f || Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.TRANSITION_ANIMATION_SCALE,
            1f,
        ) == 0f
    }
    val retainedScrollDistances = rememberSaveable(saver = ScrollDistanceMapSaver) {
        mutableMapOf()
    }
    var scrollDistancePx by remember(listState, scrollStateKey) {
        val initialDistance = retainedScrollDistances[scrollStateKey] ?: when {
            listState.firstVisibleItemIndex == 0 -> listState.firstVisibleItemScrollOffset.toFloat()
            // The list restores its item index/offset saveably, but an exact aggregate pixel
            // distance is unavailable for a deep item. Keep Top visible until item zero gives us
            // an exact distance instead of hiding it while the list is still far down.
            else -> Float.POSITIVE_INFINITY
        }
        mutableFloatStateOf(initialDistance)
    }
    // The Flutter ValueNotifier survives a controller swap, including its 80/600 hysteresis.
    var showTop by rememberSaveable { mutableStateOf(false) }

    fun setScrollDistance(value: Float) {
        scrollDistancePx = value.coerceAtLeast(0f)
        retainedScrollDistances[scrollStateKey] = scrollDistancePx
    }

    fun updateFooter() {
        if (headerHeightPx.intValue <= 0) return
        val hiddenFraction = (-headerOffsetPx.floatValue / headerHeightPx.intValue).coerceIn(0f, 1f)
        val next = when {
            !footerHidden && hiddenFraction >= 0.52f -> true
            footerHidden && hiddenFraction <= 0.48f -> false
            else -> footerHidden
        }
        footerHidden = next
        // Flutter emits header progress on every scroll update. Re-emitting the latch lets
        // navigation reveal the footer, then lets this route hide it again only on a new scroll.
        currentFooterHiddenChange(next)
    }

    fun updateScrollToTopVisibility() {
        showTop = if (showTop) {
            scrollDistancePx > hideTopThresholdPx
        } else {
            scrollDistancePx >= showTopThresholdPx
        }
    }

    val nestedScrollConnection = remember(listState, showTopThresholdPx, hideTopThresholdPx) {
        object : NestedScrollConnection {
            override fun onPostScroll(
                consumed: Offset,
                available: Offset,
                source: NestedScrollSource,
            ): Offset {
                if (consumed.y == 0f) return Offset.Zero
                val atTop = listState.firstVisibleItemIndex == 0 &&
                    listState.firstVisibleItemScrollOffset == 0
                if (atTop) {
                    if (headerOffsetPx.floatValue != 0f) {
                        headerOffsetPx.floatValue = 0f
                        savedHeaderHiddenFraction = 0f
                    }
                } else {
                    headerOffsetPx.floatValue = (headerOffsetPx.floatValue + consumed.y)
                        .coerceIn(-headerHeightPx.intValue.toFloat(), 0f)
                    if (headerHeightPx.intValue > 0) {
                        savedHeaderHiddenFraction =
                            (-headerOffsetPx.floatValue / headerHeightPx.intValue).coerceIn(0f, 1f)
                    }
                }
                setScrollDistance(scrollDistancePx - consumed.y)
                updateFooter()
                updateScrollToTopVisibility()
                return Offset.Zero
            }
        }
    }

    LaunchedEffect(listState, scrollStateKey, visualsActive) {
        if (!visualsActive) return@LaunchedEffect
        updateScrollToTopVisibility()
        snapshotFlow { listState.firstVisibleItemIndex to listState.firstVisibleItemScrollOffset }
            .distinctUntilChanged()
            .collect { (index, offset) ->
                if (index == 0) {
                    if (offset == 0 && headerOffsetPx.floatValue != 0f) {
                        headerOffsetPx.floatValue = 0f
                        savedHeaderHiddenFraction = 0f
                        updateFooter()
                    }
                    val exactDistance = offset.toFloat()
                    if (scrollDistancePx != exactDistance) {
                        setScrollDistance(exactDistance)
                        updateScrollToTopVisibility()
                    }
                }
            }
    }

    val chromeColor = resolveFlowChromeColor(MaterialTheme.colorScheme.background)
    Box(modifier.fillMaxSize().nestedScroll(nestedScrollConnection)) {
        Box(
            Modifier
                .fillMaxSize()
                .captureFlowBackdrop(contentBackdrop)
                .absolutePadding(left = safeLeft, right = safeRight),
        ) {
            content()
        }
        Box(
            Modifier
                .fillMaxWidth()
                .flowChromeHeight(
                    statusBarHeightPx = statusBarHeightPx,
                    minimumVisibleHeaderPx = with(density) { 6.dp.roundToPx() },
                    headerHeightPx = { headerHeightPx.intValue },
                    headerOffsetPx = { headerOffsetPx.floatValue },
                )
                .clipToBounds()
                .flowBackdropBlur(
                    source = contentBackdrop,
                    blurred = headerBackdrop,
                    radiusPx = headerBlurRadiusPx,
                )
                .drawWithContent {
                    drawContent()
                    drawRect(chromeColor)
                },
        )
        Box(
            Modifier
                .fillMaxWidth()
                .padding(top = statusBarHeight)
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .absolutePadding(left = safeLeft, right = safeRight)
                    .clipToBounds()
                    .onSizeChanged { size ->
                        if (size.height != headerHeightPx.intValue) {
                            val hiddenFraction = if (headerHeightPx.intValue > 0) {
                                (-headerOffsetPx.floatValue / headerHeightPx.intValue).coerceIn(0f, 1f)
                            } else {
                                savedHeaderHiddenFraction
                            }
                            headerHeightPx.intValue = size.height
                            headerOffsetPx.floatValue = -size.height * hiddenFraction
                            savedHeaderHiddenFraction = hiddenFraction
                            updateFooter()
                        }
                    },
            ) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .offset { IntOffset(0, headerOffsetPx.floatValue.roundToInt()) },
                ) {
                    header()
                }
            }
        }
        if (showTop) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter)
                    .offset {
                        IntOffset(
                            x = 0,
                            y = statusBarHeightPx +
                                (headerHeightPx.intValue + headerOffsetPx.floatValue)
                                    .coerceAtLeast(0f)
                                    .roundToInt() +
                                with(density) { FlowSpacing.Md.roundToPx() },
                        )
                    },
                contentAlignment = Alignment.Center,
            ) {
                FlowTooltipAction(
                    label = "Scroll to top",
                    onClick = {
                        scope.launch {
                            listState.scroll {
                                val lazyScrollScope = LazyLayoutScrollScope(listState, this)
                                with(lazyScrollScope) {
                                    if (animationsDisabled) {
                                        snapToItem(0, 0)
                                        headerOffsetPx.floatValue = 0f
                                        savedHeaderHiddenFraction = 0f
                                        setScrollDistance(0f)
                                        updateFooter()
                                        updateScrollToTopVisibility()
                                        return@with
                                    }
                                    val distance = calculateDistanceTo(0).toFloat()
                                    var previousValue = 0f
                                    animate(
                                        initialValue = 0f,
                                        targetValue = distance,
                                        animationSpec = tween(
                                            durationMillis = 320,
                                            easing = FlowEaseOutCubic,
                                        ),
                                    ) { currentValue, _ ->
                                        val consumedScroll = scrollBy(currentValue - previousValue)
                                        previousValue += consumedScroll
                                        headerOffsetPx.floatValue =
                                            (headerOffsetPx.floatValue - consumedScroll)
                                                .coerceIn(-headerHeightPx.intValue.toFloat(), 0f)
                                        if (headerHeightPx.intValue > 0) {
                                            savedHeaderHiddenFraction =
                                                (-headerOffsetPx.floatValue / headerHeightPx.intValue)
                                                    .coerceIn(0f, 1f)
                                        }
                                        setScrollDistance(scrollDistancePx + consumedScroll)
                                        updateFooter()
                                        updateScrollToTopVisibility()
                                    }
                                    snapToItem(0, 0)
                                    headerOffsetPx.floatValue = 0f
                                    savedHeaderHiddenFraction = 0f
                                    setScrollDistance(0f)
                                    updateFooter()
                                    updateScrollToTopVisibility()
                                }
                            }
                        }
                    },
                    modifier = Modifier.shadow(
                        elevation = 3.dp,
                        shape = CircleShape,
                        ambientColor = Color.Black.copy(alpha = 0.24f),
                        spotColor = Color.Black.copy(alpha = 0.24f),
                    ),
                ) {
                    Surface(
                        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
                        contentColor = MaterialTheme.colorScheme.onSurface,
                        shape = CircleShape,
                        border = BorderStroke(
                            1.dp,
                            MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                        ),
                        shadowElevation = 0.dp,
                    ) {
                        Row(
                            modifier = Modifier.height(48.dp).padding(horizontal = FlowSpacing.Md),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Default.ArrowUpward,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                            )
                            Spacer(Modifier.width(FlowSpacing.Xs))
                            Text(
                                text = "Top",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.ExtraBold,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun FlowBottomBar(
    currentTab: FlowTab,
    hidden: Boolean,
    showLiveChannels: Boolean,
    onSelect: (FlowTab) -> Unit,
    modifier: Modifier = Modifier,
    backdropLayer: GraphicsLayer? = null,
) {
    val safeDrawingPadding = WindowInsets.safeDrawing.asPaddingValues()
    val layoutDirection = LocalLayoutDirection.current
    val navigationInset = safeDrawingPadding.calculateBottomPadding()
    val safeLeft = safeDrawingPadding.calculateLeftPadding(layoutDirection)
    val safeRight = safeDrawingPadding.calculateRightPadding(layoutDirection)
    val totalHeight = 60.dp + navigationInset
    val offset = animateDpAsState(
        targetValue = if (hidden) totalHeight else 0.dp,
        animationSpec = tween(180, easing = FlowEaseOutCubic),
        label = "flow_bottom_bar_offset",
    )
    val fullyHidden by remember(offset, totalHeight) {
        derivedStateOf { offset.value >= totalHeight - 0.5.dp }
    }
    val density = LocalDensity.current
    val blurredBackdrop = rememberGraphicsLayer()
    val bottomBlurRadiusPx = with(density) { 18.dp.toPx() }
    val bottomBlurEffect: RenderEffect? = remember(bottomBlurRadiusPx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            BlurEffect(bottomBlurRadiusPx, bottomBlurRadiusPx, TileMode.Clamp)
        } else {
            null
        }
    }
    SideEffect { blurredBackdrop.renderEffect = bottomBlurEffect }
    var positionInRootY by remember { mutableFloatStateOf(0f) }
    val chromeColor = resolveFlowChromeColor(MaterialTheme.colorScheme.background)
    val topBorderColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.32f)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .then(if (fullyHidden) Modifier.clearAndSetSemantics { } else Modifier)
            .offset { IntOffset(0, offset.value.roundToPx()) }
            .onGloballyPositioned { coordinates ->
                positionInRootY = coordinates.positionInRoot().y
            }
            .clipToBounds()
            .flowBackdropBlur(
                source = backdropLayer,
                blurred = blurredBackdrop,
                radiusPx = bottomBlurRadiusPx,
                sourceOffsetY = { positionInRootY },
            )
            .background(chromeColor)
            .drawWithContent {
                drawContent()
                val borderWidth = 0.5.dp.toPx()
                drawLine(
                    color = topBorderColor,
                    start = Offset(0f, borderWidth / 2f),
                    end = Offset(size.width, borderWidth / 2f),
                    strokeWidth = borderWidth,
                )
            },
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .height(60.dp)
                .absolutePadding(left = safeLeft, right = safeRight),
        ) {
            BottomBarItem(
                label = if (showLiveChannels) "Live Channels" else "Following",
                selected = currentTab == FlowTab.FOLLOWING,
                selectedIcon = if (showLiveChannels) Icons.Filled.FilledLiveTv else Icons.Default.Favorite,
                unselectedIcon = if (showLiveChannels) Icons.Outlined.OutlinedLiveTv
                    else Icons.Outlined.FavoriteBorder,
                onClick = { onSelect(FlowTab.FOLLOWING) },
                modifier = Modifier.weight(1f),
            )
            BottomBarItem(
                label = "Browse",
                selected = currentTab == FlowTab.BROWSE,
                selectedIcon = Icons.Filled.FilledExplore,
                unselectedIcon = Icons.Outlined.OutlinedExplore,
                onClick = { onSelect(FlowTab.BROWSE) },
                modifier = Modifier.weight(1f),
            )
            BottomBarItem(
                label = "Settings",
                selected = currentTab == FlowTab.SETTINGS,
                selectedIcon = Icons.Filled.FilledSettings,
                unselectedIcon = Icons.Outlined.OutlinedSettings,
                onClick = { onSelect(FlowTab.SETTINGS) },
                modifier = Modifier.weight(1f),
            )
        }
        Spacer(Modifier.height(navigationInset))
    }
}

@Composable
private fun BottomBarItem(
    label: String,
    selected: Boolean,
    selectedIcon: ImageVector,
    unselectedIcon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val color = if (selected) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.onSurface.copy(alpha = 0.54f)
    }
    Column(
        modifier = modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(FlowRadius.Medium))
            .clickable(role = Role.Button, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                // Compose maps selected + Button to checkable/checked, which TalkBack announces as
                // a toggle. Flutter announces "Selected, Button". An explicit state description
                // preserves that spoken UX while retaining Button role and activation semantics.
                if (selected) stateDescription = "Selected"
                this.onClick {
                    onClick()
                    true
                }
            },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(12.dp))
        Icon(
            imageVector = if (selected) selectedIcon else unselectedIcon,
            contentDescription = null,
            modifier = Modifier.size(25.dp),
            tint = color,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = label,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = color,
            style = MaterialTheme.typography.bodyMedium.copy(
                fontSize = 13.sp,
                lineHeight = 18.59.sp,
                fontWeight = if (selected) FontWeight.ExtraBold else FontWeight.SemiBold,
            ),
        )
    }
}
