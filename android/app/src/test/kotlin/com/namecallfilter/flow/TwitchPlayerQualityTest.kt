package com.namecallfilter.flow

import android.os.Handler
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Timeline
import androidx.media3.common.TrackGroup
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.ByteArrayDataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import androidx.media3.exoplayer.LoadControl
import androidx.media3.exoplayer.analytics.PlayerId
import androidx.media3.exoplayer.source.MediaSource.MediaPeriodId
import androidx.media3.exoplayer.source.SinglePeriodTimeline
import androidx.media3.exoplayer.source.chunk.MediaChunk
import androidx.media3.exoplayer.source.chunk.MediaChunkIterator
import androidx.media3.exoplayer.trackselection.ExoTrackSelection
import androidx.media3.exoplayer.upstream.BandwidthMeter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class TwitchPlayerQualityTest {
    @Test
    fun vodKeepsLoadingPastOneLongSegmentSoAutoCanUpgrade() {
        val timeline = SinglePeriodTimeline(60_000_000L, true, false, false, null, MediaItem.EMPTY)
        val parameters = LoadControl.Parameters(
            PlayerId.UNSET,
            timeline,
            MediaPeriodId(timeline.getUidOfPeriod(0)),
            0L,
            10_000_000L,
            1f,
            true,
            false,
            C.TIME_UNSET,
            C.TIME_UNSET,
        )
        val vod = TwitchPlayerView.playbackLoadControl(isLive = false)
        val live = TwitchPlayerView.playbackLoadControl(isLive = true)
        vod.onPrepared(PlayerId.UNSET)
        live.onPrepared(PlayerId.UNSET)

        assertTrue(vod.shouldContinueLoading(parameters))
        assertFalse(live.shouldContinueLoading(parameters))
    }

    @Test
    fun audioOnlyCanReturnToAutoOrTheRequestedVideoTrackWithoutChangingAudio() {
        val video = TrackGroup(Format.Builder().setSampleMimeType(MimeTypes.VIDEO_H264).build())
        val audio = TrackGroup(Format.Builder().setSampleMimeType(MimeTypes.AUDIO_AAC).build())
        val audioOverride = TrackSelectionOverride(audio, 0)
        val videoOverride = TrackSelectionOverride(video, 0)
        val manual = TrackSelectionParameters.DEFAULT.buildUpon()
            .setOverrideForType(videoOverride)
            .setOverrideForType(audioOverride)
            .build()

        val audioOnly = TwitchPlayerView.qualityParameters(manual, "audio_only")
        assertTrue(audioOnly.disabledTrackTypes.contains(C.TRACK_TYPE_VIDEO))
        assertFalse(audioOnly.disabledTrackTypes.contains(C.TRACK_TYPE_AUDIO))
        assertFalse(audioOnly.overrides.containsKey(video))
        assertEquals(audioOverride, audioOnly.overrides[audio])

        val auto = TwitchPlayerView.qualityParameters(audioOnly, "auto")
        assertFalse(auto.disabledTrackTypes.contains(C.TRACK_TYPE_VIDEO))
        assertEquals(audioOverride, auto.overrides[audio])

        val restored = TwitchPlayerView.qualityParameters(audioOnly, "video:720:30", videoOverride)
        assertFalse(restored.disabledTrackTypes.contains(C.TRACK_TYPE_VIDEO))
        assertEquals(videoOverride, restored.overrides[video])
        assertEquals(audioOverride, restored.overrides[audio])
    }

    @Test
    fun autoUpgradesAfterBandwidthRecoveryWithinTheActualLiveBuffer() {
        var bandwidth = 500_000L
        var nowMs = 0L
        val meter = object : BandwidthMeter {
            override fun getBitrateEstimate() = bandwidth
            override fun getTransferListener(): TransferListener? = null
            override fun addEventListener(handler: Handler, listener: BandwidthMeter.EventListener) {}
            override fun removeEventListener(listener: BandwidthMeter.EventListener) {}
        }
        val clock = object : Clock by Clock.DEFAULT {
            override fun elapsedRealtime() = nowMs
        }
        val group = TrackGroup(
            Format.Builder().setId("160p").setHeight(160).setAverageBitrate(200_000)
                .setSampleMimeType(MimeTypes.VIDEO_H264).build(),
            Format.Builder().setId("1080p60").setWidth(1920).setHeight(1080).setAverageBitrate(6_000_000)
                .setSampleMimeType(MimeTypes.VIDEO_H264).build(),
            Format.Builder().setId("1440p60").setWidth(2560).setHeight(1440).setAverageBitrate(12_000_000)
                .setSampleMimeType(MimeTypes.VIDEO_H265).build(),
        )
        // Queue selection never opens this spec; JVM Android stubs cannot construct a Uri.
        val unsafeClass = Class.forName("sun.misc.Unsafe")
        val unsafeField = unsafeClass.getDeclaredField("theUnsafe").apply { isAccessible = true }
        val dataSpec = unsafeClass.getMethod("allocateInstance", Class::class.java)
            .invoke(unsafeField.get(null), DataSpec::class.java) as DataSpec
        val queuedHd = listOf(2_000_000L, 10_000_000L).map { chunkDurationUs ->
            List(3) { index ->
                object : MediaChunk(
                    ByteArrayDataSource(byteArrayOf(1)),
                    dataSpec,
                    group.getFormat(1),
                    C.SELECTION_REASON_ADAPTIVE,
                    null,
                    index * chunkDurationUs,
                    (index + 1) * chunkDurationUs,
                    index.toLong(),
                ) {
                    override fun load() {}
                    override fun cancelLoad() {}
                    override fun isLoadCompleted() = true
                }
            }
        }
        fun createSelection(isLive: Boolean) = checkNotNull(
            TwitchPlayerView.adaptiveTrackSelectionFactory(clock, isLive).createTrackSelections(
                arrayOf(ExoTrackSelection.Definition(group, 0, 1, 2)),
                meter,
                MediaPeriodId(Any()),
                Timeline.EMPTY,
            ).single(),
        )
        val selection = createSelection(isLive = true)
        val vodSelection = createSelection(isLive = false)
        fun update(bufferedUs: Long) = selection.updateSelectedTrack(
            0L,
            bufferedUs,
            // Twitch's promoted prefetch overstates the timeline's live duration.
            30_000_000L,
            emptyList(),
            arrayOf(MediaChunkIterator.EMPTY, MediaChunkIterator.EMPTY, MediaChunkIterator.EMPTY),
        )

        update(1_650_000L)
        assertEquals("160p", selection.selectedFormat.id)
        bandwidth = 14_000_000L
        update(500_000L)
        assertEquals("160p", selection.selectedFormat.id) // Buffer must be healthy first.
        update(1_650_000L)
        assertEquals("1080p60", selection.selectedFormat.id)
        queuedHd.forEach {
            assertEquals(3, selection.evaluateQueueSize(0L, it))
            assertEquals(3, vodSelection.evaluateQueueSize(0L, it))
        }
        bandwidth = 50_000_000L
        update(1_650_000L)
        assertEquals("1440p60", selection.selectedFormat.id)
        nowMs += 1_000L
        // VOD replaces the HD tail, retaining the current complete segment; live is unchanged.
        queuedHd.forEach {
            assertEquals(3, selection.evaluateQueueSize(0L, it))
            assertEquals(1, vodSelection.evaluateQueueSize(0L, it))
        }
        bandwidth = 500_000L
        update(500_000L)
        assertEquals("160p", selection.selectedFormat.id) // Auto still responds to a slow network.
        nowMs += 1_000L
        queuedHd.forEach {
            assertEquals(3, selection.evaluateQueueSize(0L, it))
            assertEquals(3, vodSelection.evaluateQueueSize(0L, it))
        }
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
