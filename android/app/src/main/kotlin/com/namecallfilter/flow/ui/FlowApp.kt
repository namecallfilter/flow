package com.namecallfilter.flow.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import androidx.activity.BackEventCompat
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarData
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.core.view.WindowCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.namecallfilter.flow.data.AndroidFlowPreferencesStore
import com.namecallfilter.flow.data.AndroidKeystoreTwitchSecureStore
import com.namecallfilter.flow.data.AndroidTwitchCookieExtractor
import com.namecallfilter.flow.data.AppSettingsRepository
import com.namecallfilter.flow.data.BrowseRepository
import com.namecallfilter.flow.data.BrowseSearchRepository
import com.namecallfilter.flow.data.CategoryStreamsRepository
import com.namecallfilter.flow.data.ChannelRepository
import com.namecallfilter.flow.data.DefaultFlowPreferences
import com.namecallfilter.flow.data.FlowPreferences
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.data.FollowingRepository
import com.namecallfilter.flow.data.OkHttpTwitchApiClientFactory
import com.namecallfilter.flow.data.TwitchApiCache
import com.namecallfilter.flow.data.TwitchAuthConfig
import com.namecallfilter.flow.data.TwitchAuthController
import com.namecallfilter.flow.data.TwitchSessionStatus
import com.namecallfilter.flow.ui.components.FlowBottomBar
import com.namecallfilter.flow.ui.components.FlowVisualsActive
import com.namecallfilter.flow.ui.components.captureFlowBackdrop
import com.namecallfilter.flow.ui.navigation.ChannelSeed
import com.namecallfilter.flow.ui.navigation.FlowDestination
import com.namecallfilter.flow.ui.navigation.FlowNavigationEntry
import com.namecallfilter.flow.ui.navigation.FlowNavigationState
import com.namecallfilter.flow.ui.navigation.FlowTab
import com.namecallfilter.flow.ui.theme.FlowTheme
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope

private enum class LoginLayer { OFFER, WEB }

internal const val CLEAR_TWITCH_SESSION_FAILURE_MESSAGE =
    "We couldn't clear your Twitch session. Try again."
internal const val SAVE_GUEST_CHOICE_FAILURE_MESSAGE =
    "We couldn't save your choice. Try again."
internal const val TWITCH_AUTH_NOT_CONFIGURED_MESSAGE =
    "Set TWITCH_CLIENT_ID with --dart-define-from-file=.env to start Twitch auth."

internal sealed interface GuestContinuationResult {
    data object Completed : GuestContinuationResult
    data class Failed(val message: String) : GuestContinuationResult
}

internal suspend fun continueAsGuest(
    signOut: suspend () -> Unit,
    saveDismissedChoice: suspend () -> Unit,
): GuestContinuationResult {
    try {
        signOut()
    } catch (error: CancellationException) {
        throw error
    } catch (_: Throwable) {
        return GuestContinuationResult.Failed(CLEAR_TWITCH_SESSION_FAILURE_MESSAGE)
    }

    try {
        saveDismissedChoice()
    } catch (error: CancellationException) {
        throw error
    } catch (_: Throwable) {
        return GuestContinuationResult.Failed(SAVE_GUEST_CHOICE_FAILURE_MESSAGE)
    }
    return GuestContinuationResult.Completed
}

internal enum class MeRequestResolution {
    OPEN_SETTINGS,
    OPEN_LOGIN,
    STARTUP_OFFER_ACTIVE,
    ALREADY_HANDLING,
}

/**
 * Serializes profile requests behind Flutter's complete initial-session future. The UI can become
 * visible early when saved tokens exist, but profile actions must not observe the intermediate
 * RESTORING state and incorrectly open the login route.
 */
internal class StartupAccountCoordinator(
    private val loadSavedConnection: suspend () -> Unit,
    private val isLoggedIn: () -> Boolean,
) {
    private val initialRestoreComplete = CompletableDeferred<Unit>()
    private val lock = Any()
    private var handlingMeRequest = false

    fun completeInitialRestore() {
        initialRestoreComplete.complete(Unit)
    }

    suspend fun resolveMeRequest(
        isStartupOfferShowing: () -> Boolean,
    ): MeRequestResolution {
        val accepted = synchronized(lock) {
            if (handlingMeRequest) {
                false
            } else {
                handlingMeRequest = true
                true
            }
        }
        if (!accepted) return MeRequestResolution.ALREADY_HANDLING

        return try {
            initialRestoreComplete.await()
            // Flutter deliberately asks the store to load once more after the initial future. The
            // repository coalesces or skips this when already current, and performs it when needed.
            loadSavedConnection()
            when {
                isStartupOfferShowing() -> MeRequestResolution.STARTUP_OFFER_ACTIVE
                isLoggedIn() -> MeRequestResolution.OPEN_SETTINGS
                else -> MeRequestResolution.OPEN_LOGIN
            }
        } finally {
            synchronized(lock) { handlingMeRequest = false }
        }
    }
}

