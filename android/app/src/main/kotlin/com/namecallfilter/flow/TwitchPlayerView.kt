package com.namecallfilter.flow

import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.media.AudioManager
import android.media.AudioRecordingConfiguration
import android.media.MediaMetadata
import android.media.MediaRecorder
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewTreeObserver
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.Metadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.Tracks
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.chunk.MediaChunk
import androidx.media3.exoplayer.source.chunk.MediaChunkIterator
import androidx.media3.exoplayer.trackselection.AdaptiveTrackSelection
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.trackselection.ExoTrackSelection
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.IOException
import java.net.URI
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.roundToInt

@UnstableApi
internal class TwitchPlayerView(
    context: Context,
    private val activity: MainActivity,
    messenger: BinaryMessenger,
    viewId: Int,
    private val initialUrl: String?,
    private var mediaTitle: String,
    private var mediaArtist: String,
    private var mediaArtworkUrl: String?,
    initialQualityId: String,
    private val initialPositionMs: Long,
    private val isLive: Boolean,
    private var pictureInPictureEnabled: Boolean,
    private val proxyUrls: List<String>,
) : PlatformView {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val playerView = LayoutInflater.from(context).inflate(
        R.layout.flow_twitch_player,
        null,
        false,
    ) as PlayerView
    private val methodChannel = MethodChannel(messenger, "flow/twitch_player/$viewId")
    private val eventChannel = EventChannel(messenger, "flow/twitch_player/$viewId/events")
    private val layoutObserver = activity.window.decorView.viewTreeObserver
    private val pictureInPictureLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
        activity.updatePictureInPicture()
        updateDictationPlayback()
    }
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private var voiceRecognitionActive = false
    private var dictationPlayback = false
    private var volumeBeforeDictation = 1f
    private val recordingCallback = object : AudioManager.AudioRecordingCallback() {
        override fun onRecordingConfigChanged(configs: MutableList<AudioRecordingConfiguration>) {
            voiceRecognitionActive = configs.any {
                it.clientAudioSource == MediaRecorder.AudioSource.VOICE_RECOGNITION
            }
            updateDictationPlayback()
        }
    }
    private val liveSpeedControl = TwitchLatencyPlaybackSpeedControl()
    private val player: ExoPlayer
    private var eventSink: EventChannel.EventSink? = null
    private var latencySession: TwitchLatencySession? = null
    private var metadataListener: Player.Listener? = null
    private var sessionGeneration = 0L
    private var latestLatencyMs: Long? = null
    private var lastPrimaryLatencyRealtimeMs: Long? = null
    private var latestError: String? = null
    private var latestQualities: List<Map<String, Any?>> = emptyList()
    @Volatile private var selectedQualityId = initialQualityId
    private var currentQualityLabel: String? = null
    private val qualityOverrides = mutableMapOf<String, TrackSelectionOverride>()
    @Volatile private var adaptiveQualityIds = emptySet<String>()
    @Volatile private var qualityOverrideActive = false
    private val adCues = mutableMapOf<String, TwitchAdCue>()
    private val stitchedAdLatencyFallback = StitchedAdLatencyFallback()
    private var latestAdEvent: Map<String, Any?> = inactiveAdEvent()
    private var hasRenderedFirstFrame = false
    private var loadStartedRealtimeMs = 0L
    private var lastPlaybackLogRealtimeMs = 0L
    private var initialized = false
    private var disposed = false
    private var stopped = false
    private var resumeOnForeground = false
    private var pictureInPicture = false
    val isAudioOnly: Boolean
        get() = selectedQualityId == AUDIO_ONLY_QUALITY_ID
    val canPublishMediaSession: Boolean
        get() = !disposed && !stopped && player.playbackState != Player.STATE_ENDED && player.playerError == null
    val mediaMetadata: MediaMetadata
        get() = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, mediaTitle)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, mediaArtist)
            .putString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI, mediaArtworkUrl)
            .apply {
                if (!isLive && player.duration > 0) putLong(MediaMetadata.METADATA_KEY_DURATION, player.duration)
            }
            .build()
    val mediaPlaybackState: PlaybackState
        get() {
            val state = when {
                player.playbackState == Player.STATE_ENDED -> PlaybackState.STATE_STOPPED
                !player.playWhenReady -> PlaybackState.STATE_PAUSED
                player.playbackState == Player.STATE_IDLE || player.playbackState == Player.STATE_BUFFERING ->
                    PlaybackState.STATE_BUFFERING
                else -> PlaybackState.STATE_PLAYING
            }
            val actions = PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE
            return PlaybackState.Builder()
                .setActions(if (canSeekInPictureInPicture) actions or PlaybackState.ACTION_SEEK_TO else actions)
                .setState(
                    state,
                    if (isLive) PlaybackState.PLAYBACK_POSITION_UNKNOWN else player.currentPosition,
                    if (player.isPlaying) player.playbackParameters.speed else 0f,
                )
                .build()
        }
    val hasPictureInPictureContent: Boolean
        get() = pictureInPictureEnabled && !isAudioOnly && !disposed
    val canEnterPictureInPicture: Boolean
        get() = hasPictureInPictureContent && initialized && player.playWhenReady &&
            player.playbackState != Player.STATE_IDLE && player.playbackState != Player.STATE_ENDED &&
            player.playerError == null
    val pictureInPicturePlaying: Boolean
        get() = player.playWhenReady && player.playbackState != Player.STATE_ENDED
    val canSeekInPictureInPicture: Boolean
        get() = !isLive && player.isCurrentMediaItemSeekable
    private val adProgressTicker = object : Runnable {
        override fun run() {
            if (disposed) {
                return
            }
            if (dictationPlayback) updateDictationPlayback()
            updateAdProgress()
            if (!isLive) emitState(updateSystemControls = false)
            val now = SystemClock.elapsedRealtime()
            if (isLive && player.playWhenReady && now - lastPlaybackLogRealtimeMs >= 10_000L) {
                lastPlaybackLogRealtimeMs = now
                Log.d(
                    LOG_TAG,
                    "playback state=${player.playbackState} buffered=${player.totalBufferedDuration}ms " +
                        "latency=${latestLatencyMs}ms speed=${liveSpeedControl.lastAdjustedPlaybackSpeed} " +
                        "target=${liveSpeedControl.getTargetLiveOffsetUs() / 1000}ms",
                )
            }
            mainHandler.postDelayed(this, AD_PROGRESS_INTERVAL_MS)
        }
    }
    private val playbackListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_BUFFERING) {
                if (hasRenderedFirstFrame && player.playWhenReady) {
                    Log.d(
                        LOG_TAG,
                        "rebuffer buffered=${player.totalBufferedDuration}ms " +
                            "media3LiveOffset=${player.currentLiveOffset}ms " +
                            "measuredLatency=${latestLatencyMs}ms",
                    )
                }
            }
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emitState()
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            updateDictationPlayback()
            if (!playWhenReady) {
                liveSpeedControl.invalidateMeasurementForDiscontinuity("pause")
            }
            emitState()
        }

        override fun onPlaybackSuppressionReasonChanged(playbackSuppressionReason: Int) {
            updateDictationPlayback()
        }

        override fun onPlayerError(error: PlaybackException) {
            if (isLive && error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
                Log.d(LOG_TAG, "recovering behind live window at default position")
                liveSpeedControl.reset()
                player.seekToDefaultPosition()
                player.prepare()
                return
            }
            latestError = error.message ?: "The stream could not be played."
            Log.e(LOG_TAG, "playback failed", error)
            activity.updatePictureInPicture()
            emitError(latestError!!)
        }

        override fun onRenderedFirstFrame() {
            if (!hasRenderedFirstFrame) {
                Log.d(LOG_TAG, "first frame after=${SystemClock.elapsedRealtime() - loadStartedRealtimeMs}ms")
            }
            hasRenderedFirstFrame = true
        }

        override fun onTimelineChanged(timeline: Timeline, reason: Int) {
            activity.updatePictureInPicture()
        }

        override fun onTracksChanged(tracks: Tracks) {
            updateQualities(tracks)
        }
    }

    init {
        val trackSelector = DefaultTrackSelector(
            context,
            adaptiveTrackSelectionFactory(
                isLive = isLive,
                preferredQualityId = { selectedQualityId },
                onVideoSelection = { ids -> if (!qualityOverrideActive) adaptiveQualityIds = ids },
            ),
        )
        // Auto follows decoder support and connection capacity, including source
        // renditions above the display size and transitions between AVC and HEVC.
        trackSelector.parameters = trackSelector.parameters.buildUpon()
            .clearViewportSizeConstraints()
            .setAllowVideoMixedMimeTypeAdaptiveness(true)
            .build()
        // Keep capacity measured by previous playback and learn from completed
        // segments immediately; server-paced prefetch isn't a bandwidth sample.
        val bandwidthMeter = activity.playbackBandwidthMeter
        player = ExoPlayer.Builder(context)
            .setTrackSelector(trackSelector)
            .setLoadControl(playbackLoadControl(isLive))
            .setBandwidthMeter(bandwidthMeter)
            .setLivePlaybackSpeedControl(liveSpeedControl)
            .build()
        player.setAudioAttributes(AudioAttributes.DEFAULT, true)
        player.setHandleAudioBecomingNoisy(true)
        player.playWhenReady = true
        player.addListener(playbackListener)
        player.addAnalyticsListener(object : AnalyticsListener {
            override fun onDroppedVideoFrames(
                eventTime: AnalyticsListener.EventTime,
                droppedFrames: Int,
                elapsedMs: Long,
            ) {
                Log.d(LOG_TAG, "dropped frames=$droppedFrames interval=${elapsedMs}ms")
            }

            override fun onVideoInputFormatChanged(
                eventTime: AnalyticsListener.EventTime,
                format: Format,
                decoderReuseEvaluation: DecoderReuseEvaluation?,
            ) {
                val label = qualityLabel(format)
                if (currentQualityLabel != label) {
                    currentQualityLabel = label
                    Log.d(
                        LOG_TAG,
                        "video quality=$label mode=$selectedQualityId " +
                            "codec=${format.sampleMimeType} reuse=${decoderReuseEvaluation?.result} " +
                            "bandwidth=${bandwidthMeter.bitrateEstimate}bps " +
                            "buffered=${player.totalBufferedDuration}ms",
                    )
                    emitQualities()
                }
            }
        })
        playerView.player = player
        playerView.setShutterBackgroundColor(Color.BLACK)
        Log.d(
            LOG_TAG,
            "live playback target=${TARGET_LIVE_OFFSET_MS}ms " +
                "transc_r speed range=${TwitchLatencyPlaybackSpeedControl.MIN_PLAYBACK_SPEED}x-" +
                "${TwitchLatencyPlaybackSpeedControl.MAX_PLAYBACK_SPEED}x",
        )

        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    emitState()
                    emitLatency(latestLatencyMs)
                    emitQualities()
                    emit(latestAdEvent)
                    setPictureInPicture(pictureInPicture)
                    latestError?.let(::emitError)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    if (!initialized && !stopped) {
                        initialized = true
                        initialUrl?.takeIf { it.isNotBlank() }?.let(::load)
                    }
                    result.success(null)
                }

                "play" -> {
                    resumeAtLiveEdge()
                    result.success(null)
                }

                "pause" -> {
                    resumeOnForeground = false
                    player.pause()
                    result.success(null)
                }

                "stop" -> {
                    stopped = true
                    resumeOnForeground = false
                    sessionGeneration++
                    player.pause()
                    player.stop()
                    result.success(null)
                }

                "togglePlayback" -> {
                    togglePlayback()
                    result.success(null)
                }

                "jumpToLive" -> {
                    jumpToLiveEdge()
                    result.success(null)
                }

                "seekTo" -> {
                    val positionMs = (call.arguments as? Number)?.toLong()
                    if (isLive || positionMs == null || positionMs < 0) {
                        result.error("invalid_seek", "A recording position is required.", null)
                    } else {
                        seekTo(positionMs)
                        result.success(null)
                    }
                }

                "setQuality" -> setQuality(call.arguments as? String, result)

                "setMediaMetadata" -> {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val artworkUrl = call.argument<String>("artworkUrl")
                    if (title == null || artist == null) {
                        result.error("invalid_metadata", "A title and artist are required.", null)
                    } else {
                        if (title != mediaTitle || artist != mediaArtist || artworkUrl != mediaArtworkUrl) {
                            mediaTitle = title
                            mediaArtist = artist
                            mediaArtworkUrl = artworkUrl
                            activity.updatePictureInPicture()
                        }
                        result.success(null)
                    }
                }

                "setPictureInPictureEnabled" -> {
                    val enabled = call.arguments as? Boolean
                    if (enabled == null) {
                        result.error("invalid_pip_setting", "A picture-in-picture preference is required.", null)
                    } else {
                        pictureInPictureEnabled = enabled
                        activity.updatePictureInPicture()
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        layoutObserver.addOnGlobalLayoutListener(pictureInPictureLayoutListener)
        audioManager.registerAudioRecordingCallback(recordingCallback, mainHandler)
        activity.registerPlayer(this)
        mainHandler.post(adProgressTicker)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        disposed = true
        audioManager.unregisterAudioRecordingCallback(recordingCallback)
        if (layoutObserver.isAlive) layoutObserver.removeOnGlobalLayoutListener(pictureInPictureLayoutListener)
        activity.unregisterPlayer(this)
        mainHandler.removeCallbacks(adProgressTicker)
        sessionGeneration++
        liveSpeedControl.reset()
        metadataListener?.let(player::removeListener)
        metadataListener = null
        latencySession = null
        adCues.clear()
        stitchedAdLatencyFallback.reset()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        playerView.player = null
        player.release()
    }

    private fun updateDictationPlayback() {
        if (disposed) return
        val keepVideoPlaying = shouldKeepVideoDuringDictation(
            keyboardVisible = ViewCompat.getRootWindowInsets(activity.window.decorView)
                ?.isVisible(WindowInsetsCompat.Type.ime()) == true,
            voiceRecognitionActive = voiceRecognitionActive,
            playWhenReady = player.playWhenReady && !stopped,
            audioOnly = isAudioOnly,
            audioMode = audioManager.mode,
            suppressionReason = player.playbackSuppressionReason,
            alreadyActive = dictationPlayback,
        )
        if (dictationPlayback == keepVideoPlaying) return
        dictationPlayback = keepVideoPlaying
        if (keepVideoPlaying) {
            // Dictation owns audio focus; keep only the muted video advancing.
            volumeBeforeDictation = player.volume
            player.volume = 0f
            player.setAudioAttributes(AudioAttributes.DEFAULT, false)
        } else {
            player.setAudioAttributes(AudioAttributes.DEFAULT, true)
            player.volume = volumeBeforeDictation
        }
    }

    fun pauseForBackground(resumeOnReturn: Boolean) {
        resumeOnForeground = resumeOnReturn && player.playWhenReady && player.playbackState != Player.STATE_ENDED
        player.pause()
    }

    fun togglePlayback() {
        if (player.playWhenReady && (isLive || player.playbackState != Player.STATE_ENDED)) {
            player.pause()
        } else {
            resumeAtLiveEdge()
        }
    }

    fun seekBy(offsetMs: Long) {
        seekTo(player.currentPosition + offsetMs)
    }

    fun seekTo(positionMs: Long) {
        if (!isLive) {
            player.seekTo(positionMs.coerceIn(0L, player.duration.coerceAtLeast(0L)))
            emitState()
        }
    }

    fun resumeFromBackground() {
        if (resumeOnForeground) {
            resumeOnForeground = false
            resumeAtLiveEdge()
        }
    }

    fun setPictureInPicture(active: Boolean) {
        pictureInPicture = active
        emit(mapOf("type" to "pip", "active" to active))
    }

    fun beginPictureInPictureTransition() {
        emit(mapOf("type" to "pipTransition", "active" to true))
    }

    fun pictureInPictureSourceRect(): Rect? = Rect().takeIf { rect ->
        playerView.videoSurfaceView?.getGlobalVisibleRect(rect) == true && !rect.isEmpty
    }

    fun isVideoViewReady(width: Int, height: Int): Boolean = playerView.videoSurfaceView?.let {
        it.isShown && abs(it.width - width) <= 1 && abs(it.height - height) <= 1
    } ?: true

    fun dismissPictureInPicture() {
        emit(mapOf("type" to "dismissed"))
    }

    private fun load(url: String) {
        if (stopped || disposed) return
        val playbackUrl = withDeviceSupportedTwitchCodecs(url)
        val generation = ++sessionGeneration
        liveSpeedControl.reset()
        loadStartedRealtimeMs = SystemClock.elapsedRealtime()
        lastPlaybackLogRealtimeMs = loadStartedRealtimeMs
        latestLatencyMs = null
        lastPrimaryLatencyRealtimeMs = null
        latestError = null
        latestQualities = emptyList()
        adCues.clear()
        stitchedAdLatencyFallback.reset()
        qualityOverrides.clear()
        adaptiveQualityIds = emptySet()
        qualityOverrideActive = false
        currentQualityLabel = null
        player.trackSelectionParameters = qualityParameters(player.trackSelectionParameters, selectedQualityId)
        hasRenderedFirstFrame = false
        if (!isLive) {
            val dataSourceFactory = DefaultDataSource.Factory(
                playerView.context,
                DefaultHttpDataSource.Factory().setUserAgent(USER_AGENT),
            )
            player.setMediaSource(
                HlsMediaSource.Factory(dataSourceFactory).createMediaSource(
                    MediaItem.Builder()
                        .setUri(Uri.parse(playbackUrl))
                        .setMimeType(MimeTypes.APPLICATION_M3U8)
                        .build(),
                ),
                // Media3 treats zero as the placeholder default and moves EVENT VODs to the live edge.
                initialPositionMs.coerceAtLeast(1L),
            )
            player.prepare()
            return
        }
        emitLatency(null)
        emitQualities()
        emitAd(null)

        metadataListener?.let(player::removeListener)
        val session = TwitchLatencySession(
            onAcceptedLatency = { latencyMs ->
                if (generation == sessionGeneration && player.playWhenReady) {
                    val measuredRealtimeMs = SystemClock.elapsedRealtime()
                    lastPrimaryLatencyRealtimeMs = measuredRealtimeMs
                    if (stitchedAdLatencyFallback.onAcceptedPrimaryLatency()) {
                        Log.d(LOG_TAG, "latency switched from stitched-ad timeline to transc_r")
                    }
                    emitLatency(latencyMs)
                    liveSpeedControl.updateLatencyMeasurement(latencyMs)
                }
            },
        )
        latencySession = session
        metadataListener = object : Player.Listener {
            override fun onMetadata(metadata: Metadata) {
                if (generation == sessionGeneration) {
                    session.handleMetadata(metadata)
                }
            }
        }.also(player::addListener)

        val proxyClients = if (proxyUrls.isEmpty()) {
            emptyList()
        } else {
            proxyUrls.mapNotNull { proxyUrl ->
                buildHttpProxyClient(
                    listOf(proxyUrl),
                ) { host, proxyType ->
                    Log.d(LOG_TAG, "ad proxy connection host=$host route=$proxyType")
                }
            }
        }
        val directDataSourceFactory = DefaultDataSource.Factory(
            playerView.context,
            DefaultHttpDataSource.Factory().setUserAgent(USER_AGENT),
        )
        val proxyDataSourceFactories = proxyClients.map {
            DefaultDataSource.Factory(
                playerView.context,
                OkHttpDataSource.Factory(it).setUserAgent(USER_AGENT),
            )
        }
        if (proxyDataSourceFactories.isNotEmpty()) {
            Log.d(LOG_TAG, "adaptive ad proxy active (${proxyUrls.size} endpoints)")
        }
        val prefetchSegments = TwitchPrefetchSegments()
        val hlsDataSourceFactory = AdaptiveTwitchHlsDataSourceFactory(
            manifestResolver = TwitchPlaybackCoordinator(
                rootUsherUri = playbackUrl,
                directFactory = directDataSourceFactory,
                proxyFactories = proxyDataSourceFactories,
                freshRootUsherUri = ::refreshPlaybackUri,
                onEvent = { message -> Log.d(LOG_TAG, "adaptive ad proxy: $message") },
            ),
            directFactory = ResolvingDataSource.Factory(directDataSourceFactory) { dataSpec ->
                val flags = prefetchSegments.flagsFor(dataSpec.uri.toString(), dataSpec.flags)
                if (flags == dataSpec.flags) dataSpec else dataSpec.buildUpon().setFlags(flags).build()
            },
        )
        val mediaSource = HlsMediaSource.Factory(hlsDataSourceFactory)
            .setExtractorFactory(TwitchEmsgMetadataBridgeExtractorFactory())
            .setMetadataType(HlsMediaSource.METADATA_TYPE_ID3)
            .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy())
            .setPlaylistParserFactory(
                ServerTimePlaylistParserFactory(
                    latencySession = session,
                    prefetchSegments = prefetchSegments,
                    onAdCues = { parsedCues ->
                        mainHandler.post {
                            if (generation != sessionGeneration) {
                                return@post
                            }
                            parsedCues.forEach { cue -> adCues[cue.id] = cue }
                            updateAdProgress()
                        }
                    },
                ),
            )
            .createMediaSource(
                MediaItem.Builder()
                    .setUri(Uri.parse(playbackUrl))
                    .setMimeType(MimeTypes.APPLICATION_M3U8)
                    .setLiveConfiguration(
                        MediaItem.LiveConfiguration.Builder()
                            .setTargetOffsetMs(TARGET_LIVE_OFFSET_MS)
                            .setMinOffsetMs(MIN_LIVE_OFFSET_MS)
                            .setMaxOffsetMs(MAX_LIVE_OFFSET_MS)
                            .setMinPlaybackSpeed(TwitchLatencyPlaybackSpeedControl.MIN_PLAYBACK_SPEED)
                            .setMaxPlaybackSpeed(TwitchLatencyPlaybackSpeedControl.MAX_PLAYBACK_SPEED)
                            .build(),
                    )
                    .build(),
            )

        player.setMediaSource(mediaSource)
        player.prepare()
    }

    private fun refreshPlaybackUri(): String {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            throw IOException("Playback URI refresh cannot run on the main thread")
        }
        val completed = CountDownLatch(1)
        var refreshedUrl: String? = null
        var refreshError: IOException? = null
        mainHandler.post {
            if (disposed) {
                refreshError = IOException("Twitch player was disposed")
                completed.countDown()
                return@post
            }
            methodChannel.invokeMethod(
                "refreshPlaybackUri",
                null,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val value = result as? String
                        val uri = value?.let { runCatching { URI(it) }.getOrNull() }
                        if (
                            value.isNullOrBlank() ||
                            uri?.scheme != "https" ||
                            uri.host.isNullOrBlank()
                        ) {
                            refreshError = IOException("Flutter returned an invalid playback URI")
                        } else {
                            refreshedUrl = withDeviceSupportedTwitchCodecs(value)
                        }
                        completed.countDown()
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        refreshError = IOException(message ?: "Playback URI refresh failed ($code)")
                        completed.countDown()
                    }

                    override fun notImplemented() {
                        refreshError = IOException("Playback URI refresh is unavailable")
                        completed.countDown()
                    }
                },
            )
        }
        try {
            if (!completed.await(PLAYBACK_URI_REFRESH_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                throw IOException("Playback URI refresh timed out")
            }
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            throw IOException("Playback URI refresh was interrupted", error)
        }
        refreshError?.let { throw it }
        return refreshedUrl ?: throw IOException("Playback URI refresh returned no URL")
    }

    private fun resumeAtLiveEdge() {
        if (stopped || disposed) return
        if (isLive) {
            jumpToLiveEdge()
        } else {
            if (player.playbackState == Player.STATE_ENDED) player.seekTo(0)
            player.play()
        }
    }

    private fun jumpToLiveEdge() {
        if (!isLive || stopped || disposed) return
        latestError = null
        val measuredLatencyMs = latestLatencyMs
        val measurementAgeMs = lastPrimaryLatencyRealtimeMs?.let { SystemClock.elapsedRealtime() - it }
        val liveShiftMs = if (
            player.isPlaying && measurementAgeMs != null &&
            measurementAgeMs in 0..PRIMARY_LATENCY_FRESHNESS_MS && measuredLatencyMs != null
        ) measuredLatencyMs - TARGET_LIVE_OFFSET_MS else null
        if (liveShiftMs != null && liveShiftMs <= 100L) {
            Log.d(LOG_TAG, "live seek skipped at target latency=${measuredLatencyMs}ms")
            return
        }
        liveSpeedControl.reset()
        if (liveShiftMs != null) {
            Log.d(LOG_TAG, "live seek forward=${liveShiftMs}ms latency=${measuredLatencyMs}ms")
            player.seekTo(player.currentPosition + liveShiftMs)
        } else {
            Log.d(LOG_TAG, "live seek to precise default latency=${measuredLatencyMs}ms")
            player.seekToDefaultPosition()
        }
        if (player.playbackState == Player.STATE_IDLE) player.prepare()
        player.play()
    }

    private fun updateAdProgress() {
        val playbackEpochMs = currentPlaybackEpochMs() ?: return
        val cueIterator = adCues.entries.iterator()
        while (cueIterator.hasNext()) {
            if (cueIterator.next().value.endEpochMs < playbackEpochMs - EXPIRED_AD_CUE_RETENTION_MS) {
                cueIterator.remove()
            }
        }
        val progress = twitchAdProgress(adCues.values, playbackEpochMs)
        stitchedAdLatencyFallback.onAdProgress(progress != null)
        emitAd(progress)

        val primaryLatencyIsFresh = lastPrimaryLatencyRealtimeMs?.let { measuredAtMs ->
            SystemClock.elapsedRealtime() - measuredAtMs <= PRIMARY_LATENCY_FRESHNESS_MS
        } == true
        if (
            player.playWhenReady &&
            stitchedAdLatencyFallback.shouldUseTimeline(primaryLatencyIsFresh)
        ) {
            adFallbackLatencyMs(
                clientNowMs = System.currentTimeMillis(),
                serverOffsetMs = latencySession?.serverOffsetMs,
                playbackEpochMs = playbackEpochMs,
            )?.let { latencyMs ->
                emitLatency(latencyMs)
            }
        }
    }

    private fun currentPlaybackEpochMs(): Long? {
        val timeline = player.currentTimeline
        val mediaItemIndex = player.currentMediaItemIndex
        if (timeline.isEmpty || mediaItemIndex !in 0 until timeline.windowCount) {
            return null
        }
        val window = timeline.getWindow(mediaItemIndex, Timeline.Window())
        return playbackEpochMs(window.windowStartTimeMs, player.currentPosition)
    }

    private fun updateQualities(tracks: Tracks) {
        qualityOverrides.clear()
        val qualities = mutableListOf<Map<String, Any?>>()
        tracks.groups.forEach { group ->
            if (group.type != C.TRACK_TYPE_VIDEO) {
                return@forEach
            }
            for (trackIndex in 0 until group.length) {
                if (!group.isTrackSupported(trackIndex)) {
                    continue
                }
                val format = group.getTrackFormat(trackIndex)
                if (format.height <= 0) {
                    continue
                }
                val id = stableQualityId(format.height, format.frameRate)
                if (id in qualityOverrides) {
                    continue
                }
                qualityOverrides[id] = TrackSelectionOverride(group.mediaTrackGroup, trackIndex)
                qualities += mapOf(
                    "id" to id,
                    "label" to qualityLabel(format),
                    "width" to format.width,
                    "height" to format.height,
                    "fps" to format.frameRate.takeIf { it > 0 },
                    "bitrate" to format.bitrate.takeIf { it > 0 },
                )
            }
        }
        val visibleQualities = deduplicateQualities(qualities, selectedQualityId)
        val selectedQualityIsVisible = visibleQualities.any { it["id"] == selectedQualityId }
        if (
            selectedQualityId != AUTO_QUALITY_ID && selectedQualityId != AUDIO_ONLY_QUALITY_ID &&
            visibleQualities.isNotEmpty() && !selectedQualityIsVisible
        ) {
            selectedQualityId = AUTO_QUALITY_ID
        }
        applyQualitySelection()
        latestQualities = visibleQualities.map { quality ->
            mapOf(
                "id" to quality["id"],
                "label" to quality["label"],
            )
        } + mapOf("id" to AUDIO_ONLY_QUALITY_ID, "label" to "Audio only")
        emitQualities()
    }

    private fun setQuality(id: String?, result: MethodChannel.Result) {
        if (id == selectedQualityId) {
            result.success(null)
            return
        }
        if (id == null || (id != AUTO_QUALITY_ID && id != AUDIO_ONLY_QUALITY_ID && id !in qualityOverrides)) {
            result.error("invalid_quality", "That video quality is no longer available.", null)
            return
        }
        selectedQualityId = id
        // Video quality is read at the next chunk boundary. Replacing an HLS
        // track override would discard its buffered audio/video and force a seek.
        applyQualitySelection()
        Log.d(LOG_TAG, "quality requested=$id buffered=${player.totalBufferedDuration}ms")
        activity.updatePictureInPicture()
        emitQualities()
        result.success(null)
    }

    private fun applyQualitySelection() {
        // A different decoder/group may not belong to the adaptive selection.
        // Use Media3's standard override then, so every offered choice works.
        val parameters = qualityParameters(
            player.trackSelectionParameters, selectedQualityId, qualityOverrides[selectedQualityId],
            if (isLive) adaptiveQualityIds else emptySet(),
        )
        qualityOverrideActive = parameters.overrides.keys.any { it.type == C.TRACK_TYPE_VIDEO }
        if (parameters != player.trackSelectionParameters) player.trackSelectionParameters = parameters
    }

    private fun qualityLabel(format: Format): String {
        val provided = format.label?.trim().orEmpty()
        if (provided.isNotEmpty()) {
            return provided
        }
        val frameRate = format.frameRate.takeIf { it >= 50 }?.roundToInt()
        return buildString {
            append(format.height)
            append('p')
            if (frameRate != null) {
                append(frameRate)
            }
        }
    }

    private fun emitLatency(latencyMs: Long?) {
        latestLatencyMs = latencyMs
        emit(mapOf("type" to "latency", "latencyMs" to latencyMs))
    }

    private fun emitState(updateSystemControls: Boolean = true) {
        // MediaSession advances its clock; only state, seek and layout changes need system updates.
        if (updateSystemControls) activity.updatePictureInPicture()
        emit(
            mapOf(
                "type" to "state",
                "isPlaying" to player.isPlaying,
                "isBuffering" to (player.playbackState == Player.STATE_BUFFERING),
                "playWhenReady" to player.playWhenReady,
                "positionMs" to player.currentPosition,
                "durationMs" to player.duration.coerceAtLeast(0),
                "isEnded" to (player.playbackState == Player.STATE_ENDED),
            ),
        )
    }

    private fun emitQualities() {
        emit(
            mapOf(
                "type" to "qualities",
                "qualities" to latestQualities,
                "selectedId" to selectedQualityId,
                "currentLabel" to if (selectedQualityId == AUDIO_ONLY_QUALITY_ID) "Audio only" else currentQualityLabel,
            ),
        )
    }

    private fun emitAd(progress: TwitchAdProgress?) {
        val event = if (progress == null) {
            inactiveAdEvent()
        } else {
            mapOf(
                "type" to "ad",
                "active" to true,
                "current" to progress.current,
                "total" to progress.total,
                "remainingMs" to progress.podRemainingMs,
            )
        }
        if (event == latestAdEvent) {
            return
        }
        val wasActive = latestAdEvent["active"] == true
        val isActive = event["active"] == true
        latestAdEvent = event
        if (wasActive != isActive) {
            Log.d(LOG_TAG, if (isActive) "stitched ad started" else "stitched ad ended")
        }
        emit(event)
    }

    private fun emitError(message: String) {
        emit(mapOf("type" to "error", "message" to message))
    }

    private fun emit(event: Map<String, Any?>) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            eventSink?.success(event)
        } else {
            mainHandler.post { eventSink?.success(event) }
        }
    }

    companion object {
        internal fun shouldKeepVideoDuringDictation(
            keyboardVisible: Boolean,
            voiceRecognitionActive: Boolean,
            playWhenReady: Boolean,
            audioOnly: Boolean,
            audioMode: Int,
            suppressionReason: Int,
            alreadyActive: Boolean,
        ): Boolean = keyboardVisible && voiceRecognitionActive && playWhenReady && !audioOnly &&
            audioMode == AudioManager.MODE_NORMAL &&
            (alreadyActive || suppressionReason == Player.PLAYBACK_SUPPRESSION_REASON_TRANSIENT_AUDIO_FOCUS_LOSS)

        internal fun playbackLoadControl(isLive: Boolean): DefaultLoadControl =
            if (isLive) {
                DefaultLoadControl.Builder()
                    .setBufferDurationsMs(
                        MIN_BUFFER_MS,
                        MAX_BUFFER_MS,
                        BUFFER_FOR_PLAYBACK_MS,
                        BUFFER_AFTER_REBUFFER_MS,
                    )
                    .setPrioritizeTimeOverSizeThresholds(true)
                    .build()
            } else {
                // VOD HLS subtracts a complete segment from the buffer before
                // adapting. The six-second live buffer cannot cover a 10s segment.
                DefaultLoadControl()
            }

        internal fun qualityParameters(
            parameters: TrackSelectionParameters,
            id: String,
            override: TrackSelectionOverride? = null,
            adaptiveQualityIds: Set<String> = emptySet(),
        ): TrackSelectionParameters = parameters.buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, id == AUDIO_ONLY_QUALITY_ID)
            .apply { if (override != null && id !in adaptiveQualityIds) setOverrideForType(override) }
            .build()

        internal fun adaptiveTrackSelectionFactory(
            clock: Clock = Clock.DEFAULT,
            isLive: Boolean = true,
            onVideoSelection: (Set<String>) -> Unit = {},
            preferredQualityId: () -> String = { AUTO_QUALITY_ID },
        ): ExoTrackSelection.Factory {
            val adaptiveFactory = AdaptiveTrackSelection.Factory(
                AUTO_QUALITY_MIN_DURATION_FOR_INCREASE_MS,
                AUTO_QUALITY_MAX_DURATION_FOR_DECREASE_MS,
                AUTO_QUALITY_MIN_DURATION_TO_RETAIN_MS,
                // VOD upgrades should not wait behind an entire buffer of lower-resolution HD.
                if (isLive) AdaptiveTrackSelection.DEFAULT_MAX_WIDTH_TO_DISCARD else Int.MAX_VALUE,
                if (isLive) AdaptiveTrackSelection.DEFAULT_MAX_HEIGHT_TO_DISCARD else Int.MAX_VALUE,
                AUTO_QUALITY_BANDWIDTH_FRACTION,
                AUTO_QUALITY_BUFFERED_FRACTION_TO_LIVE_EDGE,
                clock,
            )
            return ExoTrackSelection.Factory { definitions, bandwidthMeter, mediaPeriodId, timeline ->
                adaptiveFactory.createTrackSelections(definitions, bandwidthMeter, mediaPeriodId, timeline)
                    .map { selection ->
                        if (isLive && selection?.trackGroup?.type == C.TRACK_TYPE_VIDEO) {
                            val qualityIds = (0 until selection.length()).mapTo(mutableSetOf()) {
                                val format = selection.getFormat(it)
                                stableQualityId(format.height, format.frameRate)
                            }
                            onVideoSelection(qualityIds)
                            Log.d(LOG_TAG, "quality selection created requested=${preferredQualityId()} available=$qualityIds")
                            TwitchQualityTrackSelection(selection, preferredQualityId, clock)
                        } else {
                            selection
                        }
                    }.toTypedArray()
            }
        }

        const val LOG_TAG = "FlowTwitchPlayer"
        const val USER_AGENT = "Flow/1.0 (Android Media3)"
        const val AUTO_QUALITY_ID = "auto"
        const val AUDIO_ONLY_QUALITY_ID = "audio_only"
        // Twitch prefetch distorts the timeline offset. Native adaptive speed
        // control therefore uses validated transc_r latency for its target.
        const val TARGET_LIVE_OFFSET_MS = TwitchLatencyPlaybackSpeedControl.TARGET_LIVE_OFFSET_MS
        const val MIN_LIVE_OFFSET_MS = 1500L
        const val MAX_LIVE_OFFSET_MS = 3500L
        const val MIN_BUFFER_MS = 2000
        const val MAX_BUFFER_MS = 6000
        const val BUFFER_FOR_PLAYBACK_MS = 1000
        const val BUFFER_AFTER_REBUFFER_MS = 1500
        // A ten-second promotion gate can never be met by our six-second buffer.
        // Twitch prefetch also inflates the advertised live duration used by
        // Media3's live-edge adjustment. Promote once the real startup buffer is
        // healthy, while still selecting by measured bandwidth.
        const val AUTO_QUALITY_MIN_DURATION_FOR_INCREASE_MS = BUFFER_FOR_PLAYBACK_MS
        // Keep the downgrade guard inside the live-edge buffer.
        const val AUTO_QUALITY_MAX_DURATION_FOR_DECREASE_MS = 1_000
        const val AUTO_QUALITY_MIN_DURATION_TO_RETAIN_MS = MIN_BUFFER_MS
        const val AUTO_QUALITY_BANDWIDTH_FRACTION = 0.60f
        const val AUTO_QUALITY_BUFFERED_FRACTION_TO_LIVE_EDGE = 0.90f
        const val PLAYBACK_URI_REFRESH_TIMEOUT_SECONDS = 15L
        const val AD_PROGRESS_INTERVAL_MS = 500L
        const val EXPIRED_AD_CUE_RETENTION_MS = 30 * 60_000L
        const val PRIMARY_LATENCY_FRESHNESS_MS = 2500L
    }
}

