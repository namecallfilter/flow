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

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "flow/twitch_player",
            TwitchPlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flow/cookie_extractor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractTwitchAuthToken" -> result.success(extractTwitchCookie("auth-token"))
                    "extractTwitchDeviceId" -> result.success(extractTwitchCookie("unique_id"))
                    "getTwitchIntegrityContext" -> {
                        val authorization = call.argument<String>("authorization")
                        if (authorization.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            TwitchIntegritySession(this).start(authorization) { headers ->
                                result.success(headers)
                            }
                        }
                    }
                    else -> result.notImplemented()
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
}

internal fun extractTwitchCookie(
    name: String,
    cookieForUrl: (String) -> String? = CookieManager.getInstance()::getCookie,
): String? = sequenceOf("https://twitch.tv", "https://www.twitch.tv")
    .firstNotNullOfOrNull { url ->
        cookieForUrl(url)
            ?.split(";")
            ?.map { it.trim() }
            ?.firstOrNull { it.startsWith("$name=") }
            ?.substringAfter("$name=")
    }