internal class TopLevelRefreshCoordinator(
    private val followingRepository: FollowingRepository,
    private val browseRepository: BrowseRepository,
    private val refreshScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
    private val refreshFollowing: suspend (Boolean) -> Unit = { refresh ->
        followingRepository.loadSavedConnection(refresh = refresh)
    },
) {
    private val lock = Any()
    private var active: CompletableDeferred<Unit>? = null
    private var refreshQueued = false
    private var queuedFollowingRefresh: Deferred<Throwable?>? = null

    suspend fun refresh(refresh: Boolean) {
        val (operation, leader, queuedToStart) = synchronized(lock) {
            active?.let { current ->
                var followingRefresh: Deferred<Throwable?>? = null
                if (refresh) {
                    refreshQueued = true
                    if (queuedFollowingRefresh == null) {
                        followingRefresh = refreshScope.async(start = CoroutineStart.LAZY) {
                            captureRefreshFailure {
                                refreshFollowing(true)
                            }
                        }
                        queuedFollowingRefresh = followingRefresh
                    }
                }
                return@synchronized Triple(current, false, followingRefresh)
            }
            Triple(CompletableDeferred<Unit>().also { active = it }, true, null)
        }
        queuedToStart?.start()
        if (!leader) {
            operation.await()
            return
        }

        var nextRefresh = refresh
        var nextFollowingRefresh: Deferred<Throwable?>? = null
        var failure: Throwable? = null
        try {
            while (true) {
                performRefresh(nextRefresh, nextFollowingRefresh)
                val (runTrailingRefresh, queuedFollowing) = synchronized(lock) {
                    if (refreshQueued) {
                        refreshQueued = false
                        true to queuedFollowingRefresh.also { queuedFollowingRefresh = null }
                    } else {
                        if (active === operation) active = null
                        operation.complete(Unit)
                        false to null
                    }
                }
                if (!runTrailingRefresh) break
                nextRefresh = true
                nextFollowingRefresh = queuedFollowing
            }
        } catch (error: Throwable) {
            failure = error
            throw error
        } finally {
            val abandonedFollowingRefresh = synchronized(lock) {
                if (active === operation) {
                    active = null
                    refreshQueued = false
                }
                queuedFollowingRefresh.also { queuedFollowingRefresh = null }
            }
            abandonedFollowingRefresh?.cancel()
            if (!operation.isCompleted) {
                if (failure == null) operation.complete(Unit) else operation.completeExceptionally(failure)
            }
        }
    }

    private suspend fun performRefresh(
        refresh: Boolean,
        followingRefresh: Deferred<Throwable?>?,
    ) = supervisorScope {
        val browseState = browseRepository.state.value
        listOf(
            async {
                if (followingRefresh != null) {
                    followingRefresh.await()
                } else {
                    captureRefreshFailure {
                        refreshFollowing(refresh)
                    }
                }
            },
            async {
                captureRefreshFailure {
                    when {
                        refresh && browseState.categoriesLoaded -> browseRepository.refreshCategoriesFirstPage()
                        !browseState.categoriesLoaded -> browseRepository.loadCategories(
                            reset = true,
                            refresh = refresh,
                        )
                    }
                }
            },
            async {
                captureRefreshFailure {
                    when {
                        refresh && browseState.liveChannelsLoaded -> browseRepository.refreshLiveChannelsFirstPage()
                        !browseState.liveChannelsLoaded -> browseRepository.loadLiveChannels(
                            reset = true,
                            refresh = refresh,
                        )
                    }
                }
            },
        ).awaitAll().firstOrNull { it != null }?.let { throw it }
    }

    private suspend fun captureRefreshFailure(block: suspend () -> Unit): Throwable? = try {
        block()
        null
    } catch (error: CancellationException) {
        throw error
    } catch (error: Throwable) {
        error
    }
}

internal class FlowAppDependencies(
    val preferences: FlowPreferences,
    val settingsRepository: AppSettingsRepository,
    val authController: TwitchAuthController,
    val apiCache: TwitchApiCache,
    val followingRepository: FollowingRepository,
    val browseRepository: BrowseRepository,
    val searchRepository: BrowseSearchRepository,
) {
    companion object {
        fun create(context: Context): FlowAppDependencies {
            val appContext = context.applicationContext
            val preferences = DefaultFlowPreferences(AndroidFlowPreferencesStore(appContext))
            val settingsRepository = AppSettingsRepository(preferences)
            val authConfig = TwitchAuthConfig.fromBuildConfig()
            val apiFactory = OkHttpTwitchApiClientFactory(authConfig)
            val authController = TwitchAuthController(
                config = authConfig,
                secureStore = AndroidKeystoreTwitchSecureStore(appContext),
                apiClientFactory = apiFactory,
                cookieExtractor = AndroidTwitchCookieExtractor(),
            )
            val apiCache = TwitchApiCache(
                clientLoader = {
                    val tokens = authController.readSavedTokens()
                    apiFactory.create(
                        accessToken = tokens.accessToken.orEmpty(),
                        gqlAccessToken = tokens.webSessionToken,
                    )
                },
            )
            val followingRepository = FollowingRepository(authController, apiCache)
            val browseRepository = BrowseRepository(apiCache)
            return FlowAppDependencies(
                preferences = preferences,
                settingsRepository = settingsRepository,
                authController = authController,
                apiCache = apiCache,
                followingRepository = followingRepository,
                browseRepository = browseRepository,
                searchRepository = BrowseSearchRepository(apiCache, preferences),
            )
        }
    }
}

