package com.namecallfilter.flow.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Category
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.ScreenRotation
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.namecallfilter.flow.TwitchPlayerEvent
import com.namecallfilter.flow.TwitchPlayerView
import com.namecallfilter.flow.TwitchQualityOption
import com.namecallfilter.flow.data.AppSettingsRepository
import com.namecallfilter.flow.data.BrowseCategory
import com.namecallfilter.flow.data.StreamChannel
import com.namecallfilter.flow.data.TwitchApiCache
import com.namecallfilter.flow.data.browseCategoryFromApi
import com.namecallfilter.flow.data.browseErrorMessage
import com.namecallfilter.flow.data.colorsForText
import com.namecallfilter.flow.data.formatCompactCount
import com.namecallfilter.flow.ui.components.AvatarRing
import com.namecallfilter.flow.ui.components.FlowTooltipAction
import com.namecallfilter.flow.ui.components.LiveDot
import com.namecallfilter.flow.ui.components.LocalFlowVisualsActive
import com.namecallfilter.flow.ui.theme.FlowSpacing
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.time.Duration
import java.time.Instant
import java.util.Locale
import kotlin.math.roundToInt

private const val PlayerOverlayAnimationMillis = 160
private val PlayerEaseOutCubic = CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlayerScreen(
    channel: StreamChannel,
    apiCache: TwitchApiCache,
    settingsRepository: AppSettingsRepository,
    coveredByDestination: Boolean,
    onBack: () -> Unit,
    onOpenChannel: (String) -> Unit,
    onOpenCategory: (BrowseCategory) -> Unit,
) {
    val context = LocalContext.current
    val visualsActive = LocalFlowVisualsActive.current
    val activity = context.findActivity()
    val lifecycleOwner = LocalLifecycleOwner.current
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    val layoutDirection = LocalLayoutDirection.current
    val safeDrawingPadding = WindowInsets.safeDrawing.asPaddingValues()
    val overlayHorizontalPadding = if (isLandscape) {
        maxOf(
            8.dp,
            safeDrawingPadding.calculateLeftPadding(layoutDirection),
            safeDrawingPadding.calculateRightPadding(layoutDirection),
        )
    } else {
        8.dp
    }
    val overlayVerticalPadding = if (isLandscape) {
        maxOf(
            8.dp,
            safeDrawingPadding.calculateTopPadding(),
            safeDrawingPadding.calculateBottomPadding(),
        )
    } else {
        8.dp
    }
    val scope = rememberCoroutineScope()
    val snackbarHost = remember { SnackbarHostState() }

    var reloadKey by remember(channel.login) { mutableIntStateOf(0) }
    var playbackUrl by remember(channel.login) { mutableStateOf<String?>(null) }
    var proxyUrls by remember(channel.login) { mutableStateOf(emptyList<String>()) }
    var player by remember(channel.login) { mutableStateOf<TwitchPlayerView?>(null) }
    var latencyMs by remember(channel.login) { mutableStateOf<Long?>(null) }
    var activeAd by remember(channel.login) { mutableStateOf<TwitchPlayerEvent.Ad?>(null) }
    var qualities by remember(channel.login) { mutableStateOf(emptyList<TwitchQualityOption>()) }
    var selectedQualityId by remember(channel.login) { mutableStateOf("auto") }
    var isPlaying by remember(channel.login) { mutableStateOf(false) }
    var isBuffering by remember(channel.login) { mutableStateOf(true) }
    var playWhenReady by remember(channel.login) { mutableStateOf(true) }
    var errorMessage by remember(channel.login) { mutableStateOf<String?>(null) }
    var controlsVisible by remember(channel.login) { mutableStateOf(true) }
    var showQualitySheet by remember { mutableStateOf(false) }
    var viewerText by remember(channel.login) { mutableStateOf(channel.viewers) }
    var wasPlayingBeforeBackground by remember { mutableStateOf(false) }
    var resumeAfterDestination by remember(channel.login) { mutableStateOf(false) }
    var destinationWasInactive by remember(channel.login) { mutableStateOf(false) }
    var destinationOpening by remember(channel.login) { mutableStateOf(false) }
    var destinationCoverObserved by remember(channel.login) { mutableStateOf(false) }
    var playerForcedLandscape by remember(channel.login) { mutableStateOf(false) }
    var appIsResumed by remember(channel.login) {
        mutableStateOf(lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
    }
    var nowMillis by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val destinationInactive = coveredByDestination || destinationOpening

    val currentPlayer by rememberUpdatedState(player)
    val currentPlayWhenReady by rememberUpdatedState(playWhenReady)
    val currentDestinationInactive by rememberUpdatedState(destinationInactive)

    // Match Flutter's synchronous destination-opening guard: pause the player
    // and restore the normal display mode before any category lookup begins.
    val beginDestinationOpen: () -> Boolean = {
        if (destinationInactive) {
            false
        } else {
            destinationWasInactive = true
            resumeAfterDestination = playWhenReady
            destinationOpening = true
            player?.pause()
            if (playerForcedLandscape) activity?.restorePlayerDisplayMode()
            true
        }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_PAUSE -> {
                    appIsResumed = false
                    if (!currentDestinationInactive && currentPlayWhenReady) {
                        wasPlayingBeforeBackground = true
                    }
                    currentPlayer?.pause()
                }
                Lifecycle.Event.ON_RESUME -> if (wasPlayingBeforeBackground && !currentDestinationInactive) {
                    appIsResumed = true
                    wasPlayingBeforeBackground = false
                    currentPlayer?.play()
                } else appIsResumed = true
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(destinationInactive) {
        if (destinationInactive) {
            if (!destinationWasInactive) {
                destinationWasInactive = true
                resumeAfterDestination = currentPlayWhenReady
            }
            currentPlayer?.pause()
            if (playerForcedLandscape) activity?.restorePlayerDisplayMode()
        } else if (destinationWasInactive) {
            destinationWasInactive = false
            if (playerForcedLandscape) activity?.setPlayerLandscape(true)
            if (resumeAfterDestination) {
                if (appIsResumed) currentPlayer?.play() else wasPlayingBeforeBackground = true
            }
            resumeAfterDestination = false
        }
    }

    // Keep the opening guard set for the whole pushed route. Clearing it only
    // after the covering destination has appeared and disappeared prevents a
    // rapid second tap from starting duplicate lookup/navigation work.
    LaunchedEffect(coveredByDestination) {
        if (coveredByDestination) {
            destinationCoverObserved = true
        } else if (destinationCoverObserved) {
            destinationCoverObserved = false
            destinationOpening = false
        }
    }

    // A playback surface can finish attaching after a destination has already
    // covered the player. Keep that late surface paused until the route returns.
    LaunchedEffect(player, destinationInactive) {
        if (destinationInactive) player?.pause()
    }

    DisposableEffect(activity) {
        onDispose {
            activity?.restorePlayerDisplayMode()
        }
    }

    LaunchedEffect(channel.startedAt, visualsActive) {
        while (visualsActive && isActive && channel.startedAt != null) {
            nowMillis = System.currentTimeMillis()
            delay(1_000)
        }
    }

    LaunchedEffect(channel.login, appIsResumed, visualsActive) {
        if (!appIsResumed || !visualsActive) return@LaunchedEffect
        while (isActive) {
            runCatching {
                apiCache.fetchLiveStreamsPage(
                    first = 1,
                    userLogins = listOf(channel.login),
                    refresh = true,
                ).data.firstOrNull()?.viewerCount
            }.getOrNull()?.takeIf { it >= 0 }?.let { viewerText = formatCompactCount(it) }
            delay(30_000)
        }
    }

    LaunchedEffect(channel.login, reloadKey) {
        playbackUrl = null
        errorMessage = null
        latencyMs = null
        activeAd = null
        qualities = emptyList()
        selectedQualityId = "auto"
        controlsVisible = true
        isBuffering = true
        isPlaying = false
        playWhenReady = true
        try {
            val normalizedLogin = channel.login.trim().lowercase(Locale.ROOT)
            proxyUrls = try {
                settingsRepository.load()
                if (!settingsRepository.state.value.adProxyEnabled) {
                    emptyList()
                } else {
                    try {
                        val subscribed = apiCache.fetchChannelSubscriptionStatus(normalizedLogin)
                        settingsRepository.syncAdProxySubscriptionChannel(normalizedLogin, subscribed)
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (_: Throwable) {
                        // Subscription state is optional; use the last persisted value.
                    }
                    val settings = settingsRepository.state.value
                    if (normalizedLogin !in settings.adProxyEffectiveWhitelistedChannels) {
                        settings.adProxyUrls
                    } else {
                        emptyList()
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Throwable) {
                // Proxy configuration must never prevent direct playback.
                emptyList()
            }
            playbackUrl = apiCache.fetchLivePlaybackUri(channel.login).toString()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Throwable) {
            isBuffering = false
            playWhenReady = false
            errorMessage = playerErrorMessage(error)
        }
    }

    LaunchedEffect(
        isPlaying,
        isBuffering,
        controlsVisible,
        errorMessage,
        showQualitySheet,
        destinationInactive,
    ) {
        if (
            !destinationInactive &&
            isPlaying &&
            !isBuffering &&
            controlsVisible &&
            errorMessage == null &&
            !showQualitySheet
        ) {
            delay(3_000)
            controlsVisible = false
        }
    }

    val adTopPadding by animateDpAsState(
        targetValue = overlayVerticalPadding + if (controlsVisible) 44.dp else 4.dp,
        animationSpec = tween(
            durationMillis = PlayerOverlayAnimationMillis,
            easing = PlayerEaseOutCubic,
        ),
        label = "playerAdTopPadding",
    )

    if (showQualitySheet) {
        fun selectQuality(id: String) {
            showQualitySheet = false
            if (player?.setQuality(id) == false) {
                scope.launch {
                    snackbarHost.showSnackbar("That video quality is no longer available.")
                }
            }
        }
        ModalBottomSheet(
            onDismissRequest = { showQualitySheet = false },
            containerColor = MaterialTheme.colorScheme.background,
            contentColor = MaterialTheme.colorScheme.onBackground,
            tonalElevation = 0.dp,
            scrimColor = Color.Black.copy(alpha = 0.54f),
            dragHandle = {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .pointerInput(Unit) {
                            detectTapGestures(onTap = { showQualitySheet = false })
                        }
                        .clearAndSetSemantics {
                            contentDescription = "Dismiss"
                            role = Role.Button
                            onClick {
                                showQualitySheet = false
                                true
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    BottomSheetDefaults.DragHandle(
                        modifier = Modifier.clearAndSetSemantics { },
                    )
                }
            },
        ) {
            Text(
                text = "Quality",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(
                    start = FlowSpacing.Lg,
                    top = 0.dp,
                    end = FlowSpacing.Lg,
                    bottom = FlowSpacing.Md,
                ),
            )
            HorizontalDivider(
                modifier = Modifier.padding(horizontal = FlowSpacing.Lg),
                thickness = 0.5.dp,
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
            )
            LazyColumn(
                modifier = Modifier.fillMaxWidth().weight(1f, fill = false),
            ) {
                item(key = "auto") {
                    QualityRow(
                        label = "Auto",
                        selected = selectedQualityId == "auto",
                        onClick = { selectQuality("auto") },
                    )
                }
                items(qualities.size, key = { qualities[it].id }) { index ->
                    val quality = qualities[index]
                    QualityRow(
                        label = quality.label,
                        selected = selectedQualityId == quality.id,
                        onClick = { selectQuality(quality.id) },
                    )
                }
                if (qualities.isEmpty()) {
                    item(key = "loading") {
                        Box(Modifier.fillMaxWidth().height(48.dp), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                        }
                    }
                }
            }
            Spacer(Modifier.navigationBarsPadding())
        }
    }

    val playerSnackbarBottomInset =
        WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        snackbarHost = {
            FlowSnackbarHost(
                hostState = snackbarHost,
                bottomInset = playerSnackbarBottomInset,
            )
        },
    ) { contentPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(contentPadding),
            contentAlignment = Alignment.TopCenter,
        ) {
            val viewportModifier = if (isLandscape) {
                Modifier.fillMaxSize()
            } else {
                Modifier
                    .statusBarsPadding()
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
            }
            Box(
                modifier = viewportModifier
                    .background(Color.Black)
                    .clickable(
                        interactionSource = null,
                        indication = null,
                    ) { controlsVisible = !controlsVisible },
            ) {
                val url = playbackUrl
                if (url != null) {
                    NativePlayerSurface(
                        playbackUrl = url,
                        proxyUrls = proxyUrls,
                        apiCache = apiCache,
                        login = channel.login,
                        sessionKey = reloadKey,
                        onPlayerChanged = { player = it },
                        onEvent = { event ->
                            when (event) {
                                is TwitchPlayerEvent.Latency -> if (playWhenReady) {
                                    latencyMs = event.latencyMs
                                }
                                is TwitchPlayerEvent.Ad -> activeAd = event.takeIf { it.active }
                                is TwitchPlayerEvent.State -> {
                                    isPlaying = event.isPlaying
                                    isBuffering = event.isBuffering
                                    playWhenReady = event.playWhenReady
                                    if (!event.playWhenReady || event.isBuffering) controlsVisible = true
                                }
                                is TwitchPlayerEvent.Qualities -> {
                                    qualities = event.qualities
                                    selectedQualityId = event.selectedId
                                }
                                is TwitchPlayerEvent.Error -> {
                                    isBuffering = false
                                    controlsVisible = true
                                    activeAd = null
                                    errorMessage = event.message
                                }
                            }
                        },
                    )
                }

                PlayerScrim(visible = controlsVisible || isBuffering || errorMessage != null)

                AnimatedVisibility(
                    visible = controlsVisible,
                    enter = fadeIn(
                        animationSpec = tween(
                            durationMillis = PlayerOverlayAnimationMillis,
                            easing = LinearEasing,
                        ),
                    ),
                    exit = fadeOut(
                        animationSpec = tween(
                            durationMillis = PlayerOverlayAnimationMillis,
                            easing = LinearEasing,
                        ),
                    ),
                    modifier = Modifier.align(Alignment.TopCenter),
                ) {
                    PlayerHeader(
                        channel = channel,
                        horizontalPadding = overlayHorizontalPadding,
                        verticalPadding = overlayVerticalPadding,
                        onBack = onBack,
                        onOpenChannel = {
                            if (beginDestinationOpen()) onOpenChannel(channel.login)
                        },
                        onOpenCategory = {
                            val categoryName = channel.category.trim()
                            if (
                                categoryName.isNotEmpty() &&
                                !categoryName.equals("live", true) &&
                                beginDestinationOpen()
                            ) {
                                scope.launch {
                                    try {
                                        val match = apiCache.searchCategoriesPage(categoryName, first = 10).data
                                            .firstOrNull { it.name.equals(categoryName, true) }
                                        if (match == null) {
                                            destinationOpening = false
                                            snackbarHost.showSnackbar("That category is no longer available.")
                                        } else {
                                            onOpenCategory(
                                                browseCategoryFromApi(match).copy(
                                                    viewerCount = 0,
                                                    viewers = "--",
                                                ),
                                            )
                                        }
                                    } catch (cancelled: CancellationException) {
                                        destinationOpening = false
                                        throw cancelled
                                    } catch (error: Throwable) {
                                        destinationOpening = false
                                        snackbarHost.showSnackbar(browseErrorMessage(error))
                                    }
                                }
                            }
                        },
                        onQuality = { showQualitySheet = true },
                    )
                }

                if (errorMessage != null) {
                    PlayerError(
                        message = requireNotNull(errorMessage),
                        onRetry = { reloadKey += 1 },
                        modifier = Modifier.align(Alignment.Center),
                    )
                } else if (isBuffering && playWhenReady) {
                    CircularProgressIndicator(
                        color = Color.White,
                        strokeWidth = 3.dp,
                        modifier = Modifier.align(Alignment.Center).size(42.dp),
                    )
                } else {
                    AnimatedVisibility(
                        visible = controlsVisible,
                        enter = fadeIn(
                            animationSpec = tween(
                                durationMillis = PlayerOverlayAnimationMillis,
                                easing = LinearEasing,
                            ),
                        ),
                        exit = fadeOut(
                            animationSpec = tween(
                                durationMillis = PlayerOverlayAnimationMillis,
                                easing = LinearEasing,
                            ),
                        ),
                        modifier = Modifier.align(Alignment.Center),
                    ) {
                        val playbackActionLabel = if (playWhenReady) "Pause" else "Play"
                        FlowTooltipAction(
                            label = playbackActionLabel,
                            onClick = {
                                controlsVisible = true
                                player?.togglePlayback()
                            },
                            modifier = Modifier.size(68.dp),
                        ) {
                            Icon(
                                imageVector = if (playWhenReady) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(54.dp),
                            )
                        }
                    }
                }

                AnimatedVisibility(
                    visible = controlsVisible,
                    enter = fadeIn(
                        animationSpec = tween(
                            durationMillis = PlayerOverlayAnimationMillis,
                            easing = LinearEasing,
                        ),
                    ),
                    exit = fadeOut(
                        animationSpec = tween(
                            durationMillis = PlayerOverlayAnimationMillis,
                            easing = LinearEasing,
                        ),
                    ),
                    modifier = Modifier.align(Alignment.BottomCenter),
                ) {
                    PlayerFooter(
                        viewers = viewerText,
                        liveDuration = liveDuration(channel.startedAt, nowMillis),
                        latencyMs = latencyMs,
                        isLandscape = isLandscape,
                        horizontalPadding = overlayHorizontalPadding,
                        verticalPadding = overlayVerticalPadding,
                        onJumpLive = {
                            controlsVisible = true
                            player?.jumpToLive()
                        },
                        onRefresh = { reloadKey += 1 },
                        onToggleLandscape = {
                            val nextLandscape = if (playerForcedLandscape) false else !isLandscape
                            playerForcedLandscape = nextLandscape
                            activity?.setPlayerLandscape(nextLandscape)
                        },
                    )
                }

                activeAd?.let {
                    AdPill(
                        ad = it,
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(
                                start = overlayHorizontalPadding + 48.dp,
                                top = adTopPadding,
                                end = overlayHorizontalPadding + 48.dp,
                            ),
                    )
                }
            }
        }
    }
}

@Composable
private fun NativePlayerSurface(
    playbackUrl: String,
    proxyUrls: List<String>,
    apiCache: TwitchApiCache,
    login: String,
    sessionKey: Int,
    onPlayerChanged: (TwitchPlayerView?) -> Unit,
    onEvent: (TwitchPlayerEvent) -> Unit,
) {
    val context = LocalContext.current
    val currentEventHandler by rememberUpdatedState(onEvent)
    val nativePlayer = remember(playbackUrl, proxyUrls, sessionKey) {
        TwitchPlayerView(
            context = context,
            initialUrl = playbackUrl,
            proxyUrls = proxyUrls,
            playbackUriRefresher = {
                runBlocking(Dispatchers.IO) {
                    apiCache.fetchLivePlaybackUri(login).toString()
                }
            },
            onEvent = { currentEventHandler(it) },
        )
    }
    DisposableEffect(nativePlayer) {
        onPlayerChanged(nativePlayer)
        nativePlayer.initialize()
        onDispose {
            onPlayerChanged(null)
            nativePlayer.release()
        }
    }
    AndroidView(
        factory = { nativePlayer.view },
        modifier = Modifier.fillMaxSize(),
    )
}

@Composable
private fun PlayerScrim(visible: Boolean) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(
            animationSpec = tween(
                durationMillis = PlayerOverlayAnimationMillis,
                easing = LinearEasing,
            ),
        ),
        exit = fadeOut(
            animationSpec = tween(
                durationMillis = PlayerOverlayAnimationMillis,
                easing = LinearEasing,
            ),
        ),
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colorStops = arrayOf(
                            0f to Color(0xB3000000),
                            0.30f to Color.Transparent,
                            0.62f to Color.Transparent,
                            1f to Color(0xBF000000),
                        ),
                    ),
                ),
        )
    }
}

