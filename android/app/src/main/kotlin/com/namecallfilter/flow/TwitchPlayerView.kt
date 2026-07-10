package com.namecallfilter.flow

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.View
import androidx.media3.common.AudioAttributes
import androidx.media3.common.MediaItem
import androidx.media3.common.Metadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
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
    private val playbackListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            emitState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            latestError = error.message ?: "The stream could not be played."
            emitError(latestError!!)
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
                    player.play()
                    result.success(null)
                }

                "pause" -> {
                    player.pause()
                    result.success(null)
                }

                "togglePlayback" -> {
                    if (player.isPlaying) player.pause() else player.play()
                    result.success(null)
                }

                "jumpToLive" -> {
                    player.seekToDefaultPosition()
                    player.play()
                    result.success(null)
                }

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
        emitLatency(null)

        metadataListener?.let(player::removeListener)
        val session = TwitchLatencySession(
            onAcceptedLatency = { latencyMs ->
                if (generation == sessionGeneration) {
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
        const val USER_AGENT = "Flow/1.0 (Android Media3)"
        const val TARGET_LIVE_OFFSET_MS = 2000L
        const val MIN_LIVE_OFFSET_MS = 1500L
        const val MAX_LIVE_OFFSET_MS = 6000L
        const val MIN_PLAYBACK_SPEED = 0.98f
        const val MAX_PLAYBACK_SPEED = 1.02f
        const val MIN_BUFFER_MS = 2000
        const val MAX_BUFFER_MS = 6000
        const val BUFFER_FOR_PLAYBACK_MS = 500
        const val BUFFER_AFTER_REBUFFER_MS = 1500
    }
}
