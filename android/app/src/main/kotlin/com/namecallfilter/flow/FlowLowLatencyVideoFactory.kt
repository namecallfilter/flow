package com.namecallfilter.flow

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class FlowLowLatencyVideoFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return FlowLowLatencyVideoView(
            context = context,
            messenger = messenger,
            viewId = viewId,
            params = args as? Map<*, *>,
        )
    }
}
