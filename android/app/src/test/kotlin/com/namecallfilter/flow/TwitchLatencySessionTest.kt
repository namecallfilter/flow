package com.namecallfilter.flow

import androidx.media3.common.util.UnstableApi
import androidx.media3.common.Metadata
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

        assertEquals(1_699_999_998_000L, session.lastTranscR)
        assertEquals(listOf(2_000L), accepted)
    }

    @Test
    fun aNewSessionStartsWithNoMeasurementState() {
        val session = TwitchLatencySession(onAcceptedLatency = {}, logger = {})

        assertNull(session.serverOffsetMs)
        assertNull(session.lastTranscR)
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
        assertEquals(emptyList<Long>(), accepted)

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

        assertEquals(listOf(2_000L), accepted)
    }

}
