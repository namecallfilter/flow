package com.namecallfilter.flow

import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.LivePlaybackSpeedControl
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class TwitchLatencyPlaybackSpeedControlTest {
    @Test
    fun freshTranscRReplacesTimelineOffsetAndPreservesBufferedDuration() {
        val delegates = mutableListOf<RecordingLivePlaybackSpeedControl>()
        val controller = controller(clockMs = { 10_000L }, delegates = delegates)
        controller.updateLatencyMeasurement(
            latencyMs = 9_000L,
            source = LiveLatencyMeasurementSource.STITCHED_AD_TIMELINE,
        )
        assertSpeed(
            1.0f,
            controller.getAdjustedPlaybackSpeed(
                liveOffsetUs = 50_000_000L,
                bufferedDurationUs = 4_000_000L,
            ),
        )

        controller.updateLatencyMeasurement(2_000L)
        assertSpeed(
            DELEGATE_SPEED,
            controller.getAdjustedPlaybackSpeed(
                liveOffsetUs = 50_000_000L,
                bufferedDurationUs = 4_000_000L,
            ),
        )

        assertEquals(
            listOf(AdjustedSpeedCall(liveOffsetUs = 2_000_000L, bufferedDurationUs = 4_000_000L)),
            delegates.single().adjustedSpeedCalls,
        )
    }

    @Test
    fun staleTranscRReturnsUnitSpeedWithoutCallingDelegate() {
        var nowMs = 10_000L
        val delegates = mutableListOf<RecordingLivePlaybackSpeedControl>()
        val controller = controller(clockMs = { nowMs }, delegates = delegates)
        controller.updateLatencyMeasurement(2_000L)
        nowMs += TwitchLatencyPlaybackSpeedControl.MAX_MEASUREMENT_AGE_MS + 1L

        assertSpeed(
            1.0f,
            controller.getAdjustedPlaybackSpeed(
                liveOffsetUs = 50_000_000L,
                bufferedDurationUs = 4_000_000L,
            ),
        )
        assertTrue(delegates.single().adjustedSpeedCalls.isEmpty())
    }

    @Test
    fun resetRecreatesDelegateAndClearsTranscR() {
        val delegates = mutableListOf<RecordingLivePlaybackSpeedControl>()
        val controller = controller(clockMs = { 10_000L }, delegates = delegates)
        val liveConfiguration = liveConfiguration()
        controller.setLiveConfiguration(liveConfiguration)
        controller.updateLatencyMeasurement(2_000L)

        controller.reset()

        assertEquals(2, delegates.size)
        assertSame(liveConfiguration, delegates.last().receivedLiveConfiguration)
        assertSpeed(
            1.0f,
            controller.getAdjustedPlaybackSpeed(
                liveOffsetUs = 50_000_000L,
                bufferedDurationUs = 4_000_000L,
            ),
        )
        assertTrue(delegates.last().adjustedSpeedCalls.isEmpty())
    }

    @Test
    fun invalidatedTranscRWaitsForFreshMeasurement() {
        val delegates = mutableListOf<RecordingLivePlaybackSpeedControl>()
        val controller = controller(clockMs = { 10_000L }, delegates = delegates)
        controller.updateLatencyMeasurement(2_000L)
        assertSpeed(DELEGATE_SPEED, adjustedSpeed(controller))

        controller.invalidateMeasurementForDiscontinuity("test seek")
        assertSpeed(1.0f, adjustedSpeed(controller))
        assertEquals(1, delegates.single().adjustedSpeedCalls.size)

        controller.updateLatencyMeasurement(2_200L)
        assertSpeed(DELEGATE_SPEED, adjustedSpeed(controller))
        assertEquals(
            AdjustedSpeedCall(liveOffsetUs = 2_200_000L, bufferedDurationUs = 4_000_000L),
            delegates.single().adjustedSpeedCalls.last(),
        )
    }

    @Test
    fun forwardsConfigurationButKeepsRebufferAndLoadControlTargetsIndependent() {
        val delegates = mutableListOf<RecordingLivePlaybackSpeedControl>()
        val controller = controller(clockMs = { 10_000L }, delegates = delegates)
        val liveConfiguration = liveConfiguration()

        controller.setLiveConfiguration(liveConfiguration)
        controller.notifyRebuffer()
        controller.setTargetLiveOffsetOverrideUs(50_000_000L)

        val delegate = delegates.single()
        assertSame(liveConfiguration, delegate.receivedLiveConfiguration)
        assertEquals(0, delegate.rebufferCount)
        assertTrue(delegate.targetLiveOffsetOverridesUs.isEmpty())
        assertEquals(3_000_000L, controller.targetLiveOffsetUs)
        assertEquals(1_650L, liveConfiguration.targetOffsetMs)
        assertEquals(1.0f, liveConfiguration.minPlaybackSpeed, 0.0001f)
        assertEquals(1.03f, liveConfiguration.maxPlaybackSpeed, 0.0001f)
        assertEquals(
            5_000L,
            TwitchLatencyPlaybackSpeedControl.MIN_PLAYBACK_SPEED_UPDATE_INTERVAL_MS,
        )
    }

    private fun controller(
        clockMs: () -> Long,
        delegates: MutableList<RecordingLivePlaybackSpeedControl>,
    ) = TwitchLatencyPlaybackSpeedControl(
        realtimeClockMs = clockMs,
        logger = {},
        delegateFactory = {
            RecordingLivePlaybackSpeedControl().also(delegates::add)
        },
    )

    private fun adjustedSpeed(controller: TwitchLatencyPlaybackSpeedControl): Float =
        controller.getAdjustedPlaybackSpeed(
            liveOffsetUs = 50_000_000L,
            bufferedDurationUs = 4_000_000L,
        )

    private fun liveConfiguration(): MediaItem.LiveConfiguration =
        MediaItem.LiveConfiguration.Builder()
            .setTargetOffsetMs(TwitchLatencyPlaybackSpeedControl.TARGET_LIVE_OFFSET_MS)
            .setMinPlaybackSpeed(TwitchLatencyPlaybackSpeedControl.MIN_PLAYBACK_SPEED)
            .setMaxPlaybackSpeed(TwitchLatencyPlaybackSpeedControl.MAX_PLAYBACK_SPEED)
            .build()

    private fun assertSpeed(expected: Float, actual: Float) {
        assertEquals(expected, actual, 0.0001f)
    }

    private data class AdjustedSpeedCall(
        val liveOffsetUs: Long,
        val bufferedDurationUs: Long,
    )

    private class RecordingLivePlaybackSpeedControl : LivePlaybackSpeedControl {
        var receivedLiveConfiguration: MediaItem.LiveConfiguration? = null
        var rebufferCount = 0
        val targetLiveOffsetOverridesUs = mutableListOf<Long>()
        val adjustedSpeedCalls = mutableListOf<AdjustedSpeedCall>()

        override fun setLiveConfiguration(liveConfiguration: MediaItem.LiveConfiguration) {
            receivedLiveConfiguration = liveConfiguration
        }

        override fun setTargetLiveOffsetOverrideUs(liveOffsetUs: Long) {
            targetLiveOffsetOverridesUs += liveOffsetUs
        }

        override fun notifyRebuffer() {
            rebufferCount++
        }

        override fun getAdjustedPlaybackSpeed(
            liveOffsetUs: Long,
            bufferedDurationUs: Long,
        ): Float {
            adjustedSpeedCalls += AdjustedSpeedCall(liveOffsetUs, bufferedDurationUs)
            return DELEGATE_SPEED
        }

        override fun getTargetLiveOffsetUs(): Long = DELEGATE_TARGET_LIVE_OFFSET_US
    }

    private companion object {
        const val DELEGATE_SPEED = 1.02f
        const val DELEGATE_TARGET_LIVE_OFFSET_US = 1_650_000L
    }
}
