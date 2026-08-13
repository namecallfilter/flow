package com.namecallfilter.flow.ui

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceError
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Login
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.namecallfilter.flow.data.TwitchAuthCallback
import com.namecallfilter.flow.data.TwitchAuthConnection
import com.namecallfilter.flow.data.TwitchAuthController
import com.namecallfilter.flow.ui.components.FlowTooltipAction
import com.namecallfilter.flow.ui.theme.FlowLayout
import com.namecallfilter.flow.ui.theme.FlowRadius
import com.namecallfilter.flow.ui.theme.FlowSpacing
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.net.URI
import kotlin.coroutines.resume

@Composable
internal fun TwitchLoginOfferScreen(
    statusMessage: String?,
    showCloseButton: Boolean,
    loginBusy: Boolean,
    continueBusy: Boolean,
    onLogin: () -> Unit,
    onContinue: () -> Unit,
) {
    val actionsBusy = loginBusy || continueBusy
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        val minimumContentHeight =
            (maxHeight - FlowSpacing.Xl - FlowSpacing.Xl).coerceAtLeast(0.dp)
        Box(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(FlowSpacing.Xl),
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .widthIn(max = 520.dp)
                    .fillMaxWidth()
                    .heightIn(min = minimumContentHeight),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                LoginOfferActions(
                    placeholder = true,
                    loginBusy = loginBusy,
                    actionsBusy = actionsBusy,
                    onLogin = onLogin,
                    onContinue = onContinue,
                    modifier = Modifier.navigationBarsPadding(),
                )
                LoginOfferWelcome(statusMessage)
                LoginOfferActions(
                    placeholder = false,
                    loginBusy = loginBusy,
                    actionsBusy = actionsBusy,
                    onLogin = onLogin,
                    onContinue = onContinue,
                    modifier = Modifier.navigationBarsPadding(),
                )
            }
        }
        if (showCloseButton) {
            FlowTooltipAction(
                label = "Close",
                onClick = onContinue,
                enabled = !actionsBusy,
                modifier = Modifier.size(FlowLayout.SearchFieldHeight),
                tooltipModifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = FlowSpacing.Sm, top = FlowSpacing.Md)
                    .statusBarsPadding(),
            ) {
                Icon(Icons.Default.Close, contentDescription = null)
            }
        }
    }
}

