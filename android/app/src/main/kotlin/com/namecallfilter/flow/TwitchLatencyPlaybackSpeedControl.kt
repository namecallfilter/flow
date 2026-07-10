package com.namecallfilter.flow

import android.os.SystemClock
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.LivePlaybackSpeedControl

internal enum class TwitchLatencySpeedMode {
    STEADY,
    CATCHING_UP,
    RESTORING_SAFETY,
}

internal enum class TwitchLatencySpeedReason {
    NO_MEASUREMENT,
    STALE_MEASUREMENT,
    PLAYBACK_INACTIVE,
    LOW_BUFFER,
    TARGET_RANGE,
    HIGH_LATENCY,
    LOW_LATENCY,
}

internal data class TwitchLatencySpeedInput(
    val latencyMs: Long?,
    val measurementAgeMs: Long?,
    val playbackActive: Boolean,
    val bufferedDurationMs: Long?,
)

internal data class TwitchLatencySpeedDecision(
    val speed: Float,
    val mode: TwitchLatencySpeedMode,
    val reason: TwitchLatencySpeedReason,
)

/**
 * A deliberately conservative controller around Twitch's validated transc_r latency.
 *
 * Playback speed is proportional to the measured target error, with a small 1x
 * deadband. Buffer tiers cap (rather than completely disable) catch-up so a
 * low-latency stream can correct slow upward drift without consuming its last
 * few hundred milliseconds of playable media.
 */
internal class TwitchLatencySpeedPolicy {
    fun reset() = Unit