@Composable
private fun PlayerHeader(
    channel: StreamChannel,
    horizontalPadding: androidx.compose.ui.unit.Dp,
    verticalPadding: androidx.compose.ui.unit.Dp,
    onBack: () -> Unit,
    onOpenChannel: () -> Unit,
    onOpenCategory: () -> Unit,
    onQuality: () -> Unit,
) {
    val avatarInteractionSource = remember { MutableInteractionSource() }
    val categoryInteractionSource = remember { MutableInteractionSource() }
    Row(
        modifier = Modifier.fillMaxWidth().padding(
            horizontal = horizontalPadding,
            vertical = verticalPadding,
        ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PlayerIconButton(Icons.AutoMirrored.Rounded.ArrowBack, "Back", onBack)
        Spacer(Modifier.width(4.dp))
        AvatarRing(
            initials = channel.initials,
            colors = channel.avatarColors,
            imageUrl = channel.avatarImageUrl,
            size = 36.dp,
            modifier = Modifier
                .semantics { contentDescription = "Open ${channel.name} channel" }
                .clickable(
                    interactionSource = avatarInteractionSource,
                    indication = null,
                    role = Role.Button,
                    onClick = onOpenChannel,
                ),
        )
        Spacer(Modifier.width(4.dp))
        Column(Modifier.weight(1f)) {
            Text(
                text = buildAnnotatedString {
                    withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) {
                        append(channel.name)
                    }
                    if (channel.title.isNotEmpty()) {
                        withStyle(
                            SpanStyle(
                                color = Color.White.copy(alpha = 0.82f),
                                fontWeight = FontWeight.SemiBold,
                            ),
                        ) {
                            append("  ${channel.title}")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodyMedium.copy(
                    color = Color.White,
                    fontSize = 15.sp,
                    lineHeight = 21.45.sp,
                ),
            )
            Spacer(Modifier.height(2.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .semantics { contentDescription = "Open ${channel.category} category" }
                    .clickable(
                        interactionSource = categoryInteractionSource,
                        indication = null,
                        role = Role.Button,
                        onClick = onOpenCategory,
                    ),
            ) {
                Icon(Icons.Rounded.Category, null, tint = Color.White.copy(alpha = 0.78f), modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    text = channel.category,
                    color = Color.White.copy(alpha = 0.78f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontSize = 12.sp,
                        lineHeight = 17.16.sp,
                        fontWeight = FontWeight.SemiBold,
                    ),
                )
            }
        }
        PlayerIconButton(Icons.Rounded.Settings, "Video quality", onQuality)
    }
}

@Composable
private fun PlayerFooter(
    viewers: String,
    liveDuration: Duration?,
    latencyMs: Long?,
    isLandscape: Boolean,
    horizontalPadding: androidx.compose.ui.unit.Dp,
    verticalPadding: androidx.compose.ui.unit.Dp,
    onJumpLive: () -> Unit,
    onRefresh: () -> Unit,
    onToggleLandscape: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(
            horizontal = horizontalPadding,
            vertical = verticalPadding,
        ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .width(32.dp)
                .height(40.dp)
                .padding(start = 12.dp, end = 4.dp),
            contentAlignment = Alignment.Center,
        ) {
            LiveDot(size = 10.dp)
        }
        ScaleDownToFit(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                OverlayMetric(formatLiveDuration(liveDuration))
                Spacer(Modifier.width(12.dp))
                Icon(Icons.Rounded.Visibility, null, tint = Color.White, modifier = Modifier.size(19.dp))
                Spacer(Modifier.width(5.dp))
                OverlayMetric(viewers)
                Spacer(Modifier.width(12.dp))
                Icon(Icons.Rounded.Speed, null, tint = Color.White, modifier = Modifier.size(19.dp))
                Spacer(Modifier.width(5.dp))
                OverlayMetric(latencyMs?.let { String.format(Locale.US, "%.2fs", it / 1000.0) } ?: "--")
            }
        }
        Spacer(Modifier.width(8.dp))
        PlayerIconButton(Icons.Rounded.FastForward, "Jump to live edge", onJumpLive)
        Spacer(Modifier.width(8.dp))
        PlayerIconButton(Icons.Rounded.Refresh, "Refresh player", onRefresh)
        Spacer(Modifier.width(8.dp))
        PlayerIconButton(
            Icons.Rounded.ScreenRotation,
            if (isLandscape) "Exit landscape" else "Enter landscape",
            onToggleLandscape,
        )
    }
}

@Composable
private fun ScaleDownToFit(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Layout(
        content = content,
        modifier = modifier,
    ) { measurables, constraints ->
        val placeable = measurables.single().measure(Constraints())
        val widthScale = if (constraints.hasBoundedWidth && placeable.width > 0) {
            constraints.maxWidth.toFloat() / placeable.width
        } else {
            1f
        }
        val heightScale = if (constraints.hasBoundedHeight && placeable.height > 0) {
            constraints.maxHeight.toFloat() / placeable.height
        } else {
            1f
        }
        val scale = minOf(1f, widthScale, heightScale)
        val scaledWidth = (placeable.width * scale).roundToInt()
        val scaledHeight = (placeable.height * scale).roundToInt()
        val layoutWidth = if (constraints.hasBoundedWidth) {
            constraints.maxWidth
        } else {
            scaledWidth.coerceIn(constraints.minWidth, constraints.maxWidth)
        }
        val layoutHeight = scaledHeight.coerceIn(constraints.minHeight, constraints.maxHeight)

        layout(layoutWidth, layoutHeight) {
            placeable.placeWithLayer(
                x = 0,
                y = (layoutHeight - placeable.height) / 2,
            ) {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0f, 0.5f)
            }
        }
    }
}

@Composable
private fun PlayerIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    onClick: () -> Unit,
) {
    FlowTooltipAction(
        label = description,
        onClick = onClick,
        modifier = Modifier.size(40.dp),
    ) {
        Icon(icon, null, tint = Color.White, modifier = Modifier.size(27.dp))
    }
}

