package com.namecallfilter.flow

import android.net.Uri
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.DataReader
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.ExperimentalApi
import androidx.media3.common.util.ParsableByteArray
import androidx.media3.common.util.TimestampAdjuster
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.analytics.PlayerId
import androidx.media3.exoplayer.hls.DefaultHlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsMediaChunkExtractor
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.ForwardingExtractorOutput
import androidx.media3.extractor.TrackOutput
import androidx.media3.extractor.metadata.emsg.EventMessage
import androidx.media3.extractor.metadata.emsg.EventMessageDecoder
import androidx.media3.extractor.metadata.emsg.EventMessageEncoder
import androidx.media3.extractor.metadata.id3.Id3Decoder
import androidx.media3.extractor.text.SubtitleParser
import java.io.EOFException
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONObject

/**
 * Keeps Media3's normal HLS ID3 path while teaching it Twitch's CMAF EMSG alias.
 *
 * Twitch fMP4 segments carry timed ID3 in an EMSG whose scheme is
 * `urn:twitch:id3`. Media3 drops that custom scheme before its timed metadata
 * renderer sees it. This factory relabels any structurally valid embedded ID3
 * envelope and delegates all media extraction; [TwitchLatencySession] remains
 * responsible for selecting only `TXXX/segmentmetadata`. A raw-JSON form is
 * retained as a compatibility fallback for older Twitch variants.
 */
@UnstableApi
internal class TwitchEmsgMetadataBridgeExtractorFactory(
    private val delegate: HlsExtractorFactory = DefaultHlsExtractorFactory(),
    logger: (String) -> Unit = { message -> Log.d(LOG_TAG, message) },
) : HlsExtractorFactory {
    private val bridge = TwitchEmsgMetadataBridge(logger)

    override fun createExtractor(
        uri: Uri,
        format: Format,
        muxedCaptionFormats: List<Format>?,
        timestampAdjuster: TimestampAdjuster,
        responseHeaders: Map<String, List<String>>,
        sniffingExtractorInput: ExtractorInput,
        playerId: PlayerId,
    ): HlsMediaChunkExtractor = TwitchEmsgMetadataBridgeChunkExtractor(
        delegate = delegate.createExtractor(
            uri,
            format,
            muxedCaptionFormats,
            timestampAdjuster,
            responseHeaders,
            sniffingExtractorInput,
            playerId,
        ),
        bridge = bridge,
    )

    override fun setSubtitleParserFactory(
        subtitleParserFactory: SubtitleParser.Factory,
    ): HlsExtractorFactory {
        delegate.setSubtitleParserFactory(subtitleParserFactory)
        return this
    }

    @Suppress("DEPRECATION")
    @ExperimentalApi
    override fun experimentalParseSubtitlesDuringExtraction(
        parseSubtitlesDuringExtraction: Boolean,
    ): HlsExtractorFactory {
        delegate.experimentalParseSubtitlesDuringExtraction(parseSubtitlesDuringExtraction)
        return this
    }

    @ExperimentalApi
    override fun experimentalSetCodecsToParseWithinGopSampleDependencies(
        codecsToParseWithinGopSampleDependencies: @C.VideoCodecFlags Int,
    ): HlsExtractorFactory {
        delegate.experimentalSetCodecsToParseWithinGopSampleDependencies(
            codecsToParseWithinGopSampleDependencies,
        )
        return this
    }

    override fun getOutputTextFormat(sourceFormat: Format): Format =
        delegate.getOutputTextFormat(sourceFormat)
}

@UnstableApi
private class TwitchEmsgMetadataBridgeChunkExtractor(
    private val delegate: HlsMediaChunkExtractor,
    private val bridge: TwitchEmsgMetadataBridge,
) : HlsMediaChunkExtractor {
    override fun init(extractorOutput: ExtractorOutput) {
        delegate.init(TwitchEmsgMetadataBridgeExtractorOutput(extractorOutput, bridge))
    }

    override fun read(extractorInput: ExtractorInput): Boolean = delegate.read(extractorInput)

    override fun isPackedAudioExtractor(): Boolean = delegate.isPackedAudioExtractor

    override fun isReusable(): Boolean = delegate.isReusable

    override fun recreate(): HlsMediaChunkExtractor = TwitchEmsgMetadataBridgeChunkExtractor(
        delegate = delegate.recreate(),
        bridge = bridge,
    )

    override fun onTruncatedSegmentParsed() = delegate.onTruncatedSegmentParsed()
}

