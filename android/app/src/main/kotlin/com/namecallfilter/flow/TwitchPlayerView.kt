package com.namecallfilter.flow

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.Metadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLivePlaybackSpeedControl
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlin.math.max
import kotlin.math.roundToInt

@UnstableApi
internal class TwitchPlayerView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    initialUrl: String?,
) : PlatformView {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val playerView = LayoutInflater.from(context).inflate(
        R.layout.flow_twitch_player,
        null,
        false,
    ) as PlayerView
    private val methodChannel = MethodChannel(messenger, "flow/twitch_player/$viewId")
    private val eventChannel = EventChannel(messenger, "flow/twitch_player/$viewId/events")
    private val player: ExoPlayer
    private var eventSink: EventChannel.EventSink? = null
    private var latencySession: TwitchLatencySession? = null
    private var metadataListener: Player.Listener? = null
    private var sessionGeneration = 0L
    private var latestLatencyMs: Long? = null
    private var latestError: String? = null
    private var latestQualities: List<Map<String, Any?>> = emptyList()
    private var selectedQualityId = AUTO_QUALITY_ID
    private val qualityOverrides = mutableMapOf<String, TrackSelectionOverride>()
    private var pendingLiveEdgeSeek = false
    private var hasRenderedFirstFrame = false
    private val playbackListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (
                playbackState == Player.STATE_BUFFERING &&
                hasRenderedFirstFrame &&
                player.playWhenReady
            ) {
                Log.d(
                    LOG_TAG,
                    "rebuffer buffered=${player.totalBufferedDuration}ms " +
                        "liveOffset=${player.currentLiveOffset}ms",
                )
            }
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emitState()
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            latestError = error.message ?: "The stream could not be played."
            emitError(latestError!!)
        }

        override fun onRenderedFirstFrame() {
            hasRenderedFirstFrame = true
        }

        override fun onTimelineChanged(timeline: Timeline, reason: Int) {
            if (pendingLiveEdgeSeek && seekToLiveEdge()) {
                pendingLiveEdgeSeek = false
            }
        }

        override fun onTracksChanged(tracks: Tracks) {
            updateQualities(tracks)
        }
    }

    init {
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                MIN_BUFFER_MS,
                MAX_BUFFER_MS,
                BUFFER_FOR_PLAYBACK_MS,
                BUFFER_AFTER_REBUFFER_MS,
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()
        val liveSpeedControl = DefaultLivePlaybackSpeedControl.Builder()
            .setFallbackMinPlaybackSpeed(MIN_PLAYBACK_SPEED)
            .setFallbackMaxPlaybackSpeed(MAX_PLAYBACK_SPEED)
            .setMaxLiveOffsetErrorMsForUnitSpeed(MAX_OFFSET_ERROR_FOR_UNIT_SPEED_MS)
            .setTargetLiveOffsetIncrementOnRebufferMs(TARGET_OFFSET_REBUFFER_INCREMENT_MS)
            .build()
        player = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setLivePlaybackSpeedControl(liveSpeedControl)
            .build()
        player.setAudioAttributes(AudioAttributes.DEFAULT, true)
        player.setHandleAudioBecomingNoisy(true)
        player.addListener(playbackListener)
        playerView.player = player
        playerView.setShutterBackgroundColor(Color.BLACK)

        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    emitLatency(latestLatencyMs)
                    emitState()
                    emitQualities()
                    latestError?.let(::emitError)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> {
                    val url = call.arguments as? String
                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "A Twitch HLS URL is required.", null)
                    } else {
                        load(url)
                        result.success(null)
                    }
                }

                "play" -> {
                    resumeAtLiveEdge()
                    result.success(null)
                }

                "pause" -> {
                    player.pause()
                    result.success(null)
                }

                "togglePlayback" -> {
                    if (player.playWhenReady) player.pause() else resumeAtLiveEdge()
                    result.success(null)
                }

                "jumpToLive" -> {
                    resumeAtLiveEdge()
                    result.success(null)
                }

                "setQuality" -> setQuality(call.arguments as? String, result)

                else -> result.notImplemented()
            }
        }

        if (!initialUrl.isNullOrBlank()) {
            load(initialUrl)
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        sessionGeneration++
        metadataListener?.let(player::removeListener)
        metadataListener = null
        latencySession = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        playerView.player = null
        player.release()
    }

    private fun load(url: String) {
        val generation = ++sessionGeneration
        latestLatencyMs = null
        latestError = null
        latestQualities = emptyList()
        qualityOverrides.clear()
        selectedQualityId = AUTO_QUALITY_ID
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .build()
        pendingLiveEdgeSeek = false
        hasRenderedFirstFrame = false
        emitLatency(null)
        emitQualities()

        metadataListener?.let(player::removeListener)
        val session = TwitchLatencySession(
            onAcceptedLatency = { latencyMs ->
                if (generation == sessionGeneration && player.playWhenReady) {
                    emitLatency(latencyMs)
                }
            },
        )
        latencySession = session
        metadataListener = object : Player.Listener {
            override fun onMetadata(metadata: Metadata) {
                if (generation == sessionGeneration) {
                    session.handleMetadata(metadata)
                }
            }
        }.also(player::addListener)

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(USER_AGENT)
        val dataSourceFactory = DefaultDataSource.Factory(playerView.context, httpDataSourceFactory)
        val mediaSource = HlsMediaSource.Factory(dataSourceFactory)
            .setMetadataType(HlsMediaSource.METADATA_TYPE_ID3)
            .setPlaylistParserFactory(ServerTimePlaylistParserFactory(session))
            .createMediaSource(
                MediaItem.Builder()
                    .setUri(Uri.parse(url))
                    .setMimeType(MimeTypes.APPLICATION_M3U8)
                    .setLiveConfiguration(
                        MediaItem.LiveConfiguration.Builder()
                            .setTargetOffsetMs(TARGET_LIVE_OFFSET_MS)
                            .setMinOffsetMs(MIN_LIVE_OFFSET_MS)
                            .setMaxOffsetMs(MAX_LIVE_OFFSET_MS)
                            .setMinPlaybackSpeed(MIN_PLAYBACK_SPEED)
                            .setMaxPlaybackSpeed(MAX_PLAYBACK_SPEED)
                            .build(),
                    )
                    .build(),
            )

        player.setMediaSource(mediaSource)
        player.prepare()
        player.play()
    }

    private fun resumeAtLiveEdge() {
        if (!seekToLiveEdge()) {
            pendingLiveEdgeSeek = true
        }
        player.play()
    }

    private fun seekToLiveEdge(): Boolean {
        val timeline = player.currentTimeline
        if (
            timeline.isEmpty ||
            player.currentMediaItemIndex < 0 ||
            player.currentMediaItemIndex >= timeline.windowCount
        ) {
            return false
        }

        val window = timeline.getWindow(player.currentMediaItemIndex, Timeline.Window())
        if (window.isLive()) {
            val positionMs = playableLivePositionMs(
                durationMs = window.durationMs,
                liveEdgeOffsetMs = LIVE_EDGE_SEEK_OFFSET_MS,
                currentPositionMs = player.currentPosition,
            ) ?: return false
            if (positionMs > player.currentPosition) {
                player.seekTo(player.currentMediaItemIndex, positionMs)
            }
            return true
        }

        player.seekToDefaultPosition()
        return true
    }

    private fun updateQualities(tracks: Tracks) {
        qualityOverrides.clear()
        val qualities = mutableListOf<Map<String, Any?>>()
        tracks.groups.forEachIndexed { groupIndex, group ->
            if (group.type != C.TRACK_TYPE_VIDEO) {
                return@forEachIndexed
            }
            for (trackIndex in 0 until group.length) {
                if (!group.isTrackSupported(trackIndex)) {
                    continue
                }
                val format = group.getTrackFormat(trackIndex)
                if (format.height <= 0) {
                    continue
                }
                val id = "$groupIndex:$trackIndex"
                qualityOverrides[id] = TrackSelectionOverride(
                    group.mediaTrackGroup,
                    trackIndex,
                )
                qualities += mapOf(
                    "id" to id,
                    "label" to qualityLabel(format),
                    "width" to format.width,
                    "height" to format.height,
                    "fps" to format.frameRate.takeIf { it > 0 },
                    "bitrate" to format.bitrate.takeIf { it > 0 },
                )
            }
        }
        latestQualities = qualities
            .distinctBy { listOf(it["height"], it["fps"], it["bitrate"]) }
            .sortedWith(
                compareByDescending<Map<String, Any?>> { it["height"] as? Int ?: 0 }
                    .thenByDescending { (it["fps"] as? Number)?.toDouble() ?: 0.0 },
            )
        if (selectedQualityId != AUTO_QUALITY_ID && !qualityOverrides.containsKey(selectedQualityId)) {
            selectedQualityId = AUTO_QUALITY_ID
        }
        emitQualities()
    }

    private fun setQuality(id: String?, result: MethodChannel.Result) {
        if (id == AUTO_QUALITY_ID) {
            player.trackSelectionParameters = player.trackSelectionParameters
                .buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                .build()
            selectedQualityId = AUTO_QUALITY_ID
            emitQualities()
            result.success(null)
            return
        }

        val override = id?.let(qualityOverrides::get)
        if (id == null || override == null) {
            result.error("invalid_quality", "That video quality is no longer available.", null)
            return
        }
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .setOverrideForType(override)
            .build()
        selectedQualityId = id
        emitQualities()
        result.success(null)
    }

    private fun qualityLabel(format: Format): String {
        val provided = format.label?.trim().orEmpty()
        if (provided.isNotEmpty()) {
            return provided
        }
        val frameRate = format.frameRate.takeIf { it >= 50 }?.roundToInt()
        return buildString {
            append(format.height)
            append('p')
            if (frameRate != null) {
                append(frameRate)
            }
        }
    }

    private fun emitLatency(latencyMs: Long?) {
        latestLatencyMs = latencyMs
        emit(mapOf("type" to "latency", "latencyMs" to latencyMs))
    }

    private fun emitState() {
        emit(
            mapOf(
                "type" to "state",
                "isPlaying" to player.isPlaying,
                "isBuffering" to (player.playbackState == Player.STATE_BUFFERING),
                "playWhenReady" to player.playWhenReady,
            ),
        )
    }

    private fun emitQualities() {
        emit(
            mapOf(
                "type" to "qualities",
                "qualities" to latestQualities,
                "selectedId" to selectedQualityId,
            ),
        )
    }

    private fun emitError(message: String) {
        emit(mapOf("type" to "error", "message" to message))
    }

    private fun emit(event: Map<String, Any?>) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            eventSink?.success(event)
        } else {
            mainHandler.post { eventSink?.success(event) }
        }
    }

    private companion object {
        const val LOG_TAG = "FlowTwitchPlayer"
        const val USER_AGENT = "Flow/1.0 (Android Media3)"
        const val AUTO_QUALITY_ID = "auto"
        const val LIVE_EDGE_SEEK_OFFSET_MS = 1000L
        const val TARGET_LIVE_OFFSET_MS = 1250L
        const val MIN_LIVE_OFFSET_MS = 500L
        const val MAX_LIVE_OFFSET_MS = 4000L
        const val MIN_PLAYBACK_SPEED = 0.98f
        const val MAX_PLAYBACK_SPEED = 1.04f
        const val MAX_OFFSET_ERROR_FOR_UNIT_SPEED_MS = 100L
        const val TARGET_OFFSET_REBUFFER_INCREMENT_MS = 250L
        const val MIN_BUFFER_MS = 1500
        const val MAX_BUFFER_MS = 5000
        const val BUFFER_FOR_PLAYBACK_MS = 750
        const val BUFFER_AFTER_REBUFFER_MS = 1000
    }
}

internal fun liveEdgePositionMs(durationMs: Long, safetyMs: Long): Long? =
    if (durationMs == C.TIME_UNSET || durationMs < 0) null else max(0L, durationMs - safetyMs)

internal fun playableLivePositionMs(
    durationMs: Long,
    liveEdgeOffsetMs: Long,
    currentPositionMs: Long,
): Long? = liveEdgePositionMs(durationMs, liveEdgeOffsetMs)?.let { max(currentPositionMs, it) }
