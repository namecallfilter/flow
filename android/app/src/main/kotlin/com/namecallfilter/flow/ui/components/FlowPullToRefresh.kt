package com.namecallfilter.flow.ui.components

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.LocalOverscrollFactory
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

private const val PullResistance = 0.55f
private const val ReverseResistance = 0.9f
private val PullTriggerDistance = 96.dp
private val PullSettleEasing = CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f)
private const val RefreshStrokeHeadInterval = 0.33f
private const val RefreshPathDurationMs = 1333f
private const val RefreshRotationDurationMs = 2222f
private const val RefreshInitialPathPhase = 0.5f
private const val RefreshInitialRotationPhase =
    RefreshPathDurationMs / (2f * RefreshRotationDurationMs)

private fun LazyListState.hasDriftedFromTop(): Boolean =
    firstVisibleItemIndex != 0 || firstVisibleItemScrollOffset > 0

/**
 * Flow's original pull gesture: the list remains clamped while a standalone indicator travels
 * through the page chrome. Reversing direction cancels the refresh, even if the user pulls down
 * to the threshold again before lifting their finger.
 */
@Composable
fun FlowPullToRefresh(
    listState: LazyListState,
    indicatorStartTop: Dp,
    indicatorMaxTravel: Dp,
    onRefresh: suspend () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    val density = LocalDensity.current
    val triggerPx = with(density) { PullTriggerDistance.toPx() }
    val indicatorStartPx = with(density) { indicatorStartTop.toPx() }
    val indicatorTravelPx = with(density) { indicatorMaxTravel.toPx() }
    val latestRefresh by rememberUpdatedState(onRefresh)
    val refreshScope = rememberCoroutineScope()
    var pullExtentPx by remember { mutableFloatStateOf(0f) }
    var dragging by remember { mutableStateOf(false) }
    var refreshing by remember { mutableStateOf(false) }
    val displayedExtentPx by animateFloatAsState(
        targetValue = pullExtentPx,
        animationSpec = if (dragging) snap() else tween(150, easing = PullSettleEasing),
        label = "flow_pull_extent",
    )
    val displayedOpacity by animateFloatAsState(
        targetValue = if (pullExtentPx > 0f || refreshing) 1f else 0f,
        animationSpec = if (dragging) snap() else tween(150, easing = PullSettleEasing),
        label = "flow_pull_opacity",
    )

    val gestureModifier = Modifier.pointerInput(listState, triggerPx) {
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            var lastPosition = down.position
            var pulling = false
            var intercepting = false
            var reversed = false
            var blockingRefreshScroll = refreshing

            while (true) {
                // Observe before LazyColumn. Consume an active pull gesture and all movement while
                // the refresh callback is running so content cannot drift under the indicator.
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val change = event.changes.firstOrNull { it.id == down.id } ?: break
                val currentPosition = change.position
                val deltaY = currentPosition.y - lastPosition.y
                lastPosition = currentPosition

                if (!change.pressed) break

                val atTop = listState.firstVisibleItemIndex == 0 &&
                    listState.firstVisibleItemScrollOffset <= 1
                val shouldConsumeMovement = shouldConsumePullMovement(
                    refreshing = blockingRefreshScroll || refreshing,
                    intercepting = intercepting,
                    atTop = atTop,
                    deltaY = deltaY,
                )
                if (!shouldConsumeMovement) continue

                event.changes.forEach { it.consume() }
                if (blockingRefreshScroll || refreshing) {
                    // Keep the whole gesture blocked even when the request finishes before the
                    // finger lifts; handing a partially consumed drag back to LazyColumn jumps it.
                    blockingRefreshScroll = true
                    continue
                }

                intercepting = true
                if (deltaY < 0f) reversed = true
                val resistedDelta = deltaY * if (deltaY > 0f) PullResistance else ReverseResistance
                val nextExtent = (pullExtentPx + resistedDelta).coerceIn(0f, triggerPx)
                if (listState.hasDriftedFromTop()) listState.requestScrollToItem(0)
                pullExtentPx = nextExtent
                pulling = nextExtent > 0f
                dragging = pulling
                // Flutter stops treating the gesture as a pull as soon as the extent reaches
                // zero. The next upward movement can therefore scroll the list normally.
                if (!pulling) intercepting = false
            }

            if (refreshing) return@awaitEachGesture
            dragging = false
            val shouldRefresh = pulling && !reversed && pullExtentPx >= triggerPx
            if (shouldRefresh) {
                refreshScope.launch {
                    if (refreshing) return@launch
                    refreshing = true
                    pullExtentPx = triggerPx
                    if (listState.hasDriftedFromTop()) listState.requestScrollToItem(0)
                    try {
                        latestRefresh()
                    } finally {
                        refreshing = false
                        pullExtentPx = 0f
                    }
                }
            } else if (pullExtentPx > 0f) {
                pullExtentPx = 0f
            }
        }
    }

    val displayedProgress = (displayedExtentPx / triggerPx).coerceIn(0f, 1f)
    // Flutter replaces the determinate painter's value with zero as soon as collapse starts;
    // only AnimatedPositioned and AnimatedOpacity retain the prior visual state for 150ms.
    val painterProgress = (pullExtentPx / triggerPx).coerceIn(0f, 1f)
    Box(modifier.fillMaxSize().then(gestureModifier)) {
        CompositionLocalProvider(LocalOverscrollFactory provides null) {
            content()
        }
        if (
            painterProgress > 0f ||
            displayedProgress > 0f ||
            displayedOpacity > 0f ||
            refreshing
        ) {
            FlowRefreshIndicator(
                progress = painterProgress,
                refreshing = refreshing,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .offset {
                        IntOffset(
                            x = 0,
                            y = (indicatorStartPx + indicatorTravelPx * displayedProgress).roundToInt(),
                        )
                    }
                    .graphicsLayer { alpha = displayedOpacity },
            )
        }
    }
}

