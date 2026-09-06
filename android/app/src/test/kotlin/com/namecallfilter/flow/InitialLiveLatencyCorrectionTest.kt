package com.namecallfilter.flow

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class InitialLiveLatencyCorrectionTest {
    @Test
    fun metadataFreePlaybackFinishesItsTimedOutRequestWithoutAReplay() {
        val coordinator = LiveLatencyCorrectionCoordinator(maximumSeekAttempts = 3)
        coordinator.arm(LiveLatencyCorrectionReason.QUALITY_CHANGE, 1_650L, 0L)

        assertTrue(coordinator.finishIfMetadataUnavailable(isPlaying = true, hasMeasuredLatency = false))
        assertFalse(coordinator.hasPendingRequest)
        assertEquals(
            LiveLatencyCorrectionOutcome.COMPLETE,
            evaluate(coordinator, measurement(latencyMs = 5_000L, sequence = 1L)).outcome,
        )
    }

    @Test
    fun stalledOrMeasuredPlaybackRetainsTheExistingTimeoutRecovery() {
        val coordinator = LiveLatencyCorrectionCoordinator(maximumSeekAttempts = 3)
        coordinator.arm(LiveLatencyCorrectionReason.RESUME, 1_650L, 0L)

        assertFalse(coordinator.finishIfMetadataUnavailable(isPlaying = false, hasMeasuredLatency = false))
        assertTrue(coordinator.hasPendingRequest)
        assertFalse(coordinator.finishIfMetadataUnavailable(isPlaying = true, hasMeasuredLatency = true))
        assertTrue(coordinator.hasPendingRequest)
    }

    @Test
    fun longPauseOrLargeLatencyReloadsInsteadOfChasingSixSecondsOfOldBuffer() {
        assertTrue(shouldReloadLivePlayback(pausedForMs = 10_000L))
        assertTrue(shouldReloadLivePlayback(measuredLatencyMs = 30_000L))
        assertFalse(shouldReloadLivePlayback(pausedForMs = 1_000L, measuredLatencyMs = 2_000L))
        assertFalse(shouldReloadLivePlayback())
    }

    @Test
    fun targetAndLowerLatenciesNeverSeekBackward() {
        listOf(500L, 1_750L).forEach { latencyMs ->
            val plan = plan(
                measuredLatencyMs = latencyMs,
                currentPositionMs = 10_000L,
                bufferedPositionMs = 15_000L,
                windowDurationMs = 15_000L,
            )

            assertEquals(LiveLatencyCorrectionPlanOutcome.AT_TARGET, plan.outcome)
            assertNull(plan.seekPositionMs)
        }
    }

    @Test
    fun knownLiveWindowAlsoBoundsAPartialBufferedCorrection() {
        val plan = plan(
            measuredLatencyMs = 4_500L,
            currentPositionMs = 10_000L,
            bufferedPositionMs = 14_000L,
            windowDurationMs = 13_000L,
        )

        assertEquals(LiveLatencyCorrectionPlanOutcome.SEEK, plan.outcome)
        assertEquals(11_000L, plan.seekPositionMs)
    }

    @Test
    fun longPauseImmediatelyAdvancesToBufferedEdgeInsteadOfSpeedOnlyCatchUp() {
        val plan = plan(
            measuredLatencyMs = 15_990L,
            currentPositionMs = 16_019L,
            bufferedPositionMs = 28_000L,
            windowDurationMs = 34_000L,
        )

        assertEquals(LiveLatencyCorrectionPlanOutcome.SEEK, plan.outcome)
        assertEquals(26_000L, plan.seekPositionMs)
    }

    @Test
    fun coordinatorRequiresPostActionAndPostSeekFreshTranscR() {
        val coordinator = LiveLatencyCorrectionCoordinator(maximumSeekAttempts = 3)
        coordinator.arm(
            reason = LiveLatencyCorrectionReason.RESUME,
            targetLatencyMs = 1_650L,
            requireMeasurementAfterSequence = 1_000L,
        )

        assertEquals(
            LiveLatencyCorrectionOutcome.WAIT_FOR_FRESH_MEASUREMENT,
            evaluate(coordinator, measurement(latencyMs = 5_000L, sequence = 1_000L)).outcome,
        )

        val seek = evaluate(
            coordinator,
            measurement(latencyMs = 5_000L, sequence = 1_001L),
        )
        assertEquals(LiveLatencyCorrectionOutcome.SEEK, seek.outcome)
        assertEquals(13_350L, seek.seekPositionMs)
        assertTrue(coordinator.hasPendingRequest)

        assertEquals(
            LiveLatencyCorrectionOutcome.WAIT_FOR_FRESH_MEASUREMENT,
            evaluate(coordinator, measurement(latencyMs = 1_650L, sequence = 1_001L)).outcome,
        )
        val verified = evaluate(
            coordinator,
            measurement(latencyMs = 1_700L, sequence = 1_002L),
        )
        assertEquals(LiveLatencyCorrectionOutcome.COMPLETE, verified.outcome)
        assertFalse(coordinator.hasPendingRequest)
    }

    @Test
    fun coordinatorBoundsFailedPostSeekVerificationRetries() {
        val coordinator = LiveLatencyCorrectionCoordinator(maximumSeekAttempts = 2)
        coordinator.arm(
            reason = LiveLatencyCorrectionReason.EXPLICIT_JUMP,
            targetLatencyMs = 1_650L,
            requireMeasurementAfterSequence = null,
        )

        assertEquals(
            LiveLatencyCorrectionOutcome.SEEK,
            evaluate(coordinator, measurement(5_000L, 1L)).outcome,
        )
        assertEquals(
            LiveLatencyCorrectionOutcome.SEEK,
            evaluate(coordinator, measurement(4_000L, 2L)).outcome,
        )
        assertEquals(
            LiveLatencyCorrectionOutcome.FALLBACK_TO_SPEED,
            evaluate(coordinator, measurement(3_000L, 3L)).outcome,
        )
        assertFalse(coordinator.hasPendingRequest)
    }

    @Test
    fun onlyLivePlayingJumpUsesAnImmediateFreshMeasurement() {
        val measurement = measurement(latencyMs = 4_000L, sequence = 10L)

        assertTrue(
            shouldUseImmediateLatencyCorrection(
                reason = LiveLatencyCorrectionReason.EXPLICIT_JUMP,
                isPlaying = true,
                measurement = measurement,
                nowRealtimeMs = 2_000L,
                maximumAgeMs = 2_500L,
            ),
        )
        assertFalse(
            shouldUseImmediateLatencyCorrection(
                reason = LiveLatencyCorrectionReason.RESUME,
                isPlaying = true,
                measurement = measurement,
                nowRealtimeMs = 2_000L,
                maximumAgeMs = 2_500L,
            ),
        )
        assertFalse(
            shouldUseImmediateLatencyCorrection(
                reason = LiveLatencyCorrectionReason.EXPLICIT_JUMP,
                isPlaying = false,
                measurement = measurement,
                nowRealtimeMs = 2_000L,
                maximumAgeMs = 2_500L,
            ),
        )
        assertFalse(
            shouldUseImmediateLatencyCorrection(
                reason = LiveLatencyCorrectionReason.EXPLICIT_JUMP,
                isPlaying = true,
                measurement = measurement,
                nowRealtimeMs = 2_551L,
                maximumAgeMs = 2_500L,
            ),
        )
    }

    @Test
    fun invalidValuesAreRejected() {
        assertEquals(
            LiveLatencyCorrectionPlanOutcome.INVALID_INPUT,
            plan(
                measuredLatencyMs = -1L,
                currentPositionMs = 10_000L,
                bufferedPositionMs = 15_000L,
                windowDurationMs = 15_000L,
            ).outcome,
        )
        assertEquals(
            LiveLatencyCorrectionPlanOutcome.INVALID_INPUT,
            plan(
                measuredLatencyMs = Long.MAX_VALUE,
                currentPositionMs = 2_000L,
                bufferedPositionMs = Long.MAX_VALUE,
                windowDurationMs = null,
            ).outcome,
        )
    }

    @Test
    fun correctionNeverSeeksBackwardEvenWithNoMinimumAdvance() {
        for (bufferedPositionMs in listOf(0L, 10_000L, 12_000L)) {
            val plan = planLiveLatencyCorrection(
                measuredLatencyMs = 5_000L,
                targetLatencyMs = 1_650L,
                currentPositionMs = 10_000L,
                bufferedPositionMs = bufferedPositionMs,
                windowDurationMs = null,
                bufferedSafetyMs = 2_000L,
                minimumAdvanceMs = 0L,
                targetToleranceMs = 100L,
            )

            assertEquals(LiveLatencyCorrectionPlanOutcome.WAIT_FOR_BUFFER, plan.outcome)
            assertNull(plan.seekPositionMs)
        }
    }

    private fun plan(
        measuredLatencyMs: Long,
        currentPositionMs: Long,
        bufferedPositionMs: Long?,
        windowDurationMs: Long?,
    ): LiveLatencyCorrectionPlan = planLiveLatencyCorrection(
        measuredLatencyMs = measuredLatencyMs,
        targetLatencyMs = 1_650L,
        currentPositionMs = currentPositionMs,
        bufferedPositionMs = bufferedPositionMs,
        windowDurationMs = windowDurationMs,
        bufferedSafetyMs = 2_000L,
        minimumAdvanceMs = 100L,
        targetToleranceMs = 100L,
    )

    private fun evaluate(
        coordinator: LiveLatencyCorrectionCoordinator,
        measurement: LiveLatencyMeasurement,
    ): LiveLatencyCorrectionDecision = coordinator.evaluate(
        measurement = measurement,
        currentPositionMs = 10_000L,
        bufferedPositionMs = 16_000L,
        windowDurationMs = 16_000L,
        bufferedSafetyMs = 2_000L,
        minimumAdvanceMs = 100L,
        targetToleranceMs = 100L,
    )

    private fun measurement(
        latencyMs: Long,
        sequence: Long,
    ) = LiveLatencyMeasurement(
        latencyMs = latencyMs,
        sequence = sequence,
        measuredRealtimeMs = 50L,
        source = LiveLatencyMeasurementSource.TRANSC_R,
        transcRMs = sequence,
    )
}
