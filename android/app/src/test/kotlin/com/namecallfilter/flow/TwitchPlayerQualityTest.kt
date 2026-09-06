package com.namecallfilter.flow

import android.os.Handler
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.Timeline
import androidx.media3.common.TrackGroup
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.TransferListener
import androidx.media3.exoplayer.source.MediaSource.MediaPeriodId
import androidx.media3.exoplayer.source.chunk.MediaChunkIterator
import androidx.media3.exoplayer.trackselection.ExoTrackSelection
import androidx.media3.exoplayer.upstream.BandwidthMeter
import org.junit.Assert.assertEquals
import org.junit.Test

@UnstableApi
class TwitchPlayerQualityTest {
    @Test
    fun autoUpgradesAfterBandwidthRecoveryWithinTheActualLiveBuffer() {
        var bandwidth = 500_000L
        val meter = object : BandwidthMeter {
            override fun getBitrateEstimate() = bandwidth
            override fun getTransferListener(): TransferListener? = null
            override fun addEventListener(handler: Handler, listener: BandwidthMeter.EventListener) {}
            override fun removeEventListener(listener: BandwidthMeter.EventListener) {}
        }
        val clock = object : Clock by Clock.DEFAULT {
            override fun elapsedRealtime() = 0L
        }
        val group = TrackGroup(
            Format.Builder().setId("160p").setHeight(160).setAverageBitrate(200_000)
                .setSampleMimeType(MimeTypes.VIDEO_H264).build(),
            Format.Builder().setId("1080p60").setHeight(1080).setAverageBitrate(6_000_000)
                .setSampleMimeType(MimeTypes.VIDEO_H264).build(),
        )
        val selection = checkNotNull(
            TwitchPlayerView.adaptiveTrackSelectionFactory(clock).createTrackSelections(
                arrayOf(ExoTrackSelection.Definition(group, 0, 1)),
                meter,
                MediaPeriodId(Any()),
                Timeline.EMPTY,
            ).single(),
        )
        fun update(bufferedUs: Long) = selection.updateSelectedTrack(
            0L,
            bufferedUs,
            // Twitch's promoted prefetch overstates the timeline's live duration.
            30_000_000L,
            emptyList(),
            arrayOf(MediaChunkIterator.EMPTY, MediaChunkIterator.EMPTY),
        )

        update(1_650_000L)
        assertEquals("160p", selection.selectedFormat.id)
        bandwidth = 50_000_000L
        update(500_000L)
        assertEquals("160p", selection.selectedFormat.id) // Buffer must be healthy first.
        update(1_650_000L)
        assertEquals("1080p60", selection.selectedFormat.id)
        bandwidth = 500_000L
        update(500_000L)
        assertEquals("160p", selection.selectedFormat.id) // Auto still responds to a slow network.
    }

    @Test
    fun qualityPreferenceUsesResolutionAndRoundedFrameRateInsteadOfTrackIndexes() {
        assertEquals("video:1080:60", stableQualityId(1080, 59.94f))
        assertEquals(stableQualityId(1080, 60f), stableQualityId(1080, 59.94f))
        assertEquals("video:720:30", stableQualityId(720, 29.97f))
        assertEquals("video:720:0", stableQualityId(720, -1f))
    }

    @Test
    fun selectedDuplicateRemainsVisible() {
        val visible = deduplicateQualities(
            qualities = listOf(
                quality("first", height = 720, fps = 60.0, bitrate = 3_000_000),
                quality("selected", height = 720, fps = 60.0, bitrate = 3_000_000),
                quality("lower", height = 480, fps = 30.0, bitrate = 1_000_000),
            ),
            selectedQualityId = "selected",
        )

        assertEquals(listOf("selected", "lower"), visible.map { it["id"] })
    }

    private fun quality(
        id: String,
        height: Int,
        fps: Double,
        bitrate: Int,
    ): Map<String, Any?> = mapOf(
        "id" to id,
        "height" to height,
        "fps" to fps,
        "bitrate" to bitrate,
    )
}
