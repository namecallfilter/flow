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
}

internal enum class TwitchLatencySpeedReason {
    NO_MEASUREMENT,
    STALE_MEASUREMENT,
    LOW_BUFFER,
    TARGET_RANGE,
    HIGH_LATENCY,
}

internal data class TwitchLatencySpeedInput(
    val latencyMs: Long?,
    val measurementAgeMs: Long?,
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
 * Playback speed uses one stable correction level. Enter/exit
 * hysteresis prevents normal segment-metadata jitter around the target from
 * repeatedly rebuilding Media3's time-stretching audio pipeline. Catch-up stays
 * at the same speed until latency reaches the exit threshold.
 *
 * Low buffer uses a separate hysteresis gate. This avoids oscillating between
 * 1x and catch-up speed when the reported buffered duration sits on a boundary.
 */
internal class TwitchLatencySpeedPolicy {
    private var catchingUp = false
    private var bufferConstrained = false

    fun reset() {
        catchingUp = false
        bufferConstrained = false
    }

    fun decide(input: TwitchLatencySpeedInput): TwitchLatencySpeedDecision {
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

        if (!catchingUp && latencyMs < CATCH_UP_ENTER_LATENCY_MS) {
            return steady(TwitchLatencySpeedReason.TARGET_RANGE)
        }
        if (catchingUp && latencyMs <= CATCH_UP_EXIT_LATENCY_MS) {
            reset()
            return steady(TwitchLatencySpeedReason.TARGET_RANGE)
        }
        if (!catchingUp) {
            catchingUp = true
            // Enter catch-up only after a full safety buffer is available.
            // Once active, the lower pause threshold prevents a normal HLS
            // buffer sawtooth from repeatedly toggling the audio processor.
            bufferConstrained = true
        }

        val bufferedDurationMs = input.bufferedDurationMs
        bufferConstrained = when {
            bufferedDurationMs == null -> true
            bufferConstrained -> bufferedDurationMs < RESUME_CATCH_UP_BUFFER_MS
            else -> bufferedDurationMs < PAUSE_CATCH_UP_BUFFER_MS
        }
        val speed = if (bufferConstrained) NORMAL_PLAYBACK_SPEED else CATCH_UP_SPEED
        return TwitchLatencySpeedDecision(
            speed = speed,
            mode = TwitchLatencySpeedMode.CATCHING_UP,
            reason = if (bufferConstrained) {
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
        const val CATCH_UP_ENTER_LATENCY_MS = 1_850L
        const val CATCH_UP_EXIT_LATENCY_MS = TARGET_LATENCY_MS
        const val PAUSE_CATCH_UP_BUFFER_MS = 250L
        const val RESUME_CATCH_UP_BUFFER_MS = 1_000L
        const val MAX_MEASUREMENT_AGE_MS = 6_000L
        const val NORMAL_PLAYBACK_SPEED = 1.0f
        const val CATCH_UP_SPEED = 1.03f
        const val MAX_PLAYBACK_SPEED = CATCH_UP_SPEED
        const val MIN_PLAYBACK_SPEED = NORMAL_PLAYBACK_SPEED
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
    private var lastLoggedDecision: TwitchLatencySpeedDecision? = null

    @Synchronized
    fun reset() {
        measurement = null
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
        // Media3 calls this only for buffer depletion. The playback position has
        // not discontinuously changed, so the last validated latency remains
        // useful if the rebuffer is brief. Age validation still prevents an old
        // sample from driving correction after a long stall.
        logger("speed control preserving fresh latency through rebuffer")
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
