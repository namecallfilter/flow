package com.namecallfilter.flow

import android.os.SystemClock
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.exoplayer.DefaultLivePlaybackSpeedControl
import androidx.media3.exoplayer.LivePlaybackSpeedControl

/** Media3 live-speed control driven by validated Twitch `transc_r` latency. */
@UnstableApi
internal class TwitchLatencyPlaybackSpeedControl(
    private val realtimeClockMs: () -> Long = SystemClock::elapsedRealtime,
    private val logger: (String) -> Unit = { message -> Log.d(LOG_TAG, message) },
    private val delegateFactory: () -> LivePlaybackSpeedControl = {
        DefaultLivePlaybackSpeedControl.Builder().build()
    },
) : LivePlaybackSpeedControl {
    private var delegate = delegateFactory()
    private var liveConfiguration: MediaItem.LiveConfiguration? = null
    private var measurement: Measurement? = null
    @Volatile
    var lastAdjustedPlaybackSpeed = 1f
        private set

    @Synchronized
    fun reset() {
        measurement = null
        delegate = delegateFactory()
        liveConfiguration?.let(delegate::setLiveConfiguration)
        logger("speed control reset")
    }

    @Synchronized
    fun updateLatencyMeasurement(latencyMs: Long) {
        if (latencyMs < 0) {
            return
        }
        measurement = Measurement(latencyMs, realtimeClockMs())
    }

    @Synchronized
    fun invalidateMeasurementForDiscontinuity(reason: String) {
        measurement = null
        logger("speed control waiting for fresh transc_r reason=$reason")
    }

    @Synchronized
    override fun setLiveConfiguration(liveConfiguration: MediaItem.LiveConfiguration) {
        this.liveConfiguration = liveConfiguration
        delegate.setLiveConfiguration(liveConfiguration)
    }

    @Synchronized
    override fun setTargetLiveOffsetOverrideUs(liveOffsetUs: Long) {
        // Twitch prefetch makes Media3's timeline-derived live offset inaccurate.
    }

    @Synchronized
    override fun notifyRebuffer() {
        delegate.notifyRebuffer()
        measurement = null
        logger("rebuffer target=${Util.usToMs(delegate.targetLiveOffsetUs)}ms")
    }

    @Synchronized
    override fun getAdjustedPlaybackSpeed(
        liveOffsetUs: Long,
        bufferedDurationUs: Long,
    ): Float {
        // Ignore Media3's timeline offset and use only a fresh transc_r measurement.
        val currentMeasurement = measurement
        val measurementAgeMs = currentMeasurement?.let { realtimeClockMs() - it.realtimeMs } ?: -1L
        val speed = if (currentMeasurement != null && measurementAgeMs in 0..MAX_MEASUREMENT_AGE_MS) {
            delegate.getAdjustedPlaybackSpeed(
                Util.msToUs(currentMeasurement.latencyMs),
                bufferedDurationUs,
            )
        } else {
            1f
        }
        lastAdjustedPlaybackSpeed = speed
        return speed
    }

    @Synchronized
    override fun getTargetLiveOffsetUs(): Long = delegate.targetLiveOffsetUs

    private data class Measurement(
        val latencyMs: Long,
        val realtimeMs: Long,
    )

    internal companion object {
        const val TARGET_LIVE_OFFSET_MS = 1_600L
        const val MIN_PLAYBACK_SPEED = DefaultLivePlaybackSpeedControl.DEFAULT_FALLBACK_MIN_PLAYBACK_SPEED
        // Let native proportional control recover brief proxy/startup delays sooner.
        const val MAX_PLAYBACK_SPEED = 1.10f
        const val MAX_MEASUREMENT_AGE_MS = 6_000L
        private const val LOG_TAG = "FlowTwitchPlayer"
    }
}
