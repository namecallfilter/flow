package com.namecallfilter.flow.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipAnchorPosition
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.namecallfilter.flow.data.StreamChannel
import com.namecallfilter.flow.ui.theme.FlowColors
import com.namecallfilter.flow.ui.theme.FlowRadius
import com.namecallfilter.flow.ui.theme.FlowSpacing
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.math.max

internal const val FlowTooltipDurationMillis = 2_000L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FlowTooltip(
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val tooltipState = rememberTooltipState(isPersistent = true)
    LaunchedEffect(tooltipState.isVisible) {
        if (tooltipState.isVisible) {
            delay(FlowTooltipDurationMillis)
            tooltipState.dismiss()
        }
    }
    TooltipBox(
        positionProvider = TooltipDefaults.rememberTooltipPositionProvider(
            TooltipAnchorPosition.Below,
        ),
        tooltip = {
            val shape = RoundedCornerShape(12.dp)
            Surface(
                shape = shape,
                color = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                border = androidx.compose.foundation.BorderStroke(
                    0.5.dp,
                    MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                ),
                tonalElevation = 0.dp,
                shadowElevation = 0.dp,
            ) {
                Text(
                    text = label,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    color = MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        },
        state = tooltipState,
        modifier = modifier,
        enableUserInput = enabled,
        content = content,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FlowTooltipAction(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tooltipModifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val platformViewConfiguration = LocalViewConfiguration.current
    val exactViewConfiguration = remember(platformViewConfiguration) {
        object : ViewConfiguration by platformViewConfiguration {
            override val minimumTouchTargetSize: DpSize = DpSize.Zero
        }
    }
    val tooltipState = rememberTooltipState(isPersistent = true)
    val tooltipScope = rememberCoroutineScope()
    var suppressClickAfterTooltip by remember { mutableStateOf(false) }
    LaunchedEffect(tooltipState.isVisible) {
        if (tooltipState.isVisible) {
            delay(FlowTooltipDurationMillis)
            tooltipState.dismiss()
        }
    }
    val showTooltip = {
        tooltipScope.launch { tooltipState.show() }
        Unit
    }
    CompositionLocalProvider(LocalViewConfiguration provides exactViewConfiguration) {
        TooltipBox(
            positionProvider = TooltipDefaults.rememberTooltipPositionProvider(
                TooltipAnchorPosition.Below,
            ),
            tooltip = { FlowTooltipSurface(label) },
            state = tooltipState,
            modifier = tooltipModifier,
            // Owning the gesture here avoids TooltipBox exposing a second, empty
            // long-click accessibility node around the actual button.
            enableUserInput = false,
        ) {
            val tooltipGestureModifier = Modifier.pointerInput(label, enabled) {
                awaitEachGesture {
                    val down = awaitFirstDown(
                        requireUnconsumed = false,
                        pass = PointerEventPass.Initial,
                    )
                    val releasedBeforeLongPress = withTimeoutOrNull(
                        viewConfiguration.longPressTimeoutMillis,
                    ) {
                        while (true) {
                            val change = awaitPointerEvent(PointerEventPass.Final)
                                .changes
                                .firstOrNull { it.id == down.id }
                            if (change == null || !change.pressed) break
                        }
                        true
                    } ?: false
                    if (!releasedBeforeLongPress) {
                        if (enabled) suppressClickAfterTooltip = true
                        showTooltip()
                        while (true) {
                            val change = awaitPointerEvent(PointerEventPass.Final)
                                .changes
                                .firstOrNull { it.id == down.id }
                            if (change == null || !change.pressed) break
                        }
                    }
                }
            }
            Box(
                modifier = modifier
                    .clip(CircleShape)
                    .then(tooltipGestureModifier)
                    .clickable(
                        enabled = enabled,
                        role = Role.Button,
                        onClick = {
                            if (suppressClickAfterTooltip) {
                                suppressClickAfterTooltip = false
                            } else {
                                onClick()
                            }
                        },
                    )
                    .clearAndSetSemantics {
                        contentDescription = label
                        role = Role.Button
                        if (enabled) {
                            this.onClick {
                                onClick()
                                true
                            }
                        } else {
                            disabled()
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                content()
            }
        }
    }
}

@Composable
private fun FlowTooltipSurface(label: String) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface,
        border = androidx.compose.foundation.BorderStroke(
            0.5.dp,
            MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
        ),
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
fun PageHeaderTitle(
    title: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier.height(32.dp),
        contentAlignment = Alignment.TopStart,
    ) {
        Text(
            text = title,
            modifier = Modifier
                .height(32.dp)
                .clearAndSetSemantics { contentDescription = title }
                .wrapContentHeight(
                    align = Alignment.Top,
                    unbounded = true,
                )
                .drawWithContent {
                    translate(top = (-2.5).dp.toPx()) {
                        this@drawWithContent.drawContent()
                    }
                },
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.displaySmall.copy(
                fontSize = 32.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                platformStyle = PlatformTextStyle(includeFontPadding = false),
            ),
        )
    }
}

@Composable
fun BackPageHeader(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    action: (@Composable () -> Unit)? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth().padding(
            start = FlowSpacing.Lg,
            top = FlowSpacing.Lg,
            end = FlowSpacing.Lg,
            bottom = 16.5.dp,
        ),
        verticalAlignment = Alignment.Top,
    ) {
        FlowTooltipAction(
            label = "Back",
            onClick = onBack,
            modifier = Modifier.size(width = 40.dp, height = 32.dp),
        ) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.CenterStart,
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
        Spacer(Modifier.width(FlowSpacing.Xs))
        PageHeaderTitle(title, Modifier.weight(1f))
        if (action != null) action()
    }
}

@Composable
fun FlowSearchTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "Search channels or categories",
    readOnly: Boolean = false,
    onClear: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val focused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(50.dp)
    TextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.height(48.dp).border(
            width = 1.5.dp,
            color = if (focused) MaterialTheme.colorScheme.primary.copy(alpha = 0.8f) else Color.Transparent,
            shape = shape,
        ),
        singleLine = true,
        readOnly = readOnly,
        interactionSource = interactionSource,
        shape = shape,
        placeholder = { Text(placeholder, maxLines = 1) },
        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
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
        } else null,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = MaterialTheme.colorScheme.surface,
            unfocusedContainerColor = MaterialTheme.colorScheme.surface,
            disabledContainerColor = MaterialTheme.colorScheme.surface,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
    )
}

@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    expanded: Boolean? = null,
    onToggle: (() -> Unit)? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.headlineSmall.copy(
                fontSize = 24.sp,
                lineHeight = 31.92.sp,
                fontWeight = FontWeight.ExtraBold,
            ),
        )
    if (expanded != null && onToggle != null) {
            val rotation by animateFloatAsState(
                targetValue = if (expanded) 0f else -90f,
                animationSpec = tween(durationMillis = 180, easing = LinearEasing),
                label = "flow_section_rotation",
            )
            val tooltip = if (expanded) "Collapse $title" else "Expand $title"
            FlowTooltipAction(
                label = tooltip,
                onClick = onToggle,
                modifier = Modifier.size(48.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.ExpandMore,
                    contentDescription = null,
                    modifier = Modifier.graphicsRotation(rotation),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                )
            }
        }
    }
}

