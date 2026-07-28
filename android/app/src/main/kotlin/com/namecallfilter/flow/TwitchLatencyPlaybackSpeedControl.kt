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
        DefaultLivePlaybackSpeedControl.Builder()
            .setFallbackMinPlaybackSpeed(MIN_PLAYBACK_SPEED)
            .setFallbackMaxPlaybackSpeed(MAX_PLAYBACK_SPEED)
            .setMinUpdateIntervalMs(MIN_PLAYBACK_SPEED_UPDATE_INTERVAL_MS)
            .build()
    },
) : LivePlaybackSpeedControl {
    private var delegate = delegateFactory()
    private var liveConfiguration: MediaItem.LiveConfiguration? = null
    private var measurement: Measurement? = null

    @Synchronized
    fun reset() {
        measurement = null
        delegate = delegateFactory()
        liveConfiguration?.let(delegate::setLiveConfiguration)
        logger("speed control reset")
    }

    @Synchronized
    fun updateLatencyMeasurement(
        latencyMs: Long,
        source: LiveLatencyMeasurementSource = LiveLatencyMeasurementSource.TRANSC_R,
    ) {
        if (latencyMs < 0 || source != LiveLatencyMeasurementSource.TRANSC_R) {
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
        // Rebuffering must not move the validated transc_r correction target.
    }

    @Synchronized
    override fun getAdjustedPlaybackSpeed(
        liveOffsetUs: Long,
        bufferedDurationUs: Long,
    ): Float {
        // Ignore Media3's timeline offset and use only a fresh transc_r measurement.
        val currentMeasurement = measurement ?: return MIN_PLAYBACK_SPEED
        val measurementAgeMs = realtimeClockMs() - currentMeasurement.realtimeMs
        if (measurementAgeMs !in 0..MAX_MEASUREMENT_AGE_MS) {
            return MIN_PLAYBACK_SPEED
        }
        return delegate.getAdjustedPlaybackSpeed(
            Util.msToUs(currentMeasurement.latencyMs),
            bufferedDurationUs,
        )
    }

    @Synchronized
    override fun getTargetLiveOffsetUs(): Long = Util.msToUs(LOAD_CONTROL_TARGET_LIVE_OFFSET_MS)

    private data class Measurement(
        val latencyMs: Long,
        val realtimeMs: Long,
    )

    internal companion object {
        const val TARGET_LIVE_OFFSET_MS = 1_650L
        // DefaultLoadControl caps readiness at half the reported live target.
        const val LOAD_CONTROL_TARGET_LIVE_OFFSET_MS = 3_000L
        const val MIN_PLAYBACK_SPEED = 1.0f
        const val MAX_PLAYBACK_SPEED = 1.03f
        const val MIN_PLAYBACK_SPEED_UPDATE_INTERVAL_MS = 5_000L
        const val MAX_MEASUREMENT_AGE_MS = 6_000L
        private const val LOG_TAG = "FlowTwitchPlayer"
    }
}
