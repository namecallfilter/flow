package com.namecallfilter.flow

internal enum class LiveLatencyCorrectionReason {
    STARTUP,
    RESUME,
    EXPLICIT_JUMP,
}

internal enum class LiveLatencyMeasurementSource {
    TRANSC_R,
    STITCHED_AD_TIMELINE,
}

internal enum class LiveLatencyCorrectionOutcome {
    WAIT_FOR_FRESH_MEASUREMENT,
    WAIT_FOR_BUFFER,
    SEEK,
    COMPLETE,
    FALLBACK_TO_SPEED,
    INVALID_INPUT,
}

internal data class LiveLatencyMeasurement(
    val latencyMs: Long,
    val sequence: Long,
    val measuredRealtimeMs: Long,
    val source: LiveLatencyMeasurementSource,
    val transcRMs: Long? = null,
)

internal data class LiveLatencyCorrectionDecision(
    val outcome: LiveLatencyCorrectionOutcome,
    val reason: LiveLatencyCorrectionReason? = null,
    val seekPositionMs: Long? = null,
    val reachesTarget: Boolean = false,
    val seekAttempt: Int = 0,
)

/**
 * Stateful request coordinator around the pure [planLiveLatencyCorrection] planner.
 *
 * Every request has a measurement-sequence barrier. A sample received before the request or
 * before the previous correction seek cannot verify the new playback position.
 * A seek therefore remains pending until a newer primary `transc_r` sample or
 * stitched-ad timeline measurement confirms it. Retries are bounded; speed
 * control remains the safe fallback if several exact, forward-only seeks do not converge.
 */
internal class LiveLatencyCorrectionCoordinator(
    private val maximumSeekAttempts: Int,
) {
    private var request: Request? = null

    val hasPendingRequest: Boolean
        get() = request != null

    val pendingReason: LiveLatencyCorrectionReason?
        get() = request?.reason

    fun reset() {
        request = null
    }

    fun arm(
        reason: LiveLatencyCorrectionReason,
        targetLatencyMs: Long,
        requireMeasurementAfterSequence: Long?,
    ) {
        request = Request(
            reason = reason,
            targetLatencyMs = targetLatencyMs,
            requireMeasurementAfterSequence = requireMeasurementAfterSequence,
            seekAttempts = 0,
        )
    }

    fun evaluate(
        measurement: LiveLatencyMeasurement?,
        currentPositionMs: Long,
        bufferedPositionMs: Long?,
        windowDurationMs: Long?,
        bufferedSafetyMs: Long,
        partialBufferedSafetyMs: Long,
        minimumAdvanceMs: Long,
        targetToleranceMs: Long,
    ): LiveLatencyCorrectionDecision {
        val currentRequest = request
            ?: return LiveLatencyCorrectionDecision(LiveLatencyCorrectionOutcome.COMPLETE)
        if (
            measurement == null ||
            currentRequest.requireMeasurementAfterSequence?.let {
                measurement.sequence <= it
            } == true
        ) {
            return LiveLatencyCorrectionDecision(
                outcome = LiveLatencyCorrectionOutcome.WAIT_FOR_FRESH_MEASUREMENT,
                reason = currentRequest.reason,
                seekAttempt = currentRequest.seekAttempts,
            )
        }

        val plan = planLiveLatencyCorrection(
            measuredLatencyMs = measurement.latencyMs,
            targetLatencyMs = currentRequest.targetLatencyMs,
            currentPositionMs = currentPositionMs,
            bufferedPositionMs = bufferedPositionMs,
            windowDurationMs = windowDurationMs,
            bufferedSafetyMs = bufferedSafetyMs,
            partialBufferedSafetyMs = partialBufferedSafetyMs,
            minimumAdvanceMs = minimumAdvanceMs,
            targetToleranceMs = targetToleranceMs,
        )
        return when (plan.outcome) {
            LiveLatencyCorrectionPlanOutcome.AT_TARGET -> {
                request = null
                LiveLatencyCorrectionDecision(
                    outcome = LiveLatencyCorrectionOutcome.COMPLETE,
                    reason = currentRequest.reason,
                    seekAttempt = currentRequest.seekAttempts,
                )
            }
            LiveLatencyCorrectionPlanOutcome.WAIT_FOR_BUFFER ->
                LiveLatencyCorrectionDecision(
                    outcome = LiveLatencyCorrectionOutcome.WAIT_FOR_BUFFER,
                    reason = currentRequest.reason,
                    seekAttempt = currentRequest.seekAttempts,
                )
            LiveLatencyCorrectionPlanOutcome.INVALID_INPUT ->
                LiveLatencyCorrectionDecision(
                    outcome = LiveLatencyCorrectionOutcome.INVALID_INPUT,
                    reason = currentRequest.reason,
                    seekAttempt = currentRequest.seekAttempts,
                )
            LiveLatencyCorrectionPlanOutcome.SEEK -> {
                if (currentRequest.seekAttempts >= maximumSeekAttempts) {
                    request = null
                    LiveLatencyCorrectionDecision(
                        outcome = LiveLatencyCorrectionOutcome.FALLBACK_TO_SPEED,
                        reason = currentRequest.reason,
                        seekAttempt = currentRequest.seekAttempts,
                    )
                } else {
                    val nextAttempt = currentRequest.seekAttempts + 1
                    request = currentRequest.copy(
                        requireMeasurementAfterSequence = measurement.sequence,
                        seekAttempts = nextAttempt,
                    )
                    LiveLatencyCorrectionDecision(
                        outcome = LiveLatencyCorrectionOutcome.SEEK,
                        reason = currentRequest.reason,
                        seekPositionMs = plan.seekPositionMs,
                        reachesTarget = plan.reachesTarget,
                        seekAttempt = nextAttempt,
                    )
                }
            }
        }
    }

    private data class Request(
        val reason: LiveLatencyCorrectionReason,
        val targetLatencyMs: Long,
        val requireMeasurementAfterSequence: Long?,
        val seekAttempts: Int,
    )
}

