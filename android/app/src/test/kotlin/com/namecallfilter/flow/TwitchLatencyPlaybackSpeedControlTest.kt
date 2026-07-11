package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Test

@UnstableApi
class TwitchLatencyPlaybackSpeedControlTest {
    private val policy = TwitchLatencySpeedPolicy()

    @Test
    fun catchUpIsBoundedBetweenOneAndOnePointZeroThree() {
        listOf(700L, 1_500L, 1_650L, 1_849L).forEach { latencyMs ->
            assertSpeed(1.0f, policy.decide(input(latencyMs = latencyMs)))
        }

        assertSpeed(1.03f, policy.decide(input(latencyMs = 1_850L)))
        assertSpeed(1.03f, policy.decide(input(latencyMs = Long.MAX_VALUE)))
    }

    @Test
    fun latencyHysteresisDoesNotToggleAudioSpeedAroundTarget() {
        assertSpeed(1.03f, policy.decide(input(latencyMs = 1_850L)))

        listOf(1_825L, 1_725L, 1_651L).forEach { latencyMs ->
            assertSpeed(1.03f, policy.decide(input(latencyMs = latencyMs)))
        }
        assertSpeed(1.0f, policy.decide(input(latencyMs = 1_650L)))
        assertSpeed(1.0f, policy.decide(input(latencyMs = 1_849L)))
    }

    @Test
    fun oneCatchUpSpeedAvoidsAudioPipelineChurnAsLatencyChanges() {
        listOf(1_850L, 2_000L, 2_500L, 3_500L, 8_000L, 2_200L, 1_651L).forEach { latencyMs ->
            assertSpeed(1.03f, policy.decide(input(latencyMs = latencyMs)))
        }
    }

    @Test
    fun bufferGateHasHysteresisAndKeepsCatchUpArmed() {
        assertDecision(
            speed = 1.0f,
            reason = TwitchLatencySpeedReason.LOW_BUFFER,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 249L)),
        )
        assertDecision(
            speed = 1.0f,
            reason = TwitchLatencySpeedReason.LOW_BUFFER,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 999L)),
        )
        assertDecision(
            speed = 1.03f,
            reason = TwitchLatencySpeedReason.HIGH_LATENCY,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 1_000L)),
        )
        assertDecision(
            speed = 1.03f,
            reason = TwitchLatencySpeedReason.HIGH_LATENCY,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 500L)),
        )
        assertDecision(
            speed = 1.0f,
            reason = TwitchLatencySpeedReason.LOW_BUFFER,
            policy.decide(input(latencyMs = 4_000L, bufferedDurationMs = 249L)),
        )
    }

    @Test
    fun firstCatchUpEntryRequiresTheFullResumeBuffer() {
        val firstAtNineHundredNinetyNine = TwitchLatencySpeedPolicy().decide(
            input(latencyMs = 4_000L, bufferedDurationMs = 999L),
        )
        assertDecision(
            speed = 1.0f,
            reason = TwitchLatencySpeedReason.LOW_BUFFER,
            decision = firstAtNineHundredNinetyNine,
        )

        val firstAtOneSecond = TwitchLatencySpeedPolicy().decide(
            input(latencyMs = 4_000L, bufferedDurationMs = 1_000L),
        )
        assertDecision(
            speed = 1.03f,
            reason = TwitchLatencySpeedReason.HIGH_LATENCY,
            decision = firstAtOneSecond,
        )
    }

    @Test
    fun missingAndStaleMeasurementsNeverChangeSpeed() {
        listOf(
            input(latencyMs = null),
            input(latencyMs = 6_000L, measurementAgeMs = 6_001L),
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
    fun briefRebufferPreservesFreshCorrection() {
        var realtimeMs = 10_000L
        val controller = TwitchLatencyPlaybackSpeedControl(
            realtimeClockMs = { realtimeMs },
            logger = {},
        )
        controller.setPlaybackActive(true)
        controller.updateLatencyMeasurement(4_000L)
        assertSpeed(1.03f, adjustedSpeed(controller))

        controller.notifyRebuffer()
        assertSpeed(1.03f, adjustedSpeed(controller))
    }

    @Test
    fun staleGapStopsSpeedWithoutDiscardingCatchUpHysteresis() {
        val policy = TwitchLatencySpeedPolicy()
        assertSpeed(1.03f, policy.decide(input(latencyMs = 1_900L)))
        assertSpeed(
            1.0f,
            policy.decide(input(latencyMs = 1_800L, measurementAgeMs = 6_001L)),
        )
        assertSpeed(
            1.03f,
            policy.decide(input(latencyMs = 1_800L, measurementAgeMs = 0L)),
        )
    }

    @Test
    fun asynchronousIsPlayingCallbackCannotSuppressMedia3Correction() {
        var realtimeMs = 10_000L
        val controller = TwitchLatencyPlaybackSpeedControl(
            realtimeClockMs = { realtimeMs },
            logger = {},
        )
        controller.setPlaybackActive(true)
        controller.updateLatencyMeasurement(2_000L)
        assertSpeed(1.03f, adjustedSpeed(controller))

        controller.setPlaybackActive(false)
        realtimeMs += 250L
        assertSpeed(1.03f, adjustedSpeed(controller))

        controller.setPlaybackActive(true)
        assertSpeed(1.03f, adjustedSpeed(controller))
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

        assertSpeed(1.03f, adjustedSpeed(controller))
    }

    private fun input(
        latencyMs: Long? = 3_000L,
        measurementAgeMs: Long? = 500L,
        bufferedDurationMs: Long? = 4_000L,
    ) = TwitchLatencySpeedInput(
        latencyMs = latencyMs,
        measurementAgeMs = measurementAgeMs,
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
