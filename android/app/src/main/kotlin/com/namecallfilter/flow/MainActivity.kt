package com.namecallfilter.flow

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.PictureInPictureUiState
import android.app.RemoteAction
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Rect
import android.graphics.drawable.Icon
import android.media.session.MediaSession
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Rational
import android.webkit.CookieManager
import androidx.core.content.ContextCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.upstream.experimental.ExperimentalBandwidthMeter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.min
import kotlin.math.roundToInt

@UnstableApi
class MainActivity : FlutterActivity() {
    // Keep measured capacity when opening another player, including long-segment VODs.
    internal val playbackBandwidthMeter by lazy {
        ExperimentalBandwidthMeter.Builder(applicationContext).build()
    }
    private var activePlayer: TwitchPlayerView? = null
    private var wasInPictureInPicture = false
    private var playbackVisible = false
    private var playbackResumed = false
    private var backgroundAudioState: Pair<TwitchPlayerView, Boolean>? = null
    private val audioMediaSession = lazy {
        MediaSession(this, "Flow").apply {
            setSessionActivity(PendingIntent.getActivity(
                this@MainActivity, 0, Intent(this@MainActivity, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ))
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    activePlayer?.let { if (!it.pictureInPicturePlaying) it.togglePlayback() }
                }

                override fun onPause() {
                    activePlayer?.let { if (it.pictureInPicturePlaying) it.togglePlayback() }
                }

                override fun onSeekTo(pos: Long) {
                    activePlayer?.seekTo(pos)
                }
            })
        }
    }
    private var enteringPictureInPicture = false
    private var pictureInPictureSourceRect: Rect? = null
    private var pictureInPictureVideoRect: Rect? = null
    private var pictureInPictureDrawTarget: Rect? = null
    private var pictureInPictureDrawDeadlineMs = 0L
    private var pictureInPictureActionState: Pair<Boolean, Boolean>? = null
    private val pictureInPictureReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !isInPictureInPictureMode) return
            when (intent.getStringExtra("control")) {
                "rewind" -> activePlayer?.seekBy(-10_000)
                "toggle" -> activePlayer?.togglePlayback()
                "forward" -> activePlayer?.seekBy(10_000)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (supportsPictureInPicture()) {
            ContextCompat.registerReceiver(
                this,
                pictureInPictureReceiver,
                IntentFilter("$packageName.PIP_CONTROL"),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.decorView.viewTreeObserver.addOnPreDrawListener(::pictureInPictureFrameReady)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "flow/twitch_player",
            TwitchPlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger, this),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow/cookie_extractor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractTwitchAuthToken" -> result.success(extractTwitchCookie("auth-token"))
                    "extractTwitchDeviceId" -> result.success(extractTwitchCookie("unique_id"))
                    "getTwitchIntegrityContext" -> {
                        val authorization = call.argument<String>("authorization")
                        if (authorization.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            TwitchIntegritySession(this).start(authorization) { headers ->
                                result.success(headers)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow/external_url")
            .setMethodCallHandler { call, result ->
                if (call.method == "openExternalUrl") {
                    openExternalUrl(call.arguments as? String, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    internal fun registerPlayer(player: TwitchPlayerView) {
        val previousPlayer = activePlayer
        activePlayer = player
        previousPlayer?.pauseForBackground(resumeOnReturn = false)
        pictureInPictureSourceRect = null
        pictureInPictureVideoRect = null
        if (!playbackVisible && !player.isAudioOnly) player.pauseForBackground(resumeOnReturn = true)
        updatePictureInPicture()
    }

    internal fun unregisterPlayer(player: TwitchPlayerView) {
        if (activePlayer === player) {
            activePlayer = null
            pictureInPictureSourceRect = null
            pictureInPictureVideoRect = null
            updatePictureInPicture()
        }
    }

    internal fun updatePictureInPicture() {
        updateAudioPlayback()
        if (!supportsPictureInPicture()) return
        val videoRect = activePlayer?.pictureInPictureSourceRect()
        if (isInPictureInPictureMode) {
            pictureInPictureVideoRect = videoRect
            val actionState = activePlayer?.let { it.pictureInPicturePlaying to it.canSeekInPictureInPicture }
            if (actionState != pictureInPictureActionState) {
                setPictureInPictureParams(
                    PictureInPictureParams.Builder().setActions(pictureInPictureActions()).build(),
                )
            }
            return
        }
        if (!playbackResumed || enteringPictureInPicture) return
        // Flutter applies the restored platform-view layout after the activity resumes.
        if (pictureInPictureVideoRect != null && videoRect == pictureInPictureVideoRect) return
        pictureInPictureVideoRect = null
        setPictureInPictureParams(pictureInPictureParams())
    }

    private fun updateAudioPlayback() {
        val player = activePlayer?.takeIf { it.canPublishMediaSession && (playbackVisible || it.isAudioOnly) }
        val state = player?.let { it to it.pictureInPicturePlaying }
        if (player != null) {
            val session = audioMediaSession.value
            session.setMetadata(player.mediaMetadata)
            session.setPlaybackState(player.mediaPlaybackState)
            session.isActive = true
            if (state != backgroundAudioState) {
                ContextCompat.startForegroundService(
                    this,
                    Intent(this, AudioPlaybackService::class.java).putExtra("session", session.sessionToken),
                )
            }
        } else if (backgroundAudioState != null) {
            audioMediaSession.value.isActive = false
            stopService(Intent(this, AudioPlaybackService::class.java))
        }
        backgroundAudioState = state
    }

    private fun supportsPictureInPicture() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun pictureInPictureFrameReady(): Boolean {
        if (pictureInPictureDrawDeadlineMs == 0L) return true
        val player = activePlayer
        val target = pictureInPictureDrawTarget
        if (player == null || target == null || SystemClock.uptimeMillis() >= pictureInPictureDrawDeadlineMs) {
            pictureInPictureDrawDeadlineMs = 0L
            return true
        }
        if (!player.isVideoViewReady(target.width(), target.height())) return false
        pictureInPictureDrawDeadlineMs = 0L
        return true
    }

    private fun pictureInPictureParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .setActions(pictureInPictureActions())
        // The exit animation needs the video's bounds in the normal activity, not the PiP window.
        if (!enteringPictureInPicture && !isInPictureInPictureMode) {
            activePlayer?.pictureInPictureSourceRect()?.let {
                if (it != pictureInPictureSourceRect) {
                    pictureInPictureSourceRect = it
                    builder.setSourceRectHint(it)
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(activePlayer?.canEnterPictureInPicture == true)
            builder.setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    private fun pictureInPictureActions(): List<RemoteAction> {
        pictureInPictureActionState = activePlayer?.let { it.pictureInPicturePlaying to it.canSeekInPictureInPicture }
        val (playing, seekable) = pictureInPictureActionState ?: return emptyList()
        return buildList {
            if (seekable) add(pictureInPictureAction(R.drawable.ic_pip_rewind, "Rewind 10 seconds", "rewind"))
            add(pictureInPictureAction(
                if (playing) R.drawable.ic_pip_pause else R.drawable.ic_pip_play,
                if (playing) "Pause" else "Play",
                "toggle",
            ))
            if (seekable) add(pictureInPictureAction(R.drawable.ic_pip_forward, "Forward 10 seconds", "forward"))
        }
    }

    private fun pictureInPictureAction(iconId: Int, title: String, control: String) = RemoteAction(
        Icon.createWithResource(this, iconId),
        title,
        title,
        PendingIntent.getBroadcast(
            this,
            iconId,
            Intent("$packageName.PIP_CONTROL").setPackage(packageName).putExtra("control", control),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ),
    )

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (supportsPictureInPicture() && activePlayer?.canEnterPictureInPicture == true) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                enterPictureInPictureMode(pictureInPictureParams())
            }
            enteringPictureInPicture = true
        }
    }

    override fun onPictureInPictureUiStateChanged(pipState: PictureInPictureUiState) {
        super.onPictureInPictureUiStateChanged(pipState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM && pipState.isTransitioningToPip) {
            enteringPictureInPicture = true
            activePlayer?.beginPictureInPictureTransition()
        }
    }

    override fun onPictureInPictureModeChanged(active: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(active, newConfig)
        // Keep the last valid window frame until Flutter applies the native video's new size.
        pictureInPictureDrawTarget = pictureInPictureSourceRect?.let { normalRect ->
            if (active) {
                val density = resources.displayMetrics.density
                val scale = min(newConfig.screenWidthDp * density / normalRect.width(), newConfig.screenHeightDp * density / normalRect.height())
                Rect(0, 0, (normalRect.width() * scale).roundToInt(), (normalRect.height() * scale).roundToInt())
            } else {
                normalRect
            }
        }
        pictureInPictureDrawDeadlineMs = SystemClock.uptimeMillis() + 500
        enteringPictureInPicture = active
        if (active) wasInPictureInPicture = true
        activePlayer?.setPictureInPicture(active)
    }

    override fun onStart() {
        super.onStart()
        playbackVisible = true
        activePlayer?.resumeFromBackground()
    }

    override fun onResume() {
        super.onResume()
        playbackResumed = true
        wasInPictureInPicture = false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !isInPictureInPictureMode) {
            enteringPictureInPicture = false
            activePlayer?.setPictureInPicture(false)
        }
        updatePictureInPicture()
    }

    override fun onPause() {
        playbackResumed = false
        super.onPause()
    }

    override fun onStop() {
        playbackVisible = false
        if (activePlayer?.isAudioOnly != true) {
            activePlayer?.pauseForBackground(resumeOnReturn = !wasInPictureInPicture)
        }
        if (wasInPictureInPicture) activePlayer?.dismissPictureInPicture()
        updateAudioPlayback()
        super.onStop()
    }

    override fun onDestroy() {
        if (audioMediaSession.isInitialized()) audioMediaSession.value.release()
        stopService(Intent(this, AudioPlaybackService::class.java))
        if (supportsPictureInPicture()) unregisterReceiver(pictureInPictureReceiver)
        super.onDestroy()
    }

    private fun openExternalUrl(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("invalid_url", "URL is required.", null)
            return
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addCategory(Intent.CATEGORY_BROWSABLE)

        try {
            startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        }
    }
}

internal fun extractTwitchCookie(
    name: String,
    cookieForUrl: (String) -> String? = CookieManager.getInstance()::getCookie,
): String? = sequenceOf("https://twitch.tv", "https://www.twitch.tv")
    .firstNotNullOfOrNull { url ->
        cookieForUrl(url)
            ?.split(";")
            ?.map { it.trim() }
            ?.firstOrNull { it.startsWith("$name=") }
            ?.substringAfter("$name=")
    }
