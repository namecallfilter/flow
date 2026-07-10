package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import androidx.media3.common.Metadata
import androidx.media3.common.C
import androidx.media3.extractor.metadata.id3.TextInformationFrame
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

@UnstableApi
class TwitchLatencySessionTest {
    @Test
    fun firstServerOffsetWinsAndLatencyUsesTranscR() {
        var nowMs = 1_700_000_000_000L
        val accepted = mutableListOf<Long>()
        val session = TwitchLatencySession(
            clockMs = { nowMs },
            onAcceptedLatency = accepted::add,
            logger = {},
        )

        session.captureServerTimeEpochSeconds(1_700_000_000.250)
        session.captureServerTimeEpochSeconds(1_700_000_010.000)
        session.handleSegmentMetadataValue("{\"transc_r\":1699999998150}")

        assertEquals(250L, session.serverOffsetMs)
        assertEquals(1_699_999_998_150L, session.lastTranscR)
        assertEquals(2_100L, session.displayedLatencyMs)
        assertEquals(listOf(2_100L), accepted)
    }

    @Test
    fun rejectedValuesPreserveLastValidLatency() {
        val nowMs = 1_700_000_000_000L
        val accepted = mutableListOf<Long>()
        val session = TwitchLatencySession(
            clockMs = { nowMs },
            onAcceptedLatency = accepted::add,
            logger = {},
        )
        session.captureServerTimeEpochSeconds(1_700_000_000.000)
        session.handleSegmentMetadataValue("{\"transc_r\":1699999998000}")

        session.handleSegmentMetadataValue("{\"transc_r\":1700000000100}")
        session.handleSegmentMetadataValue("{\"transc_r\":1699999000000}")
        session.handleSegmentMetadataValue("{\"transc_r\":\"bad\"}")

        assertEquals(2_000L, session.displayedLatencyMs)
        assertEquals(listOf(2_000L), accepted)
    }

    @Test
    fun aNewSessionStartsWithNoMeasurementState() {
        val session = TwitchLatencySession(onAcceptedLatency = {}, logger = {})

        assertNull(session.serverOffsetMs)
        assertNull(session.lastTranscR)
        assertNull(session.displayedLatencyMs)
    }

    @Test
    fun onlyMatchingSegmentMetadataTxxxFramesAreUsed() {
        val nowMs = 1_700_000_000_000L
        val accepted = mutableListOf<Long>()
        val session = TwitchLatencySession(
            clockMs = { nowMs },
            onAcceptedLatency = accepted::add,
            logger = {},
        )
        session.captureServerTimeEpochSeconds(1_700_000_000.000)

        session.handleMetadata(
            Metadata(
                listOf(
                    TextInformationFrame(
                        "TXXX",
                        "different",
                        listOf("{\"transc_r\":1699999998000}"),
                    ),
                    TextInformationFrame(
                        "TIT2",
                        "segmentmetadata",
                        listOf("{\"transc_r\":1699999998000}"),
                    ),
                ),
            ),
        )
        assertNull(session.displayedLatencyMs)

        session.handleMetadata(
            Metadata(
                listOf(
                    TextInformationFrame(
                        "TXXX",
                        "segmentmetadata",
                        listOf("{\"transc_r\":1699999998000}"),
                    ),
                ),
            ),
        )

        assertEquals(2_000L, session.displayedLatencyMs)
        assertEquals(listOf(2_000L), accepted)
    }

    @Test
    fun forwardLiveDefaultPositionUsesMedia3CorrectionAndNeverSeeksBackward() {
        assertEquals(9_000L, forwardLiveDefaultPositionMs(9_000L, 4_000L))
        assertEquals(9_500L, forwardLiveDefaultPositionMs(9_000L, 9_500L))
        assertEquals(0L, forwardLiveDefaultPositionMs(0L, 0L))
        assertNull(forwardLiveDefaultPositionMs(C.TIME_UNSET, 4_000L))
    }

    @Test
    fun liveEdgeJumpUsesCorrectedTargetThenSafeBufferedEdgeWithoutRepeatedPresses() {
        assertEquals(
            9_000L,
            forwardLiveEdgePositionMs(
                defaultPositionMs = 9_000L,
                currentPositionMs = 8_000L,
                bufferedPositionMs = 8_500L,
                windowDurationMs = 11_000L,
                normalTargetOffsetMs = 2_000L,
                jumpTargetOffsetMs = 2_000L,
                bufferedSafetyMs = 750L,
                minimumAdvanceMs = 250L,
            ),
        )
        assertEquals(
            10_000L,
            forwardLiveEdgePositionMs(
                defaultPositionMs = 9_000L,
                currentPositionMs = 8_000L,
                bufferedPositionMs = 10_500L,
                windowDurationMs = 11_000L,
                normalTargetOffsetMs = 2_000L,
                jumpTargetOffsetMs = 1_000L,
                bufferedSafetyMs = 750L,
                minimumAdvanceMs = 250L,
            ),
        )
        assertEquals(
            11_250L,
            forwardLiveEdgePositionMs(
                defaultPositionMs = 9_000L,
                currentPositionMs = 10_200L,
                bufferedPositionMs = 12_000L,
                windowDurationMs = 12_500L,
                normalTargetOffsetMs = 2_000L,
                jumpTargetOffsetMs = 1_000L,
                bufferedSafetyMs = 750L,
                minimumAdvanceMs = 250L,
            ),
        )
        assertEquals(
            10_000L,
            forwardLiveEdgePositionMs(
                defaultPositionMs = 9_000L,
                currentPositionMs = 9_600L,
                bufferedPositionMs = 10_500L,
                windowDurationMs = 11_000L,
                normalTargetOffsetMs = 2_000L,
                jumpTargetOffsetMs = 1_000L,
                bufferedSafetyMs = 750L,
                minimumAdvanceMs = 250L,
            ),
        )
        assertEquals(
            10_000L,
            forwardLiveEdgePositionMs(
                defaultPositionMs = 9_000L,
                currentPositionMs = 9_500L,
                bufferedPositionMs = C.TIME_UNSET,
                windowDurationMs = 11_000L,
                normalTargetOffsetMs = 2_000L,
                jumpTargetOffsetMs = 1_000L,
                bufferedSafetyMs = 750L,
                minimumAdvanceMs = 250L,
            ),
        )
        assertEquals(
            10_000L,
            forwardLiveEdgePositionMs(
                defaultPositionMs = 9_000L,
                currentPositionMs = 8_000L,
                bufferedPositionMs = 8_500L,
                windowDurationMs = 11_000L,
                normalTargetOffsetMs = 2_000L,
                jumpTargetOffsetMs = 1_000L,
                bufferedSafetyMs = 750L,
                minimumAdvanceMs = 250L,
            ),
        )
        assertNull(
            forwardLiveEdgePositionMs(
                defaultPositionMs = 9_000L,
                currentPositionMs = 8_000L,
                bufferedPositionMs = 10_500L,
                windowDurationMs = 11_000L,
                normalTargetOffsetMs = 1_000L,
                jumpTargetOffsetMs = 2_000L,
                bufferedSafetyMs = 750L,
                minimumAdvanceMs = 250L,
            ),
        )
    }
}