/**
 * Compose's equivalent of Flutter's Offstage for retained navigation entries. The destination
 * stays composed so its in-flight work and transient state survive, but its subtree is not placed
 * and therefore cannot draw, hit-test, expose semantics, or create backdrop layers.
 */
private fun Modifier.flowOffstage(offstage: Boolean): Modifier = if (!offstage) {
    this
} else {
    layout { measurable, constraints ->
        val placeable = measurable.measure(constraints)
        layout(placeable.width, placeable.height) {
            // Deliberately do not place the retained subtree.
        }
    }
}

/** Native Compose entry point used by [com.namecallfilter.flow.MainActivity]. */
@Composable
fun FlowApp() {
    val context = LocalContext.current
    val dependencies = remember(context.applicationContext) {
        FlowAppDependencies.create(context.applicationContext)
    }
    FlowApp(dependencies)
}

@Composable
internal fun FlowApp(dependencies: FlowAppDependencies) {
    val settings by dependencies.settingsRepository.state.collectAsStateWithLifecycle()
    var settingsLoadFinished by remember { mutableStateOf(settings.isLoaded) }
    LaunchedEffect(dependencies.settingsRepository) {
        runCatching { dependencies.settingsRepository.load() }
        settingsLoadFinished = true
    }
    FlowTheme(settings.themeMode) {
        SystemBarAppearance(settings.themeMode)
        if (settings.isLoaded || settingsLoadFinished) {
            FlowAppContent(dependencies)
        } else {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(if (isSystemInDarkTheme()) Color.Black else Color.White),
            )
        }
    }
}