@Composable
private fun OverlayMetric(text: String) {
    Text(
        text = text,
        maxLines = 1,
        style = MaterialTheme.typography.bodyMedium.copy(
            color = Color.White,
            fontSize = 14.sp,
            lineHeight = 20.02.sp,
            fontWeight = FontWeight.Bold,
            fontFeatureSettings = "tnum",
        ),
    )
}

@Composable
private fun AdPill(ad: TwitchPlayerEvent.Ad, modifier: Modifier = Modifier) {
    val hasCount = ad.current > 0 && ad.total > 0 && ad.current <= ad.total
    val prefix = if (hasCount) "Ad ${ad.current} of ${ad.total}" else "Ad"
    val seconds = ((ad.remainingMs.coerceAtLeast(0) + 999) / 1000).toInt()
    val hours = seconds / 3_600
    val minutes = (seconds / 60) % 60
    val remainingSeconds = (seconds % 60).toString().padStart(2, '0')
    val countdown = if (hours > 0) {
        "$hours:${minutes.toString().padStart(2, '0')}:$remainingSeconds"
    } else {
        "$minutes:$remainingSeconds"
    }
    val semanticsCount = if (hasCount) " ${ad.current} of ${ad.total}" else ""
    val shape = RoundedCornerShape(999.dp)
    Text(
        text = "$prefix · $countdown",
        maxLines = 1,
        style = MaterialTheme.typography.bodyMedium.copy(
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 13.sp,
            lineHeight = 18.59.sp,
            fontFeatureSettings = "tnum",
        ),
        modifier = modifier
            .semantics {
                contentDescription = "Advertisement$semanticsCount, $seconds seconds remaining"
            }
            .background(Color.Black.copy(alpha = 0.78f), shape)
            .border(1.dp, Color.White.copy(alpha = 0.16f), shape)
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

@Composable
private fun PlayerError(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .padding(horizontal = 52.dp)
            .widthIn(max = 320.dp)
            .background(Color.Black.copy(alpha = 0.72f), RoundedCornerShape(12.dp))
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = message,
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodyMedium.copy(
                fontSize = 14.sp,
                lineHeight = 20.02.sp,
                fontWeight = FontWeight.SemiBold,
            ),
        )
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onRetry) {
            Icon(Icons.Rounded.Refresh, null, tint = Color.White)
            Spacer(Modifier.width(8.dp))
            Text("Try again", color = Color.White)
        }
    }
}