// Keep the same selection and buffered chunks when the viewer changes quality.
// Media3 still schedules downloads, switches decoders, and handles Auto/failover.
@UnstableApi
internal class TwitchQualityTrackSelection(
    private val adaptive: ExoTrackSelection,
    private val preferredQualityId: () -> String,
    private val clock: Clock = Clock.DEFAULT,
) : ExoTrackSelection by adaptive {
    private var selectedIndex = adaptive.selectedIndex
    private var manualSelection = false
    private var lastLoggedRequest: String? = null

    override fun updateSelectedTrack(
        playbackPositionUs: Long,
        bufferedDurationUs: Long,
        availableDurationUs: Long,
        queue: MutableList<out MediaChunk>,
        mediaChunkIterators: Array<out MediaChunkIterator>,
    ) {
        adaptive.updateSelectedTrack(
            playbackPositionUs, bufferedDurationUs, availableDurationUs, queue, mediaChunkIterators,
        )
        val requested = preferredQualityId()
        val nowMs = clock.elapsedRealtime()
        val requestedIndex = (0 until length()).firstOrNull { index ->
            val format = getFormat(index)
            stableQualityId(format.height, format.frameRate) == requested && !isTrackExcluded(index, nowMs)
        }
        selectedIndex = requestedIndex ?: adaptive.selectedIndex
        manualSelection = requestedIndex != null
        if (lastLoggedRequest != requested) {
            lastLoggedRequest = requested
            val available = (0 until length()).map {
                val format = getFormat(it)
                stableQualityId(format.height, format.frameRate)
            }
            Log.d(TwitchPlayerView.LOG_TAG,
                "quality chunk requested=$requested selected=$selectedIndex manual=$requestedIndex available=$available")
        }
    }

    override fun getSelectedIndex(): Int = selectedIndex

    override fun getSelectedIndexInTrackGroup(): Int = getIndexInTrackGroup(selectedIndex)

    override fun getSelectedFormat(): Format = getFormat(selectedIndex)

    override fun getSelectionReason(): Int =
        if (manualSelection) C.SELECTION_REASON_MANUAL else adaptive.selectionReason

    override fun evaluateQueueSize(playbackPositionUs: Long, queue: MutableList<out MediaChunk>): Int =
        if (preferredQualityId() == TwitchPlayerView.AUTO_QUALITY_ID) {
            adaptive.evaluateQueueSize(playbackPositionUs, queue)
        } else {
            queue.size
        }

    override fun equals(other: Any?): Boolean =
        other is TwitchQualityTrackSelection && adaptive == other.adaptive

    override fun hashCode(): Int = adaptive.hashCode()
}

// A manifest's group/track indexes and bitrates can change on refresh. Resolution
// and frame rate express the viewer's choice across those regenerated manifests.
internal fun stableQualityId(height: Int, frameRate: Float): String =
    "video:$height:${if (frameRate > 0) frameRate.roundToInt() else 0}"

internal fun deduplicateQualities(
    qualities: List<Map<String, Any?>>,
    selectedQualityId: String,
): List<Map<String, Any?>> = qualities
    .sortedBy { if (it["id"] == selectedQualityId) 0 else 1 }
    .distinctBy { listOf(it["height"], it["fps"], it["bitrate"]) }
    .sortedWith(
        compareByDescending<Map<String, Any?>> { it["height"] as? Int ?: 0 }
            .thenByDescending { (it["fps"] as? Number)?.toDouble() ?: 0.0 },
    )

private fun inactiveAdEvent(): Map<String, Any?> = mapOf(
    "type" to "ad",
    "active" to false,
)

internal fun roundRemainingAdTimeMs(remainingMs: Long): Long =
    if (remainingMs <= 0) 0 else ((remainingMs + 999L) / 1000L) * 1000L