@UnstableApi
private class TwitchEmsgMetadataBridgeExtractorOutput(
    extractorOutput: ExtractorOutput,
    private val bridge: TwitchEmsgMetadataBridge,
) : ForwardingExtractorOutput(extractorOutput) {
    private val metadataOutputs = mutableMapOf<Int, TrackOutput>()

    override fun track(id: Int, type: @C.TrackType Int): TrackOutput {
        val output = super.track(id, type)
        if (type != C.TRACK_TYPE_METADATA) {
            return output
        }
        return metadataOutputs.getOrPut(id) {
            TwitchEmsgMetadataBridgeTrackOutput(output, bridge)
        }
    }
}

/** Buffers one metadata sample so its EMSG envelope can be rewritten before forwarding. */
@UnstableApi
internal class TwitchEmsgMetadataBridgeTrackOutput(
    private val delegate: TrackOutput,
    private val bridge: TwitchEmsgMetadataBridge,
) : TrackOutput {
    private var buffer = ByteArray(INITIAL_BUFFER_SIZE)
    private var bufferPosition = 0
    private var inspectEmsgSamples = false
    private var passthrough = false
    private var bypassQueuedSamples = false

    override fun durationUs(durationUs: Long) = delegate.durationUs(durationUs)

    override fun format(format: Format) {
        inspectEmsgSamples = format.sampleMimeType == MimeTypes.APPLICATION_EMSG
        delegate.format(format)
    }

    override fun sampleData(
        input: DataReader,
        length: Int,
        allowEndOfInput: Boolean,
        sampleDataPart: @TrackOutput.SampleDataPart Int,
    ): Int {
        if (!inspectEmsgSamples) {
            return delegate.sampleData(input, length, allowEndOfInput, sampleDataPart)
        }
        if (bypassQueuedSamples) {
            return delegate.sampleData(input, length, allowEndOfInput, sampleDataPart)
        }
        if (passthrough || sampleDataPart != TrackOutput.SAMPLE_DATA_PART_MAIN) {
            enablePassthrough()
            return delegate.sampleData(input, length, allowEndOfInput, sampleDataPart)
        }
        if (!canBuffer(length)) {
            enableBoundedPassthrough()
            return delegate.sampleData(input, length, allowEndOfInput, sampleDataPart)
        }
        ensureBufferCapacity(bufferPosition + length)
        val bytesRead = input.read(buffer, bufferPosition, length)
        if (bytesRead == C.RESULT_END_OF_INPUT) {
            if (allowEndOfInput) {
                return C.RESULT_END_OF_INPUT
            }
            throw EOFException()
        }
        bufferPosition += bytesRead
        return bytesRead
    }

    override fun sampleData(
        data: ParsableByteArray,
        length: Int,
        sampleDataPart: @TrackOutput.SampleDataPart Int,
    ) {
        if (!inspectEmsgSamples) {
            delegate.sampleData(data, length, sampleDataPart)
            return
        }
        if (bypassQueuedSamples) {
            delegate.sampleData(data, length, sampleDataPart)
            return
        }
        if (passthrough || sampleDataPart != TrackOutput.SAMPLE_DATA_PART_MAIN) {
            enablePassthrough()
            delegate.sampleData(data, length, sampleDataPart)
            return
        }
        if (!canBuffer(length)) {
            enableBoundedPassthrough()
            delegate.sampleData(data, length, sampleDataPart)
            return
        }
        ensureBufferCapacity(bufferPosition + length)
        data.readBytes(buffer, bufferPosition, length)
        bufferPosition += length
    }

    override fun sampleMetadata(
        timeUs: Long,
        flags: @C.BufferFlags Int,
        size: Int,
        offset: Int,
        cryptoData: TrackOutput.CryptoData?,
    ) {
        if (!inspectEmsgSamples || passthrough) {
            delegate.sampleMetadata(timeUs, flags, size, offset, cryptoData)
            return
        }
        if (bypassQueuedSamples) {
            delegate.sampleMetadata(timeUs, flags, size, offset, cryptoData)
            if (offset == 0) {
                bypassQueuedSamples = false
            }
            return
        }
        val sampleEnd = bufferPosition - offset
        val sampleStart = sampleEnd - size
        if (size < 0 || offset < 0 || sampleStart != 0 || sampleEnd < 0) {
            // This should not occur for EMSG tracks. Preserve the original data
            // and stop inspecting rather than risking metadata corruption.
            enablePassthrough()
            delegate.sampleMetadata(timeUs, flags, size, offset, cryptoData)
            return
        }

        val originalSample = buffer.copyOfRange(sampleStart, sampleEnd)
        val bridgedSample = bridge.rewriteSample(originalSample)
        delegate.sampleData(
            ParsableByteArray(bridgedSample),
            bridgedSample.size,
            TrackOutput.SAMPLE_DATA_PART_MAIN,
        )
        delegate.sampleMetadata(
            timeUs,
            flags,
            bridgedSample.size,
            /* offset= */ 0,
            cryptoData,
        )

        if (offset > 0) {
            System.arraycopy(buffer, sampleEnd, buffer, 0, offset)
        }
        bufferPosition = offset
    }

    private fun enablePassthrough() {
        if (passthrough) {
            return
        }
        flushBufferedData()
        passthrough = true
    }

    private fun enableBoundedPassthrough() {
        flushBufferedData()
        bypassQueuedSamples = true
    }

    private fun flushBufferedData() {
        if (bufferPosition == 0) {
            return
        }
        delegate.sampleData(
            ParsableByteArray(buffer, bufferPosition),
            bufferPosition,
            TrackOutput.SAMPLE_DATA_PART_MAIN,
        )
        bufferPosition = 0
    }

    private fun ensureBufferCapacity(requiredLength: Int) {
        if (buffer.size < requiredLength) {
            buffer = buffer.copyOf(requiredLength + requiredLength / 2)
        }
    }

    private fun canBuffer(additionalLength: Int): Boolean =
        additionalLength >= 0 &&
            bufferPosition <= MAX_BUFFERED_EMSG_BYTES - additionalLength

    private companion object {
        const val INITIAL_BUFFER_SIZE = 512
        const val MAX_BUFFERED_EMSG_BYTES = 128 * 1024
    }
}