@Composable
private fun QualityRow(label: String, selected: Boolean, onClick: () -> Unit) {
    ListItem(
        headlineContent = {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontSize = 15.sp,
                    lineHeight = 22.5.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
        },
        trailingContent = { if (selected) Icon(Icons.Rounded.Check, "Selected") },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        modifier = Modifier
            .semantics { this.selected = selected }
            .clickable(onClick = onClick),
    )
}

private fun liveDuration(startedAt: Instant?, nowMillis: Long): Duration? {
    if (startedAt == null) return null
    return Duration.between(startedAt, Instant.ofEpochMilli(nowMillis)).let {
        if (it.isNegative) Duration.ZERO else it
    }
}

private fun formatLiveDuration(duration: Duration?): String {
    if (duration == null) return "LIVE"
    val seconds = duration.seconds.coerceAtLeast(0)
    val hours = seconds / 3600
    val minutes = (seconds / 60) % 60
    val remainder = seconds % 60
    return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, remainder)
    else "%d:%02d".format(seconds / 60, remainder)
}

private fun playerErrorMessage(error: Throwable): String =
    error.message?.trim()?.takeIf(String::isNotEmpty) ?: "The stream could not be loaded."

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

private fun Activity.setPlayerLandscape(landscape: Boolean) {
    requestedOrientation = if (landscape) {
        ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    } else {
        ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }
    WindowCompat.getInsetsController(window, window.decorView).apply {
        if (landscape) {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior =
                androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            show(WindowInsetsCompat.Type.systemBars())
        }
    }
}

private fun Activity.restorePlayerDisplayMode() {
    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    WindowCompat.getInsetsController(window, window.decorView).show(WindowInsetsCompat.Type.systemBars())
}
