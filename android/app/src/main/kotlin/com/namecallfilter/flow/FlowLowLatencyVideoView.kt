package com.namecallfilter.flow

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Metadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsManifest
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.hls.playlist.HlsMediaPlaylist
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.extractor.metadata.id3.TextInformationFrame
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.json.JSONObject

@OptIn(UnstableApi::class)
class FlowLowLatencyVideoView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    params: Map<*, *>?,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "flow/low_latency_video/$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var disposed = false
    private var pendingErrorMessage: String? = null
    private var twitchLiveLatencySeconds: Double? = null
    private var lastTranscodeReceiveMs = -1L

    private val trackSelector = DefaultTrackSelector(appContext)
    private val player = ExoPlayer.Builder(appContext)
        .setTrackSelector(trackSelector)
        .setLoadControl(
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    LOW_LATENCY_MIN_BUFFER_MS,
                    LOW_LATENCY_MAX_BUFFER_MS,
                    LOW_LATENCY_PLAYBACK_BUFFER_MS,
                    LOW_LATENCY_REBUFFER_MS,
                )
                .build(),
        )
        .build()

    private val playerView = PlayerView(context).apply {
        setBackgroundColor(Color.BLACK)
        keepScreenOn = true
        useController = false
        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        player = this@FlowLowLatencyVideoView.player
    }

    private val playerListener = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            channel.invokeMethod("playing", isPlaying)
        }

        override fun onTracksChanged(tracks: Tracks) {
            if (disposed) {
                return
            }
            sendQualitiesEvent(tracks)
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            channel.invokeMethod("buffering", playbackState == Player.STATE_BUFFERING)
            if (playbackState == Player.STATE_READY) {
                maybeSeekToLiveOnStart()
            }
            sendLatency()
        }

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            sendLatency()
        }

        override fun onMetadata(metadata: Metadata) {
            if (processTwitchMetadata(metadata)) {
                sendLatency()
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            reportError(error.message ?: "Video playback failed.")
        }
    }

    private val latencyTicker = object : Runnable {
        override fun run() {
            if (disposed) {
                return
            }
            sendLatency()
            mainHandler.postDelayed(this, LATENCY_READ_INTERVAL_MS)
        }
    }

    init {
        channel.setMethodCallHandler(this)
        player.addListener(playerListener)

        val url = params?.get("url") as? String
        if (url.isNullOrBlank()) {
            reportError("Video URL is missing.")
        } else {
            load(url)
        }
    }

    private fun load(url: String) {
        TwitchLatencyMetadata.resetServerOffset()
        twitchLiveLatencySeconds = null
        lastTranscodeReceiveMs = -1L

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(USER_AGENT)

        val dataSourceFactory = DefaultDataSource.Factory(appContext, httpDataSourceFactory)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMimeType(MimeTypes.APPLICATION_M3U8)
            .setLiveConfiguration(
                MediaItem.LiveConfiguration.Builder()
                    .setTargetOffsetMs(TARGET_LIVE_OFFSET_MS)
                    .build(),
            )
            .build()

        val mediaSource = HlsMediaSource.Factory(dataSourceFactory)
            .setPlaylistParserFactory(TwitchLowLatencyHlsPlaylistParserFactory())
            .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy(6))
            .createMediaSource(mediaItem)

        pendingInitialLiveSeek = true
        player.setMediaSource(mediaSource)
        player.setPlaybackSpeed(1f)
        player.prepare()
        player.playWhenReady = true
        mainHandler.removeCallbacks(latencyTicker)
        mainHandler.post(latencyTicker)
    }

    override fun getView(): View = playerView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                sendInitialEvents()
                result.success(null)
            }

            "play" -> {
                player.play()
                result.success(null)
            }

            "pause" -> {
                player.pause()
                result.success(null)
            }

            "seekToLive" -> {
                seekToLiveTarget()
                result.success(null)
            }

            "setQuality" -> {
                val requestedQualityId = call.arguments as? String
                if (requestedQualityId == null) {
                    result.error("invalid_quality_id", "Expected a string quality id.", null)
                    return
                }

                selectedQualityId = requestedQualityId
                pendingQualityId = requestedQualityId
                if (applyQualitySelection(requestedQualityId)) {
                    pendingQualityId = null
                }
                sendQualitiesEvent()
                result.success(null)
            }

            "latency" -> result.success(currentLatencySeconds())

            "dispose" -> {
                dispose()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun sendLatency() {
        channel.invokeMethod("latency", currentLatencySeconds())
    }

    private fun reportError(message: String) {
        pendingErrorMessage = message
        channel.invokeMethod("error", message)
    }

    private fun sendInitialEvents() {
        pendingErrorMessage?.let { channel.invokeMethod("error", it) }
        channel.invokeMethod("playing", player.isPlaying)
        channel.invokeMethod("buffering", player.playbackState == Player.STATE_BUFFERING)
        sendLatency()
        sendQualitiesEvent()
    }

    private fun seekToLiveTarget() {
        if (player.isPlayingAd) {
            sendLatency()
            return
        }

        targetLivePosition()?.let { player.seekTo(it) }
        player.play()
        mainHandler.postDelayed(
            {
                if (!disposed) {
                    sendLatency()
                }
            },
            LIVE_EDGE_LATENCY_UPDATE_DELAY_MS,
        )
    }

    private fun maybeSeekToLiveOnStart() {
        if (!pendingInitialLiveSeek || player.isPlayingAd) {
            return
        }

        pendingInitialLiveSeek = false
        targetLivePosition()?.let { player.seekTo(it) }
        player.play()
        mainHandler.postDelayed(
            {
                if (!disposed) {
                    sendLatency()
                }
            },
            LIVE_EDGE_LATENCY_UPDATE_DELAY_MS,
        )
    }

    private fun targetLivePosition(): Long? {
        val availableEndMs = currentAvailableLiveEdgeMs() ?: return null

        val targetPositionMs = (availableEndMs - TARGET_LIVE_OFFSET_MS).coerceAtLeast(0L)
        return targetPositionMs.takeIf { it > player.currentPosition }
    }

    private fun currentLatencySeconds(): Double? {
        if (player.isPlayingAd) {
            return null
        }

        return twitchLiveLatencySeconds
            ?: currentBehindLiveEdgeMs()?.div(1000.0)
    }

    private fun currentHlsMediaPlaylist(): HlsMediaPlaylist? =
        (player.currentManifest as? HlsManifest)
            ?.mediaPlaylist

    private fun currentAvailableLiveEdgeMs(): Long? {
        val playlist = currentHlsMediaPlaylist() ?: return null
        return TwitchLatencyMetadata.availableEndMsFor(playlist.baseUri)
            ?: playlist.durationUs.div(1000L).takeIf { it > 0 }
    }

    private fun currentBehindLiveEdgeMs(): Long? {
        val availableEndMs = currentAvailableLiveEdgeMs() ?: return null

        return (availableEndMs - player.currentPosition).coerceAtLeast(0L)
    }

    private fun processTwitchMetadata(metadata: Metadata): Boolean {
        var didUpdate = false
        for (index in 0 until metadata.length()) {
            val entry = metadata.get(index)
            if (entry is TextInformationFrame) {
                didUpdate = processTextInformationFrame(entry) || didUpdate
            }
        }
        return didUpdate
    }

    private fun processTextInformationFrame(frame: TextInformationFrame): Boolean {
        if (frame.id != "TXXX" || frame.description != "segmentmetadata") {
            return false
        }

        for (text in frame.values) {
            val transcodeReceiveMs = parseTwitchTranscodeReceiveMs(text) ?: continue
            if (transcodeReceiveMs <= 0 || transcodeReceiveMs < lastTranscodeReceiveMs) {
                return false
            }

            lastTranscodeReceiveMs = transcodeReceiveMs
            return updateTwitchLiveLatency()
        }

        return false
    }

    private fun parseTwitchTranscodeReceiveMs(text: String): Long? {
        val jsonValue =
            runCatching {
                val json = JSONObject(text)
                if (!json.has("transc_r")) {
                    null
                } else {
                    json.optLong("transc_r").takeIf { it > 0L }
                }
            }.getOrNull()

        if (jsonValue != null) {
            return jsonValue
        }

        return Regex("""(?:^|[&;,\s])transc_r[=:]"?(\d+)""")
            .find(text)
            ?.groupValues
            ?.getOrNull(1)
            ?.toLongOrNull()
    }

    private fun updateTwitchLiveLatency(): Boolean {
        val transcodeReceiveMs = lastTranscodeReceiveMs.takeIf { it > 0L } ?: return false
        val serverOffsetMs =
            TwitchLatencyMetadata.latestServerOffsetMs()
                ?: return false

        val latencyMs = System.currentTimeMillis() + serverOffsetMs - transcodeReceiveMs
        if (latencyMs < 0L) {
            Log.w(
                TAG,
                "Ignoring negative Twitch latency " +
                    "latencyMs=$latencyMs " +
                    "serverOffsetMs=$serverOffsetMs " +
                    "transcodeReceiveMs=$transcodeReceiveMs",
            )
            return false
        }

        if (latencyMs > MAX_TWITCH_LATENCY_MS) {
            Log.w(
                TAG,
                "Ignoring huge Twitch latency " +
                    "latencyMs=$latencyMs " +
                    "serverOffsetMs=$serverOffsetMs " +
                    "transcodeReceiveMs=$transcodeReceiveMs",
            )
            return false
        }

        twitchLiveLatencySeconds = latencyMs / 1000.0

        return true
    }

    private fun sendQualitiesEvent(tracks: Tracks = player.currentTracks) {
        val previousSelectedQuality = availableVideoQualities.firstOrNull {
            it.id == selectedQualityId
        }
        val qualityOptions = extractVideoQualities(tracks)
        availableVideoQualities = qualityOptions

        if (!disposed && pendingQualityId != null) {
            if (applyQualitySelection(pendingQualityId!!)) {
                pendingQualityId = null
            }
        }

        val currentSelection = currentQualitySelection(previousSelectedQuality)
        selectedQualityId = currentSelection

        val qualitiesPayload = ArrayList<Map<String, String>>(1 + qualityOptions.size)
        qualitiesPayload.add(
            mapOf(
                "id" to AUTO_QUALITY_ID,
                "label" to AUTO_QUALITY_LABEL,
            ),
        )
        for (option in qualityOptions) {
            qualitiesPayload.add(
                mapOf(
                    "id" to option.id,
                    "label" to option.label,
                ),
            )
        }

        channel.invokeMethod(
            "qualities",
            mapOf(
                "qualities" to qualitiesPayload,
                "selectedQualityId" to currentSelection,
            ),
        )
    }

    private fun currentQualitySelection(previousSelectedQuality: VideoQualityOption?): String {
        if (selectedQualityId == AUTO_QUALITY_ID) {
            return AUTO_QUALITY_ID
        }

        val exactOption = availableVideoQualities.firstOrNull { it.id == selectedQualityId }
        if (exactOption != null) {
            return selectedQualityId
        }

        val stableOption = previousSelectedQuality?.let { previous ->
            availableVideoQualities.firstOrNull { it.hasSameRendition(previous) }
        }
        if (stableOption != null && applyQualitySelection(stableOption.id)) {
            return stableOption.id
        }

        applyAutoQuality()
        return AUTO_QUALITY_ID
    }

    private fun applyQualitySelection(qualityId: String): Boolean {
        if (qualityId == AUTO_QUALITY_ID) {
            applyAutoQuality()
            selectedQualityId = AUTO_QUALITY_ID
            return true
        }

        val option = availableVideoQualities.firstOrNull { it.id == qualityId } ?: return false
        val params = trackSelector
            .buildUponParameters()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .setOverrideForType(option.override)
            .build()
        trackSelector.setParameters(params)
        selectedQualityId = qualityId
        return true
    }

    private fun applyAutoQuality() {
        val params = trackSelector
            .buildUponParameters()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .build()
        trackSelector.setParameters(params)
    }

    private fun extractVideoQualities(tracks: Tracks): List<VideoQualityOption> {
        val options = mutableListOf<VideoQualityOption>()

        for (groupIndex in 0 until tracks.groups.size) {
            val group = tracks.groups[groupIndex]
            if (group.type != C.TRACK_TYPE_VIDEO || !group.isSupported) {
                continue
            }

            for (trackIndex in 0 until group.length) {
                if (!group.isTrackSupported(trackIndex)) {
                    continue
                }
                val format = group.getTrackFormat(trackIndex)
                val label = qualityLabel(format.height, format.frameRate) ?: continue

                options.add(
                    VideoQualityOption(
                        id = qualityId(
                            groupIndex,
                            trackIndex,
                            format.height,
                            format.frameRate,
                            format.bitrate,
                        ),
                        label = label,
                        height = format.height,
                        frameRate = format.frameRate,
                        override = TrackSelectionOverride(group.mediaTrackGroup, trackIndex),
                    ),
                )
            }
        }

        return options
            .distinctBy { it.label }
            .sortedWith(
                compareByDescending<VideoQualityOption> { it.height }
                    .thenByDescending { it.frameRate },
            )
    }

    private fun qualityLabel(height: Int, frameRate: Float): String? {
        if (height <= 0) {
            return null
        }
        val fps =
            if (frameRate > 0f) {
                Math.round(frameRate).coerceAtLeast(1)
            } else {
                0
            }
        return if (fps > 0) "${height}p$fps" else "${height}p"
    }

    private fun qualityId(
        groupIndex: Int,
        trackIndex: Int,
        height: Int,
        frameRate: Float,
        bitrate: Int,
    ): String {
        val fps = if (frameRate > 0f) "-${Math.round(frameRate)}" else ""
        val bitrateSuffix = if (bitrate > 0) "-$bitrate" else ""
        return "${height}p$fps$bitrateSuffix-g$groupIndex-t$trackIndex"
    }

    private data class VideoQualityOption(
        val id: String,
        val label: String,
        val height: Int,
        val frameRate: Float,
        val override: TrackSelectionOverride,
    ) {
        fun hasSameRendition(other: VideoQualityOption): Boolean =
            height == other.height && Math.round(frameRate) == Math.round(other.frameRate)
    }

    override fun dispose() {
        if (disposed) {
            return
        }

        disposed = true
        mainHandler.removeCallbacks(latencyTicker)
        player.removeListener(playerListener)
        playerView.keepScreenOn = false
        playerView.player = null
        player.release()
        channel.setMethodCallHandler(null)
    }

    private var selectedQualityId = AUTO_QUALITY_ID
    private var pendingQualityId: String? = null
    private var pendingInitialLiveSeek = false
    private var availableVideoQualities: List<VideoQualityOption> = emptyList()

    private companion object {
        const val LOW_LATENCY_MIN_BUFFER_MS = 8000
        const val LOW_LATENCY_MAX_BUFFER_MS = 30000
        const val LOW_LATENCY_PLAYBACK_BUFFER_MS = 1000
        const val LOW_LATENCY_REBUFFER_MS = 1500
        const val TARGET_LIVE_OFFSET_MS = 2000L
        const val LATENCY_READ_INTERVAL_MS = 1000L
        const val LIVE_EDGE_LATENCY_UPDATE_DELAY_MS = 250L
        const val MAX_TWITCH_LATENCY_MS = 30_000L
        const val AUTO_QUALITY_ID = "auto"
        const val AUTO_QUALITY_LABEL = "Auto"
        const val TAG = "FlowLowLatencyVideo"
        const val USER_AGENT =
            "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
    }
}
