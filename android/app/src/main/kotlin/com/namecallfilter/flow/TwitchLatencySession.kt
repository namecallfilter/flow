package com.namecallfilter.flow

import android.util.Log
import androidx.media3.common.Metadata
import androidx.media3.common.util.UnstableApi
import androidx.media3.extractor.metadata.id3.TextInformationFrame
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.roundToLong

@UnstableApi
internal class TwitchLatencySession(
    private val clockMs: () -> Long = System::currentTimeMillis,
    private val onAcceptedLatency: (Long) -> Unit,
    private val logger: (String) -> Unit = { message -> Log.d(LOG_TAG, message) },
) {
    private val serverOffset = AtomicLong(UNSET_VALUE)
    private val transcR = AtomicReference<Long?>(null)

    internal val serverOffsetMs: Long?
        get() = serverOffset.get().takeUnless { it == UNSET_VALUE }

    internal val lastTranscR: Long?
        get() = transcR.get()

    fun captureServerTimeEpochSeconds(serverTimeSeconds: Double) {
        if (
            !serverTimeSeconds.isFinite() ||
            serverTimeSeconds < MIN_REASONABLE_EPOCH_SECONDS ||
            serverTimeSeconds > MAX_REASONABLE_EPOCH_SECONDS
        ) {
            logger("latency rejected X-SERVER-TIME=$serverTimeSeconds")
            return
        }

        val serverTimeMs = (serverTimeSeconds * MILLIS_PER_SECOND).roundToLong()
        val initialOffsetMs = serverTimeMs - clockMs()
        if (serverOffset.compareAndSet(UNSET_VALUE, initialOffsetMs)) {
            logger("latency initial server offset=${initialOffsetMs}ms")
        }
    }

    fun handleMetadata(metadata: Metadata) {
        for (index in 0 until metadata.length()) {
            val frame = metadata[index]
            if (
                frame is TextInformationFrame &&
                frame.id == TXXX_ID &&
                frame.description == SEGMENT_METADATA_DESCRIPTION
            ) {
                frame.values.firstOrNull()?.let(::handleSegmentMetadataValue)
            }
        }
    }

    internal fun handleSegmentMetadataValue(value: String) {
        val parsedTranscR = try {
            val rawValue = JSONObject(value).opt(TRANSC_R_KEY)
            when (rawValue) {
                is Number -> rawValue.toDouble()
                is String -> rawValue.toDoubleOrNull()
                else -> null
            }
        } catch (_: Exception) {
            null
        }

        if (parsedTranscR == null || !parsedTranscR.isFinite() || parsedTranscR <= 0) {
            logger("latency rejected invalid transc_r")
            return
        }

        val parsedTranscRMs = parsedTranscR.roundToLong()
        logger("latency parsed transc_r=$parsedTranscRMs")

        val offsetMs = serverOffset.get()
        if (offsetMs == UNSET_VALUE) {
            logger("latency rejected transc_r before server offset")
            return
        }

        val latencyMs = clockMs() + offsetMs - parsedTranscRMs
        if (latencyMs < 0 || latencyMs > MAX_REASONABLE_LATENCY_MS) {
            logger("latency rejected value=${latencyMs}ms")
            return
        }

        // Resume/jump freshness barriers must be anchored to accepted metadata.
        // A rejected future or otherwise invalid value must not poison them.
        transcR.set(parsedTranscRMs)
        logger("latency accepted=${latencyMs}ms")
        onAcceptedLatency(latencyMs)
    }

    private companion object {
        const val LOG_TAG = "FlowTwitchPlayer"
        const val TXXX_ID = "TXXX"
        const val SEGMENT_METADATA_DESCRIPTION = "segmentmetadata"
        const val TRANSC_R_KEY = "transc_r"
        const val MILLIS_PER_SECOND = 1000.0
        const val MIN_REASONABLE_EPOCH_SECONDS = 1_000_000_000.0
        const val MAX_REASONABLE_EPOCH_SECONDS = 10_000_000_000.0
        const val MAX_REASONABLE_LATENCY_MS = 10 * 60 * 1000L
        const val UNSET_VALUE = Long.MIN_VALUE
    }
}
