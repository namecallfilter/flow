package com.namecallfilter.flow

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.LayoutInflater
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
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.trackselection.AdaptiveTrackSelection
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.ui.PlayerView
import java.io.IOException
import java.net.URI
import kotlin.math.roundToInt

internal sealed interface TwitchPlayerEvent {
    data class Latency(val latencyMs: Long?) : TwitchPlayerEvent

    data class Ad(
        val active: Boolean,
        val current: Int = 0,
        val total: Int = 0,
        val remainingMs: Long = 0,
    ) : TwitchPlayerEvent

    data class State(
        val isPlaying: Boolean,
        val isBuffering: Boolean,
        val playWhenReady: Boolean,
    ) : TwitchPlayerEvent

    data class Qualities(
        val qualities: List<TwitchQualityOption>,
        val selectedId: String,
    ) : TwitchPlayerEvent

    data class Error(val message: String) : TwitchPlayerEvent
}

internal data class TwitchQualityOption(
    val id: String,
    val label: String,
)

@UnstableApi
internal class TwitchPlayerView(
    context: Context,
    private val initialUrl: String?,
    private val proxyUrls: List<String>,
    private val playbackUriRefresher: () -> String,
    private val onEvent: (TwitchPlayerEvent) -> Unit = {},
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val playerView = LayoutInflater.from(context).inflate(
        R.layout.flow_twitch_player,
        null,
        false,
    ) as PlayerView
    private val liveSpeedControl = TwitchLatencyPlaybackSpeedControl()
    private val latencyCorrection = LiveLatencyCorrectionCoordinator(
        maximumSeekAttempts = MAX_CORRECTION_SEEK_ATTEMPTS,
    )
    private val behindLiveWindowRecovery = BehindLiveWindowRecoveryCoordinator()
    private val player: ExoPlayer
    private var latencySession: TwitchLatencySession? = null
    private var metadataListener: Player.Listener? = null
    private var sessionGeneration = 0L
    private var latestLatencyMs: Long? = null
    private var lastPrimaryLatencyRealtimeMs: Long? = null
    private var latestError: String? = null
    private var latestQualities: List<TwitchQualityOption> = emptyList()
    private var selectedQualityId = AUTO_QUALITY_ID
    private val qualityOverrides = mutableMapOf<String, TrackSelectionOverride>()
    private val adCues = mutableMapOf<String, TwitchAdCue>()
    private val stitchedAdLatencyFallback = StitchedAdLatencyFallback()
    private var latestAdEvent = inactiveAdEvent()
    private var hasRenderedFirstFrame = false
    private var latestCorrectionMeasurement: LiveLatencyMeasurement? = null
    private var correctionMeasurementSequence = 0L
    private var lastCorrectionWaitReason: String? = null
    private var initialized = false
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
            if (playbackState == Player.STATE_BUFFERING) {
                latestCorrectionMeasurement = null
                if (hasRenderedFirstFrame && player.playWhenReady) {
                    Log.d(
                        LOG_TAG,
                        "rebuffer buffered=${player.totalBufferedDuration}ms " +
                            "media3LiveOffset=${player.currentLiveOffset}ms " +
                            "measuredLatency=${latestLatencyMs}ms; " +
                            "see speed-control decision for adjusted speed",
                    )
                }
            }
            maybeApplyPendingLatencyCorrection()
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            maybeApplyPendingLatencyCorrection()
            emitState()
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            if (!playWhenReady) {
                latestCorrectionMeasurement = null
            }
            maybeApplyPendingLatencyCorrection()
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            if (
                error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW &&
                behindLiveWindowRecovery.tryBeginRecovery()
            ) {
                recoverFromBehindLiveWindow(error)
                return
            }
            latestError = error.message ?: "The stream could not be played."
            Log.e(LOG_TAG, "playback failed", error)
            emitError(latestError!!)
        }

        override fun onRenderedFirstFrame() {
            behindLiveWindowRecovery.onRenderedFirstFrame()
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
        val trackSelector = DefaultTrackSelector(
            context,
            AdaptiveTrackSelection.Factory(
                AUTO_QUALITY_MIN_DURATION_FOR_INCREASE_MS,
                AUTO_QUALITY_MAX_DURATION_FOR_DECREASE_MS,
                AUTO_QUALITY_MIN_DURATION_TO_RETAIN_MS,
                AUTO_QUALITY_BANDWIDTH_FRACTION,
                AUTO_QUALITY_BUFFERED_FRACTION_TO_LIVE_EDGE,
                Clock.DEFAULT,
            ),
        )
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
            .setTrackSelector(trackSelector)
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
                "transc_r speed range=${TwitchLatencyPlaybackSpeedControl.MIN_PLAYBACK_SPEED}x-" +
                "${TwitchLatencyPlaybackSpeedControl.MAX_PLAYBACK_SPEED}x",
        )

        mainHandler.post(adProgressTicker)
    }

    val view: PlayerView
        get() = playerView

    fun initialize() {
        if (initialized || disposed) return
        initialized = true
        initialUrl?.takeIf { it.isNotBlank() }?.let(::load)
        emitState()
        emitLatency(latestLatencyMs)
        emitQualities()
        emit(latestAdEvent)
        latestError?.let(::emitError)
    }

    fun play() {
        if (!disposed) resumeAtLiveEdge()
    }

    fun pause() {
        if (!disposed) player.pause()
    }

    fun togglePlayback() {
        if (disposed) return
        if (player.playWhenReady) player.pause() else resumeAtLiveEdge()
    }

    fun jumpToLive() {
        if (!disposed) jumpToLiveEdge()
    }

    fun release() {
        if (disposed) return
        disposed = true
        mainHandler.removeCallbacks(adProgressTicker)
        sessionGeneration++
        liveSpeedControl.reset()
        latencyCorrection.reset()
        behindLiveWindowRecovery.reset()
        metadataListener?.let(player::removeListener)
        metadataListener = null
        latencySession = null
        adCues.clear()
        stitchedAdLatencyFallback.reset()
        playerView.player = null
        player.release()
    }

    private fun load(url: String) {
        val playbackUrl = withDeviceSupportedTwitchCodecs(url)
        val generation = ++sessionGeneration
        liveSpeedControl.reset()
        latencyCorrection.reset()
        behindLiveWindowRecovery.reset()
        latestLatencyMs = null
        lastPrimaryLatencyRealtimeMs = null
        latestError = null
        latestQualities = emptyList()
        adCues.clear()
        stitchedAdLatencyFallback.reset()
        qualityOverrides.clear()
        selectedQualityId = AUTO_QUALITY_ID
        clearVideoTrackOverride()
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
        emitAd(null)

        metadataListener?.let(player::removeListener)
        lateinit var session: TwitchLatencySession
        session = TwitchLatencySession(
            onAcceptedLatency = { latencyMs ->
                if (generation == sessionGeneration && player.playWhenReady) {
                    val measuredRealtimeMs = SystemClock.elapsedRealtime()
                    lastPrimaryLatencyRealtimeMs = measuredRealtimeMs
                    if (stitchedAdLatencyFallback.onAcceptedPrimaryLatency()) {
                        Log.d(LOG_TAG, "latency switched from stitched-ad timeline to transc_r")
                    }
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
        val hlsDataSourceFactory = AdaptiveTwitchHlsDataSourceFactory(
            manifestResolver = TwitchPlaybackCoordinator(
                rootUsherUri = playbackUrl,
                directFactory = directDataSourceFactory,
                proxyFactories = proxyDataSourceFactories,
                freshRootUsherUri = ::refreshPlaybackUri,
                onEvent = { message -> Log.d(LOG_TAG, "adaptive ad proxy: $message") },
            ),
            directFactory = directDataSourceFactory,
        )
        val mediaSource = HlsMediaSource.Factory(hlsDataSourceFactory)
            .setExtractorFactory(TwitchEmsgMetadataBridgeExtractorFactory())
            .setMetadataType(HlsMediaSource.METADATA_TYPE_ID3)
            .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy())
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
        player.play()
    }

    private fun refreshPlaybackUri(): String {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            throw IOException("Playback URI refresh cannot run on the main thread")
        }
        if (disposed) throw IOException("Twitch player was disposed")
        val value = try {
            playbackUriRefresher()
        } catch (error: IOException) {
            throw error
        } catch (error: Exception) {
            throw IOException(error.message ?: "Playback URI refresh failed", error)
        }
        val uri = runCatching { URI(value) }.getOrNull()
        if (value.isBlank() || uri?.scheme != "https" || uri.host.isNullOrBlank()) {
            throw IOException("Playback URI refresh returned an invalid URL")
        }
        return withDeviceSupportedTwitchCodecs(value)
    }

    private fun resumeAtLiveEdge() {
        requestLatencyCorrection(LiveLatencyCorrectionReason.RESUME)
    }

    private fun jumpToLiveEdge() {
        requestLatencyCorrection(LiveLatencyCorrectionReason.EXPLICIT_JUMP)
    }

    private fun recoverFromBehindLiveWindow(error: PlaybackException) {
        val resumePlayback = player.playWhenReady
        Log.w(
            LOG_TAG,
            "behind live window; recovering at default position " +
                "playWhenReady=$resumePlayback",
            error,
        )

        hasRenderedFirstFrame = false
        latestError = null
        latestCorrectionMeasurement = null
        lastPrimaryLatencyRealtimeMs = null
        lastCorrectionWaitReason = null
        emitLatency(null)
        liveSpeedControl.invalidateMeasurementForDiscontinuity("behind live window recovery")
        latencyCorrection.arm(
            reason = LiveLatencyCorrectionReason.RESUME,
            targetLatencyMs = TARGET_LIVE_OFFSET_MS,
            requireMeasurementAfterSequence = correctionMeasurementSequence,
        )
        logLatencyCorrectionArmed(
            reason = LiveLatencyCorrectionReason.RESUME,
            measurementBarrier = correctionMeasurementSequence,
        )

        player.seekToDefaultPosition()
        player.prepare()
        player.playWhenReady = resumePlayback
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
        val visibleQualities = deduplicateQualities(qualities, selectedQualityId)
        val selectedQualityIsVisible = visibleQualities.any { it["id"] == selectedQualityId }
        if (selectedQualityId != AUTO_QUALITY_ID && !selectedQualityIsVisible) {
            clearVideoTrackOverride()
            selectedQualityId = AUTO_QUALITY_ID
        }
        latestQualities = visibleQualities.map { quality ->
            TwitchQualityOption(
                id = quality["id"].toString(),
                label = quality["label"].toString(),
            )
        }
        emitQualities()
    }

    fun setQuality(id: String): Boolean {
        if (id == selectedQualityId) {
            return true
        }
        if (id == AUTO_QUALITY_ID) {
            clearVideoTrackOverride()
            finishQualityChange(AUTO_QUALITY_ID)
            return true
        }

        val override = qualityOverrides[id] ?: return false
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .setOverrideForType(override)
            .build()
        finishQualityChange(id)
        return true
    }

    private fun finishQualityChange(id: String) {
        selectedQualityId = id
        emitQualities()
        if (player.playWhenReady) {
            requestLatencyCorrection(LiveLatencyCorrectionReason.QUALITY_CHANGE)
        }
    }

    private fun clearVideoTrackOverride() {
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .build()
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
        emit(TwitchPlayerEvent.Latency(latencyMs))
    }

    private fun emitState() {
        emit(
            TwitchPlayerEvent.State(
                isPlaying = player.isPlaying,
                isBuffering = player.playbackState == Player.STATE_BUFFERING,
                playWhenReady = player.playWhenReady,
            ),
        )
    }

    private fun emitQualities() {
        emit(
            TwitchPlayerEvent.Qualities(
                qualities = latestQualities,
                selectedId = selectedQualityId,
            ),
        )
    }

    private fun emitAd(progress: TwitchAdProgress?) {
        val event: TwitchPlayerEvent.Ad = if (progress == null) {
            inactiveAdEvent()
        } else {
            TwitchPlayerEvent.Ad(
                active = true,
                current = progress.current,
                total = progress.total,
                remainingMs = progress.podRemainingMs,
            )
        }
        if (event == latestAdEvent) {
            return
        }
        val wasActive = latestAdEvent.active
        val isActive = event.active
        latestAdEvent = event
        if (wasActive != isActive) {
            Log.d(LOG_TAG, if (isActive) "stitched ad started" else "stitched ad ended")
        }
        emit(event)
    }

    private fun emitError(message: String) {
        emit(TwitchPlayerEvent.Error(message))
    }

    private fun emit(event: TwitchPlayerEvent) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            onEvent(event)
        } else {
            mainHandler.post { onEvent(event) }
        }
    }

    private companion object {
        const val LOG_TAG = "FlowTwitchPlayer"
        const val USER_AGENT = "Flow/1.0 (Android Media3)"
        const val AUTO_QUALITY_ID = "auto"
        // Twitch's promoted prefetch segments distort Media3's calculated live
        // offset. HLS startup, action seeks, and playback speed therefore share
        // this validated transc_r target.
        const val TARGET_LIVE_OFFSET_MS = TwitchLatencyPlaybackSpeedControl.TARGET_LIVE_OFFSET_MS
        const val MIN_LIVE_OFFSET_MS = 1500L
        const val MAX_LIVE_OFFSET_MS = 3500L
        const val MIN_BUFFER_MS = 2000
        const val MAX_BUFFER_MS = 6000
        const val BUFFER_FOR_PLAYBACK_MS = 1000
        const val BUFFER_AFTER_REBUFFER_MS = 1500
        const val AUTO_QUALITY_MIN_DURATION_FOR_INCREASE_MS = 10_000
        // Keep the downgrade guard inside Twitch's 1.65-second live-edge buffer.
        const val AUTO_QUALITY_MAX_DURATION_FOR_DECREASE_MS = 1_000
        const val AUTO_QUALITY_MIN_DURATION_TO_RETAIN_MS = 10_000
        const val AUTO_QUALITY_BANDWIDTH_FRACTION = 0.60f
        const val AUTO_QUALITY_BUFFERED_FRACTION_TO_LIVE_EDGE = 0.90f
        const val AD_PROGRESS_INTERVAL_MS = 500L
        const val EXPIRED_AD_CUE_RETENTION_MS = 30 * 60_000L
        const val PRIMARY_LATENCY_FRESHNESS_MS = 2500L
        // Keep every correction seek above Media3's post-rebuffer threshold.
        const val CORRECTION_EDGE_GUARD_MS = BUFFER_AFTER_REBUFFER_MS + 500L
        const val CORRECTION_MINIMUM_ADVANCE_MS = 100L
        const val CORRECTION_TARGET_TOLERANCE_MS = 100L
        const val CORRECTION_MEASUREMENT_MAX_AGE_MS = 2500L
        const val MAX_CORRECTION_SEEK_ATTEMPTS = 3
    }
}

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

private fun inactiveAdEvent() = TwitchPlayerEvent.Ad(active = false)

internal fun roundRemainingAdTimeMs(remainingMs: Long): Long =
    if (remainingMs <= 0) 0 else ((remainingMs + 999L) / 1000L) * 1000L