private fun Modifier.graphicsRotation(degrees: Float): Modifier =
    graphicsLayer(rotationZ = degrees)

@Composable
fun AvatarRing(
    initials: String,
    colors: List<Int>,
    modifier: Modifier = Modifier,
    imageUrl: String? = null,
    size: Dp = 42.dp,
    isLive: Boolean = false,
    statusColor: Color? = null,
) {
    val surface = MaterialTheme.colorScheme.background
    val initialsSize = with(LocalDensity.current) { (size * 0.28f).toSp() }
    Box(modifier = modifier.size(size)) {
        val ringModifier = if (isLive) {
            Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        listOf(MaterialTheme.colorScheme.tertiary, MaterialTheme.colorScheme.primary),
                    ),
                    CircleShape,
                )
                .padding(3.dp)
        } else {
            Modifier.fillMaxSize()
        }
        var imageFailed by remember(imageUrl) { mutableStateOf(false) }
        Box(modifier = ringModifier.clip(CircleShape)) {
            if (imageUrl.isNullOrBlank() || imageFailed) {
                GradientImageFallback(
                    initials = initials,
                    colors = colors,
                    initialsFontSize = initialsSize,
                )
            } else {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    filterQuality = FilterQuality.High,
                    modifier = Modifier.fillMaxSize(),
                    onError = { imageFailed = true },
                )
            }
        }
        if (statusColor != null) {
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = 1.dp, y = 1.dp)
                    .size(size * 0.24f)
                    .background(statusColor, CircleShape)
                    .border(2.dp, surface, CircleShape),
            )
        }
    }
}

