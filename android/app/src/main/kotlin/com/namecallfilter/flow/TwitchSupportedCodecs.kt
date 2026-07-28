package com.namecallfilter.flow

import android.media.MediaCodecList
import okhttp3.HttpUrl.Companion.toHttpUrl

internal fun withDeviceSupportedTwitchCodecs(url: String): String =
    withSupportedTwitchCodecs(url, deviceDecoderMimeTypes)

internal fun withSupportedTwitchCodecs(
    url: String,
    decoderMimeTypes: Set<String>,
): String {
    val normalizedTypes = decoderMimeTypes.mapTo(mutableSetOf()) { it.lowercase() }
    val codecs = buildList {
        add("h264")
        if (VIDEO_HEVC in normalizedTypes) add("h265")
        if (VIDEO_AV1 in normalizedTypes) add("av1")
    }
    return url.toHttpUrl()
        .newBuilder()
        .setQueryParameter("supported_codecs", codecs.joinToString(","))
        .build()
        .toString()
}

private val deviceDecoderMimeTypes: Set<String> by lazy {
    runCatching {
        MediaCodecList(MediaCodecList.REGULAR_CODECS)
            .codecInfos
            .asSequence()
            .filterNot { it.isEncoder }
            .flatMap { it.supportedTypes.asSequence() }
            .map { it.lowercase() }
            .toSet()
    }.getOrDefault(emptySet())
}

private const val VIDEO_HEVC = "video/hevc"
private const val VIDEO_AV1 = "video/av01"
