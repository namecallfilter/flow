package com.namecallfilter.flow

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import org.mozilla.geckoview.GeckoResult
import org.mozilla.geckoview.GeckoSession
import org.mozilla.geckoview.GeckoView
import org.mozilla.geckoview.PanZoomController
import org.mozilla.geckoview.ScreenLength
import org.mozilla.geckoview.WebRequestError

/** Observes the authenticated Twitch page's own requests without changing them. */
class TwitchIntegritySession(private val activity: Activity) {
    fun start(expectedAuthorization: String, callback: (Map<String, String>?) -> Unit) {
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            if (activity.isFinishing || activity.isDestroyed || expectedAuthorization.isBlank()) {
                callback(null)
                return@post
            }
            var completed = false
            var session: GeckoSession? = null
            var view: GeckoView? = null
            var observed: Map<String, String>? = null
            var stopObserving: () -> Unit = {}
            var pageFinished = false
            var scrollsRemaining = 5

            fun cleanup() {
                handler.removeCallbacksAndMessages(null)
                stopObserving()
                session?.navigationDelegate = null
                session?.progressDelegate = null
                if (session?.isOpen == true) session?.stop()
                view?.releaseSession()
                if (session?.isOpen == true) session?.close()
                (view?.parent as? ViewGroup)?.removeView(view)
            }

            fun finish(context: Map<String, String>?) {
                if (completed) return
                completed = true
                cleanup()
                callback(context)
            }

            fun scrollWhenReady() {
                if (completed || !pageFinished || observed == null || scrollsRemaining == 0) return
                scrollsRemaining--
                session?.panZoomController?.scrollBy(
                    ScreenLength.zero(), ScreenLength.fromVisualViewportHeight(1.0), PanZoomController.SCROLL_BEHAVIOR_AUTO,
                )
            }

            handler.postDelayed({ finish(observed) }, 20_000)
            try {
                stopObserving = TwitchLoginView.observeRequests(activity, expectedAuthorization) { message ->
                    if (completed) return@observeRequests
                    if (activity.isFinishing || activity.isDestroyed) {
                        finish(null)
                        return@observeRequests
                    }
                    try { when (message.optString("type")) {
                        "contextReady" -> if (!message.optBoolean("matches")) {
                            // Older installations may only have the original WebView session.
                            completed = true
                            cleanup()
                            startWebView(expectedAuthorization, callback)
                        } else if (session == null) {
                            val page = GeckoSession()
                            session = page
                            page.navigationDelegate = object : GeckoSession.NavigationDelegate {
                                override fun onLoadError(session: GeckoSession, uri: String?, error: WebRequestError): GeckoResult<String>? {
                                    finish(null)
                                    return null
                                }
                            }
                            page.progressDelegate = object : GeckoSession.ProgressDelegate {
                                override fun onPageStop(session: GeckoSession, success: Boolean) {
                                    if (!success) finish(null) else {
                                        pageFinished = true
                                        scrollWhenReady()
                                    }
                                }
                            }
                            val browser = GeckoView(activity)
                            view = browser
                            browser.setViewBackend(GeckoView.BACKEND_TEXTURE_VIEW)
                            browser.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
                            browser.isFocusable = false
                            activity.findViewById<ViewGroup>(android.R.id.content).addView(
                                browser, 0, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
                            )
                            page.open(TwitchLoginView.runtimeFor(activity))
                            browser.setSession(page)
                            page.loadUri("https://www.twitch.tv/directory/all")
                        }
                        "requestContext" -> {
                            val headers = message.optJSONObject("headers") ?: return@observeRequests
                            observed = headers.keys().asSequence().associateWith { headers.getString(it) }
                            if (observed!!.containsKey("Client-Integrity")) finish(observed) else scrollWhenReady()
                        }
                        "contextFailed" -> finish(null)
                    } } catch (_: Exception) { finish(null) }
                }
                if (completed) stopObserving()
            } catch (_: Exception) {
                finish(null)
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun startWebView(expectedAuthorization: String, callback: (Map<String, String>?) -> Unit) {
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            if (activity.isFinishing || activity.isDestroyed || expectedAuthorization.isBlank()) {
                callback(null)
                return@post
            }
            val parent = activity.findViewById<ViewGroup>(android.R.id.content)
            val webView = WebView(activity)
            var completed = false
            var observed: Map<String, String>? = null
            var pageFinished = false
            var scrollPosted = false
            var lastScrolledHeight = 0
            var scrollsRemaining = 5
            var scrollListener: ViewTreeObserver.OnPreDrawListener? = null

            fun finish(context: Map<String, String>?) {
                if (completed) return
                completed = true
                handler.removeCallbacksAndMessages(null)
                scrollListener?.let { webView.viewTreeObserver.removeOnPreDrawListener(it) }
                webView.stopLoading()
                webView.webViewClient = WebViewClient()
                (webView.parent as? ViewGroup)?.removeView(webView)
                webView.destroy()
                callback(context)
            }

            fun scrollWhenReady() {
                if (completed || scrollPosted || !pageFinished || observed == null || scrollsRemaining == 0) return
                val height = webView.contentHeight
                if (height <= lastScrolledHeight || !webView.canScrollVertically(1)) return
                scrollPosted = true
                handler.post {
                    scrollPosted = false
                    if (!completed) {
                        if (activity.isFinishing || activity.isDestroyed) {
                            finish(null)
                        } else if (webView.pageDown(true)) {
                            lastScrolledHeight = height
                            scrollsRemaining--
                        }
                    }
                }
            }

            webView.webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView,
                    request: WebResourceRequest,
                ): WebResourceResponse? {
                    val uri = request.url
                    if (uri.scheme != "https" || uri.host != "gql.twitch.tv" ||
                        uri.path != "/gql" || request.method != "POST"
                    ) return null
                    val headers = request.requestHeaders
                    fun header(name: String): String? = headers.entries
                        .firstOrNull { it.key.equals(name, ignoreCase = true) }
                        ?.value?.takeIf { it.isNotBlank() }

                    // Anonymous boot requests are normal; a different signed-in user is not.
                    val authorization = header("Authorization") ?: return null
                    if (authorization.trim() != expectedAuthorization.trim()) {
                        handler.post { finish(null) }
                        return null
                    }
                    val context = mutableMapOf<String, String>()
                    for (name in listOf("Client-Id", "Client-Session-Id", "Client-Version")) {
                        context[name] = header(name) ?: return null
                    }
                    context["X-Device-ID"] = header("X-Device-ID") ?: header("Device-ID")
                        ?: return null
                    for (name in listOf("Client-Integrity", "User-Agent", "Origin", "Referer")) {
                        header(name)?.let { context[name] = it }
                    }
                    handler.post {
                        if (!completed) {
                            observed = context
                            if (context.containsKey("Client-Integrity")) {
                                finish(context)
                            } else {
                                scrollWhenReady()
                            }
                        }
                    }
                    return null
                }

                override fun onPageFinished(view: WebView, url: String) {
                    if (!completed) {
                        pageFinished = true
                        scrollWhenReady()
                    }
                }

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    if (request.isForMainFrame) {
                        finish(null)
                    }
                }
            }
            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            webView.isFocusable = false
            // Keep a normal viewport behind Flutter so the page can lay out its directory.
            parent.addView(
                webView,
                0,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            // Scroll as directory content is laid out, without fixed waits between pages.
            scrollListener = ViewTreeObserver.OnPreDrawListener {
                scrollWhenReady()
                true
            }.also { webView.viewTreeObserver.addOnPreDrawListener(it) }
            handler.postDelayed({ finish(observed) }, 20_000)
            webView.loadUrl("https://www.twitch.tv/directory/all")
        }
    }
}