@Composable
fun GradientImageFallback(
    colors: List<Int>,
    modifier: Modifier = Modifier,
    initials: String? = null,
    diagonalPattern: Boolean = false,
    streamPattern: Boolean = false,
    initialsFontSize: androidx.compose.ui.unit.TextUnit = androidx.compose.ui.unit.TextUnit.Unspecified,
) {
    val gradient = colors.ifEmpty { listOf(0xFF4B286D.toInt(), 0xFFAD5FC7.toInt()) }
        .map(::Color)
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.linearGradient(gradient)),
        contentAlignment = Alignment.Center,
    ) {
        if (diagonalPattern) {
            Canvas(Modifier.fillMaxSize()) {
                if (streamPattern) {
                    var x = -size.width
                    while (x < size.width * 1.5f) {
                        drawLine(
                            color = Color.White.copy(alpha = 0.16f),
                            start = Offset(x, 0f),
                            end = Offset(x + size.height, size.height),
                            strokeWidth = 1.2.dp.toPx(),
                        )
                        x += 18.dp.toPx()
                    }
                } else {
                    var x = -size.height
                    while (x < size.width * 1.7f) {
                        drawLine(
                            color = Color.White.copy(alpha = 0.16f),
                            start = Offset(x, size.height),
                            end = Offset(x + size.height, 0f),
                            strokeWidth = 1.1.dp.toPx(),
                        )
                        x += 16.dp.toPx()
                    }
                }
            }
        }
        if (!initials.isNullOrEmpty()) {
            Text(
                text = initials,
                color = Color.White,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontSize = initialsFontSize,
                    lineHeight = initialsFontSize * 1.43f,
                    fontWeight = FontWeight.Black,
                ),
            )
        }
    }
}