@UnstableApi
internal class TwitchEmsgMetadataBridge(
    private val logger: (String) -> Unit = { message -> Log.d(LOG_TAG, message) },
) {
    private val loggedRecovery = AtomicBoolean(false)
    private val loggedOversizedPayload = AtomicBoolean(false)

    fun rewriteSample(sample: ByteArray): ByteArray {
        val eventMessage = try {
            EventMessageDecoder().decode(ParsableByteArray(sample))
        } catch (_: RuntimeException) {
            return sample
        }
        if (eventMessage.wrappedMetadataFormat != null) {
            return sample
        }
        if (eventMessage.schemeIdUri != TWITCH_ID3_SCHEME) {
            return sample
        }
        if (eventMessage.messageData.size > MAX_SEGMENT_METADATA_BYTES) {
            if (loggedOversizedPayload.compareAndSet(false, true)) {
                logger(
                    "latency rejected oversized Twitch EMSG payload=" +
                        "${eventMessage.messageData.size} bytes",
                )
            }
            return sample
        }
        val embeddedId3 = decodeId3Payload(eventMessage.messageData)
        val jsonValue = if (embeddedId3 == null) {
            eventMessage.messageData
                .toString(StandardCharsets.UTF_8)
                .trimEnd('\u0000')
        } else {
            null
        }
        val payloadHasTranscR = try {
            jsonValue != null && JSONObject(jsonValue).has(TRANSC_R_KEY)
        } catch (_: Exception) {
            false
        }
        val isRawTwitchSegmentMetadata = payloadHasTranscR &&
            eventMessage.value == SEGMENT_METADATA_DESCRIPTION
        if (embeddedId3 == null && !isRawTwitchSegmentMetadata) {
            return sample
        }

        val id3Payload = embeddedId3
            ?: encodeTxxxId3Tag(
                SEGMENT_METADATA_DESCRIPTION,
                checkNotNull(jsonValue),
            )
        val bridged = EventMessage(
            AOM_ID3_SCHEME,
            eventMessage.value,
            eventMessage.durationMs,
            eventMessage.id,
            id3Payload,
        )
        if (loggedRecovery.compareAndSet(false, true)) {
            logger(
                "latency bridging Twitch EMSG scheme=${eventMessage.schemeIdUri} " +
                    "value=${eventMessage.value} " +
                    "payload=${if (embeddedId3 != null) "id3" else "json"} " +
                    "as timed ID3",
            )
        }
        return EventMessageEncoder().encode(bridged)
    }

    private fun decodeId3Payload(payload: ByteArray): ByteArray? {
        if (
            payload.size < ID3_TAG_HEADER_SIZE ||
            payload[0] != 'I'.code.toByte() ||
            payload[1] != 'D'.code.toByte() ||
            payload[2] != '3'.code.toByte()
        ) {
            return null
        }
        Id3Decoder().decode(payload, payload.size) ?: return null
        return payload
    }

    internal companion object {
        const val TWITCH_ID3_SCHEME = "urn:twitch:id3"
        const val AOM_ID3_SCHEME = "https://aomedia.org/emsg/ID3"
        const val SEGMENT_METADATA_DESCRIPTION = "segmentmetadata"
        const val TRANSC_R_KEY = "transc_r"
        const val MAX_SEGMENT_METADATA_BYTES = 64 * 1024
    }
}

