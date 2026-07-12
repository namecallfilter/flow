package com.namecallfilter.flow

import okhttp3.Call
import okhttp3.Credentials
import okhttp3.EventListener
import okhttp3.OkHttpClient
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ProxySelector
import java.net.SocketAddress
import java.net.URI

internal data class HttpProxyConfig(
    val proxy: Proxy,
    val username: String?,
    val password: String?,
)

internal fun buildHttpProxyClient(
    urls: List<String>,
    onConnect: (host: String, proxyType: Proxy.Type) -> Unit = { _, _ -> },
): OkHttpClient? {
    val configs = urls.mapNotNull(::parseHttpProxy)
    if (configs.isEmpty()) {
        return null
    }
    val proxySelector = OrderedHttpProxySelector(
        configs.map(HttpProxyConfig::proxy),
    )
    return OkHttpClient.Builder()
        .proxySelector(proxySelector)
        .eventListenerFactory {
            object : EventListener() {
                override fun connectStart(
                    call: Call,
                    inetSocketAddress: InetSocketAddress,
                    proxy: Proxy,
                ) {
                    onConnect(call.request().url.host, proxy.type())
                }
            }
        }
        .proxyAuthenticator { route, response ->
            if (response.request.header("Proxy-Authorization") != null) {
                proxySelector.markFailed(route?.proxy)
                return@proxyAuthenticator null
            }
            val address = route?.proxy?.address() as? InetSocketAddress
            val config = configs.firstOrNull {
                val proxyAddress = it.proxy.address() as InetSocketAddress
                proxyAddress.hostString.equals(address?.hostString, ignoreCase = true) &&
                    proxyAddress.port == address?.port
            }
            val username = config?.username
            if (username == null) {
                if (response.header("Proxy-Authenticate") != "OkHttp-Preemptive") {
                    proxySelector.markFailed(route?.proxy)
                }
                return@proxyAuthenticator null
            }
            response.request.newBuilder()
                .header("Proxy-Authorization", Credentials.basic(username, config.password.orEmpty()))
                .build()
        }
        .build()
}

internal fun parseHttpProxy(value: String): HttpProxyConfig? {
    val uri = runCatching { URI(value) }.getOrNull() ?: return null
    if (
        !uri.scheme.equals("http", ignoreCase = true) ||
        uri.host.isNullOrBlank() ||
        uri.port == 0 ||
        uri.port > 65535 ||
        (!uri.path.isNullOrEmpty() && uri.path != "/") ||
        uri.query != null ||
        uri.fragment != null
    ) {
        return null
    }
    val credentials = uri.userInfo?.split(':', limit = 2)
    if (credentials?.firstOrNull().isNullOrEmpty() && uri.userInfo != null) {
        return null
    }
    return HttpProxyConfig(
        proxy = Proxy(
            Proxy.Type.HTTP,
            InetSocketAddress.createUnresolved(uri.host, if (uri.port == -1) 80 else uri.port),
        ),
        username = credentials?.firstOrNull(),
        password = credentials?.getOrNull(1),
    )
}

internal class OrderedHttpProxySelector(
    private val proxies: List<Proxy>,
) : ProxySelector() {
    private val failed = mutableSetOf<Proxy>()

    @Synchronized
    override fun select(uri: URI?): List<Proxy> {
        if (!shouldProxyTwitchPlayback(uri)) {
            return listOf(Proxy.NO_PROXY)
        }
        val available = proxies.filterNot(failed::contains)
        if (available.isNotEmpty()) {
            return available + Proxy.NO_PROXY
        }
        failed.clear()
        return listOf(Proxy.NO_PROXY)
    }

    @Synchronized
    fun markFailed(proxy: Proxy?) {
        if (proxy != null) {
            failed.add(proxy)
        }
    }

    override fun connectFailed(uri: URI?, socketAddress: SocketAddress?, error: IOException?) {
        proxies.firstOrNull { it.address() == socketAddress }?.let(::markFailed)
    }
}

internal fun shouldProxyTwitchPlayback(uri: URI?): Boolean {
    val host = uri?.host?.lowercase() ?: return false
    return host == "usher.ttvnw.net" ||
        Regex("^[a-z0-9-]+\\.playlist\\.(?:live-video|ttvnw)\\.net$").matches(host) ||
            Regex("^video-weaver\\.[a-z0-9-]+\\.hls\\.ttvnw\\.net$").matches(host)
}
