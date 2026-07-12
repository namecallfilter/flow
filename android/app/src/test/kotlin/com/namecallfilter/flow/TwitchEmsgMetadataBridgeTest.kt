package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.DataReader
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.ParsableByteArray
import androidx.media3.common.util.UnstableApi
import androidx.media3.extractor.TrackOutput
import androidx.media3.extractor.metadata.emsg.EventMessage
import androidx.media3.extractor.metadata.emsg.EventMessageDecoder
import androidx.media3.extractor.metadata.emsg.EventMessageEncoder
import androidx.media3.extractor.metadata.id3.Id3Decoder
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class TwitchEmsgMetadataBridgeTest {
    @Test
    fun twitchId3EmsgWithEmptyValueIsRelabeledAndUsesExistingLatencySession() {
        val logs = mutableListOf<String>()
        val bridge = TwitchEmsgMetadataBridge(logger = logs::add)
        val original = twitchEmsg(VALID_SEGMENT_JSON)
        val originalEvent = EventMessageDecoder().decode(ParsableByteArray(original))

        val rewritten = bridge.rewriteSample(original)
        val bridgedEvent = EventMessageDecoder().decode(ParsableByteArray(rewritten))

        assertEquals(TwitchEmsgMetadataBridge.AOM_ID3_SCHEME, bridgedEvent.schemeIdUri)
        assertEquals("", bridgedEvent.value)
        assertArrayEquals(originalEvent.messageData, bridgedEvent.messageData)
        val metadata = Id3Decoder().decode(
            bridgedEvent.messageData,
            bridgedEvent.messageData.size,
        )
        assertNotNull(metadata)

        val accepted = mutableListOf<Long>()
        val session = TwitchLatencySession(
            clockMs = { CLIENT_NOW_MS },
            onAcceptedLatency = accepted::add,
            logger = {},
        )
        session.captureServerTimeEpochSeconds(SERVER_NOW_SECONDS)
        session.handleMetadata(checkNotNull(metadata))

        assertEquals(listOf(2_100L), accepted)
        assertEquals(1, logs.count { it.contains("bridging Twitch EMSG") })
    }

    @Test
    fun legacyRawJsonSegmentEmsgIsConvertedToId3() {
        val original = EventMessageEncoder().encode(
            EventMessage(
                TwitchEmsgMetadataBridge.TWITCH_ID3_SCHEME,
                TwitchEmsgMetadataBridge.SEGMENT_METADATA_DESCRIPTION,
                2_000,
                8,
                VALID_SEGMENT_JSON.toByteArray(),
            ),
        )

        val bridged = EventMessageDecoder().decode(
            ParsableByteArray(TwitchEmsgMetadataBridge(logger = {}).rewriteSample(original)),
        )
        val metadata = Id3Decoder().decode(bridged.messageData, bridged.messageData.size)

        assertEquals(TwitchEmsgMetadataBridge.AOM_ID3_SCHEME, bridged.schemeIdUri)
        assertNotNull(metadata)
    }

    @Test
    fun standardAndUnrelatedEmsgSamplesRemainByteForByteUnchanged() {
        val bridge = TwitchEmsgMetadataBridge(logger = {})
        val standard = EventMessageEncoder().encode(
            EventMessage(
                TwitchEmsgMetadataBridge.AOM_ID3_SCHEME,
                "segmentmetadata",
                0,
                1,
                encodeTxxxId3Tag("segmentmetadata", VALID_SEGMENT_JSON),
            ),
        )
        val unrelated = EventMessageEncoder().encode(
            EventMessage(
                "urn:twitch:id3",
                "different",
                0,
                2,
                VALID_SEGMENT_JSON.toByteArray(),
            ),
        )
        val unrelatedId3 = EventMessageEncoder().encode(
            EventMessage(
                "urn:unrelated",
                "",
                0,
                3,
                encodeTxxxId3Tag("different", "not latency"),
            ),
        )

        assertArrayEquals(standard, bridge.rewriteSample(standard))
        assertArrayEquals(unrelated, bridge.rewriteSample(unrelated))
        assertArrayEquals(unrelatedId3, bridge.rewriteSample(unrelatedId3))
    }

    @Test
    fun twitchEnvelopeWithUnrelatedId3IsRelabeledThenFilteredDownstream() {
        val original = EventMessageEncoder().encode(
            EventMessage(
                TwitchEmsgMetadataBridge.TWITCH_ID3_SCHEME,
                "",
                0,
                3,
                encodeTxxxId3Tag("different", "not latency"),
            ),
        )

        val rewritten = EventMessageDecoder().decode(
            ParsableByteArray(TwitchEmsgMetadataBridge(logger = {}).rewriteSample(original)),
        )

        assertEquals(TwitchEmsgMetadataBridge.AOM_ID3_SCHEME, rewritten.schemeIdUri)
        val metadata = Id3Decoder().decode(rewritten.messageData, rewritten.messageData.size)
        assertNotNull(metadata)
        val accepted = mutableListOf<Long>()
        TwitchLatencySession(
            clockMs = { CLIENT_NOW_MS },
            onAcceptedLatency = accepted::add,
            logger = {},
        ).handleMetadata(checkNotNull(metadata))
        assertTrue(accepted.isEmpty())
    }

    @Test
    fun trackOutputPreservesTimestampsForQueuedSamplesWithDecreasingOffsets() {
        val bridge = TwitchEmsgMetadataBridge(logger = {})
        val delegate = CapturingTrackOutput()
        val output = TwitchEmsgMetadataBridgeTrackOutput(delegate, bridge)
        val twitchSample = twitchEmsg(VALID_SEGMENT_JSON)
        val unrelatedSample = EventMessageEncoder().encode(
            EventMessage("urn:unrelated", "other", 0, 9, byteArrayOf(1, 2, 3)),
        )
        val secondTwitchSample = twitchEmsg("{\"transc_r\":1699999998200}")
        val queuedSamples = twitchSample + unrelatedSample + secondTwitchSample
        val splitPosition = queuedSamples.size / 2

        output.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_EMSG).build())
        output.sampleData(
            ParsableByteArray(queuedSamples.copyOfRange(0, splitPosition)),
            splitPosition,
            TrackOutput.SAMPLE_DATA_PART_MAIN,
        )
        val remainingData = queuedSamples.copyOfRange(splitPosition, queuedSamples.size)
        output.sampleData(
            ParsableByteArray(remainingData),
            remainingData.size,
            TrackOutput.SAMPLE_DATA_PART_MAIN,
        )
        output.sampleMetadata(
            123_000L,
            C.BUFFER_FLAG_KEY_FRAME,
            twitchSample.size,
            unrelatedSample.size + secondTwitchSample.size,
            null,
        )
        output.sampleMetadata(
            456_000L,
            0,
            unrelatedSample.size,
            secondTwitchSample.size,
            null,
        )
        output.sampleMetadata(789_000L, 0, secondTwitchSample.size, 0, null)

        assertEquals(3, delegate.samples.size)
        assertEquals(123_000L, delegate.samples[0].timeUs)
        assertEquals(456_000L, delegate.samples[1].timeUs)
        assertEquals(789_000L, delegate.samples[2].timeUs)
        assertEquals(
            TwitchEmsgMetadataBridge.AOM_ID3_SCHEME,
            EventMessageDecoder()
                .decode(ParsableByteArray(delegate.samples[0].data))
                .schemeIdUri,
        )
        assertArrayEquals(unrelatedSample, delegate.samples[1].data)
        assertEquals(
            TwitchEmsgMetadataBridge.AOM_ID3_SCHEME,
            EventMessageDecoder()
                .decode(ParsableByteArray(delegate.samples[2].data))
                .schemeIdUri,
        )
        assertTrue(delegate.samples.all { it.offset == 0 })
    }

    @Test
    fun trackOutputPassesNativeTransportStreamId3ThroughUntouched() {
        val delegate = CapturingTrackOutput()
        val output = TwitchEmsgMetadataBridgeTrackOutput(
            delegate,
            TwitchEmsgMetadataBridge(logger = {}),
        )
        val id3 = encodeTxxxId3Tag(
            TwitchEmsgMetadataBridge.SEGMENT_METADATA_DESCRIPTION,
            VALID_SEGMENT_JSON,
        )

        output.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_ID3).build())
        output.sampleData(
            ParsableByteArray(id3),
            id3.size,
            TrackOutput.SAMPLE_DATA_PART_MAIN,
        )
        output.sampleMetadata(321_000L, C.BUFFER_FLAG_KEY_FRAME, id3.size, 0, null)

        assertEquals(1, delegate.samples.size)
        assertEquals(321_000L, delegate.samples.single().timeUs)
        assertArrayEquals(id3, delegate.samples.single().data)
    }

    @Test
    fun oversizedEmsgSampleUsesBoundedPassthroughWithoutDisablingLaterBridge() {
        val delegate = CapturingTrackOutput()
        val output = TwitchEmsgMetadataBridgeTrackOutput(
            delegate,
            TwitchEmsgMetadataBridge(logger = {}),
        )
        val oversized = ByteArray(129 * 1024) { index -> (index and 0xFF).toByte() }

        output.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_EMSG).build())
        output.sampleData(
            ParsableByteArray(oversized),
            oversized.size,
            TrackOutput.SAMPLE_DATA_PART_MAIN,
        )
        output.sampleMetadata(654_000L, 0, oversized.size, 0, null)

        val valid = twitchEmsg(VALID_SEGMENT_JSON)
        output.sampleData(
            ParsableByteArray(valid),
            valid.size,
            TrackOutput.SAMPLE_DATA_PART_MAIN,
        )
        output.sampleMetadata(655_000L, 0, valid.size, 0, null)

        assertEquals(2, delegate.samples.size)
        assertArrayEquals(oversized, delegate.samples.first().data)
        val bridged = EventMessageDecoder().decode(
            ParsableByteArray(delegate.samples.last().data),
        )
        assertEquals(TwitchEmsgMetadataBridge.AOM_ID3_SCHEME, bridged.schemeIdUri)
    }

    private fun twitchEmsg(json: String): ByteArray = EventMessageEncoder().encode(
        EventMessage(
            TwitchEmsgMetadataBridge.TWITCH_ID3_SCHEME,
            "",
            2_000,
            7,
            encodeTxxxId3Tag(
                TwitchEmsgMetadataBridge.SEGMENT_METADATA_DESCRIPTION,
                json,
            ),
        ),
    )

    private class CapturingTrackOutput : TrackOutput {
        data class Sample(val timeUs: Long, val data: ByteArray, val offset: Int)

        private val pending = ByteArrayOutputStream()
        val samples = mutableListOf<Sample>()

        override fun format(format: Format) = Unit

        override fun sampleData(
            input: DataReader,
            length: Int,
            allowEndOfInput: Boolean,
            sampleDataPart: @TrackOutput.SampleDataPart Int,
        ): Int {
            val bytes = ByteArray(length)
            val read = input.read(bytes, 0, length)
            if (read > 0) {
                pending.write(bytes, 0, read)
            }
            return read
        }

        override fun sampleData(
            data: ParsableByteArray,
            length: Int,
            sampleDataPart: @TrackOutput.SampleDataPart Int,
        ) {
            val bytes = ByteArray(length)
            data.readBytes(bytes, 0, length)
            pending.write(bytes)
        }

        override fun sampleMetadata(
            timeUs: Long,
            flags: @C.BufferFlags Int,
            size: Int,
            offset: Int,
            cryptoData: TrackOutput.CryptoData?,
        ) {
            val buffered = pending.toByteArray()
            val sampleEnd = buffered.size - offset
            val sampleStart = sampleEnd - size
            samples += Sample(timeUs, buffered.copyOfRange(sampleStart, sampleEnd), offset)
            pending.reset()
            if (offset > 0) {
                pending.write(buffered, sampleEnd, offset)
            }
        }
    }

    private companion object {
        const val CLIENT_NOW_MS = 1_700_000_000_000L
        const val SERVER_NOW_SECONDS = 1_700_000_000.250
        const val VALID_SEGMENT_JSON = "{\"transc_r\":1699999998150}"
    }
}
