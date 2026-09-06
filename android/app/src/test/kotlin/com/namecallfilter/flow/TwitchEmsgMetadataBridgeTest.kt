package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.DataReader
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.ParsableByteArray
import androidx.media3.common.util.TimestampAdjuster
import androidx.media3.common.util.UnstableApi
import androidx.media3.extractor.DiscardingTrackOutput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.SeekMap
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
    fun queuedHevcEmsgPreservesItsObservedPresentationDeltaAcrossASeek() {
        val adjuster = TimestampAdjuster(28_000_000L)
        adjuster.adjustSampleTimestamp(18_486_033_000L)
        val target = CapturingTrackOutput()
        val output = extractorOutput(target, adjuster)
        val media = output.track(1, C.TRACK_TYPE_VIDEO)
        val metadata = output.track(2, C.TRACK_TYPE_METADATA)
        metadata.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_EMSG).build())
        val expectedTimesUs = listOf(28_034_000L, 30_034_000L, 48_034_000L)

        expectedTimesUs.forEach { presentationTimeUs ->
            media.sampleMetadata(presentationTimeUs - 34_000L, 0, 0, 0, null)
            writeTwitchSample(metadata, adjuster.adjustSampleTimestamp(presentationTimeUs))
        }

        assertEquals(expectedTimesUs, target.samples.map { it.timeUs })
    }

    @Test
    fun confirmedHevcOffsetSurvivesPositiveTimestampsAndARecreatedOutput() {
        val adjuster = TimestampAdjuster(28_000_000L)
        val mediaTimeUs = adjuster.adjustSampleTimestamp(18_486_033_000L)
        val bridge = TwitchEmsgMetadataBridge(logger = {})
        assertEquals(
            listOf(mediaTimeUs + 34_000L),
            forwardedTimestamps(
                adjuster, mediaTimeUs,
                listOf(adjuster.adjustSampleTimestamp(mediaTimeUs + 34_000L)), bridge,
            ),
        )

        // Native period time keeps advancing even when the visible HLS window moves.
        val laterMediaTimeUs = 18_500_000_000L
        val laterPresentationTimeUs = laterMediaTimeUs + 34_000L
        val doubledTimeUs = adjuster.adjustSampleTimestamp(laterPresentationTimeUs)
        assertTrue(doubledTimeUs > 0)
        assertEquals(
            listOf(laterPresentationTimeUs, laterPresentationTimeUs),
            forwardedTimestamps(
                adjuster, laterMediaTimeUs,
                listOf(doubledTimeUs, laterPresentationTimeUs), bridge,
            ),
        )

        val otherOffset = TimestampAdjuster(28_000_000L)
        val otherMediaTimeUs = otherOffset.adjustSampleTimestamp(27_000_000L)
        val unprovenTimeUs = otherOffset.adjustSampleTimestamp(otherMediaTimeUs + 34_000L)
        assertEquals(
            listOf(unprovenTimeUs),
            forwardedTimestamps(otherOffset, otherMediaTimeUs, listOf(unprovenTimeUs), bridge),
        )
    }

    @Test
    fun invalidLargeLeadsNegativeCandidatesAndAlreadyCorrectEmsgAreNotRepaired() {
        val adjuster = TimestampAdjuster(28_000_000L)
        val mediaTimeUs = adjuster.adjustSampleTimestamp(18_486_033_000L)
        val unchangedTimesUs = listOf(
            adjuster.adjustSampleTimestamp(mediaTimeUs + 2_000_000L),
            adjuster.adjustSampleTimestamp(-34_000L),
            mediaTimeUs + 34_000L,
        )

        assertEquals(unchangedTimesUs, forwardedTimestamps(adjuster, mediaTimeUs, unchangedTimesUs))
    }

    @Test
    fun unprovenPositiveOffsetsRequireAnExactMatchAndArithmeticOverflowKeepsTheOriginal() {
        val positiveAdjuster = TimestampAdjuster(28_000_000L)
        val mediaTimeUs = positiveAdjuster.adjustSampleTimestamp(27_000_000L)
        val exactTimeUs = positiveAdjuster.adjustSampleTimestamp(mediaTimeUs)
        val positiveLeadTimeUs = positiveAdjuster.adjustSampleTimestamp(mediaTimeUs + 34_000L)
        assertEquals(
            listOf(positiveLeadTimeUs, mediaTimeUs),
            forwardedTimestamps(positiveAdjuster, mediaTimeUs, listOf(positiveLeadTimeUs, exactTimeUs)),
        )

        val overflowingAdjuster = TimestampAdjuster(0L)
        overflowingAdjuster.adjustSampleTimestamp(-Long.MAX_VALUE + 1L)
        assertEquals(listOf(-3L), forwardedTimestamps(overflowingAdjuster, 0L, listOf(-3L)))
    }

    @Test
    fun queuedTwitchEmsgRemovesTheDuplicateNativeOffsetAndKeepsTheVideoTimestamp() {
        // CMAF's source clock can be hours ahead of the current HLS window.
        val adjuster = TimestampAdjuster(28_000_000L)
        val videoTimeUs = adjuster.adjustSampleTimestamp(17_060_033_000L)
        val duplicatedEmsgTimeUs = adjuster.adjustSampleTimestamp(videoTimeUs)
        assertTrue(duplicatedEmsgTimeUs < 0)
        val target = CapturingTrackOutput()
        val output = extractorOutput(target, adjuster)
        output.track(1, C.TRACK_TYPE_VIDEO).sampleMetadata(videoTimeUs, 0, 0, 0, null)
        val metadata = output.track(2, C.TRACK_TYPE_METADATA)
        metadata.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_EMSG).build())
        val sample = twitchEmsg(VALID_SEGMENT_JSON)

        metadata.sampleData(ParsableByteArray(sample), sample.size, TrackOutput.SAMPLE_DATA_PART_MAIN)
        metadata.sampleMetadata(duplicatedEmsgTimeUs, C.BUFFER_FLAG_KEY_FRAME, sample.size, 0, null)

        assertEquals(videoTimeUs, target.samples.single().timeUs)
        assertEquals(
            TwitchEmsgMetadataBridge.AOM_ID3_SCHEME,
            EventMessageDecoder().decode(ParsableByteArray(target.samples.single().data)).schemeIdUri,
        )
    }

    @Test
    fun nativeAbsoluteEmsgUnrelatedEmsgAndTsMetadataKeepTheirOriginalTimestamps() {
        val adjuster = TimestampAdjuster(28_000_000L)
        val videoTimeUs = adjuster.adjustSampleTimestamp(17_060_033_000L)
        val target = CapturingTrackOutput()
        val output = extractorOutput(target, adjuster)
        output.track(1, C.TRACK_TYPE_VIDEO).sampleMetadata(videoTimeUs, 0, 0, 0, null)
        val metadata = output.track(2, C.TRACK_TYPE_METADATA)
        metadata.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_EMSG).build())
        val absolute = twitchEmsg(VALID_SEGMENT_JSON)
        metadata.sampleData(ParsableByteArray(absolute), absolute.size, TrackOutput.SAMPLE_DATA_PART_MAIN)
        metadata.sampleMetadata(videoTimeUs, C.BUFFER_FLAG_KEY_FRAME, absolute.size, 0, null)
        val unrelated = EventMessageEncoder().encode(EventMessage("urn:other", "", 0, 1, byteArrayOf(1)))
        val unrelatedTimeUs = adjuster.adjustSampleTimestamp(videoTimeUs)
        metadata.sampleData(ParsableByteArray(unrelated), unrelated.size, TrackOutput.SAMPLE_DATA_PART_MAIN)
        metadata.sampleMetadata(unrelatedTimeUs, 0, unrelated.size, 0, null)
        val ts = encodeTxxxId3Tag("segmentmetadata", VALID_SEGMENT_JSON)
        metadata.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_ID3).build())
        metadata.sampleData(ParsableByteArray(ts), ts.size, TrackOutput.SAMPLE_DATA_PART_MAIN)
        metadata.sampleMetadata(videoTimeUs + 2_000_000L, 0, ts.size, 0, null)

        assertEquals(listOf(videoTimeUs, unrelatedTimeUs, videoTimeUs + 2_000_000L), target.samples.map { it.timeUs })
        assertArrayEquals(unrelated, target.samples[1].data)
        assertArrayEquals(ts, target.samples[2].data)
    }

    private fun extractorOutput(
        target: TrackOutput,
        adjuster: TimestampAdjuster,
        bridge: TwitchEmsgMetadataBridge = TwitchEmsgMetadataBridge(logger = {}),
    ) =
        TwitchEmsgMetadataBridgeExtractorOutput(
            object : ExtractorOutput {
                override fun track(id: Int, type: Int): TrackOutput =
                    if (type == C.TRACK_TYPE_METADATA) target else DiscardingTrackOutput()
                override fun endTracks() = Unit
                override fun seekMap(seekMap: SeekMap) = Unit
            },
            bridge,
            adjuster,
        )

    private fun forwardedTimestamps(
        adjuster: TimestampAdjuster,
        mediaTimeUs: Long,
        metadataTimesUs: List<Long>,
        bridge: TwitchEmsgMetadataBridge = TwitchEmsgMetadataBridge(logger = {}),
    ): List<Long> {
        val target = CapturingTrackOutput()
        val output = extractorOutput(target, adjuster, bridge)
        output.track(1, C.TRACK_TYPE_VIDEO).sampleMetadata(mediaTimeUs, 0, 0, 0, null)
        val metadata = output.track(2, C.TRACK_TYPE_METADATA)
        metadata.format(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_EMSG).build())
        metadataTimesUs.forEach { writeTwitchSample(metadata, it) }
        return target.samples.map { it.timeUs }
    }

    private fun writeTwitchSample(metadata: TrackOutput, timeUs: Long) {
        val sample = twitchEmsg(VALID_SEGMENT_JSON)
        metadata.sampleData(ParsableByteArray(sample), sample.size, TrackOutput.SAMPLE_DATA_PART_MAIN)
        metadata.sampleMetadata(timeUs, C.BUFFER_FLAG_KEY_FRAME, sample.size, 0, null)
    }

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
