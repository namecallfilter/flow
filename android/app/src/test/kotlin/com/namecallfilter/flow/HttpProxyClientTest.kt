package com.namecallfilter.flow

import okhttp3.Credentials
import okhttp3.Request
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ServerSocket
import java.net.URI
import kotlin.concurrent.thread

class HttpProxyClientTest {
    @Test
    fun parsesOnlyHttpProxyUrls() {
        val config = parseHttpProxy("http://user:pass@proxy.example:8080")!!
        val address = config.proxy.address() as InetSocketAddress

        assertEquals("proxy.example", address.hostString)
        assertEquals(8080, address.port)
        assertEquals("user", config.username)
        assertEquals("pass", config.password)
        assertNull(parseHttpProxy("https://proxy.example:8080"))
        assertNull(parseHttpProxy("http://proxy.example:8080/path"))
        assertNull(parseHttpProxy("http://:pass@proxy.example:8080"))
        assertNull(parseHttpProxy("http://proxy.example:99999"))
    }

    @Test
    fun skipsProxyClientWhenAllUrlsAreInvalid() {
        assertNull(
            buildHttpProxyClient(
                listOf("https://proxy.example:8080", "not a proxy", "http://proxy.example/path"),
            ),
        )
    }

    @Test
    fun preservesMainAndFallbackOrder() {
        val proxies = listOf(
            parseHttpProxy("http://main.example:8080")!!.proxy,
            parseHttpProxy("http://fallback.example:3128")!!.proxy,
        )

        val selector = OrderedHttpProxySelector(proxies)
        val uri = URI("https://video-weaver.sfo05.hls.ttvnw.net/v1/playlist/index.m3u8")

        assertEquals(proxies + Proxy.NO_PROXY, selector.select(uri))
        selector.markFailed(proxies.first())
        assertEquals(listOf(proxies.last(), Proxy.NO_PROXY), selector.select(uri))
        selector.markFailed(proxies.last())
        assertEquals(listOf(Proxy.NO_PROXY), selector.select(uri))
        assertEquals(proxies + Proxy.NO_PROXY, selector.select(uri))
    }

    @Test
    fun proxiesRedirectedManifestHosts() {
        val proxy = parseHttpProxy("http://proxy.example:8080")!!.proxy
        val selector = OrderedHttpProxySelector(listOf(proxy))

        assertEquals(
            listOf(proxy, Proxy.NO_PROXY),
            selector.select(URI("https://redirected-manifest.example/stream")),
        )
    }

    @Test
    fun authenticatesHttpProxy() {
        ServerSocket(0).use { server ->
            server.soTimeout = 5_000
            val requests = mutableListOf<List<String>>()
            val worker = thread {
                var authenticated = false
                while (!authenticated && requests.size < 2) {
                    server.accept().use { socket ->
                        val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
                        val lines = buildList {
                            while (true) {
                                val line = reader.readLine() ?: break
                                if (line.isEmpty()) break
                                add(line)
                            }
                        }
                        requests.add(lines)
                        authenticated = lines.any {
                            it.equals(
                                "Proxy-Authorization: ${Credentials.basic("user", "pass")}",
                                ignoreCase = true,
                            )
                        }
                        val response = if (authenticated) {
                            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
                        } else {
                            "HTTP/1.1 407 Proxy Authentication Required\r\n" +
                                "Proxy-Authenticate: Basic realm=proxy\r\n" +
                                "Content-Length: 0\r\nConnection: close\r\n\r\n"
                        }
                        socket.getOutputStream().write(response.toByteArray())
                    }
                }
            }

            val client = requireNotNull(
                buildHttpProxyClient(
                    listOf("http://user:pass@127.0.0.1:${server.localPort}"),
                ),
            )
            client.newCall(
                Request.Builder()
                    .url("http://video-weaver.sfo05.hls.ttvnw.net/v1/playlist/index.m3u8")
                    .build(),
            ).execute().use { response ->
                assertEquals(200, response.code)
                assertEquals("OK", response.body?.string())
            }
            worker.join(6_000)

            assertEquals(2, requests.size)
        }
    }

    @Test
    fun authenticatesHttpsProxyTunnel() {
        ServerSocket(0).use { server ->
            server.soTimeout = 5_000
            val requests = mutableListOf<List<String>>()
            val worker = thread {
                while (requests.size < 2) {
                    server.accept().use { socket ->
                        val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
                        val lines = buildList {
                            while (true) {
                                val line = reader.readLine() ?: break
                                if (line.isEmpty()) break
                                add(line)
                            }
                        }
                        requests.add(lines)
                        val authenticated = lines.any {
                            it.equals(
                                "Proxy-Authorization: ${Credentials.basic("user", "pass")}",
                                ignoreCase = true,
                            )
                        }
                        val response = if (authenticated) {
                            "HTTP/1.1 200 Connection Established\r\n\r\n"
                        } else {
                            "HTTP/1.1 407 Proxy Authentication Required\r\n" +
                                "Proxy-Authenticate: Basic realm=proxy\r\n" +
                                "Content-Length: 0\r\nConnection: close\r\n\r\n"
                        }
                        socket.getOutputStream().write(response.toByteArray())
                        if (authenticated) {
                            return@thread
                        }
                    }
                }
            }

            val client = requireNotNull(
                buildHttpProxyClient(
                    listOf("http://user:pass@127.0.0.1:${server.localPort}"),
                ),
            )
            val result = runCatching {
                client.newCall(
                    Request.Builder()
                        .url("https://video-weaver.sfo05.hls.ttvnw.net/v1/playlist/index.m3u8")
                        .build(),
                ).execute().close()
            }
            worker.join(6_000)

            assertTrue(result.isFailure)
            assertTrue(requests.last().first().startsWith("CONNECT "))
            assertTrue(
                requests.last().any {
                    it.equals(
                        "Proxy-Authorization: ${Credentials.basic("user", "pass")}",
                        ignoreCase = true,
                    )
                },
            )
        }
    }
}