internal enum class LiveLatencyCorrectionPlanOutcome {
    SEEK,
    AT_TARGET,
    WAIT_FOR_BUFFER,
    INVALID_INPUT,
}

internal data class LiveLatencyCorrectionPlan(
    val outcome: LiveLatencyCorrectionPlanOutcome,
    val seekPositionMs: Long? = null,
    val reachesTarget: Boolean = false,
)

/**
 * Plans a correction solely from Twitch's validated `transc_r` latency.
 *
 * The desired position is the current position plus the measured excess latency.
 * It never uses Media3's default position or `currentLiveOffset`, and it never
 * seeks backward. A correction never enters unbuffered Twitch prefetch: when the
 * exact target is beyond the safe buffered edge, it advances to that buffered
 * edge and remains pending. The coordinator then waits for a fresh post-seek
 * measurement and performs another bounded correction toward the same target.
 */
internal fun planLiveLatencyCorrection(
    measuredLatencyMs: Long,
    targetLatencyMs: Long,
    currentPositionMs: Long,
    bufferedPositionMs: Long?,
    windowDurationMs: Long?,
    bufferedSafetyMs: Long,
    partialBufferedSafetyMs: Long,
    minimumAdvanceMs: Long,
    targetToleranceMs: Long,
): LiveLatencyCorrectionPlan {
    if (
        measuredLatencyMs < 0 ||
        targetLatencyMs < 0 ||
        currentPositionMs < 0 ||
        bufferedSafetyMs < 0 ||
        partialBufferedSafetyMs < bufferedSafetyMs ||
        minimumAdvanceMs < 0 ||
        targetToleranceMs < 0 ||
        bufferedPositionMs?.let { it < 0 } == true ||
        windowDurationMs?.let { it < 0 } == true
    ) {
        return LiveLatencyCorrectionPlan(LiveLatencyCorrectionPlanOutcome.INVALID_INPUT)
    }

    val excessLatencyMs = runCatching {
        Math.subtractExact(measuredLatencyMs, targetLatencyMs)
    }.getOrNull() ?: return LiveLatencyCorrectionPlan(
        LiveLatencyCorrectionPlanOutcome.INVALID_INPUT,
    )
    if (excessLatencyMs <= targetToleranceMs) {
        return LiveLatencyCorrectionPlan(LiveLatencyCorrectionPlanOutcome.AT_TARGET)
    }

    val desiredPositionMs = runCatching {
        Math.addExact(currentPositionMs, excessLatencyMs)
    }.getOrNull() ?: return LiveLatencyCorrectionPlan(
        LiveLatencyCorrectionPlanOutcome.INVALID_INPUT,
    )
    val advanceMs = runCatching {
        Math.subtractExact(desiredPositionMs, currentPositionMs)
    }.getOrNull() ?: return LiveLatencyCorrectionPlan(
        LiveLatencyCorrectionPlanOutcome.INVALID_INPUT,
    )
    if (advanceMs < minimumAdvanceMs) {
        return LiveLatencyCorrectionPlan(LiveLatencyCorrectionPlanOutcome.WAIT_FOR_BUFFER)
    }

    val knownBufferedPositionMs = bufferedPositionMs
        ?: return LiveLatencyCorrectionPlan(LiveLatencyCorrectionPlanOutcome.WAIT_FOR_BUFFER)
    val exactBufferedReachMs = runCatching {
        Math.subtractExact(knownBufferedPositionMs, bufferedSafetyMs)
    }.getOrNull() ?: return LiveLatencyCorrectionPlan(
        LiveLatencyCorrectionPlanOutcome.WAIT_FOR_BUFFER,
    )
    val exactWindowReachMs = windowDurationMs?.let { windowDuration ->
        runCatching { Math.subtractExact(windowDuration, bufferedSafetyMs) }.getOrNull()
    }
    val exactSafeReachMs = exactWindowReachMs?.let {
        minOf(exactBufferedReachMs, it)
    } ?: exactBufferedReachMs
    if (desiredPositionMs <= exactSafeReachMs) {
        return LiveLatencyCorrectionPlan(
            outcome = LiveLatencyCorrectionPlanOutcome.SEEK,
            seekPositionMs = desiredPositionMs,
            reachesTarget = true,
        )
    }

    val partialBufferedReachMs = runCatching {
        Math.subtractExact(knownBufferedPositionMs, partialBufferedSafetyMs)
    }.getOrNull() ?: return LiveLatencyCorrectionPlan(
        LiveLatencyCorrectionPlanOutcome.WAIT_FOR_BUFFER,
    )
    val partialWindowReachMs = windowDurationMs?.let { windowDuration ->
        runCatching {
            Math.subtractExact(windowDuration, partialBufferedSafetyMs)
        }.getOrNull()
    }
    val safeReachMs = partialWindowReachMs?.let {
        minOf(partialBufferedReachMs, it)
    } ?: partialBufferedReachMs
    val safeAdvanceMs = runCatching {
        Math.subtractExact(safeReachMs, currentPositionMs)
    }.getOrNull() ?: return LiveLatencyCorrectionPlan(
        LiveLatencyCorrectionPlanOutcome.INVALID_INPUT,
    )
    if (safeAdvanceMs < minimumAdvanceMs) {
        return LiveLatencyCorrectionPlan(LiveLatencyCorrectionPlanOutcome.WAIT_FOR_BUFFER)
    }

    return LiveLatencyCorrectionPlan(
        outcome = LiveLatencyCorrectionPlanOutcome.SEEK,
        seekPositionMs = safeReachMs,
        reachesTarget = false,
    )
}

internal fun shouldUseImmediateLatencyCorrection(
    reason: LiveLatencyCorrectionReason,
    isPlaying: Boolean,
    measurement: LiveLatencyMeasurement?,
    nowRealtimeMs: Long,
    maximumAgeMs: Long,
): Boolean {
    if (
        reason != LiveLatencyCorrectionReason.EXPLICIT_JUMP ||
        !isPlaying ||
        measurement == null ||
        maximumAgeMs < 0
    ) {
        return false
    }
    val ageMs = nowRealtimeMs - measurement.measuredRealtimeMs
    return ageMs in 0..maximumAgeMs
}
