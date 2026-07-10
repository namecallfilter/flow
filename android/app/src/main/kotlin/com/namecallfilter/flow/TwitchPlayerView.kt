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
    private val liveSpeedControl = TwitchLatencyPlaybackSpeedControl()
    private val latencyCorrection = LiveLatencyCorrectionCoordinator(
        maximumSeekAttempts = MAX_CORRECTION_SEEK_ATTEMPTS,
    )
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
    private var hasRenderedFirstFrame = false
    private var latestCorrectionMeasurement: LiveLatencyMeasurement? = null
    private var correctionMeasurementSequence = 0L
    private var lastCorrectionWaitReason: String? = null
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
            liveSpeedControl.setPlaybackActive(player.isPlaying)
            if (
                playbackState == Player.STATE_BUFFERING &&
                hasRenderedFirstFrame &&
                player.playWhenReady
            ) {
                Log.d(
                    LOG_TAG,
                    "rebuffer buffered=${player.totalBufferedDuration}ms " +
                        "media3LiveOffset=${player.currentLiveOffset}ms " +
                        "measuredLatency=${latestLatencyMs}ms; " +
                        "see speed-control decision for adjusted speed",
                )
            }
            maybeApplyPendingLatencyCorrection()
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            liveSpeedControl.setPlaybackActive(isPlaying)
            maybeApplyPendingLatencyCorrection()
            emitState()
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            liveSpeedControl.setPlaybackActive(player.isPlaying)
            maybeApplyPendingLatencyCorrection()
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            latestError = error.message ?: "The stream could not be played."
            emitError(latestError!!)
        }

        override fun onRenderedFirstFrame() {
            hasRenderedFirstFrame = true
            maybeApplyPendingLatencyCorrection()
        }

        override fun onTimelineChanged(timeline: Timeline, reason: Int) {
            maybeApplyPendingLatencyCorrection()
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
                "load-control target=" +
                "${TwitchLatencyPlaybackSpeedControl.LOAD_CONTROL_TARGET_LIVE_OFFSET_MS}ms " +
                "transc_r speed range=${TwitchLatencySpeedPolicy.MIN_PLAYBACK_SPEED}x-" +
                "${TwitchLatencySpeedPolicy.MAX_PLAYBACK_SPEED}x",
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
        liveSpeedControl.reset()
        latencyCorrection.reset()
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
        liveSpeedControl.reset()
        latencyCorrection.reset()
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
        hasRenderedFirstFrame = false
        latestCorrectionMeasurement = null
        correctionMeasurementSequence = 0L
        lastCorrectionWaitReason = null
        latencyCorrection.arm(
            reason = LiveLatencyCorrectionReason.STARTUP,
            targetLatencyMs = TARGET_LIVE_OFFSET_MS,
            requireMeasurementAfterSequence = null,
        )
        logLatencyCorrectionArmed(LiveLatencyCorrectionReason.STARTUP, null)
        emitLatency(null)
        emitQualities()
        emitAd(null, null)

        metadataListener?.let(player::removeListener)
        lateinit var session: TwitchLatencySession
        session = TwitchLatencySession(
            onAcceptedLatency = { latencyMs ->
                if (generation == sessionGeneration && player.playWhenReady) {
                    val measuredRealtimeMs = SystemClock.elapsedRealtime()
                    lastPrimaryLatencyRealtimeMs = measuredRealtimeMs
                    emitLatency(latencyMs)
                    val transcRMs = session.lastTranscR
                    if (transcRMs != null) {
                        recordLatencyMeasurement(
                            latencyMs = latencyMs,
                            source = LiveLatencyMeasurementSource.TRANSC_R,
                            transcRMs = transcRMs,
                            measuredRealtimeMs = measuredRealtimeMs,
                        )
                    }
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
                            .setMinPlaybackSpeed(TwitchLatencySpeedPolicy.MIN_PLAYBACK_SPEED)
                            .setMaxPlaybackSpeed(TwitchLatencySpeedPolicy.MAX_PLAYBACK_SPEED)
                            .build(),
                    )
                    .build(),
            )

        player.setMediaSource(mediaSource)
        player.prepare()
        player.play()
    }

    private fun resumeAtLiveEdge() {
        requestLatencyCorrection(LiveLatencyCorrectionReason.RESUME)
    }

    private fun jumpToLiveEdge() {
        requestLatencyCorrection(LiveLatencyCorrectionReason.EXPLICIT_JUMP)
    }

    private fun requestLatencyCorrection(reason: LiveLatencyCorrectionReason) {
        val nowRealtimeMs = SystemClock.elapsedRealtime()
        val useImmediateMeasurement = shouldUseImmediateLatencyCorrection(
            reason = reason,
            isPlaying = player.isPlaying,
            measurement = latestCorrectionMeasurement,
            nowRealtimeMs = nowRealtimeMs,
            maximumAgeMs = CORRECTION_MEASUREMENT_MAX_AGE_MS,
        )
        val measurementBarrier = if (useImmediateMeasurement) {
            null
        } else {
            correctionMeasurementSequence
        }
        latencyCorrection.arm(
            reason = reason,
            targetLatencyMs = TARGET_LIVE_OFFSET_MS,
            requireMeasurementAfterSequence = measurementBarrier,
        )
        lastCorrectionWaitReason = null
        if (!useImmediateMeasurement) {
            liveSpeedControl.invalidateMeasurementForDiscontinuity(
                "${reason.name.lowercase()} request",
            )
        }
        logLatencyCorrectionArmed(reason, measurementBarrier, useImmediateMeasurement)
        player.play()
        maybeApplyPendingLatencyCorrection()
    }

    private fun maybeApplyPendingLatencyCorrection(): Boolean {
        if (!latencyCorrection.hasPendingRequest) {
            return false
        }
        if (
            !hasRenderedFirstFrame ||
            player.playbackState != Player.STATE_READY ||
            !player.playWhenReady
        ) {
            logLatencyCorrectionWait("player ready")
            return false
        }

        val measurement = latestCorrectionMeasurement
        if (measurement == null) {
            logLatencyCorrectionWait("post-action latency measurement")
            return false
        }
        val measurementAgeMs = SystemClock.elapsedRealtime() - measurement.measuredRealtimeMs
        if (
            measurementAgeMs < 0 ||
            measurementAgeMs > CORRECTION_MEASUREMENT_MAX_AGE_MS
        ) {
            latestCorrectionMeasurement = null
            logLatencyCorrectionWait("fresh latency measurement")
            return false
        }

        val timeline = player.currentTimeline
        val mediaItemIndex = player.currentMediaItemIndex
        if (timeline.isEmpty || mediaItemIndex !in 0 until timeline.windowCount) {
            logLatencyCorrectionWait("live window")
            return false
        }
        val window = timeline.getWindow(mediaItemIndex, Timeline.Window())
        if (!window.isLive()) {
            logLatencyCorrectionWait("live window")
            return false
        }
        val currentPositionMs = player.currentPosition
        val bufferedPositionMs = player.bufferedPosition.takeUnless { it == C.TIME_UNSET }
        val windowDurationMs = window.durationMs.takeUnless { it == C.TIME_UNSET }
        val decision = latencyCorrection.evaluate(
            measurement = measurement,
            currentPositionMs = player.currentPosition,
            bufferedPositionMs = bufferedPositionMs,
            windowDurationMs = windowDurationMs,
            bufferedSafetyMs = CORRECTION_EDGE_GUARD_MS,
            minimumAdvanceMs = CORRECTION_MINIMUM_ADVANCE_MS,
            targetToleranceMs = CORRECTION_TARGET_TOLERANCE_MS,
        )
        when (decision.outcome) {
            LiveLatencyCorrectionOutcome.SEEK -> {
                val seekPositionMs = checkNotNull(decision.seekPositionMs)
                latestCorrectionMeasurement = null
                lastCorrectionWaitReason = null
                Log.d(
                    LOG_TAG,
                    "latency correction seek reason=${decision.reason} " +
                        "attempt=${decision.seekAttempt}/$MAX_CORRECTION_SEEK_ATTEMPTS " +
                        "latency=${measurement.latencyMs}ms source=${measurement.source} " +
                        "transc_r=${measurement.transcRMs} sequence=${measurement.sequence} " +
                        "from=${currentPositionMs}ms to=${seekPositionMs}ms " +
                        "buffered=${bufferedPositionMs}ms window=${windowDurationMs}ms",
                )
                player.seekTo(mediaItemIndex, seekPositionMs)
                // The pre-seek sample cannot verify or control the new position.
                // The coordinator remains armed until a newer measurement arrives.
                liveSpeedControl.invalidateMeasurementForDiscontinuity("latency correction seek")
                return true
            }
            LiveLatencyCorrectionOutcome.COMPLETE -> {
                lastCorrectionWaitReason = null
                Log.d(
                    LOG_TAG,
                    "latency correction verified reason=${decision.reason} " +
                        "latency=${measurement.latencyMs}ms target=${TARGET_LIVE_OFFSET_MS}ms " +
                        "attempts=${decision.seekAttempt}",
                )
            }
            LiveLatencyCorrectionOutcome.WAIT_FOR_FRESH_MEASUREMENT -> {
                logLatencyCorrectionWait(
                    "post-action latency measurement",
                    "source=${measurement.source} sequence=${measurement.sequence}",
                )
            }
            LiveLatencyCorrectionOutcome.WAIT_FOR_BUFFER -> {
                logLatencyCorrectionWait(
                    "exact target position",
                    "latency=${measurement.latencyMs}ms current=${currentPositionMs}ms " +
                        "buffered=${bufferedPositionMs}ms window=${windowDurationMs}ms",
                )
            }
            LiveLatencyCorrectionOutcome.FALLBACK_TO_SPEED -> {
                lastCorrectionWaitReason = null
                Log.d(
                    LOG_TAG,
                    "latency correction retry limit reason=${decision.reason} " +
                        "latency=${measurement.latencyMs}ms; continuing bounded speed catch-up",
                )
            }
            LiveLatencyCorrectionOutcome.INVALID_INPUT -> {
                latestCorrectionMeasurement = null
                logLatencyCorrectionWait("valid player positions")
            }
        }
        return false
    }

    private fun logLatencyCorrectionArmed(
        reason: LiveLatencyCorrectionReason,
        measurementBarrier: Long?,
        immediate: Boolean = false,
    ) {
        Log.d(
            LOG_TAG,
            "latency correction armed reason=$reason target=${TARGET_LIVE_OFFSET_MS}ms " +
                "afterSequence=$measurementBarrier immediate=$immediate",
        )
    }

    private fun recordLatencyMeasurement(
        latencyMs: Long,
        source: LiveLatencyMeasurementSource,
        transcRMs: Long? = null,
        measuredRealtimeMs: Long = SystemClock.elapsedRealtime(),
    ) {
        correctionMeasurementSequence++
        latestCorrectionMeasurement = LiveLatencyMeasurement(
            latencyMs = latencyMs,
            sequence = correctionMeasurementSequence,
            measuredRealtimeMs = measuredRealtimeMs,
            source = source,
            transcRMs = transcRMs,
        )
        liveSpeedControl.updateLatencyMeasurement(latencyMs, source)
        maybeApplyPendingLatencyCorrection()
    }

    private fun logLatencyCorrectionWait(reason: String, detail: String? = null) {
        if (reason == lastCorrectionWaitReason) {
            return
        }
        lastCorrectionWaitReason = reason
        Log.d(
            LOG_TAG,
            "latency correction waiting for $reason" +
                detail?.let { " ($it)" }.orEmpty(),
        )
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
            )?.let { latencyMs ->
                emitLatency(latencyMs)
                recordLatencyMeasurement(
                    latencyMs = latencyMs,
                    source = LiveLatencyMeasurementSource.STITCHED_AD_TIMELINE,
                )
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
        // offset. HLS startup, action seeks, and playback speed therefore share
        // this validated transc_r target. LoadControl receives a separate stable
        // readiness target from TwitchLatencyPlaybackSpeedControl.
        const val TARGET_LIVE_OFFSET_MS = TwitchLatencySpeedPolicy.TARGET_LATENCY_MS
        const val MIN_LIVE_OFFSET_MS = 1500L
        const val MAX_LIVE_OFFSET_MS = 3500L
        const val MIN_BUFFER_MS = 6000
        const val MAX_BUFFER_MS = 12000
        const val BUFFER_FOR_PLAYBACK_MS = 1000
        const val BUFFER_AFTER_REBUFFER_MS = 1500
        const val MINIMUM_LOAD_RETRY_COUNT = 6
        const val AD_PROGRESS_INTERVAL_MS = 500L
        const val EXPIRED_AD_CUE_RETENTION_MS = 30 * 60_000L
        const val PRIMARY_LATENCY_FRESHNESS_MS = 2500L
        const val CORRECTION_EDGE_GUARD_MS = 250L
        const val CORRECTION_MINIMUM_ADVANCE_MS = 100L
        const val CORRECTION_TARGET_TOLERANCE_MS = 100L
        const val CORRECTION_MEASUREMENT_MAX_AGE_MS = 2500L
        const val MAX_CORRECTION_SEEK_ATTEMPTS = 3
    }
}

private fun inactiveAdEvent(): Map<String, Any?> = mapOf(
    "type" to "ad",
    "active" to false,
)

internal fun roundRemainingAdTimeMs(remainingMs: Long): Long =
    if (remainingMs <= 0) 0 else ((remainingMs + 999L) / 1000L) * 1000L
