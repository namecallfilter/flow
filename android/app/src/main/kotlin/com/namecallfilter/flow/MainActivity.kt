package com.namecallfilter.flow

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow/cookie_extractor")
            .setMethodCallHandler { call, result ->
                if (call.method == "extractTwitchAuthToken") {
                    result.success(extractTwitchAuthToken())
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow/external_url")
            .setMethodCallHandler { call, result ->
                if (call.method == "openExternalUrl") {
                    openExternalUrl(call.arguments as? String, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openExternalUrl(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("invalid_url", "URL is required.", null)
            return
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addCategory(Intent.CATEGORY_BROWSABLE)

        try {
            startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        }
    }

    private fun extractTwitchAuthToken(): String? {
        val cookieManager = CookieManager.getInstance()
        val cookies = cookieManager.getCookie("https://twitch.tv")
            ?: cookieManager.getCookie("https://www.twitch.tv")

        return cookies
            ?.split(";")
            ?.map { it.trim() }
            ?.firstOrNull { it.startsWith("auth-token=") }
            ?.substringAfter("auth-token=")
    }
}