@Composable
fun RemoteThumbnail(
    imageUrl: String?,
    colors: List<Int>,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    streamPattern: Boolean = false,
) {
    var imageFailed by remember(imageUrl) { mutableStateOf(false) }
    val showFallback = imageUrl.isNullOrBlank() || imageFailed

    Box(modifier) {
        if (showFallback) {
            GradientImageFallback(
                colors = colors,
                diagonalPattern = true,
                streamPattern = streamPattern,
            )
        } else {
            AsyncImage(
                model = imageUrl,
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
fun StreamCard(
    channel: StreamChannel,
    onOpenStream: () -> Unit,
    onOpenChannel: () -> Unit,
    modifier: Modifier = Modifier,
    showCategory: Boolean = true,
    onOpenCategory: (() -> Unit)? = null,
) {
    val colors = MaterialTheme.colorScheme
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = 7.dp)
            .clickable(onClick = onOpenStream),
        color = colors.surface,
        shape = RoundedCornerShape(FlowRadius.Card),
        border = androidx.compose.foundation.BorderStroke(
            0.8.dp,
            colors.outlineVariant.copy(alpha = if (colors.background == Color.Black) 0.14f else 0.34f),
        ),
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 86.dp)
                .padding(horizontal = FlowSpacing.Sm, vertical = 6.dp),
        ) {
            val thumbnailWidth = if (maxWidth < 350.dp) 116.dp else 124.dp
            Row(
                modifier = Modifier.fillMaxWidth().heightIn(min = 74.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
            Box(
                modifier = Modifier
                    .width(thumbnailWidth)
                    .aspectRatio(16f / 9f)
                    .clip(RoundedCornerShape(FlowRadius.Small)),
            ) {
                RemoteThumbnail(
                    imageUrl = channel.thumbnailUrl,
                    colors = channel.thumbnailColors,
                    modifier = Modifier.fillMaxSize(),
                    contentDescription = null,
                    streamPattern = true,
                )
                ViewerBadge(
                    viewers = channel.viewers,
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(start = 6.dp, bottom = 3.dp),
                )
            }
            Spacer(Modifier.width(FlowSpacing.Md))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.Center) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AvatarRing(
                        initials = channel.initials,
                        colors = channel.avatarColors,
                        imageUrl = channel.avatarImageUrl,
                        size = 28.dp,
                        modifier = Modifier.clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            onClick = onOpenChannel,
                        ),
                    )
                    Spacer(Modifier.width(FlowSpacing.Sm))
                    Text(
                        text = channel.name,
                        modifier = Modifier
                            .weight(1f, fill = false)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = onOpenChannel,
                            ),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = colors.onSurface,
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontSize = 16.sp,
                            lineHeight = 17.6.sp,
                            fontWeight = FontWeight.ExtraBold,
                        ),
                    )
                    Spacer(Modifier.width(5.dp))
                    Icon(
                        imageVector = Icons.Default.Verified,
                        contentDescription = null,
                        modifier = Modifier
                            .size(14.dp)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = onOpenChannel,
                            ),
                        tint = colors.primary.copy(
                            alpha = if (colors.background == Color.Black) 0.72f else 0.66f,
                        ),
                    )
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    text = channel.title,
                    maxLines = if (showCategory) 1 else 2,
                    minLines = if (showCategory) 1 else 2,
                    overflow = TextOverflow.Ellipsis,
                    color = colors.onSurface.copy(alpha = 0.86f),
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontSize = 14.sp,
                        lineHeight = 16.52.sp,
                        fontWeight = FontWeight.Medium,
                    ),
                )
                if (showCategory) {
                    Spacer(Modifier.height(5.dp))
                    val openCategory = onOpenCategory
                    Text(
                        text = channel.category,
                        modifier = Modifier
                            .clickable(enabled = openCategory != null) { openCategory?.invoke() }
                            .clearAndSetSemantics {
                                contentDescription = "Open ${channel.category} category"
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
                        color = if (openCategory != null) colors.primary
                            else colors.onSurface.copy(alpha = 0.58f),
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontSize = 13.sp,
                            lineHeight = 14.95.sp,
                            fontWeight = FontWeight.Medium,
                        ),
                    )
                }
            }
            }
        }
    }
}

@Composable
private fun ViewerBadge(viewers: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .background(Color.Black.copy(alpha = 0.52f), RoundedCornerShape(50))
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LiveDot(size = 7.dp)
        Spacer(Modifier.width(5.dp))
        Text(
            text = viewers,
            color = Color.White,
            maxLines = 1,
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 11.sp,
                lineHeight = 11.sp,
                fontWeight = FontWeight.Bold,
                fontFeatureSettings = "tnum",
            ),
        )
    }
}

@Composable
fun LiveDot(modifier: Modifier = Modifier, size: Dp = 8.dp) {
    Box(modifier.size(size).background(FlowColors.Live, CircleShape))
}

@Composable
fun StatusMessage(
    message: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = message,
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = FlowSpacing.Lg),
        textAlign = TextAlign.Center,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
        fontWeight = FontWeight.Bold,
        style = MaterialTheme.typography.bodyMedium,
    )
}

@Composable
fun ErrorBanner(message: String, modifier: Modifier = Modifier) {
    Text(
        text = message,
        modifier = modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.72f),
                RoundedCornerShape(FlowRadius.Medium),
            )
            .padding(FlowSpacing.Md),
        color = MaterialTheme.colorScheme.onErrorContainer,
        fontWeight = FontWeight.Bold,
        style = MaterialTheme.typography.bodyMedium,
    )
}