@Composable
private fun FlowRefreshIndicator(
    progress: Float,
    refreshing: Boolean,
    modifier: Modifier = Modifier,
) {
    // Flutter RefreshProgressIndicator: 4dp outer elevation margin, a 41dp material circle,
    // 12dp inner padding, and a 2.5dp square-capped stroke.
    Box(modifier.size(49.dp), contentAlignment = Alignment.Center) {
        Surface(
            modifier = Modifier.size(41.dp),
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surface,
            shadowElevation = 2.dp,
        ) {
            Box(Modifier.fillMaxSize().padding(12.dp), contentAlignment = Alignment.Center) {
                if (refreshing) {
                    IndeterminateRefreshArc(
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.fillMaxSize(),
                    )
                } else {
                    DeterminateRefreshArc(
                        progress = progress,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }
    }
}

/**
 * Port of Flutter's RefreshProgressIndicator painter. The progress value drives the first half of
 * Flutter's 1333ms material path, including its FastOutSlowIn arc growth and extra arrow rotation.
 */
@Composable
private fun DeterminateRefreshArc(
    progress: Float,
    color: Color,
    modifier: Modifier = Modifier,
) {
    val coercedProgress = progress.coerceIn(0f, 1f)
    Canvas(modifier) {
        val strokeWidth = 2.5.dp.toPx()
        val center = Offset(size.width / 2f, size.height / 2f)
        // Flutter paints against the entire 17dp CustomPaint bounds. With center stroke
        // alignment, its arc path radius is therefore 8.5dp (not inset by half the stroke).
        val radius = size.minDimension / 2f
        val converted = ((coercedProgress - 0.1f) /
            (RefreshStrokeHeadInterval - 0.1f)).coerceIn(0f, 1f)
        val arrowScale = converted
        val headValue = 1.05f * FastOutSlowInEasing.transform(converted)
        val epsilonDegrees = 0.001f * 180f / PI.toFloat()
        val sweepDegrees = max(epsilonDegrees, headValue * 270f)
        val underlyingRotationDegrees = converted * (
            45f +
                360f * RefreshInitialRotationPhase
            )
        val additionalRotationDegrees = if (coercedProgress <= RefreshStrokeHeadInterval) {
            -18f - (18f * coercedProgress / RefreshStrokeHeadInterval)
        } else {
            -36f + (279f * (coercedProgress - RefreshStrokeHeadInterval) /
                (1f - RefreshStrokeHeadInterval))
        }
        val startDegrees = -90f + underlyingRotationDegrees + additionalRotationDegrees
        val diameter = radius * 2f

        drawArc(
            color = color,
            startAngle = startDegrees,
            sweepAngle = sweepDegrees,
            useCenter = false,
            topLeft = Offset(center.x - radius, center.y - radius),
            size = Size(diameter, diameter),
            style = Stroke(width = strokeWidth, cap = StrokeCap.Square),
        )

        if (arrowScale > 0f) {
            val arcEndRadians = (startDegrees + sweepDegrees) * (PI.toFloat() / 180f)
            val unitX = cos(arcEndRadians.toDouble()).toFloat()
            val unitY = sin(arcEndRadians.toDouble()).toFloat()
            val arrowRadius = strokeWidth * 2f * arrowScale
            val arrowPoint = Offset(
                x = center.x + unitX * radius - unitY * strokeWidth * 2f * arrowScale,
                y = center.y + unitY * radius + unitX * strokeWidth * 2f * arrowScale,
            )
            val arrow = Path().apply {
                moveTo(
                    center.x + unitX * (radius - arrowRadius),
                    center.y + unitY * (radius - arrowRadius),
                )
                lineTo(
                    center.x + unitX * (radius + arrowRadius),
                    center.y + unitY * (radius + arrowRadius),
                )
                lineTo(arrowPoint.x, arrowPoint.y)
                close()
            }
            drawPath(path = arrow, color = color)
        }
    }
}

@Composable
private fun IndeterminateRefreshArc(
    color: Color,
    modifier: Modifier = Modifier,
) {
    val pathPhase: Float
    val rotationPhase: Float
    if (LocalFlowVisualsActive.current) {
        val transition = rememberInfiniteTransition(label = "flow_refresh_spinner")
        val animatedPathPhase by transition.animateFloat(
            initialValue = RefreshInitialPathPhase,
            targetValue = RefreshInitialPathPhase + 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(RefreshPathDurationMs.toInt(), easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "flow_refresh_path_phase",
        )
        val animatedRotationPhase by transition.animateFloat(
            initialValue = RefreshInitialRotationPhase,
            targetValue = RefreshInitialRotationPhase + 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(RefreshRotationDurationMs.toInt(), easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "flow_refresh_rotation_phase",
        )
        pathPhase = animatedPathPhase
        rotationPhase = animatedRotationPhase
    } else {
        pathPhase = RefreshInitialPathPhase
        rotationPhase = RefreshInitialRotationPhase
    }
    Canvas(modifier) {
        val path = pathPhase % 1f
        val head = if (path <= 0.5f) {
            FastOutSlowInEasing.transform(path / 0.5f)
        } else {
            1f
        }
        val tail = if (path <= 0.5f) {
            0f
        } else {
            FastOutSlowInEasing.transform((path - 0.5f) / 0.5f)
        }
        val headValue = 1.05f * head
        val strokeWidth = 2.5.dp.toPx()
        val center = Offset(size.width / 2f, size.height / 2f)
        val radius = size.minDimension / 2f
        val startDegrees = -90f +
            tail * 270f +
            (rotationPhase % 1f) * 360f +
            path * 90f +
            243f
        val epsilonDegrees = 0.001f * 180f / PI.toFloat()
        val sweepDegrees = max(epsilonDegrees, (headValue - tail) * 270f)
        drawArc(
            color = color,
            startAngle = startDegrees,
            sweepAngle = sweepDegrees,
            useCenter = false,
            topLeft = Offset(center.x - radius, center.y - radius),
            size = Size(radius * 2f, radius * 2f),
            style = Stroke(width = strokeWidth, cap = StrokeCap.Square),
        )
    }
}
