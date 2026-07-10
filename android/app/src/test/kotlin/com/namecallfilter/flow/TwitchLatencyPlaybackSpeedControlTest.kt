package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class TwitchLatencyPlaybackSpeedControlTest {
    private val policy = TwitchLatencySpeedPolicy()

    @Test
    fun proportionalCatchUpRespondsBeforeLatencyCanRatchetUpward() {
        assertSpeed(1.0075f, policy.decide(input(latencyMs = 1_800L)))
        assertSpeed(1.0175f, policy.decide(input(latencyMs = 2_000L)))
        assertSpeed(1.0375f, policy.decide(input(latencyMs = 2_400L)))
        assertSpeed(1.05f, policy.decide(input(latencyMs = 4_000L)))

        listOf(1_575L, 1_650L, 1_725L).forEach { latencyMs ->
            assertSpeed(1.0f, policy.decide(input(latencyMs = latencyMs)))
        }
    }

    @Test
    fun bufferTiersCapCatchUpWithoutDisablingItAtNormalLowLatencyBuffers() {
        assertDecision(
            speed = 1.0f,
            reason = TwitchLatencySpeedReason.LOW_BUFFER,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 349L)),
        )
        assertDecision(
            speed = 1.01f,
            reason = TwitchLatencySpeedReason.LOW_BUFFER,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 500L)),
        )
        assertDecision(
            speed = 1.03f,
            reason = TwitchLatencySpeedReason.LOW_BUFFER,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 800L)),
        )
        assertDecision(
            speed = 1.05f,
            reason = TwitchLatencySpeedReason.HIGH_LATENCY,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 1_500L)),
        )
    }

    @Test
    fun dangerouslyLowLatencyRestoresSafetyProportionally() {
        assertSpeed(0.98f, policy.decide(input(latencyMs = 700L, bufferedDurationMs = 100L)))
        val gentle = policy.decide(input(latencyMs = 1_500L, bufferedDurationMs = 100L))
        assertTrue(gentle.speed in 0.99f..0.999f)
        assertEquals(TwitchLatencySpeedMode.RESTORING_SAFETY, gentle.mode)
    }

    @Test
    fun missingStaleAndInactiveMeasurementsNeverChangeSpeed() {
        listOf(
            input(latencyMs = null),
            input(latencyMs = 6_000L, measurementAgeMs = 3_501L),
            input(latencyMs = 6_000L, playbackActive = false),
        ).forEach { currentInput ->
            assertSpeed(1.0f, policy.decide(currentInput))
        }
    }

    @Test
    fun media3AdapterIgnoresTimelineOffsetsAndSyntheticTargetOverrides() {
        var realtimeMs = 10_000L
        val controller = TwitchLatencyPlaybackSpeedControl(
            realtimeClockMs = { realtimeMs },
            logger = {},
        )
        controller.setPlaybackActive(true)
        controller.updateLatencyMeasurement(2_000L)

        val nearTimelineOffset = controller.getAdjustedPlaybackSpeed(
            liveOffsetUs = 500_000L,
            bufferedDurationUs = 4_000_000L,
        )
        val farTimelineOffset = controller.getAdjustedPlaybackSpeed(
            liveOffsetUs = 50_000_000L,
            bufferedDurationUs = 4_000_000L,
        )
        assertEquals(nearTimelineOffset, farTimelineOffset, 0.0001f)

        controller.setTargetLiveOffsetOverrideUs(50_000_000L)
        assertEquals(3_000_000L, controller.targetLiveOffsetUs)

        controller.invalidateMeasurementForDiscontinuity("test seek")
        realtimeMs += 100L
        assertSpeed(
            1.0f,
            controller.getAdjustedPlaybackSpeed(
                liveOffsetUs = 50_000_000L,
                bufferedDurationUs = 4_000_000L,
            ),
        )
    }

    @Test
    fun freshTranscRImmediatelyRestartsCorrectionAfterRebuffer() {
        var realtimeMs = 10_000L
        val controller = TwitchLatencyPlaybackSpeedControl(
            realtimeClockMs = { realtimeMs },
            logger = {},
        )
        controller.setPlaybackActive(true)
        controller.updateLatencyMeasurement(4_000L)
        assertSpeed(1.05f, adjustedSpeed(controller))

        controller.notifyRebuffer()
        assertSpeed(1.0f, adjustedSpeed(controller))

        realtimeMs += 50L
        controller.updateLatencyMeasurement(4_000L)
        assertSpeed(1.05f, adjustedSpeed(controller))
    }

    @Test
    fun stitchedAdFallbackUsesTheSameBoundedPolicy() {
        val controller = TwitchLatencyPlaybackSpeedControl(
            realtimeClockMs = { 10_000L },
            logger = {},
        )
        controller.setPlaybackActive(true)
        controller.updateLatencyMeasurement(
            latencyMs = 2_000L,
            source = LiveLatencyMeasurementSource.STITCHED_AD_TIMELINE,
        )

        assertSpeed(1.0175f, adjustedSpeed(controller))
    }

    private fun input(
        latencyMs: Long? = 3_000L,
        measurementAgeMs: Long? = 500L,
        playbackActive: Boolean = true,
        bufferedDurationMs: Long? = 4_000L,
    ) = TwitchLatencySpeedInput(
        latencyMs = latencyMs,
        measurementAgeMs = measurementAgeMs,
        playbackActive = playbackActive,
        bufferedDurationMs = bufferedDurationMs,
    )

    private fun adjustedSpeed(controller: TwitchLatencyPlaybackSpeedControl): Float =
        controller.getAdjustedPlaybackSpeed(
            liveOffsetUs = 10_000_000L,
            bufferedDurationUs = 4_000_000L,
        )

    private fun assertSpeed(expected: Float, decision: TwitchLatencySpeedDecision) {
        assertEquals(expected, decision.speed, 0.0001f)
    }

    private fun assertSpeed(expected: Float, actual: Float) {
        assertEquals(expected, actual, 0.0001f)
    }

    private fun assertDecision(
        speed: Float,
        reason: TwitchLatencySpeedReason,
        decision: TwitchLatencySpeedDecision,
    ) {
        assertEquals(speed, decision.speed, 0.0001f)
        assertEquals(reason, decision.reason)
        assertEquals(TwitchLatencySpeedMode.CATCHING_UP, decision.mode)
    }
}