@Composable
private fun LoginOfferWelcome(statusMessage: String?) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "Welcome to Flow",
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onBackground,
            fontWeight = FontWeight.Black,
            style = MaterialTheme.typography.headlineMedium,
        )
        Spacer(Modifier.height(FlowSpacing.Sm))
        Text(
            "Log in with Twitch to see the channels you follow.",
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
            style = MaterialTheme.typography.bodyLarge.copy(lineHeight = 23.2.sp),
        )
        if (statusMessage != null) {
            Spacer(Modifier.height(FlowSpacing.Lg))
            Text(
                text = statusMessage,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.72f),
                        RoundedCornerShape(FlowRadius.Medium),
                    )
                    .padding(FlowSpacing.Md),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onErrorContainer,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun LoginOfferActions(
    placeholder: Boolean,
    loginBusy: Boolean,
    actionsBusy: Boolean,
    onLogin: () -> Unit,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val placeholderModifier = if (placeholder) {
        Modifier.alpha(0f).clearAndSetSemantics { }
    } else {
        Modifier
    }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .then(placeholderModifier),
    ) {
        Button(
            onClick = onLogin,
            enabled = !placeholder && !actionsBusy,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (loginBusy) {
                CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
            } else {
                Icon(
                    Icons.AutoMirrored.Filled.Login,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
            }
            Spacer(Modifier.width(FlowSpacing.Sm))
            Text("Log in with Twitch")
        }
        Spacer(Modifier.height(FlowSpacing.Sm))
        TextButton(
            onClick = onContinue,
            enabled = !placeholder && !actionsBusy,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Continue without an account")
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
internal fun TwitchLoginWebView(
    authController: TwitchAuthController,
    onConnected: (TwitchAuthConnection) -> Unit,
    onCancel: () -> Unit,
    onError: (String) -> Unit,
) {
    val activity = checkNotNull(LocalActivity.current) {
        "Twitch login requires an Activity context for Android Autofill"
    }
    val scope = rememberCoroutineScope()
    val cleanupScope = remember { CoroutineScope(SupervisorJob() + Dispatchers.IO) }
    var authorizationUrl by remember { mutableStateOf<String?>(null) }
    var authState by remember { mutableStateOf<String?>(null) }
    var completing by remember { mutableStateOf(false) }
    var webView by remember { mutableStateOf<WebView?>(null) }

    fun completeFromUrl(rawUrl: String) {
        if (completing) return
        val uri = runCatching { URI(rawUrl) }.getOrNull() ?: return
        if (!authController.config.isRedirectUri(uri) || !TwitchAuthCallback.hasOAuthResponse(uri)) return
        completing = true
        scope.launch {
            runCatching { authController.completeAuth(uri) }
                .onSuccess(onConnected)
                .onFailure {
                    completing = false
                    onError(it.toString())
                }
        }
    }

    LaunchedEffect(authController) {
        runCatching { authController.createAuthorizationUri() }
            .onSuccess { uri ->
                authorizationUrl = uri.toString()
                authState = Uri.parse(uri.toString()).getQueryParameter("state")
            }
            .onFailure {
                onError(it.message ?: it.toString())
                onCancel()
            }
    }
    LaunchedEffect(authorizationUrl, webView) {
        val url = authorizationUrl ?: return@LaunchedEffect
        val view = webView ?: return@LaunchedEffect
        view.awaitNonZeroLayout()
        if (webView === view && authorizationUrl == url) view.loadUrl(url)
    }
    DisposableEffect(authController) {
        onDispose {
            webView?.stopLoading()
            webView?.destroy()
            val state = authState
            if (state == null) {
                cleanupScope.cancel()
            } else {
                cleanupScope.launch {
                    runCatching { authController.cancelPendingAuth(state) }
                    cleanupScope.cancel()
                }
            }
        }
    }
    Column(Modifier.fillMaxSize()) {
        Surface(
            color = MaterialTheme.colorScheme.background,
        ) {
            androidx.compose.foundation.layout.Row(
                Modifier.fillMaxWidth().statusBarsPadding().height(56.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier.width(56.dp).fillMaxHeight(),
                    contentAlignment = Alignment.Center,
                ) {
                    FlowTooltipAction(
                        label = "Back",
                        onClick = onCancel,
                        modifier = Modifier.size(48.dp),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                }
                Text(
                    "Connect with Twitch",
                    color = MaterialTheme.colorScheme.onBackground,
                    style = MaterialTheme.typography.titleLarge,
                )
            }
        }
        Box(Modifier.fillMaxSize()) {
            AndroidView(
                modifier = Modifier.fillMaxSize(),
                factory = {
                    WebView(activity).apply {
                        webView = this
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_YES
                        }
                        settings.javaScriptEnabled = true
                        settings.domStorageEnabled = true
                        settings.javaScriptCanOpenWindowsAutomatically = true
                        settings.loadWithOverviewMode = true
                        settings.useWideViewPort = false
                        settings.displayZoomControls = false
                        settings.builtInZoomControls = true
                        settings.userAgentString =
                            "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 " +
                                "(KHTML, like Gecko) Chrome/149.0.0.0 Mobile Safari/537.36"
                        CookieManager.getInstance().setAcceptCookie(true)
                        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                        webChromeClient = WebChromeClient()
                        webViewClient = object : WebViewClient() {
                            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                                completeFromUrl(request.url.toString())
                                return false
                            }

                            override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                                completeFromUrl(url)
                            }

                            override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) {
                                completeFromUrl(url)
                            }

                            override fun onReceivedError(
                                view: WebView,
                                request: WebResourceRequest,
                                error: WebResourceError,
                            ) {
                                val safeUrl = request.url.buildUpon().clearQuery().fragment(null).build()
                                Log.w(
                                    "FlowTwitchAuth",
                                    "WebView error ${error.errorCode} mainFrame=${request.isForMainFrame} " +
                                        "url=$safeUrl: ${error.description}",
                                )
                            }

                            override fun onPageFinished(view: WebView, url: String) {
                                completeFromUrl(url)
                                view.evaluateJavascript(
                                    "(function(){" +
                                        "function patchViewport(){" +
                                        "var r=document.getElementById('root');" +
                                        "if(!r)return;" +
                                        "if(!window.__flowNeedsViewportPatch&&r.getBoundingClientRect().height>1)return;" +
                                        "window.__flowNeedsViewportPatch=true;" +
                                        "var h=window.innerHeight+'px';" +
                                        "[document.documentElement,document.body,r].forEach(function(e){" +
                                        "e.style.setProperty('height',h,'important');" +
                                        "e.style.setProperty('min-height',h,'important');});}" +
                                        "patchViewport();" +
                                        "if(window.__flowNeedsViewportPatch&&!window.__flowViewportListener){" +
                                        "window.__flowViewportListener=true;window.addEventListener('resize',patchViewport);}" +
                                        "function extendAuthBackground(){var e=document.querySelector('form');if(!e)return false;" +
                                        "while(e&&e!==document.body){var b=getComputedStyle(e).backgroundColor;" +
                                        "if(b&&b!=='transparent'&&b!=='rgba(0, 0, 0, 0)'&&b!=='rgba(0,0,0,0)'){" +
                                        "[document.documentElement,document.body,document.getElementById('root')].forEach(function(n){" +
                                        "if(n)n.style.setProperty('background-color',b,'important');});return true;}" +
                                        "e=e.parentElement;}return false;}" +
                                        "if(!extendAuthBackground()){var bo=new MutationObserver(function(){" +
                                        "if(extendAuthBackground())bo.disconnect();});" +
                                        "bo.observe(document.documentElement,{childList:true,subtree:true});}" +
                                        "function patch(){var e=document.querySelector('.fAVISI,[data-a-target=consent-banner]');" +
                                        "if(!e)return false;e.style.maxHeight='20vh';e.style.overflow='auto';return true;}" +
                                        "if(patch())return;var o=new MutationObserver(function(){if(patch())o.disconnect();});" +
                                        "o.observe(document.body,{childList:true,subtree:true});" +
                                        "})();",
                                ) {
                                    view.requestLayout()
                                    view.invalidate()
                                    view.post {
                                        view.evaluateJavascript("window.dispatchEvent(new Event('resize'));", null)
                                    }
                                }
                            }
                        }
                    }
                },
            )
        }
    }
}

private suspend fun WebView.awaitNonZeroLayout() {
    if (isLaidOut && width > 0 && height > 0) return
    suspendCancellableCoroutine { continuation ->
        lateinit var listener: View.OnLayoutChangeListener
        listener = View.OnLayoutChangeListener { view, _, _, _, _, _, _, _, _ ->
            if (view.width > 0 && view.height > 0) {
                removeOnLayoutChangeListener(listener)
                if (continuation.isActive) continuation.resume(Unit)
            }
        }
        addOnLayoutChangeListener(listener)
        continuation.invokeOnCancellation { post { removeOnLayoutChangeListener(listener) } }
        if (isLaidOut && width > 0 && height > 0) {
            removeOnLayoutChangeListener(listener)
            if (continuation.isActive) continuation.resume(Unit)
        }
    }
}