@Composable
private fun FlowAppContent(dependencies: FlowAppDependencies) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current
    val navigation: FlowNavigationState = viewModel()
    val following by dependencies.followingRepository.state.collectAsStateWithLifecycle()
    val anonymous = following.sessionStatus in setOf(
        TwitchSessionStatus.LOGGED_OUT,
        TwitchSessionStatus.RESTORE_FAILED,
    )
    val snackbarHostState = remember { SnackbarHostState() }
    val categoryRepositories = remember { mutableStateMapOf<Long, CategoryStreamsRepository>() }
    val browseCategoryRepositories = remember { mutableStateMapOf<String, CategoryStreamsRepository>() }
    val channelRepositories = remember { mutableStateMapOf<Long, ChannelRepository>() }
    val screenStateHolder = rememberSaveableStateHolder()
    val bottomBarBackdrop = rememberGraphicsLayer()
    val bottomNavigationInset = WindowInsets.safeDrawing.asPaddingValues().calculateBottomPadding()
    val imeVisible = WindowInsets.ime.getBottom(LocalDensity.current) > 0
    var retainedDestinationStateKeys by remember { mutableStateOf(emptySet<String>()) }
    val refreshCoordinator = remember(dependencies, scope) {
        TopLevelRefreshCoordinator(
            dependencies.followingRepository,
            dependencies.browseRepository,
            scope,
        )
    }
    val startupAccountCoordinator = remember(dependencies) {
        StartupAccountCoordinator(
            loadSavedConnection = {
                dependencies.followingRepository.loadSavedConnection(refresh = false)
            },
            isLoggedIn = { dependencies.followingRepository.state.value.isLoggedIn },
        )
    }
    var footerHidden by remember { mutableStateOf(false) }
    var startupResolved by remember { mutableStateOf(false) }
    var startupOffer by remember { mutableStateOf(false) }
    var loginLayer by remember { mutableStateOf<LoginLayer?>(null) }
    var loginInProgress by remember { mutableStateOf(false) }
    var continueInProgress by remember { mutableStateOf(false) }
    var loginMessage by remember { mutableStateOf<String?>(null) }
    var accountActionBusy by remember { mutableStateOf(false) }
    var predictiveBackActive by remember { mutableStateOf(false) }
    var predictiveBackProgress by remember { mutableFloatStateOf(0f) }
    var predictiveBackSwipeEdge by remember { mutableIntStateOf(BackEventCompat.EDGE_LEFT) }
    var loginBackActive by remember { mutableStateOf(false) }
    var loginBackProgress by remember { mutableFloatStateOf(0f) }
    var loginBackSwipeEdge by remember { mutableIntStateOf(BackEventCompat.EDGE_LEFT) }

    fun resetLoginBackProgress() {
        loginBackActive = false
        loginBackProgress = 0f
        loginBackSwipeEdge = BackEventCompat.EDGE_LEFT
    }

    LaunchedEffect(dependencies) {
        val initialTopLevelRefresh = async {
            refreshCoordinator.refresh(refresh = false)
        }
        val sessionRestore = async {
            dependencies.followingRepository.loadSavedConnection(refresh = false)
        }
        val dismissedLoad = async {
            runCatching { dependencies.preferences.readLoginOfferDismissed() }.getOrDefault(false)
        }
        if (dependencies.authController.config.isConfigured) {
            val tokens = runCatching { dependencies.authController.readSavedTokens() }.getOrNull()
            if (!tokens?.accessToken.isNullOrEmpty() && !tokens.webSessionToken.isNullOrBlank()) {
                startupResolved = true
            }
        }

        val dismissed = dismissedLoad.await()
        sessionRestore.await()
        startupOffer = !dismissed && !dependencies.followingRepository.state.value.isLoggedIn
        loginMessage = null
        loginLayer = if (startupOffer) LoginLayer.OFFER else null
        startupResolved = true
        startupAccountCoordinator.completeInitialRestore()
        initialTopLevelRefresh.await()
    }

    LaunchedEffect(dependencies, lifecycleOwner) {
        while (isActive) {
            delay(30_000)
            if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                refreshCoordinator.refresh(refresh = true)
            }
        }
    }
    LaunchedEffect(dependencies, lifecycleOwner) {
        var wasResumed = lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
        lifecycleOwner.lifecycle.currentStateFlow.collect { state ->
            val resumed = state.isAtLeast(Lifecycle.State.RESUMED)
            if (resumed && !wasResumed) refreshCoordinator.refresh(refresh = true)
            wasResumed = resumed
        }
    }
    LaunchedEffect(following.isLoggedIn, startupOffer, loginLayer, loginMessage) {
        if (following.isLoggedIn && startupOffer && loginLayer == LoginLayer.OFFER && loginMessage == null) {
            startupOffer = false
            loginLayer = null
        }
    }

    val activeEntryIds = navigation.activeEntryIds
    val activeDestinationStateKeys = buildSet {
        FlowTab.entries.forEach { tab ->
            navigation.stackFor(tab).forEach { routeEntry ->
                add(destinationStateKey(tab, routeEntry))
            }
        }
        navigation.playerFrames.forEach { frame ->
            frame.destinations.forEach { routeEntry ->
                add(destinationStateKey(frame.tab, routeEntry))
            }
        }
    }
    LaunchedEffect(
        navigation.currentTab,
        navigation.currentEntry.id,
        activeEntryIds,
        activeDestinationStateKeys,
    ) {
        footerHidden = false
        categoryRepositories.keys.filterNot(activeEntryIds::contains).forEach(categoryRepositories::remove)
        channelRepositories.keys.filterNot(activeEntryIds::contains).forEach(channelRepositories::remove)
        retainedDestinationStateKeys
            .filterNot(activeDestinationStateKeys::contains)
            .forEach(screenStateHolder::removeState)
        retainedDestinationStateKeys = activeDestinationStateKeys
    }

    val canHandleBack = startupResolved && loginLayer == null && navigation.canNavigateBack()
    PredictiveBackHandler(enabled = canHandleBack) { progress ->
        try {
            predictiveBackActive = true
            progress.collect { event ->
                predictiveBackProgress = event.progress
                predictiveBackSwipeEdge = event.swipeEdge
            }
            predictiveBackActive = false
            predictiveBackProgress = 0f
            navigation.navigateBack()
        } catch (error: CancellationException) {
            predictiveBackActive = false
            predictiveBackProgress = 0f
        }
    }

    val canHandleLoginBack = when (loginLayer) {
        LoginLayer.OFFER -> !startupOffer && !loginInProgress && !continueInProgress
        LoginLayer.WEB -> true
        null -> false
    }
    PredictiveBackHandler(enabled = canHandleLoginBack) { progress ->
        val handledLayer = loginLayer ?: return@PredictiveBackHandler
        try {
            loginBackActive = true
            progress.collect { event ->
                loginBackProgress = event.progress
                loginBackSwipeEdge = event.swipeEdge
            }
            resetLoginBackProgress()
            when (handledLayer) {
                LoginLayer.OFFER -> if (loginLayer == LoginLayer.OFFER) {
                    loginLayer = null
                    loginInProgress = false
                    continueInProgress = false
                    accountActionBusy = false
                }
                LoginLayer.WEB -> if (loginLayer == LoginLayer.WEB) {
                    loginLayer = LoginLayer.OFFER
                    loginInProgress = false
                }
            }
        } catch (error: CancellationException) {
            resetLoginBackProgress()
        }
    }

    LaunchedEffect(loginLayer) {
        if (loginBackActive || loginBackProgress != 0f) resetLoginBackProgress()
    }

    fun openChannel(login: String, name: String, avatarUrl: String?, live: Boolean) {
        val normalized = login.trim()
        if (normalized.isEmpty()) return
        navigation.push(
            FlowDestination.Channel(
                ChannelSeed(
                    login = normalized,
                    displayName = name.ifBlank { normalized },
                    avatarImageUrl = avatarUrl,
                    isLive = live,
                ),
            ),
        )
    }

    fun requestLogin() {
        if (accountActionBusy) return
        accountActionBusy = true
        scope.launch {
            var keepBusyForLogin = false
            try {
                when (
                    startupAccountCoordinator.resolveMeRequest(
                        isStartupOfferShowing = { startupOffer },
                    )
                ) {
                    MeRequestResolution.OPEN_SETTINGS -> navigation.selectTab(FlowTab.SETTINGS)
                    MeRequestResolution.OPEN_LOGIN -> {
                        startupOffer = false
                        loginMessage = null
                        loginLayer = LoginLayer.OFFER
                        keepBusyForLogin = true
                    }
                    MeRequestResolution.STARTUP_OFFER_ACTIVE,
                    MeRequestResolution.ALREADY_HANDLING,
                    -> Unit
                }
            } finally {
                if (!keepBusyForLogin) accountActionBusy = false
            }
        }
    }

    @Composable
    fun DestinationLayer(
        routeTab: FlowTab,
        routeEntry: FlowNavigationEntry,
        inPlayerOverlay: Boolean = false,
        isActive: Boolean = true,
        visualsActive: Boolean = isActive,
        modifier: Modifier = Modifier,
    ) {
        fun pushDestination(destination: FlowDestination) {
            if (inPlayerOverlay) navigation.pushPlayerDestination(destination)
            else navigation.push(destination)
        }

        fun openDestinationChannel(login: String, name: String, avatarUrl: String?, live: Boolean) {
            if (!inPlayerOverlay) {
                openChannel(login, name, avatarUrl, live)
                return
            }
            val normalized = login.trim()
            if (normalized.isEmpty()) return
            navigation.pushPlayerDestination(
                FlowDestination.Channel(
                    ChannelSeed(
                        login = normalized,
                        displayName = name.ifBlank { normalized },
                        avatarImageUrl = avatarUrl,
                        isLive = live,
                    ),
                ),
            )
        }

        val footerChange: (Boolean) -> Unit = { hidden ->
            if (!inPlayerOverlay && isActive) footerHidden = hidden
        }
        FlowVisualsActive(active = visualsActive) {
            Box(
                modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
            ) {
                screenStateHolder.SaveableStateProvider(
                    destinationStateKey(routeTab, routeEntry),
                ) {
                    when (val current = routeEntry.destination) {
                    FlowDestination.Following -> FollowingScreen(
                        followingRepository = dependencies.followingRepository,
                        browseRepository = dependencies.browseRepository,
                        onLogin = ::requestLogin,
                        onOpenPlayer = navigation::openPlayer,
                        onOpenChannel = ::openDestinationChannel,
                        onOpenCategory = { pushDestination(FlowDestination.Category(it)) },
                        onFooterHiddenChange = footerChange,
                    )
                    FlowDestination.Browse -> BrowseScreen(
                        repository = dependencies.browseRepository,
                        showLiveChannelsSection = !anonymous,
                        onOpenSearch = { pushDestination(FlowDestination.Search) },
                        onOpenCategory = {
                            pushDestination(
                                FlowDestination.Category(it, reuseBrowseRepository = true),
                            )
                        },
                        onOpenPlayer = navigation::openPlayer,
                        onOpenChannel = ::openDestinationChannel,
                        onFooterHiddenChange = footerChange,
                    )
                    FlowDestination.Settings -> SettingsScreen(
                        settingsRepository = dependencies.settingsRepository,
                        account = following.profileUser,
                        onSwitchAccount = {
                            if (!accountActionBusy) {
                                accountActionBusy = true
                                startupOffer = false
                                loginMessage = null
                                loginLayer = LoginLayer.OFFER
                            }
                        },
                        onSignOut = {
                            if (!accountActionBusy) {
                                accountActionBusy = true
                                scope.launch {
                                    try {
                                        runCatching { dependencies.followingRepository.signOut() }
                                            .onSuccess { snackbarHostState.showSnackbar("Signed out of Twitch") }
                                            .onFailure { snackbarHostState.showSnackbar(it.toString()) }
                                    } finally {
                                        accountActionBusy = false
                                    }
                                }
                            }
                        },
                        onOpenRepository = {
                            runCatching {
                                context.startActivity(
                                    Intent(
                                        Intent.ACTION_VIEW,
                                        Uri.parse("https://github.com/namecallfilter/flow"),
                                    ).addCategory(Intent.CATEGORY_BROWSABLE),
                                )
                            }.onFailure { error ->
                                scope.launch { snackbarHostState.showSnackbar(error.toString()) }
                            }
                        },
                        onFooterHiddenChange = footerChange,
                    )
                    FlowDestination.Search -> BrowseSearchScreen(
                        repository = dependencies.searchRepository,
                        searchScope = scope,
                        isRouteActive = isActive,
                        onBack = { navigation.navigateBack() },
                        onOpenCategory = { pushDestination(FlowDestination.Category(it)) },
                        onOpenPlayer = navigation::openPlayer,
                        onOpenChannel = ::openDestinationChannel,
                        onFooterHiddenChange = footerChange,
                    )
                    is FlowDestination.Category -> {
                        val repository = if (current.reuseBrowseRepository) {
                            browseCategoryRepositories.getOrPut(current.category.id) {
                                CategoryStreamsRepository(dependencies.apiCache, current.category)
                            }
                        } else {
                            categoryRepositories.getOrPut(routeEntry.id) {
                                CategoryStreamsRepository(dependencies.apiCache, current.category)
                            }
                        }
                        CategoryStreamsScreen(
                            repository = repository,
                            isRouteActive = isActive,
                            onBack = { navigation.navigateBack() },
                            onOpenPlayer = navigation::openPlayer,
                            onOpenChannel = ::openDestinationChannel,
                            onFooterHiddenChange = footerChange,
                        )
                    }
                    is FlowDestination.Channel -> {
                        val repository = channelRepositories.getOrPut(routeEntry.id) {
                            ChannelRepository(dependencies.apiCache, current.channel.login)
                        }
                        ChannelScreen(
                            repository = repository,
                            initialChannel = current.channel,
                            isRouteActive = isActive,
                            onBack = { navigation.navigateBack() },
                            onOpenPlayer = navigation::openPlayer,
                            onOpenCategory = { pushDestination(FlowDestination.Category(it)) },
                            onFooterHiddenChange = footerChange,
                        )
                    }
                    }
                }
            }
        }
    }

    val predictiveBackInsetPx = with(LocalDensity.current) { 8.dp.toPx() }
    fun Modifier.predictiveBackTransform(
        enabled: Boolean,
        active: Boolean,
        backProgress: Float,
        swipeEdge: Int,
    ): Modifier = graphicsLayer {
        val progress = if (enabled && active) {
            backProgress.coerceIn(0f, 1f)
        } else {
            0f
        }
        val direction = if (swipeEdge == BackEventCompat.EDGE_RIGHT) -1f else 1f
        translationX = maxOf(0f, size.width / 20f - predictiveBackInsetPx) * progress * direction
        scaleX = 1f - (0.1f * progress)
        scaleY = scaleX
        shape = RoundedCornerShape(32.dp * progress)
        clip = progress > 0f
    }
    fun Modifier.navigationPredictiveBackTransform(enabled: Boolean): Modifier =
        predictiveBackTransform(
            enabled = enabled,
            active = predictiveBackActive,
            backProgress = predictiveBackProgress,
            swipeEdge = predictiveBackSwipeEdge,
        )
    fun Modifier.loginPredictiveBackTransform(enabled: Boolean): Modifier =
        predictiveBackTransform(
            enabled = enabled,
            active = loginBackActive,
            backProgress = loginBackProgress,
            swipeEdge = loginBackSwipeEdge,
        )

    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        if (startupResolved) {
            val player = navigation.activePlayer
            val backPreview = navigation.backPreview
            val rootPlayerBackPreview = predictiveBackActive &&
                navigation.currentPlayerDestinationEntry == null &&
                navigation.playerFrames.size == 1
            val baseVisible = player == null || rootPlayerBackPreview
            Box(
                Modifier
                    .fillMaxSize()
                    .flowOffstage(!baseVisible)
                    .captureFlowBackdrop(bottomBarBackdrop),
            ) {
                val currentTab = navigation.currentTab
                val currentEntry = navigation.currentEntry
                FlowTab.entries.forEach { tab ->
                    navigation.stackFor(tab).forEach { routeEntry ->
                        val isCurrent = tab == currentTab && routeEntry.id == currentEntry.id
                        val isPreview = predictiveBackActive && player == null &&
                            backPreview?.tab == tab && backPreview.entry.id == routeEntry.id
                        key("tab-${tab.name}-${routeEntry.id}") {
                            DestinationLayer(
                                routeTab = tab,
                                routeEntry = routeEntry,
                                isActive = isCurrent && player == null && loginLayer == null,
                                visualsActive = baseVisible && loginLayer == null && (isCurrent || isPreview),
                                modifier = Modifier
                                    .zIndex(if (isCurrent) 1f else 0f)
                                    .then(
                                        if (isCurrent) Modifier.navigationPredictiveBackTransform(player == null)
                                        else Modifier,
                                    )
                                    .flowOffstage(!isCurrent && !isPreview),
                            )
                        }
                    }
                }
            }
            FlowBottomBar(
                currentTab = navigation.currentTab,
                hidden = footerHidden,
                showLiveChannels = anonymous,
                onSelect = { tab ->
                    if (!predictiveBackActive) {
                        footerHidden = false
                        navigation.selectTab(tab)
                    }
                },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .zIndex(1.5f)
                    .flowOffstage(!baseVisible || imeVisible),
                backdropLayer = bottomBarBackdrop,
            )

            val playerBackPreviewIndex = if (
                predictiveBackActive && navigation.currentPlayerDestinationEntry == null
            ) {
                navigation.playerFrames.lastIndex - 1
            } else {
                -1
            }
            navigation.playerFrames.forEachIndexed { frameIndex, frame ->
                key(frame.id) {
                    val topFrame = frameIndex == navigation.playerFrames.lastIndex
                    val frameVisible = topFrame || frameIndex == playerBackPreviewIndex
                    val coveredEntry = frame.currentDestinationEntry
                    val playerLayer = 2f + (frameIndex * 100f)
                    Surface(
                        modifier = Modifier
                            .fillMaxSize()
                            .zIndex(playerLayer)
                            .navigationPredictiveBackTransform(topFrame && coveredEntry == null)
                            .flowOffstage(!frameVisible),
                        color = MaterialTheme.colorScheme.background,
                    ) {
                        FlowVisualsActive(
                            active = frameVisible && topFrame && coveredEntry == null && loginLayer == null,
                        ) {
                            PlayerScreen(
                                channel = frame.channel,
                                apiCache = dependencies.apiCache,
                                settingsRepository = dependencies.settingsRepository,
                                coveredByDestination =
                                    !frameVisible || !topFrame || coveredEntry != null || loginLayer != null,
                                onBack = navigation::closePlayer,
                                onOpenChannel = { login ->
                                    val normalized = login.trim().ifBlank { frame.channel.login.trim() }
                                    if (normalized.isNotEmpty()) {
                                        navigation.pushPlayerDestination(
                                            FlowDestination.Channel(
                                                ChannelSeed(
                                                    login = normalized,
                                                    displayName = frame.channel.name.ifBlank { normalized },
                                                    avatarImageUrl = frame.channel.avatarImageUrl,
                                                    isLive = true,
                                                ),
                                            ),
                                        )
                                    }
                                },
                                onOpenCategory = { category ->
                                    navigation.pushPlayerDestination(FlowDestination.Category(category))
                                },
                            )
                        }
                    }

                    frame.destinations.forEachIndexed { destinationIndex, destinationEntry ->
                        val isCurrent = destinationIndex == frame.destinations.lastIndex
                        val isPreview = topFrame && predictiveBackActive &&
                            destinationIndex == frame.destinations.lastIndex - 1
                        key("player-${frame.id}-destination-${destinationEntry.id}") {
                            DestinationLayer(
                                routeTab = frame.tab,
                                routeEntry = destinationEntry,
                                inPlayerOverlay = true,
                                isActive = frameVisible && topFrame && isCurrent && loginLayer == null,
                                visualsActive = frameVisible && loginLayer == null && (isCurrent || isPreview),
                                modifier = Modifier
                                    .zIndex(playerLayer + destinationIndex + 1f)
                                    .then(
                                        if (isCurrent) Modifier.navigationPredictiveBackTransform(topFrame)
                                        else Modifier,
                                    )
                                    .flowOffstage(!frameVisible || (!isCurrent && !isPreview)),
                            )
                        }
                    }
                }
            }
        }

        FlowSnackbarHost(
            hostState = snackbarHostState,
            bottomInset = if (loginLayer == null) 60.dp + bottomNavigationInset else bottomNavigationInset,
            modifier = Modifier.align(Alignment.BottomCenter).zIndex(20_000f),
        )

        if (loginLayer != null) {
            Surface(
                modifier = Modifier
                    .fillMaxSize()
                    .zIndex(10_000f)
                    .loginPredictiveBackTransform(loginLayer == LoginLayer.OFFER),
                color = MaterialTheme.colorScheme.background,
            ) {
                TwitchLoginOfferScreen(
                    statusMessage = loginMessage ?: if (
                        startupOffer && following.sessionStatus == TwitchSessionStatus.RESTORE_FAILED
                    ) {
                        "We couldn't restore your Twitch session. Log in again or continue without an account."
                    } else {
                        null
                    },
                    showCloseButton = !startupOffer,
                    loginBusy = loginInProgress,
                    continueBusy = continueInProgress,
                    onLogin = {
                        if (!dependencies.authController.config.isConfigured) {
                            scope.launch {
                                snackbarHostState.showSnackbar(TWITCH_AUTH_NOT_CONFIGURED_MESSAGE)
                            }
                        } else {
                            loginInProgress = true
                            loginLayer = LoginLayer.WEB
                        }
                    },
                    onContinue = {
                        if (startupOffer) {
                            continueInProgress = true
                            scope.launch {
                                try {
                                    when (
                                        val result = continueAsGuest(
                                            signOut = { dependencies.followingRepository.signOut() },
                                            saveDismissedChoice = {
                                                dependencies.preferences.saveLoginOfferDismissed(true)
                                            },
                                        )
                                    ) {
                                        GuestContinuationResult.Completed -> {
                                            startupOffer = false
                                            loginMessage = null
                                            loginLayer = null
                                        }
                                        is GuestContinuationResult.Failed -> {
                                            loginMessage = result.message
                                        }
                                    }
                                } finally {
                                    continueInProgress = false
                                }
                            }
                        } else {
                            loginLayer = null
                            loginInProgress = false
                            continueInProgress = false
                            accountActionBusy = false
                        }
                    },
                )
            }
        }
        if (loginLayer == LoginLayer.WEB) {
            Surface(
                modifier = Modifier
                    .fillMaxSize()
                    .zIndex(10_001f)
                    .loginPredictiveBackTransform(enabled = true),
                color = MaterialTheme.colorScheme.background,
            ) {
                TwitchLoginWebView(
                    authController = dependencies.authController,
                    onConnected = { connection ->
                        dependencies.followingRepository.applyConnection(connection)
                        scope.launch {
                            snackbarHostState.showSnackbar("Connected as ${connection.user.displayName}")
                        }
                        startupOffer = false
                        loginMessage = null
                        loginLayer = null
                        loginInProgress = false
                        continueInProgress = false
                        accountActionBusy = false
                    },
                    onCancel = {
                        loginInProgress = false
                        loginLayer = LoginLayer.OFFER
                    },
                    onError = { message ->
                        scope.launch { snackbarHostState.showSnackbar(message) }
                    },
                )
            }
        }
    }
}