private val StaticSkeletonShimmerPhase = object : State<Float> {
    override val value: Float = 0.5f
}

private val LocalSkeletonShimmerPhase = staticCompositionLocalOf<State<Float>> {
    StaticSkeletonShimmerPhase
}

/**
 * Owns the single shimmer clock shared by every [SkeletonBox] in [content].
 *
 * Keeping the animation at the loading-screen boundary mirrors Flutter's
 * `SkeletonShimmer`: lazily added boxes join the existing phase instead of
 * allocating and scheduling their own infinite transition.
 */
@Composable
fun SkeletonShimmerHost(content: @Composable () -> Unit) {
    val phase: State<Float> = if (LocalFlowVisualsActive.current) {
        val transition = rememberInfiniteTransition(label = "flow_skeleton")
        transition.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 1_200, easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "flow_skeleton_phase",
        )
    } else {
        StaticSkeletonShimmerPhase
    }
    CompositionLocalProvider(LocalSkeletonShimmerPhase provides phase, content = content)
}

@Composable
fun SkeletonBox(
    modifier: Modifier,
    radius: Dp = FlowRadius.Small,
) {
    val phase = LocalSkeletonShimmerPhase.current
    val base = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.72f)
    val highlight = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f)
    Box(
        modifier.drawWithCache {
            val position = (phase.value * 3f) - 1.5f
            val brush = Brush.linearGradient(
                colors = listOf(base, highlight, base),
                start = Offset((position - 1f) * size.width / 2f, size.height * 0.4f),
                end = Offset((position + 1f) * size.width / 2f, size.height * 0.6f),
            )
            val cornerRadius = CornerRadius(radius.toPx())
            onDrawBehind {
                drawRoundRect(brush = brush, cornerRadius = cornerRadius)
            }
        },
    )
}

@Composable
fun StreamCardSkeleton(modifier: Modifier = Modifier, showCategory: Boolean = true) {
    val colors = MaterialTheme.colorScheme
    Surface(
        modifier = modifier.fillMaxWidth().padding(bottom = 7.dp),
        color = colors.surface,
        shape = RoundedCornerShape(FlowRadius.Card),
        border = androidx.compose.foundation.BorderStroke(
            0.8.dp,
            colors.outlineVariant.copy(
                alpha = if (colors.background == Color.Black) 0.14f else 0.34f,
            ),
        ),
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 86.dp)
                .padding(horizontal = 8.dp, vertical = 6.dp),
        ) {
            val thumbnailWidth = if (maxWidth < 350.dp) 116.dp else 124.dp
            val detailsWidth = (maxWidth - thumbnailWidth - 12.dp).coerceAtLeast(0.dp)
            val nameWidth = minOf(116.dp, (detailsWidth - 55.dp).coerceAtLeast(0.dp))
            Row(
                modifier = Modifier.fillMaxWidth().heightIn(min = 74.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
            Box(Modifier.width(thumbnailWidth).aspectRatio(16f / 9f)) {
                SkeletonBox(Modifier.fillMaxSize())
                SkeletonBox(
                    Modifier.align(Alignment.BottomStart).padding(start = 6.dp, bottom = 3.dp)
                        .size(width = 49.dp, height = 17.dp),
                    radius = 50.dp,
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SkeletonBox(Modifier.size(28.dp), radius = 50.dp)
                    Spacer(Modifier.width(8.dp))
                    SkeletonBox(Modifier.width(nameWidth).height(18.dp))
                    Spacer(Modifier.width(5.dp))
                    SkeletonBox(Modifier.size(14.dp))
                }
                Spacer(Modifier.height(6.dp))
                SkeletonBox(Modifier.width(detailsWidth * 0.92f).height(17.dp))
                Spacer(Modifier.height(5.dp))
                SkeletonBox(
                    Modifier.width(if (showCategory) 104.dp else detailsWidth * 0.92f).height(15.dp),
                )
            }
            }
        }
    }
}
