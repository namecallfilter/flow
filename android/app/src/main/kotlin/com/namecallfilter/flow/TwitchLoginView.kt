package com.namecallfilter.flow

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.webkit.CookieManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject
import org.mozilla.geckoview.AllowOrDeny
import org.mozilla.geckoview.GeckoResult
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.GeckoSession
import org.mozilla.geckoview.GeckoView
import org.mozilla.geckoview.WebExtension
import org.mozilla.geckoview.WebRequestError
import java.net.URI
import java.net.URLDecoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal class TwitchLoginViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: MainActivity,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        TwitchLoginView(activity, messenger, viewId)
}

internal class TwitchLoginView(context: Context, messenger: BinaryMessenger, viewId: Int) : PlatformView {
    private val view = GeckoView(context)
    private val session = GeckoSession()
    private val channel = MethodChannel(messenger, "flow/twitch_login/$viewId")
    private val handler = Handler(Looper.getMainLooper())
    private var disposed = false
    private var redirectUri: String? = null
    private var callbackObserved = false
    private var pendingImport: MethodChannel.Result? = null
    private var importId = 0L
    private var importSent = false
    private var importResponseReceived = false
    private val importTimeout = Runnable { failImport() }

    init {
        activeView?.dispose()
        activeView = this
        session.navigationDelegate = object : GeckoSession.NavigationDelegate {
            override fun onLoadRequest(
                session: GeckoSession,
                request: GeckoSession.NavigationDelegate.LoadRequest,
            ): GeckoResult<AllowOrDeny>? {
                if (!disposed && isTwitchLoginCallback(request.uri, redirectUri)) {
                    callbackObserved = true
                    channel.invokeMethod("onUrlChange", request.uri)
                    return GeckoResult.fromValue(AllowOrDeny.DENY)
                }
                return null
            }

            override fun onLocationChange(
                session: GeckoSession,
                url: String?,
                permissions: MutableList<GeckoSession.PermissionDelegate.ContentPermission>,
                hasUserGesture: Boolean,
            ) {
                if (!disposed && url != null) {
                    if (isTwitchLoginCallback(url, redirectUri)) callbackObserved = true
                    channel.invokeMethod("onUrlChange", url)
                }
            }

            override fun onLoadError(session: GeckoSession, uri: String?, error: WebRequestError): GeckoResult<String>? {
                if (!disposed && !callbackObserved) reportError("Couldn't load Twitch sign-in. Please try again.")
                return null
            }
        }
        channel.setMethodCallHandler { call, result ->
            if (disposed) {
                result.error("twitch_login", "Twitch sign-in was closed.", null)
            } else when (call.method) {
                "loadUrl" -> {
                    val url = call.argument<String>("url")
                    val redirect = call.argument<String>("redirectUri")
                    if (url.isNullOrBlank() || redirect.isNullOrBlank()) {
                        result.error("twitch_login", "Twitch sign-in is unavailable.", null)
                    } else {
                        try {
                            failImport()
                            redirectUri = redirect
                            callbackObserved = false
                            if (!session.isOpen) {
                                session.open(runtimeFor(context))
                                view.setSession(session)
                            }
                            session.loadUri(url)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("twitch_login", "Couldn't start Twitch sign-in. Please restart Flow.", null)
                        }
                    }
                }
                "importWebSession" -> {
                    if (pendingImport != null || !callbackObserved || extensionFailed) {
                        result.error("twitch_login", "Couldn't prepare Twitch's web session.", null)
                    } else {
                        pendingImport = result
                        importId = ++nextImportId
                        importSent = false
                        importResponseReceived = false
                        handler.postDelayed(importTimeout, 10_000)
                        requestCookies()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun reportError(message: String) {
        if (!disposed) channel.invokeMethod("onError", message)
    }

    private fun requestCookies() {
        val port = cookiePort ?: return
        if (disposed || pendingImport == null || importSent) return
        importSent = true
        try {
            port.postMessage(JSONObject().put("type", "exportCookies").put("requestId", importId))
        } catch (_: Exception) {
            failImport()
        }
    }

    private fun receiveCookies(message: JSONObject) {
        if (disposed || pendingImport == null || importResponseReceived || message.optLong("requestId", -1) != importId) return
        importResponseReceived = true
        if (!message.optBoolean("ok")) return failImport()
        try {
            val values = message.getJSONArray("cookies")
            val cookies = (0 until values.length()).map(values::getJSONObject)
            fun rootValues(name: String) = cookies.filter {
                it.optString("name") == name && it.optString("path") == "/" &&
                    it.optString("domain").removePrefix(".") in listOf("twitch.tv", "www.twitch.tv")
            }.map { it.getString("value") }.distinct()
            val expectedTokens = rootValues("auth-token")
            val expectedDeviceIds = rootValues("unique_id")
            require(expectedTokens.size == 1 && expectedTokens.single().isNotBlank())
            require(expectedDeviceIds.size <= 1)
            val writes = mutableListOf<Pair<String, String>>()
            // Remove conflicting root auth cookies left by the other browser engine.
            for (host in listOf("twitch.tv", "www.twitch.tv")) {
                for (name in listOf("auth-token", "unique_id")) {
                    for (domain in listOf("", "; Domain=.$host")) {
                        writes += "https://$host/" to "$name=; Path=/; Max-Age=0$domain"
                    }
                }
            }
            writes += cookies.map(::twitchCookieForWebView)
            writeCookies(writes, expectedTokens.single(), expectedDeviceIds.singleOrNull(), importId)
        } catch (_: Exception) {
            failImport()
        }
    }

    private fun writeCookies(writes: List<Pair<String, String>>, expectedToken: String, expectedDeviceId: String?, requestId: Long) {
        val manager = CookieManager.getInstance()
        var index = 0
        fun writeNext() {
            if (disposed || pendingImport == null || importId != requestId) return
            try {
                if (index < writes.size) {
                    val (url, header) = writes[index++]
                    manager.setCookie(url, header) { accepted ->
                        if (disposed || pendingImport == null || importId != requestId) return@setCookie
                        if (accepted) writeNext() else failImport()
                    }
                } else {
                    manager.flush()
                    val stored = listOf("https://twitch.tv/", "https://www.twitch.tv/").flatMap { url ->
                        manager.getCookie(url).orEmpty().split(';').map(String::trim)
                    }
                    fun matches(name: String, expected: String) = extractTwitchCookie(name) == expected &&
                        stored.filter { it.startsWith("$name=") }.all { it.substringAfter('=') == expected }
                    if (!matches("auth-token", expectedToken) ||
                        (expectedDeviceId != null && !matches("unique_id", expectedDeviceId))) {
                        failImport()
                    } else {
                        val result = pendingImport
                        pendingImport = null
                        handler.removeCallbacks(importTimeout)
                        result?.success(null)
                    }
                }
            } catch (_: Exception) {
                failImport()
            }
        }
        writeNext()
    }

    private fun failImport() {
        val result = pendingImport
        pendingImport = null
        handler.removeCallbacks(importTimeout)
        result?.error("twitch_login", "Couldn't prepare Twitch's web session. Please try again.", null)
    }

    override fun getView(): View = view

    override fun dispose() {
        if (disposed) return
        disposed = true
        failImport()
        channel.setMethodCallHandler(null)
        session.navigationDelegate = null
        if (session.isOpen) {
            view.releaseSession()
            session.close()
        }
        if (activeView === this) activeView = null
    }

    companion object {
        private const val EXTENSION_ID = "twitch-login@flow.namecallfilter.com"
        private const val NATIVE_APP = "flow_twitch_login"
        private var runtime: GeckoRuntime? = null
        private var activeView: TwitchLoginView? = null
        private var cookiePort: WebExtension.Port? = null
        private var extensionFailed = false
        private var nextImportId = 0L

        private fun runtimeFor(context: Context): GeckoRuntime {
            runtime?.let { return it }
            return GeckoRuntime.create(context.applicationContext).also { engine ->
                runtime = engine
                engine.webExtensionController.ensureBuiltIn(
                    "resource://android/assets/twitch-login/", EXTENSION_ID,
                ).accept({ extension ->
                    if (extension == null) {
                        extensionFailed = true
                        activeView?.failImport()
                        activeView?.reportError("Couldn't prepare Twitch sign-in. Please restart Flow.")
                        return@accept
                    }
                    extension.setMessageDelegate(object : WebExtension.MessageDelegate {
                        override fun onConnect(port: WebExtension.Port) {
                            if (port.sender.webExtension.id != EXTENSION_ID || port.name != NATIVE_APP ||
                                port.sender.environmentType != WebExtension.MessageSender.ENV_TYPE_EXTENSION ||
                                port.sender.session != null
                            ) {
                                port.disconnect()
                                return
                            }
                            cookiePort?.disconnect()
                            cookiePort = port
                            port.setDelegate(object : WebExtension.PortDelegate {
                                override fun onPortMessage(message: Any, source: WebExtension.Port) {
                                    if (source === cookiePort && message is JSONObject && message.optString("type") == "cookies") {
                                        activeView?.receiveCookies(message)
                                    }
                                }

                                override fun onDisconnect(source: WebExtension.Port) {
                                    if (source === cookiePort) {
                                        cookiePort = null
                                        activeView?.failImport()
                                    }
                                }
                            })
                            activeView?.requestCookies()
                        }
                    }, NATIVE_APP)
                }, {
                    extensionFailed = true
                    activeView?.failImport()
                    activeView?.reportError("Couldn't prepare Twitch sign-in. Please restart Flow.")
                })
            }
        }
    }
}

internal fun isTwitchLoginCallback(url: String, redirect: String?): Boolean = try {
    require(!redirect.isNullOrBlank())
    val actual = URI(url)
    val expected = URI(redirect.trim())
    require(actual.isAbsolute && actual.host != null && expected.isAbsolute && expected.host != null)
    fun host(uri: URI) = uri.host?.lowercase()?.let { if (it == "www.twitch.tv") "twitch.tv" else it }
    fun path(uri: URI) = uri.path.orEmpty().ifEmpty { "/" }.let { if (it.length > 1) it.removeSuffix("/") else it }
    actual.scheme == expected.scheme && host(actual) == host(expected) && actual.port == expected.port &&
        actual.rawUserInfo == null && path(actual) == path(expected) &&
        listOf(actual.rawQuery, actual.rawFragment).filterNotNull().any { parameters ->
            parameters.split('&').any {
                URLDecoder.decode(it.substringBefore('='), "UTF-8") in listOf("access_token", "error")
            }
        }
} catch (_: Exception) { false }

internal fun twitchCookieForWebView(cookie: JSONObject): Pair<String, String> {
    val domain = cookie.getString("domain").lowercase()
    val host = domain.removePrefix(".")
    val name = cookie.getString("name")
    val value = cookie.getString("value")
    val path = cookie.getString("path")
    require(host == "twitch.tv" || host.endsWith(".twitch.tv"))
    require(host.matches(Regex("[a-z0-9.-]+")) && name.matches(Regex("[!#$%&'*+.^_`|~0-9A-Za-z-]+")))
    require(path.startsWith('/') && listOf(value, path).none { text -> text.any { it == ';' || it == '\r' || it == '\n' } })
    require(!cookie.has("partitionKey") || cookie.isNull("partitionKey"))
    val header = buildString {
        append("$name=$value; Path=$path")
        if (!cookie.getBoolean("hostOnly")) append("; Domain=$domain")
        if (cookie.getBoolean("secure")) append("; Secure")
        if (cookie.getBoolean("httpOnly")) append("; HttpOnly")
        if (!cookie.getBoolean("session")) {
            val expires = cookie.getDouble("expirationDate")
            require(expires.isFinite() && expires > 0)
            val format = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", Locale.US)
            format.timeZone = TimeZone.getTimeZone("GMT")
            append("; Expires=${format.format(Date((expires * 1000).toLong()))}")
        }
        when (cookie.getString("sameSite")) {
            "no_restriction" -> append("; SameSite=None")
            "lax" -> append("; SameSite=Lax")
            "strict" -> append("; SameSite=Strict")
            "unspecified" -> Unit
            else -> error("Unsupported cookie attributes")
        }
    }
    return URI("https", null, host, -1, path, null, null).toASCIIString() to header
}
