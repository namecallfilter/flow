package com.namecallfilter.flow

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

@OptIn(UnstableApi::class)
class FlowLowLatencyVideoView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    params: Map<*, *>?,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "flow/low_latency_video/$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var disposed = false

    private val trackSelector = DefaultTrackSelector(appContext)
    private val player = ExoPlayer.Builder(appContext)
        .setTrackSelector(trackSelector)
        .setLoadControl(
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    LOW_LATENCY_MIN_BUFFER_MS,
                    LOW_LATENCY_MAX_BUFFER_MS,
                    LOW_LATENCY_PLAYBACK_BUFFER_MS,
                    LOW_LATENCY_REBUFFER_MS,
                )
                .build(),
        )
        .build()

    private val playerView = PlayerView(context).apply {
        setBackgroundColor(Color.BLACK)
        keepScreenOn = true
        useController = false
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        player = this@FlowLowLatencyVideoView.player
    }

    private val playerListener = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            channel.invokeMethod("playing", isPlaying)
        }

        override fun onTracksChanged(tracks: Tracks) {
            if (disposed) {
                return
            }
            sendQualitiesEvent(tracks)
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            channel.invokeMethod("buffering", playbackState == Player.STATE_BUFFERING)
            if (playbackState == Player.STATE_READY) {
                maybeSeekToLiveOnStart()
            }
            sendLatency()
        }

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            sendLatency()
        }

        override fun onPlayerError(error: PlaybackException) {
            channel.invokeMethod("error", error.message ?: "Video playback failed.")
        }
    }

    private val latencyTicker = object : Runnable {
        override fun run() {
            if (disposed) {
                return
            }
            sendLatency()
            mainHandler.postDelayed(this, LATENCY_READ_INTERVAL_MS)
        }
    }

    init {
        channel.setMethodCallHandler(this)
        player.addListener(playerListener)

        val url = params?.get("url") as? String
        if (url.isNullOrBlank()) {
            channel.invokeMethod("error", "Video URL is missing.")
        } else {
            load(url)
        }
    }

    private fun load(url: String) {
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(USER_AGENT)

        val dataSourceFactory = DefaultDataSource.Factory(appContext, httpDataSourceFactory)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMimeType(MimeTypes.APPLICATION_M3U8)
            .setLiveConfiguration(
                MediaItem.LiveConfiguration.Builder()
                    .setTargetOffsetMs(TARGET_LIVE_OFFSET_MS)
                    .setMinPlaybackSpeed(MIN_LIVE_SPEED)
                    .setMaxPlaybackSpeed(MAX_LIVE_SPEED)
                    .build(),
            )
            .build()

        val mediaSource = HlsMediaSource.Factory(dataSourceFactory)
            .setPlaylistParserFactory(TwitchLowLatencyHlsPlaylistParserFactory())
            .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy(6))
            .createMediaSource(mediaItem)

        pendingInitialLiveSeek = true
        player.setMediaSource(mediaSource)
        player.prepare()
        player.playWhenReady = true
        mainHandler.removeCallbacks(latencyTicker)
        mainHandler.post(latencyTicker)
    }

    override fun getView(): View = playerView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                player.play()
                result.success(null)
            }

            "pause" -> {
                player.pause()
                result.success(null)
            }

            "seekToLive" -> {
                seekToLiveEdge()
                sendLatency()
                result.success(null)
            }

            "setQuality" -> {
                val requestedQualityId = call.arguments as? String
                if (requestedQualityId == null) {
                    result.error("invalid_quality_id", "Expected a string quality id.", null)
                    return
                }

                selectedQualityId = requestedQualityId
                pendingQualityId = requestedQualityId
                if (applyQualitySelection(requestedQualityId)) {
                    pendingQualityId = null
                }
                sendQualitiesEvent()
                result.success(null)
            }

            "latency" -> result.success(currentLatencySeconds())

            "dispose" -> {
                dispose()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun sendLatency() {
        channel.invokeMethod("latency", currentLatencySeconds())
    }

    private fun maybeSeekToLiveOnStart() {
        if (pendingInitialLiveSeek && seekToLiveEdge()) {
            pendingInitialLiveSeek = false
        } else if (pendingInitialLiveSeek) {
            mainHandler.postDelayed(
                {
                    if (!disposed) {
                        maybeSeekToLiveOnStart()
                    }
                },
                INITIAL_LIVE_SEEK_RETRY_DELAY_MS,
            )
        }
    }

    private fun seekToLiveEdge(): Boolean {
        val targetPositionMs = targetLivePosition()
        val didSeekToTarget = targetPositionMs != null

        if (targetPositionMs != null) {
            player.seekTo(targetPositionMs)
            startLiveEdgeCorrection()
        } else {
            player.seekToDefaultPosition()
        }
        player.play()
        mainHandler.postDelayed(
            {
                if (!disposed) {
                    sendLatency()
                }
            },
            LIVE_EDGE_LATENCY_UPDATE_DELAY_MS,
        )
        return didSeekToTarget
    }

    private fun startLiveEdgeCorrection() {
        liveEdgeCorrectionGeneration++
        scheduleLiveEdgeCorrection(liveEdgeCorrectionGeneration, 1)
    }

    private fun scheduleLiveEdgeCorrection(generation: Int, attempt: Int) {
        mainHandler.postDelayed(
            {
                if (disposed || generation != liveEdgeCorrectionGeneration) {
                    return@postDelayed
                }

                val isDone = correctLiveEdgeIfNeeded()
                if (!isDone && attempt < MAX_LIVE_EDGE_CORRECTION_ATTEMPTS) {
                    scheduleLiveEdgeCorrection(generation, attempt + 1)
                }
            },
            LIVE_EDGE_CORRECTION_INTERVAL_MS,
        )
    }

    private fun correctLiveEdgeIfNeeded(): Boolean {
        if (player.playbackState != Player.STATE_READY) {
            return false
        }

        val liveOffsetMs = player.currentLiveOffset
        if (liveOffsetMs == C.TIME_UNSET) {
            return false
        }

        val driftMs = liveOffsetMs - JUMP_TO_LIVE_OFFSET_MS
        if (kotlin.math.abs(driftMs) <= LIVE_EDGE_TOLERANCE_MS) {
            sendLatency()
            return true
        }

        val targetPositionMs = targetLivePosition() ?: return false
        player.seekTo(targetPositionMs)
        player.play()
        sendLatency()
        return false
    }

    private fun targetLivePosition(): Long? {
        val currentLiveOffsetMs = player.currentLiveOffset
        if (currentLiveOffsetMs != C.TIME_UNSET) {
            return clampSeekPosition(
                player.currentPosition + currentLiveOffsetMs - JUMP_TO_LIVE_OFFSET_MS,
            )
        }

        val liveWindowEdgeMs = player.duration
        if (liveWindowEdgeMs != C.TIME_UNSET && liveWindowEdgeMs > 0) {
            return clampSeekPosition(liveWindowEdgeMs - JUMP_TO_LIVE_OFFSET_MS)
        }

        return null
    }

    private fun clampSeekPosition(positionMs: Long): Long {
        val durationMs = player.duration
        if (durationMs != C.TIME_UNSET && durationMs > 0) {
            return positionMs.coerceIn(0, durationMs)
        }
        return positionMs.coerceAtLeast(0)
    }

    private fun currentLatencySeconds(): Double? {
        val liveOffsetMs = player.currentLiveOffset
        if (liveOffsetMs != C.TIME_UNSET) {
            return liveOffsetMs.coerceAtLeast(0) / 1000.0
        }

        val durationMs = player.duration
        val positionMs = player.currentPosition
        if (durationMs != C.TIME_UNSET && durationMs > 0) {
            return (durationMs - positionMs).coerceAtLeast(0) / 1000.0
        }

        return null
    }

    private fun sendQualitiesEvent(tracks: Tracks = player.currentTracks) {
        val qualityOptions = extractVideoQualities(tracks)
        availableVideoQualities = qualityOptions

        if (!disposed && pendingQualityId != null) {
            if (applyQualitySelection(pendingQualityId!!)) {
                pendingQualityId = null
            }
        }

        val isSelectedQualityAvailable = availableVideoQualities.any { it.id == selectedQualityId }
        val currentSelection =
            if (!isSelectedQualityAvailable && selectedQualityId != AUTO_QUALITY_ID) {
                AUTO_QUALITY_ID
            } else {
                selectedQualityId
            }
        selectedQualityId = currentSelection

        val qualitiesPayload = ArrayList<Map<String, String>>(1 + qualityOptions.size)
        qualitiesPayload.add(
            mapOf(
                "id" to AUTO_QUALITY_ID,
                "label" to AUTO_QUALITY_LABEL,
            ),
        )
        for (option in qualityOptions) {
            qualitiesPayload.add(
                mapOf(
                    "id" to option.id,
                    "label" to option.label,
                ),
            )
        }

        channel.invokeMethod(
            "qualities",
            mapOf(
                "qualities" to qualitiesPayload,
                "selectedQualityId" to currentSelection,
            ),
        )
    }

    private fun applyQualitySelection(qualityId: String): Boolean {
        if (qualityId == AUTO_QUALITY_ID) {
            applyAutoQuality()
            selectedQualityId = AUTO_QUALITY_ID
            return true
        }

        val option = availableVideoQualities.firstOrNull { it.id == qualityId } ?: return false
        val params = trackSelector
            .buildUponParameters()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .setOverrideForType(option.override)
            .build()
        trackSelector.setParameters(params)
        selectedQualityId = qualityId
        return true
    }

    private fun applyAutoQuality() {
        val params = trackSelector
            .buildUponParameters()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .build()
        trackSelector.setParameters(params)
    }

    private fun extractVideoQualities(tracks: Tracks): List<VideoQualityOption> {
        val options = mutableListOf<VideoQualityOption>()

        for (groupIndex in 0 until tracks.groups.size) {
            val group = tracks.groups[groupIndex]
            if (group.type != C.TRACK_TYPE_VIDEO || !group.isSupported) {
                continue
            }

            for (trackIndex in 0 until group.length) {
                if (!group.isTrackSupported(trackIndex)) {
                    continue
                }
                val format = group.getTrackFormat(trackIndex)
                val label = qualityLabel(format.height, format.frameRate) ?: continue

                options.add(
                    VideoQualityOption(
                        id = qualityId(
                            groupIndex,
                            trackIndex,
                            format.height,
                            format.frameRate,
                            format.bitrate,
                        ),
                        label = label,
                        height = format.height,
                        frameRate = format.frameRate,
                        override = TrackSelectionOverride(group.mediaTrackGroup, trackIndex),
                    ),
                )
            }
        }

        return options
            .distinctBy { it.label }
            .sortedWith(
                compareByDescending<VideoQualityOption> { it.height }
                    .thenByDescending { it.frameRate },
            )
    }

    private fun qualityLabel(height: Int, frameRate: Float): String? {
        if (height <= 0) {
            return null
        }
        val fps =
            if (frameRate > 0f) {
                Math.round(frameRate).coerceAtLeast(1)
            } else {
                0
            }
        return if (fps > 0) "${height}p$fps" else "${height}p"
    }

    private fun qualityId(
        groupIndex: Int,
        trackIndex: Int,
        height: Int,
        frameRate: Float,
        bitrate: Int,
    ): String {
        val fps = if (frameRate > 0f) "-${Math.round(frameRate)}" else ""
        val bitrateSuffix = if (bitrate > 0) "-$bitrate" else ""
        return "${height}p$fps$bitrateSuffix-g$groupIndex-t$trackIndex"
    }

    private data class VideoQualityOption(
        val id: String,
        val label: String,
        val height: Int,
        val frameRate: Float,
        val override: TrackSelectionOverride,
    )

    override fun dispose() {
        if (disposed) {
            return
        }

        disposed = true
        mainHandler.removeCallbacks(latencyTicker)
        player.removeListener(playerListener)
        playerView.keepScreenOn = false
        playerView.player = null
        player.release()
        channel.setMethodCallHandler(null)
    }

    private var selectedQualityId = AUTO_QUALITY_ID
    private var pendingQualityId: String? = null
    private var pendingInitialLiveSeek = false
    private var liveEdgeCorrectionGeneration = 0
    private var availableVideoQualities: List<VideoQualityOption> = emptyList()

    private companion object {
        const val LOW_LATENCY_MIN_BUFFER_MS = 1000
        const val LOW_LATENCY_MAX_BUFFER_MS = 5000
        const val LOW_LATENCY_PLAYBACK_BUFFER_MS = 250
        const val LOW_LATENCY_REBUFFER_MS = 500
        const val TARGET_LIVE_OFFSET_MS = 2000L
        const val MIN_LIVE_SPEED = 0.98f
        const val MAX_LIVE_SPEED = 1.08f
        const val JUMP_TO_LIVE_OFFSET_MS = 2000L
        const val LIVE_EDGE_TOLERANCE_MS = 175L
        const val MAX_LIVE_EDGE_CORRECTION_ATTEMPTS = 6
        const val LIVE_EDGE_CORRECTION_INTERVAL_MS = 500L
        const val LATENCY_READ_INTERVAL_MS = 1000L
        const val INITIAL_LIVE_SEEK_RETRY_DELAY_MS = 250L
        const val LIVE_EDGE_LATENCY_UPDATE_DELAY_MS = 250L
        const val AUTO_QUALITY_ID = "auto"
        const val AUTO_QUALITY_LABEL = "Auto"
        const val USER_AGENT =
            "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
    }
}