/** Flutter's floating SnackBar treatment, including its scaffold-colored outlined surface. */
@Composable
internal fun FlowSnackbarHost(
    hostState: SnackbarHostState,
    modifier: Modifier = Modifier,
    bottomInset: Dp = 0.dp,
) {
    SnackbarHost(
        hostState = hostState,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = bottomInset + 8.dp),
    ) { data ->
        FlowSnackbar(data)
    }
}

@Composable
private fun FlowSnackbar(data: SnackbarData) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.background,
        contentColor = MaterialTheme.colorScheme.onSurface,
        border = BorderStroke(
            0.5.dp,
            MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
        ),
        tonalElevation = 0.dp,
        shadowElevation = 6.dp,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = data.visuals.message,
                modifier = Modifier.weight(1f).padding(start = 16.dp, top = 14.dp, bottom = 14.dp),
                style = MaterialTheme.typography.bodyMedium,
            )
            data.visuals.actionLabel?.let { actionLabel ->
                TextButton(onClick = data::performAction) {
                    Text(actionLabel)
                }
            }
            IconButton(onClick = data::dismiss) {
                Icon(Icons.Rounded.Close, contentDescription = "Close")
            }
        }
    }
}

private fun destinationStateKey(
    tab: FlowTab,
    entry: com.namecallfilter.flow.ui.navigation.FlowNavigationEntry,
): String = buildString {
    append(tab.name)
    append(':')
    append(entry.id)
    append(':')
    append(
        when (val destination = entry.destination) {
            FlowDestination.Following -> "following"
            FlowDestination.Browse -> "browse"
            FlowDestination.Settings -> "settings"
            FlowDestination.Search -> "search"
            is FlowDestination.Category -> "category:${destination.category.id}"
            is FlowDestination.Channel -> "channel:${destination.channel.login.lowercase()}"
        },
    )
}

@Composable
private fun SystemBarAppearance(themeMode: FlowThemeMode) {
    val view = LocalView.current
    val systemDark = isSystemInDarkTheme()
    val dark = when (themeMode) {
        FlowThemeMode.LIGHT -> false
        FlowThemeMode.DARK -> true
        FlowThemeMode.SYSTEM -> systemDark
    }
    SideEffect {
        val activity = view.context.findActivity() ?: return@SideEffect
        val window = activity.window
        window.statusBarColor = Color.Transparent.toArgb()
        window.navigationBarColor = Color.Transparent.toArgb()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        WindowCompat.getInsetsController(window, view).apply {
            isAppearanceLightStatusBars = !dark
            isAppearanceLightNavigationBars = !dark
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
