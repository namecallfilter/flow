package com.namecallfilter.flow

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class GoLiveMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        val preferences = getSharedPreferences("go_live", Context.MODE_PRIVATE)
        if (!preferences.getBoolean("enabled", false)) return
        try {
            // Read the same encrypted registration as Dart; never copy the Twitch token.
            val storage = FlutterSecureStorage(this)
            val initialized = CountDownLatch(1)
            var ready = false
            storage.initialize(FlutterSecureStorageConfig(mapOf("resetOnError" to "false")),
                object : SecurePreferencesCallback<Void> {
                    override fun onSuccess(result: Void?) { ready = true; initialized.countDown() }
                    override fun onError(error: Exception) { initialized.countDown() }
                },
            )
            if (!initialized.await(1, TimeUnit.SECONDS) || !ready) return
            val saved = storage.read(storage.addPrefixToKey("flow_go_live_registration")) ?: return
            val registration = JSONObject(saved)
            if (!registration.optBoolean("enabled") || registration.optBoolean("pendingUnregister")) return
            val previous = registration.optString("token")
            if (previous.isBlank() || previous == token) return
            val address = registration.optString("address").toHttpUrlOrNull() ?: return
            if (!address.isHttps || address.username.isNotEmpty() || address.password.isNotEmpty() ||
                address.encodedPath != "/" || address.query != null || address.fragment != null) return
            val id = registration.optString("installationId")
            val key = registration.optString("accessKey")
            val userId = registration.optString("userId")
            if (id.isBlank() || key.isBlank() || userId.isBlank() ||
                userId != preferences.getString("user_id", null) || !preferences.getBoolean("enabled", false)) return
            val base = "$address|$userId|$id|$previous"
            val expected = if (preferences.getString("token_base", null) == base)
                preferences.getString("token_uploaded", previous) else previous
            val body = JSONObject().put("token", token).put("previousToken", expected).toString()
            val request = Request.Builder()
                .url(address.newBuilder().addPathSegments("v1/devices").addPathSegment(id).build())
                .header("Authorization", "Bearer $key")
                .patch(body.toRequestBody("application/json".toMediaType()))
                .build()
            tokenClient.newCall(request).execute().use { response ->
                if (response.isSuccessful && preferences.getBoolean("enabled", false) &&
                    userId == preferences.getString("user_id", null)) {
                    preferences.edit().putString("token_base", base).putString("token_uploaded", token).apply()
                }
            }
        } catch (_: Exception) {
            // Offline, locked storage or a concurrent opt-out is retried on the next app resume.
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val preferences = getSharedPreferences("go_live", Context.MODE_PRIVATE)
        if (!preferences.getBoolean("enabled", false)) return
        val data = message.data
        if (data["user_id"] != preferences.getString("user_id", null)) return
        val broadcaster = data["broadcaster_id"] ?: return
        if (broadcaster !in preferences.getStringSet("channels", emptySet()).orEmpty()) return
        val login = data["channel_login"]?.takeIf { it.matches(Regex("[a-zA-Z0-9_]{1,25}")) } ?: return
        val streamId = data["stream_id"]?.takeIf { it.isNotBlank() } ?: return
        if (preferences.getString("last_stream_$broadcaster", null) == streamId) return
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED) return
        val manager = getSystemService(NotificationManager::class.java)
        if (!notificationsAllowed(this)) return
        manager.createNotificationChannel(NotificationChannel(
            "go_live", "Go-live notifications", NotificationManager.IMPORTANCE_HIGH,
        ))
        val open = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse("flow://live/$login"))
            .putExtra("flow_go_live_channel", login)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(
            this, broadcaster.hashCode(), open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val name = data["channel_name"]?.take(100) ?: login
        val title = data["stream_title"]?.take(500).orEmpty()
        val avatar = loadAvatar(data["avatar_url"])
        if (!preferences.getBoolean("enabled", false) ||
            data["user_id"] != preferences.getString("user_id", null) ||
            broadcaster !in preferences.getStringSet("channels", emptySet()).orEmpty()) return
        val streamer = Person.Builder()
            .setName("$name is live!")
            .setKey(broadcaster)
            .setIcon(avatar?.let { IconCompat.createWithBitmap(it) })
            .build()
        val shortcutId = "go_live:$broadcaster"
        val shortcut = ShortcutInfoCompat.Builder(this, shortcutId)
            .setShortLabel("$name is live!")
            .setPerson(streamer)
            .setLongLived(true)
            .setIntent(open)
            .apply { avatar?.let { setIcon(IconCompat.createWithBitmap(it)) } }
            .build()
        ShortcutManagerCompat.pushDynamicShortcut(this, shortcut)
        manager.notify("go_live:$broadcaster", 1,
            NotificationCompat.Builder(this, "go_live")
                .setSmallIcon(R.drawable.ic_stat_flow)
                .setShortcutId(shortcutId)
                .setContentTitle("$name is live!")
                .setContentText(title)
                .setStyle(NotificationCompat.MessagingStyle(Person.Builder().setName("Flow").build())
                    .setConversationTitle("$name is live!")
                    .setGroupConversation(false)
                    .addMessage(title, System.currentTimeMillis(), streamer))
                .setAllowSystemGeneratedContextualActions(false)
                .setContentIntent(pending)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build(),
        )
        preferences.edit().putString("last_stream_$broadcaster", streamId).apply()
    }

    private fun loadAvatar(address: String?): Bitmap? {
        val url = address?.toHttpUrlOrNull() ?: return null
        if (!url.isHttps || url.host != "static-cdn.jtvnw.net") return null
        return try {
            avatarClient.newCall(Request.Builder().url(url).build()).execute().use { response ->
                if (!response.isSuccessful) return null
                val source = response.body?.source() ?: return null
                if (source.request(256 * 1024 + 1L)) return null
                val bytes = source.readByteArray()
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                if (bounds.outWidth !in 1..1024 || bounds.outHeight !in 1..1024) return null
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private val tokenClient = OkHttpClient.Builder()
            .callTimeout(6, TimeUnit.SECONDS)
            .connectTimeout(3, TimeUnit.SECONDS)
            .readTimeout(3, TimeUnit.SECONDS)
            .writeTimeout(3, TimeUnit.SECONDS)
            .followRedirects(false)
            .followSslRedirects(false)
            .retryOnConnectionFailure(false)
            .build()

        private val avatarClient = tokenClient.newBuilder()
            .callTimeout(2, TimeUnit.SECONDS)
            .build()

        fun notificationsAllowed(context: Context): Boolean {
            val manager = context.getSystemService(NotificationManager::class.java)
            return manager.areNotificationsEnabled() &&
                manager.getNotificationChannel("go_live")?.importance != NotificationManager.IMPORTANCE_NONE
        }
    }
}