    fun decide(input: TwitchLatencySpeedInput): TwitchLatencySpeedDecision {
        if (!input.playbackActive) {
            return steady(TwitchLatencySpeedReason.PLAYBACK_INACTIVE)
        }
        val latencyMs = input.latencyMs
            ?: return steady(TwitchLatencySpeedReason.NO_MEASUREMENT)
        val measurementAgeMs = input.measurementAgeMs
        if (
            measurementAgeMs == null ||
            measurementAgeMs < 0 ||
            measurementAgeMs > MAX_MEASUREMENT_AGE_MS
        ) {
            return steady(TwitchLatencySpeedReason.STALE_MEASUREMENT)
        }

        val errorMs = latencyMs - TARGET_LATENCY_MS
        if (errorMs in -TARGET_DEADBAND_MS..TARGET_DEADBAND_MS) {
            return steady(TwitchLatencySpeedReason.TARGET_RANGE)
        }
        val requestedSpeed = (
            NORMAL_PLAYBACK_SPEED +
                PROPORTIONAL_GAIN_PER_MILLISECOND * errorMs.toFloat()
            ).coerceIn(MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
        if (errorMs < 0) {
            return TwitchLatencySpeedDecision(
                speed = requestedSpeed,
                mode = TwitchLatencySpeedMode.RESTORING_SAFETY,
                reason = TwitchLatencySpeedReason.LOW_LATENCY,
            )
        }

        val bufferedDurationMs = input.bufferedDurationMs
        val speed = when {
            bufferedDurationMs == null || bufferedDurationMs < MIN_CATCH_UP_BUFFER_MS ->
                NORMAL_PLAYBACK_SPEED
            bufferedDurationMs < MEDIUM_CATCH_UP_BUFFER_MS ->
                minOf(requestedSpeed, GENTLE_CATCH_UP_SPEED)
            bufferedDurationMs < MAX_CATCH_UP_BUFFER_MS ->
                minOf(requestedSpeed, MEDIUM_CATCH_UP_SPEED)
            else -> requestedSpeed
        }
        return TwitchLatencySpeedDecision(
            speed = speed,
            mode = TwitchLatencySpeedMode.CATCHING_UP,
            reason = if (speed < requestedSpeed || speed == NORMAL_PLAYBACK_SPEED) {
                TwitchLatencySpeedReason.LOW_BUFFER
            } else {
                TwitchLatencySpeedReason.HIGH_LATENCY
            },
        )
    }

    private fun steady(
        reason: TwitchLatencySpeedReason,
    ): TwitchLatencySpeedDecision {
        return TwitchLatencySpeedDecision(
            speed = NORMAL_PLAYBACK_SPEED,
            mode = TwitchLatencySpeedMode.STEADY,
            reason = reason,
        )
    }

    internal companion object {
        const val TARGET_LATENCY_MS = 1_650L
        const val TARGET_DEADBAND_MS = 75L
        const val PROPORTIONAL_GAIN_PER_MILLISECOND = 0.00005f
        const val MIN_CATCH_UP_BUFFER_MS = 350L
        const val MEDIUM_CATCH_UP_BUFFER_MS = 750L
        const val MAX_CATCH_UP_BUFFER_MS = 1_500L
        const val MAX_MEASUREMENT_AGE_MS = 3_500L
        const val NORMAL_PLAYBACK_SPEED = 1.0f
        const val GENTLE_CATCH_UP_SPEED = 1.01f
        const val MEDIUM_CATCH_UP_SPEED = 1.03f
        const val MAX_PLAYBACK_SPEED = 1.05f
        const val MIN_PLAYBACK_SPEED = 0.98f
    }
}

/**
 * Media3 adapter driven by validated Twitch latency.
 *
 * Primary measurements always come from `transc_r`. During a stitched ad that
 * omits ID3 metadata, the player may provide its existing server-clock/timeline
 * fallback so correction remains continuous across the same HLS presentation.
 */
@UnstableApi
internal class TwitchLatencyPlaybackSpeedControl(
    private val realtimeClockMs: () -> Long = SystemClock::elapsedRealtime,
    private val logger: (String) -> Unit = { message -> Log.d(LOG_TAG, message) },
    loadControlTargetLiveOffsetMs: Long = LOAD_CONTROL_TARGET_LIVE_OFFSET_MS,
) : LivePlaybackSpeedControl {
    private val policy = TwitchLatencySpeedPolicy()
    private val loadControlTargetLiveOffsetUs =
        millisecondsToMicroseconds(loadControlTargetLiveOffsetMs)
    private var measurement: Measurement? = null
    private var playbackActive = false
    private var lastLoggedDecision: TwitchLatencySpeedDecision? = null

    @Synchronized
    fun reset() {
        measurement = null
        playbackActive = false
        lastLoggedDecision = null
        policy.reset()
        logger("speed control reset")
    }

    @Synchronized
    fun updateLatencyMeasurement(
        latencyMs: Long,
        source: LiveLatencyMeasurementSource = LiveLatencyMeasurementSource.TRANSC_R,
    ) {
        if (latencyMs < 0) {
            return
        }
        measurement = Measurement(latencyMs, realtimeClockMs(), source)
    }

    @Synchronized
    fun invalidateMeasurementForDiscontinuity(reason: String) {
        measurement = null
        policy.reset()
        lastLoggedDecision = null
        logger("speed control waiting for fresh transc_r reason=$reason")
    }

    @Synchronized
    fun setPlaybackActive(isActive: Boolean) {
        if (playbackActive && !isActive) {
            // A measurement taken before a pause, seek, or rebuffer no longer
            // describes the position playback will resume from.
            measurement = null
            policy.reset()
            lastLoggedDecision = null
        }
        playbackActive = isActive
    }

    @Synchronized
    override fun setLiveConfiguration(liveConfiguration: MediaItem.LiveConfiguration) = Unit

    @Synchronized
    override fun setTargetLiveOffsetOverrideUs(liveOffsetUs: Long) {
        // Media3 derives this override from its timeline after a seek. Twitch's
        // promoted prefetch segments make that offset disagree with transc_r.
        // Accepting it would also change LoadControl's target-based readiness
        // threshold, so the stable readiness target is kept instead.
    }

    @Synchronized
    override fun notifyRebuffer() {
        measurement = null
        policy.reset()
        lastLoggedDecision = null
        logger("speed control waiting for fresh transc_r after rebuffer")
    }

    @Synchronized
    override fun getAdjustedPlaybackSpeed(
        liveOffsetUs: Long,
        bufferedDurationUs: Long,
    ): Float {
        // liveOffsetUs is intentionally ignored: Twitch prefetch segments make
        // Media3's timeline offset differ from the transc_r latency shown in UI.
        val nowRealtimeMs = realtimeClockMs()
        val currentMeasurement = measurement
        val decision = policy.decide(
            TwitchLatencySpeedInput(
                latencyMs = currentMeasurement?.latencyMs,
                measurementAgeMs = currentMeasurement?.let {
                    nowRealtimeMs - it.realtimeMs
                },
                playbackActive = playbackActive,
                bufferedDurationMs = microsecondsToMillisecondsOrNull(bufferedDurationUs),
            ),
        )
        if (decision != lastLoggedDecision) {
            logger(
                "speed control speed=${decision.speed}x mode=${decision.mode} " +
                    "reason=${decision.reason} latency=${currentMeasurement?.latencyMs}ms " +
                    "source=${currentMeasurement?.source} " +
                    "buffered=${microsecondsToMillisecondsOrNull(bufferedDurationUs)}ms",
            )
            lastLoggedDecision = decision
        }
        return decision.speed
    }

    @Synchronized
    override fun getTargetLiveOffsetUs(): Long = loadControlTargetLiveOffsetUs

    private data class Measurement(
        val latencyMs: Long,
        val realtimeMs: Long,
        val source: LiveLatencyMeasurementSource,
    )

    internal companion object {
        const val LOG_TAG = "FlowTwitchPlayer"
        // DefaultLoadControl caps startup/rebuffer readiness at half of this
        // interface target. Three seconds preserves the configured 1.0s startup
        // and 1.5s post-rebuffer thresholds without changing the 1.65s transc_r
        // target used by the HLS source, action seeks, or speed policy.
        const val LOAD_CONTROL_TARGET_LIVE_OFFSET_MS = 3_000L
    }
}

private fun millisecondsToMicroseconds(milliseconds: Long): Long {
    if (milliseconds < 0) {
        return C.TIME_UNSET
    }
    return runCatching { Math.multiplyExact(milliseconds, 1_000L) }
        .getOrDefault(C.TIME_UNSET)
}

private fun microsecondsToMillisecondsOrNull(microseconds: Long): Long? =
    microseconds
        .takeUnless { it == C.TIME_UNSET || it < 0 }
        ?.div(1_000L)
