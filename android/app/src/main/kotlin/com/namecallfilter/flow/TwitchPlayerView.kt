package com.namecallfilter.flow

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.LayoutInflater
import android.view.View
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
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLivePlaybackSpeedControl
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlin.math.roundToInt

@UnstableApi
internal class TwitchPlayerView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    initialUrl: String?,
) : PlatformView {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val playerView = LayoutInflater.from(context).inflate(
        R.layout.flow_twitch_player,
        null,
        false,
    ) as PlayerView
    private val methodChannel = MethodChannel(messenger, "flow/twitch_player/$viewId")
    private val eventChannel = EventChannel(messenger, "flow/twitch_player/$viewId/events")
    private val player: ExoPlayer
    private var eventSink: EventChannel.EventSink? = null
    private var latencySession: TwitchLatencySession? = null
    private var metadataListener: Player.Listener? = null
    private var sessionGeneration = 0L
    private var latestLatencyMs: Long? = null
    private var lastPrimaryLatencyRealtimeMs: Long? = null
    private var latestError: String? = null
    private var latestQualities: List<Map<String, Any?>> = emptyList()
    private var selectedQualityId = AUTO_QUALITY_ID
    private val qualityOverrides = mutableMapOf<String, TrackSelectionOverride>()
    private val adCues = mutableMapOf<String, TwitchAdCue>()
    private var latestAdEvent: Map<String, Any?> = inactiveAdEvent()
    private var pendingLiveEdgeTargetOffsetMs: Long? = null
    private var hasRenderedFirstFrame = false
    private var disposed = false
    private val adProgressTicker = object : Runnable {
        override fun run() {
            if (disposed) {
                return
            }
            updateAdProgress()
            mainHandler.postDelayed(this, AD_PROGRESS_INTERVAL_MS)
        }
    }
    private val playbackListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (
                playbackState == Player.STATE_BUFFERING &&
                hasRenderedFirstFrame &&
                player.playWhenReady
            ) {
                Log.d(
                    LOG_TAG,
                    "rebuffer buffered=${player.totalBufferedDuration}ms " +
                        "media3LiveOffset=${player.currentLiveOffset}ms " +
                        "measuredLatency=${latestLatencyMs}ms " +
                        "speed=${player.playbackParameters.speed}x",
                )
            }
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emitState()
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            latestError = error.message ?: "The stream could not be played."
            emitError(latestError!!)
        }

        override fun onRenderedFirstFrame() {
            hasRenderedFirstFrame = true
        }

        override fun onTimelineChanged(timeline: Timeline, reason: Int) {
            val targetOffsetMs = pendingLiveEdgeTargetOffsetMs
            if (targetOffsetMs != null && seekToLiveEdge(targetOffsetMs)) {
                pendingLiveEdgeTargetOffsetMs = null
            }
        }

        override fun onTracksChanged(tracks: Tracks) {
            updateQualities(tracks)
        }
    }

    init {
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                MIN_BUFFER_MS,
                MAX_BUFFER_MS,
                BUFFER_FOR_PLAYBACK_MS,
                BUFFER_AFTER_REBUFFER_MS,
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()
        val liveSpeedControl = DefaultLivePlaybackSpeedControl.Builder()
            .setFallbackMinPlaybackSpeed(MIN_PLAYBACK_SPEED)
            .setFallbackMaxPlaybackSpeed(MAX_PLAYBACK_SPEED)
            .setTargetLiveOffsetIncrementOnRebufferMs(TARGET_OFFSET_REBUFFER_INCREMENT_MS)
            .build()
        player = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setLivePlaybackSpeedControl(liveSpeedControl)
            .build()
        player.setAudioAttributes(AudioAttributes.DEFAULT, true)
        player.setHandleAudioBecomingNoisy(true)
        player.addListener(playbackListener)
        playerView.player = player
        playerView.setShutterBackgroundColor(Color.BLACK)
        Log.d(
            LOG_TAG,
            "live playback target=${TARGET_LIVE_OFFSET_MS}ms " +
                "speed=${MIN_PLAYBACK_SPEED}x",
        )

        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    emitLatency(latestLatencyMs)
                    emitState()
                    emitQualities()
                    emit(latestAdEvent)
                    latestError?.let(::emitError)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> {
                    val url = call.arguments as? String
                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "A Twitch HLS URL is required.", null)
                    } else {
                        load(url)
                        result.success(null)
                    }
                }

                "play" -> {
                    resumeAtLiveEdge()
                    result.success(null)
                }

                "pause" -> {
                    player.pause()
                    result.success(null)
                }

                "togglePlayback" -> {
                    if (player.playWhenReady) player.pause() else resumeAtLiveEdge()
                    result.success(null)
                }

                "jumpToLive" -> {
                    jumpToLiveEdge()
                    result.success(null)
                }

                "setQuality" -> setQuality(call.arguments as? String, result)

                else -> result.notImplemented()
            }
        }

        if (!initialUrl.isNullOrBlank()) {
            load(initialUrl)
        }
        mainHandler.post(adProgressTicker)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        disposed = true
        mainHandler.removeCallbacks(adProgressTicker)
        sessionGeneration++
        metadataListener?.let(player::removeListener)
        metadataListener = null
        latencySession = null
        adCues.clear()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        playerView.player = null
        player.release()
    }

    private fun load(url: String) {
        val generation = ++sessionGeneration
        latestLatencyMs = null
        lastPrimaryLatencyRealtimeMs = null
        latestError = null
        latestQualities = emptyList()
        adCues.clear()
        qualityOverrides.clear()
        selectedQualityId = AUTO_QUALITY_ID
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .build()
        pendingLiveEdgeTargetOffsetMs = null
        hasRenderedFirstFrame = false
        emitLatency(null)
        emitQualities()
        emitAd(null, null)

        metadataListener?.let(player::removeListener)
        val session = TwitchLatencySession(
            onAcceptedLatency = { latencyMs ->
                if (generation == sessionGeneration && player.playWhenReady) {
                    lastPrimaryLatencyRealtimeMs = SystemClock.elapsedRealtime()
                    emitLatency(latencyMs)
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

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(USER_AGENT)
        val dataSourceFactory = DefaultDataSource.Factory(playerView.context, httpDataSourceFactory)
        val mediaSource = HlsMediaSource.Factory(dataSourceFactory)
            .setMetadataType(HlsMediaSource.METADATA_TYPE_ID3)
            .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy(MINIMUM_LOAD_RETRY_COUNT))
            .setPlaylistParserFactory(
                ServerTimePlaylistParserFactory(
                    latencySession = session,
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
                    .setUri(Uri.parse(url))
                    .setMimeType(MimeTypes.APPLICATION_M3U8)
                    .setLiveConfiguration(
                        MediaItem.LiveConfiguration.Builder()
                            .setTargetOffsetMs(TARGET_LIVE_OFFSET_MS)
                            .setMinOffsetMs(MIN_LIVE_OFFSET_MS)
                            .setMaxOffsetMs(MAX_LIVE_OFFSET_MS)
                            .setMinPlaybackSpeed(MIN_PLAYBACK_SPEED)
                            .setMaxPlaybackSpeed(MAX_PLAYBACK_SPEED)
                            .build(),
                    )
                    .build(),
            )

        player.setMediaSource(mediaSource)
        player.prepare()
        player.play()
    }

    private fun resumeAtLiveEdge() {
        playAtLiveOffset(TARGET_LIVE_OFFSET_MS)
    }

    private fun jumpToLiveEdge() {
        playAtLiveOffset(JUMP_LIVE_OFFSET_MS)
    }

    private fun playAtLiveOffset(targetOffsetMs: Long) {
        if (!seekToLiveEdge(targetOffsetMs)) {
            pendingLiveEdgeTargetOffsetMs = targetOffsetMs
        }
        player.play()
    }

    private fun seekToLiveEdge(targetOffsetMs: Long): Boolean {
        val timeline = player.currentTimeline
        if (
            timeline.isEmpty ||
            player.currentMediaItemIndex < 0 ||
            player.currentMediaItemIndex >= timeline.windowCount
        ) {
            return false
        }

        val window = timeline.getWindow(player.currentMediaItemIndex, Timeline.Window())
        if (window.isLive()) {
            val positionMs = if (targetOffsetMs == TARGET_LIVE_OFFSET_MS) {
                // Resume at Media3's configured two-second default. Do not use
                // the aggressive buffered-edge shortcut for ordinary unpause.
                forwardLiveDefaultPositionMs(
                    defaultPositionMs = window.defaultPositionMs,
                    currentPositionMs = player.currentPosition,
                )
            } else {
                forwardLiveEdgePositionMs(
                    defaultPositionMs = window.defaultPositionMs,
                    currentPositionMs = player.currentPosition,
                    bufferedPositionMs = player.bufferedPosition,
                    windowDurationMs = window.durationMs,
                    normalTargetOffsetMs = TARGET_LIVE_OFFSET_MS,
                    jumpTargetOffsetMs = targetOffsetMs,
                    bufferedSafetyMs = JUMP_BUFFER_SAFETY_MS,
                    minimumAdvanceMs = MINIMUM_JUMP_ADVANCE_MS,
                )
            } ?: return false
            if (positionMs > player.currentPosition) {
                Log.d(
                    LOG_TAG,
                    "jumping live from=${player.currentPosition}ms to=${positionMs}ms " +
                        "buffered=${player.bufferedPosition}ms default=${window.defaultPositionMs}ms",
                )
                player.seekTo(player.currentMediaItemIndex, positionMs)
            }
            return true
        }

        player.seekToDefaultPosition()
        return true
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
        if (progress == null) {
            emitAd(null, null)
            return
        }

        emitAd(progress.cue, progress)
        val primaryLatencyIsFresh = lastPrimaryLatencyRealtimeMs?.let { measuredAtMs ->
            SystemClock.elapsedRealtime() - measuredAtMs <= PRIMARY_LATENCY_FRESHNESS_MS
        } == true
        if (player.playWhenReady && !primaryLatencyIsFresh) {
            adFallbackLatencyMs(
                clientNowMs = System.currentTimeMillis(),
                serverOffsetMs = latencySession?.serverOffsetMs,
                playbackEpochMs = playbackEpochMs,
            )?.let(::emitLatency)
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
        tracks.groups.forEachIndexed { groupIndex, group ->
            if (group.type != C.TRACK_TYPE_VIDEO) {
                return@forEachIndexed
            }
            for (trackIndex in 0 until group.length) {
                if (!group.isTrackSupported(trackIndex)) {
                    continue
                }
                val format = group.getTrackFormat(trackIndex)
                if (format.height <= 0) {
                    continue
                }
                val id = "$groupIndex:$trackIndex"
                qualityOverrides[id] = TrackSelectionOverride(
                    group.mediaTrackGroup,
                    trackIndex,
                )
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
        latestQualities = qualities
            .distinctBy { listOf(it["height"], it["fps"], it["bitrate"]) }
            .sortedWith(
                compareByDescending<Map<String, Any?>> { it["height"] as? Int ?: 0 }
                    .thenByDescending { (it["fps"] as? Number)?.toDouble() ?: 0.0 },
            )
        if (selectedQualityId != AUTO_QUALITY_ID && !qualityOverrides.containsKey(selectedQualityId)) {
            selectedQualityId = AUTO_QUALITY_ID
        }
        emitQualities()
    }

    private fun setQuality(id: String?, result: MethodChannel.Result) {
        if (id == AUTO_QUALITY_ID) {
            player.trackSelectionParameters = player.trackSelectionParameters
                .buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                .build()
            selectedQualityId = AUTO_QUALITY_ID
            emitQualities()
            result.success(null)
            return
        }

        val override = id?.let(qualityOverrides::get)
        if (id == null || override == null) {
            result.error("invalid_quality", "That video quality is no longer available.", null)
            return
        }
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .setOverrideForType(override)
            .build()
        selectedQualityId = id
        emitQualities()
        result.success(null)
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

    private fun emitState() {
        emit(
            mapOf(
                "type" to "state",
                "isPlaying" to player.isPlaying,
                "isBuffering" to (player.playbackState == Player.STATE_BUFFERING),
                "playWhenReady" to player.playWhenReady,
            ),
        )
    }

    private fun emitQualities() {
        emit(
            mapOf(
                "type" to "qualities",
                "qualities" to latestQualities,
                "selectedId" to selectedQualityId,
            ),
        )
    }

    private fun emitAd(cue: TwitchAdCue?, progress: TwitchAdProgress?) {
        val event = if (cue == null || progress == null) {
            inactiveAdEvent()
        } else {
            mapOf(
                "type" to "ad",
                "active" to true,
                "current" to progress.current,
                "total" to progress.total,
                // Keep the existing fields pod-wide so older Flutter clients
                // immediately show the complete break countdown.
                "durationMs" to progress.podDurationMs,
                "remainingMs" to progress.podRemainingMs,
                "currentDurationMs" to progress.currentDurationMs,
                "currentRemainingMs" to progress.currentRemainingMs,
                "rollType" to cue.rollType,
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

    private companion object {
        const val LOG_TAG = "FlowTwitchPlayer"
        const val USER_AGENT = "Flow/1.0 (Android Media3)"
        const val AUTO_QUALITY_ID = "auto"
        // Twitch's promoted prefetch segments distort Media3's calculated live
        // offset relative to transc_r. Start at the requested target, but keep
        // normal playback at 1x so that clock mismatch cannot continuously
        // accelerate the player through the safe latency margin.
        const val TARGET_LIVE_OFFSET_MS = 2000L
        const val MIN_LIVE_OFFSET_MS = 1500L
        const val MAX_LIVE_OFFSET_MS = 3500L
        const val JUMP_LIVE_OFFSET_MS = 1000L
        const val JUMP_BUFFER_SAFETY_MS = 750L
        const val MINIMUM_JUMP_ADVANCE_MS = 250L
        const val MIN_PLAYBACK_SPEED = 1.0f
        const val MAX_PLAYBACK_SPEED = 1.0f
        const val TARGET_OFFSET_REBUFFER_INCREMENT_MS = 0L
        const val MIN_BUFFER_MS = 6000
        const val MAX_BUFFER_MS = 12000
        const val BUFFER_FOR_PLAYBACK_MS = 1000
        const val BUFFER_AFTER_REBUFFER_MS = 1500
        const val MINIMUM_LOAD_RETRY_COUNT = 6
        const val AD_PROGRESS_INTERVAL_MS = 500L
        const val EXPIRED_AD_CUE_RETENTION_MS = 30 * 60_000L
        const val PRIMARY_LATENCY_FRESHNESS_MS = 2500L
    }
}

private fun inactiveAdEvent(): Map<String, Any?> = mapOf(
    "type" to "ad",
    "active" to false,
)

internal fun roundRemainingAdTimeMs(remainingMs: Long): Long =
    if (remainingMs <= 0) 0 else ((remainingMs + 999L) / 1000L) * 1000L

internal fun forwardLiveDefaultPositionMs(
    defaultPositionMs: Long,
    currentPositionMs: Long,
): Long? = when {
    defaultPositionMs == C.TIME_UNSET || defaultPositionMs < 0 -> null
    defaultPositionMs <= currentPositionMs -> currentPositionMs
    else -> defaultPositionMs
}

internal fun forwardLiveEdgePositionMs(
    defaultPositionMs: Long,
    currentPositionMs: Long,
    bufferedPositionMs: Long,
    windowDurationMs: Long,
    normalTargetOffsetMs: Long,
    jumpTargetOffsetMs: Long,
    bufferedSafetyMs: Long,
    minimumAdvanceMs: Long,
): Long? {
    if (
        defaultPositionMs == C.TIME_UNSET ||
        defaultPositionMs < 0 ||
        currentPositionMs < 0 ||
        normalTargetOffsetMs < jumpTargetOffsetMs ||
        jumpTargetOffsetMs < 0 ||
        bufferedSafetyMs < 0 ||
        minimumAdvanceMs < 0
    ) {
        return null
    }
    val targetAdvanceMs = normalTargetOffsetMs - jumpTargetOffsetMs
    val aggressiveDefaultMs = runCatching {
        Math.addExact(defaultPositionMs, targetAdvanceMs)
    }.getOrNull() ?: return null
    val safeBufferedEdgeMs = bufferedPositionMs
        .takeIf { it != C.TIME_UNSET && it >= bufferedSafetyMs }
        ?.minus(bufferedSafetyMs)
        ?.let { bufferedEdgeMs ->
            if (windowDurationMs != C.TIME_UNSET && windowDurationMs >= bufferedSafetyMs) {
                minOf(bufferedEdgeMs, windowDurationMs - bufferedSafetyMs)
            } else {
                bufferedEdgeMs
            }
        }
    if (currentPositionMs < aggressiveDefaultMs) {
        // This is an explicit jump. Media3 can fetch the corrected live target
        // even when less than the normal safety margin is buffered ahead.
        return aggressiveDefaultMs
    }
    val desiredPositionMs = if (safeBufferedEdgeMs != null) {
        // The timeline's projected default can lag behind a player that is
        // already close to live. In that case one press goes straight to the
        // safe buffered edge instead of requiring several small seeks.
        safeBufferedEdgeMs
    } else {
        currentPositionMs
    }
    return if (desiredPositionMs - currentPositionMs >= minimumAdvanceMs) {
        desiredPositionMs
    } else {
        currentPositionMs
    }
}
