package com.namecallfilter.flow

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class TwitchPlayerViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: MainActivity,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<*, *>
        return TwitchPlayerView(
            context = context,
            activity = activity,
            messenger = messenger,
            viewId = viewId,
            initialUrl = creationParams?.get("url") as? String,
            initialQualityId = creationParams?.get("qualityId") as? String ?: "auto",
            initialPositionMs = (creationParams?.get("positionMs") as? Number)?.toLong() ?: 0L,
            mediaTitle = creationParams?.get("title") as? String ?: "Flow",
            mediaArtist = creationParams?.get("artist") as? String ?: "",
            isLive = creationParams?.get("isLive") as? Boolean ?: true,
            pictureInPictureEnabled = creationParams?.get("pictureInPictureEnabled") as? Boolean ?: true,
            proxyUrls = (creationParams?.get("proxyUrls") as? List<*>)
                ?.filterIsInstance<String>()
                .orEmpty(),
        )
    }
}
