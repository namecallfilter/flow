package com.namecallfilter.flow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.drawable.Icon
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import androidx.core.content.IntentCompat

class AudioPlaybackService : Service() {
    private val channelId = "audio_playback"

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(channelId, "Audio playback", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val token = intent?.let { IntentCompat.getParcelableExtra(it, "session", MediaSession.Token::class.java) }
        if (token == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val controller = MediaController(this, token)
        val playing = controller.playbackState?.state in listOf(PlaybackState.STATE_PLAYING, PlaybackState.STATE_BUFFERING)
        if (intent.action == "toggle") {
            if (playing) controller.transportControls.pause() else controller.transportControls.play()
            return START_NOT_STICKY
        }
        val openPlayer = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val toggle = PendingIntent.getService(
            this, 0, Intent(this, AudioPlaybackService::class.java).setAction("toggle").putExtra("session", token),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }
        startForeground(
            1,
            builder
                .setSmallIcon(R.drawable.ic_pip_play)
                .setContentTitle(controller.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Flow")
                .setContentText(controller.metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST))
                .setCategory(Notification.CATEGORY_TRANSPORT)
                .setContentIntent(openPlayer)
                .setStyle(Notification.MediaStyle().setMediaSession(token).setShowActionsInCompactView(0))
                .addAction(Notification.Action.Builder(
                    Icon.createWithResource(this, if (playing) R.drawable.ic_pip_pause else R.drawable.ic_pip_play),
                    if (playing) "Pause" else "Play",
                    toggle,
                ).build())
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build(),
        )
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