internal fun encodeTxxxId3Tag(description: String, value: String): ByteArray {
    val descriptionBytes = description.toByteArray(StandardCharsets.UTF_8)
    val valueBytes = value.toByteArray(StandardCharsets.UTF_8)
    val frameBodySize = 1 + descriptionBytes.size + 1 + valueBytes.size
    val frameSize = ID3_FRAME_HEADER_SIZE + frameBodySize
    val tag = ByteArray(ID3_TAG_HEADER_SIZE + frameSize)

    tag[0] = 'I'.code.toByte()
    tag[1] = 'D'.code.toByte()
    tag[2] = '3'.code.toByte()
    tag[3] = 4 // ID3v2.4
    writeSynchSafeInt(tag, 6, frameSize)

    val frameOffset = ID3_TAG_HEADER_SIZE
    tag[frameOffset] = 'T'.code.toByte()
    tag[frameOffset + 1] = 'X'.code.toByte()
    tag[frameOffset + 2] = 'X'.code.toByte()
    tag[frameOffset + 3] = 'X'.code.toByte()
    writeSynchSafeInt(tag, frameOffset + 4, frameBodySize)

    var bodyOffset = frameOffset + ID3_FRAME_HEADER_SIZE
    tag[bodyOffset++] = ID3_UTF8_ENCODING
    descriptionBytes.copyInto(tag, bodyOffset)
    bodyOffset += descriptionBytes.size
    tag[bodyOffset++] = 0
    valueBytes.copyInto(tag, bodyOffset)
    return tag
}

private fun writeSynchSafeInt(target: ByteArray, offset: Int, value: Int) {
    require(value in 0..MAX_SYNCH_SAFE_INT)
    target[offset] = ((value ushr 21) and 0x7F).toByte()
    target[offset + 1] = ((value ushr 14) and 0x7F).toByte()
    target[offset + 2] = ((value ushr 7) and 0x7F).toByte()
    target[offset + 3] = (value and 0x7F).toByte()
}

private const val LOG_TAG = "FlowTwitchPlayer"
private const val ID3_TAG_HEADER_SIZE = 10
private const val ID3_FRAME_HEADER_SIZE = 10
private const val ID3_UTF8_ENCODING: Byte = 3
private const val MAX_SYNCH_SAFE_INT = 0x0FFFFFFF
