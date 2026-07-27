package com.namecallfilter.flow

import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class TwitchPlaybackCoordinatorTest {
    @Test
    fun initialMasterUsesOrderedProxyChainWithDirectFallback() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 2)
        val requests = mutableListOf<TwitchManifestRoute>()

        val result = session.resolve(ROOT) { route, uri ->
            requests += route
            when (route) {
                is TwitchManifestRoute.Proxy -> throw IOException("proxy failed")
                TwitchManifestRoute.Direct -> payload(directMaster(), uri)
            }
        }

        assertEquals(directMaster(), result.text)
        assertEquals(
            listOf(
                TwitchManifestRoute.Proxy(0),
                TwitchManifestRoute.Proxy(1),
                TwitchManifestRoute.Direct,
            ),
            requests,
        )
    }

    @Test
    fun successfulProxyResponseDoesNotHopToAnotherEndpoint() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 2)
        val routes = mutableListOf<TwitchManifestRoute>()

        session.resolve(ROOT) { route, uri ->
            routes += route
            payload(directMaster(), uri)
        }

        assertEquals(listOf(TwitchManifestRoute.Proxy(0)), routes)
    }

    @Test
    fun firstTrustedPlaylistUsesProxyChainAndLaterPollsAreDirect() {
        val session = sessionWithMaster()
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            payload(cleanPlaylist(), uri)
        }
        session.resolve("$DIRECT_VARIANT&_HLS_msn=101") { route, uri ->
            requests += route to uri
            payload(cleanPlaylist(101), uri)
        }

        assertEquals(
            listOf(
                TwitchManifestRoute.Proxy(0) to DIRECT_VARIANT,
                TwitchManifestRoute.Direct to "$DIRECT_VARIANT&_HLS_msn=101",
            ),
            requests,
        )
    }

    @Test
    fun firstRequestIsTrackedIndependentlyForEachRendition() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri ->
            payload(twoVariantMaster(DIRECT_VARIANT, DIRECT_SECOND_VARIANT), uri)
        }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            payload(cleanPlaylist(), uri)
        }
        session.resolve(DIRECT_SECOND_VARIANT) { route, uri ->
            requests += route to uri
            payload(cleanPlaylist(), uri)
        }

        assertEquals(
            listOf(
                TwitchManifestRoute.Proxy(0) to DIRECT_VARIANT,
                TwitchManifestRoute.Proxy(0) to DIRECT_SECOND_VARIANT,
            ),
            requests,
        )
    }

    @Test
    fun unknownManifestIsAlwaysDirect() {
        val session = sessionWithMaster()
        val requests = mutableListOf<TwitchManifestRoute>()

        val result = session.resolve(UNKNOWN_VARIANT) { route, uri ->
            requests += route
            payload(adPlaylist(), uri)
        }

        assertTrue(containsTwitchStitchedAd(result.text))
        assertEquals(listOf(TwitchManifestRoute.Direct), requests)
    }

    @Test
    fun laterDirectFailureDoesNotActivateProxying() {
        val session = sessionWithMaster()
        session.resolve(DIRECT_VARIANT) { _, uri -> payload(cleanPlaylist(), uri) }
        val failure = IOException("direct failed")
        val requests = mutableListOf<TwitchManifestRoute>()

        val thrown = assertThrows(IOException::class.java) {
            session.resolve(DIRECT_VARIANT) { route, _ ->
                requests += route
                throw failure
            }
        }

        assertSame(failure, thrown)
        assertEquals(listOf(TwitchManifestRoute.Direct), requests)
    }

    @Test
    fun stitchedAdDetectionMatchesUpstreamSubstringSemantics() {
        assertTrue(containsTwitchStitchedAd(cleanPlaylist() + "\n#EXT-X-DATERANGE:ID=\"stitched-ad-1\""))
        assertTrue(
            containsTwitchStitchedAd(
                cleanPlaylist() + "\n#EXT-X-DATERANGE:CLASS=\"TWITCH-STITCHED-AD\"",
            ),
        )
        assertFalse(containsTwitchStitchedAd(cleanPlaylist()))
    }

    @Test
    fun unusableAdResponseDoesNotRefreshTheAssignment() {
        var refreshes = 0
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = {
                refreshes++
                FRESH_ROOT
            },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }

        assertThrows(IOException::class.java) {
            session.resolve(DIRECT_VARIANT) { _, uri ->
                payload(emptyMediaPlaylist() + "\n# stitched-ad", uri)
            }
        }

        assertEquals(0, refreshes)
    }

    @Test
    fun proxiedAdGetsFreshDirectAssignment() {
        var refreshes = 0
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = {
                refreshes++
                FRESH_ROOT
            },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT ->
                    payload(master(DIRECT_REPLACEMENT, "1280x720", "720p60"), uri)
                route == TwitchManifestRoute.Direct && uri == DIRECT_REPLACEMENT ->
                    payload(cleanPlaylist(200), uri)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(1, refreshes)
        assertEquals(DIRECT_REPLACEMENT, result.finalUri)
        assertEquals(
            listOf(
                TwitchManifestRoute.Proxy(0) to DIRECT_VARIANT,
                TwitchManifestRoute.Direct to FRESH_ROOT,
                TwitchManifestRoute.Direct to DIRECT_REPLACEMENT,
            ),
            requests,
        )
    }

    @Test
    fun directAdGetsFreshProxiedAssignment() {
        var refreshes = 0
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = {
                refreshes++
                FRESH_ROOT
            },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        session.resolve(DIRECT_VARIANT) { _, uri -> payload(cleanPlaylist(), uri) }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            when {
                route == TwitchManifestRoute.Proxy(0) && uri == FRESH_ROOT ->
                    payload(proxyMaster(), uri)
                route == TwitchManifestRoute.Proxy(0) && uri == PROXY_REPLACEMENT ->
                    payload(cleanPlaylist(200), uri)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(1, refreshes)
        assertEquals(PROXY_REPLACEMENT, result.finalUri)
        assertEquals(
            listOf(
                TwitchManifestRoute.Direct to DIRECT_VARIANT,
                TwitchManifestRoute.Proxy(0) to FRESH_ROOT,
                TwitchManifestRoute.Proxy(0) to PROXY_REPLACEMENT,
            ),
            requests,
        )
    }

    @Test
    fun replacementUsesFreshRootInsteadOfOriginalToken() {
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = { FRESH_ROOT },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        val roots = mutableListOf<String>()

        session.resolve(DIRECT_VARIANT) { route, uri ->
            if (uri.contains("usher.ttvnw.net")) {
                roots += uri
            }
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT ->
                    payload(master(DIRECT_REPLACEMENT, "1280x720", "720p60"), uri)
                route == TwitchManifestRoute.Direct && uri == DIRECT_REPLACEMENT ->
                    payload(cleanPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(listOf(FRESH_ROOT), roots)
    }

    @Test
    fun replacementFailureReturnsTheUsableAdResponse() {
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = { throw IOException("token failed") },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }

        val result = session.resolve(DIRECT_VARIANT) { _, uri -> payload(adPlaylist(), uri) }

        assertTrue(containsTwitchStitchedAd(result.text))
        assertEquals(DIRECT_VARIANT, result.finalUri)
    }

    @Test
    fun missingReplacementQualityDoesNotSelectAnArbitraryRendition() {
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = { FRESH_ROOT },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        val requests = mutableListOf<String>()

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += uri
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT ->
                    payload(master(DIRECT_REPLACEMENT, "640x360", "360p30"), uri)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertTrue(containsTwitchStitchedAd(result.text))
        assertFalse(requests.contains(DIRECT_REPLACEMENT))
    }

    @Test
    fun replacementMappingsKeepLaterPollsDirectAndPreserveLlHlsCursors() {
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = { FRESH_ROOT },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        session.resolve(DIRECT_VARIANT) { route, uri ->
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT ->
                    payload(master(DIRECT_REPLACEMENT, "1280x720", "720p60"), uri)
                route == TwitchManifestRoute.Direct && uri == DIRECT_REPLACEMENT ->
                    payload(cleanPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        val result = session.resolve("$DIRECT_VARIANT&_HLS_msn=120&_HLS_skip=YES") { route, uri ->
            requests += route to uri
            payload(cleanPlaylist(120), uri)
        }

        val expected = "$DIRECT_REPLACEMENT&_HLS_msn=120&_HLS_skip=YES"
        assertEquals(expected, result.finalUri)
        assertEquals(listOf(TwitchManifestRoute.Direct to expected), requests)
    }

    @Test
    fun directReplacementUriIsRecognizedForLaterAdDetection() {
        var refreshes = 0
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = {
                refreshes++
                if (refreshes == 1) FRESH_ROOT else SECOND_FRESH_ROOT
            },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        session.resolve(DIRECT_VARIANT) { route, uri ->
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT ->
                    payload(master(DIRECT_REPLACEMENT, "1280x720", "720p60"), uri)
                route == TwitchManifestRoute.Direct && uri == DIRECT_REPLACEMENT ->
                    payload(cleanPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }
        repeat(16) {
            session.resolve(DIRECT_REPLACEMENT) { _, uri -> payload(cleanPlaylist(), uri) }
        }

        session.resolve(DIRECT_REPLACEMENT) { route, uri ->
            when {
                route == TwitchManifestRoute.Proxy(0) && uri == SECOND_FRESH_ROOT ->
                    payload(proxyMaster(), uri)
                route == TwitchManifestRoute.Proxy(0) && uri == PROXY_REPLACEMENT ->
                    payload(cleanPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(2, refreshes)
    }

    @Test
    fun bothAdAssignmentsPreferTheProxiedResponse() {
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = { FRESH_ROOT },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT ->
                    payload(master(DIRECT_REPLACEMENT, "1280x720", "720p60"), uri)
                route == TwitchManifestRoute.Direct && uri == DIRECT_REPLACEMENT ->
                    payload(adPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(DIRECT_VARIANT, result.finalUri)
    }

    @Test
    fun proxiedAdReplacementIsRetainedWhenBothAssignmentsContainAds() {
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = { FRESH_ROOT },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        session.resolve(DIRECT_VARIANT) { _, uri -> payload(cleanPlaylist(), uri) }

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            when {
                route == TwitchManifestRoute.Proxy(0) && uri == FRESH_ROOT ->
                    payload(proxyMaster(), uri)
                route == TwitchManifestRoute.Proxy(0) && uri == PROXY_REPLACEMENT ->
                    payload(adPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()
        session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            payload(adPlaylist(), uri)
        }

        assertEquals(PROXY_REPLACEMENT, result.finalUri)
        assertEquals(
            listOf(TwitchManifestRoute.Direct to PROXY_REPLACEMENT),
            requests,
        )
    }

    @Test
    fun adReplacementCooldownPreventsRepeatedTokenRefreshes() {
        var refreshes = 0
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = {
                refreshes++
                FRESH_ROOT
            },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        session.resolve(DIRECT_VARIANT) { route, uri ->
            if (uri == FRESH_ROOT) {
                throw IOException("replacement failed")
            }
            payload(adPlaylist(), uri)
        }
        session.resolve(DIRECT_VARIANT) { _, uri -> payload(adPlaylist(), uri) }
        assertEquals(1, refreshes)

        repeat(16) {
            session.resolve(DIRECT_VARIANT) { _, uri -> payload(cleanPlaylist(), uri) }
        }
        session.resolve(DIRECT_VARIANT) { route, uri ->
            if (uri == FRESH_ROOT) {
                throw IOException("replacement failed")
            }
            payload(adPlaylist(), uri)
        }

        assertEquals(2, refreshes)
    }

    @Test
    fun adOnDirectReplacementRestoresTheOriginalAssignmentDuringCooldown() {
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = { FRESH_ROOT },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        session.resolve(DIRECT_VARIANT) { route, uri ->
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT ->
                    payload(master(DIRECT_REPLACEMENT, "1280x720", "720p60"), uri)
                route == TwitchManifestRoute.Direct && uri == DIRECT_REPLACEMENT ->
                    payload(cleanPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            payload(if (uri == DIRECT_REPLACEMENT) adPlaylist() else cleanPlaylist(), uri)
        }

        assertEquals(DIRECT_VARIANT, result.finalUri)
        assertEquals(
            listOf(
                TwitchManifestRoute.Direct to DIRECT_REPLACEMENT,
                TwitchManifestRoute.Direct to DIRECT_VARIANT,
            ),
            requests,
        )
    }

    @Test
    fun adCooldownIsSharedAcrossRenditions() {
        var refreshes = 0
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = {
                refreshes++
                FRESH_ROOT
            },
        )
        session.resolve(ROOT) { _, uri ->
            payload(twoVariantMaster(DIRECT_VARIANT, DIRECT_SECOND_VARIANT), uri)
        }
        val fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload = { _, uri ->
            if (uri == FRESH_ROOT) {
                throw IOException("replacement failed")
            }
            payload(adPlaylist(), uri)
        }

        session.resolve(DIRECT_VARIANT, fetch)
        session.resolve(DIRECT_SECOND_VARIANT, fetch)

        assertEquals(1, refreshes)
    }

    @Test
    fun concurrentAdLoadsReuseTheReplacementAssignment() {
        val refreshes = AtomicInteger()
        val session = TwitchPlaybackSession(
            ROOT,
            proxyCount = 1,
            freshRootUsherUri = {
                refreshes.incrementAndGet()
                FRESH_ROOT
            },
        )
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        val replacementStarted = CountDownLatch(1)
        val releaseReplacement = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(2)
        val fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload = { route, uri ->
            when {
                route == TwitchManifestRoute.Direct && uri == FRESH_ROOT -> {
                    replacementStarted.countDown()
                    assertTrue(releaseReplacement.await(5, TimeUnit.SECONDS))
                    payload(master(DIRECT_REPLACEMENT, "1280x720", "720p60"), uri)
                }
                route == TwitchManifestRoute.Direct && uri == DIRECT_REPLACEMENT ->
                    payload(cleanPlaylist(), uri)
                else -> payload(adPlaylist(), uri)
            }
        }

        try {
            val first = executor.submit<TwitchManifestPayload> {
                session.resolve(DIRECT_VARIANT, fetch)
            }
            assertTrue(replacementStarted.await(5, TimeUnit.SECONDS))
            val second = executor.submit<TwitchManifestPayload> {
                session.resolve(DIRECT_VARIANT, fetch)
            }
            releaseReplacement.countDown()

            assertEquals(DIRECT_REPLACEMENT, first.get(5, TimeUnit.SECONDS).finalUri)
            assertEquals(DIRECT_REPLACEMENT, second.get(5, TimeUnit.SECONDS).finalUri)
            assertEquals(1, refreshes.get())
        } finally {
            releaseReplacement.countDown()
            executor.shutdownNow()
        }
    }

    private fun sessionWithMaster(): TwitchPlaybackSession {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        return session
    }

    private fun payload(text: String, uri: String) = TwitchManifestPayload(
        bytes = text.toByteArray(),
        finalUri = uri,
    )

    private fun directMaster() = master(DIRECT_VARIANT, "1280x720", "720p60")

    private fun proxyMaster() = master(PROXY_REPLACEMENT, "1280x720", "720p60")

    private fun master(uri: String, resolution: String, stableId: String) = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=$resolution,FRAME-RATE=60,CODECS="avc1.640020",STABLE-VARIANT-ID="$stableId"
        $uri
    """.trimIndent()

    private fun twoVariantMaster(firstUri: String, secondUri: String) = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,FRAME-RATE=60,CODECS="avc1.640020",STABLE-VARIANT-ID="720p60"
        $firstUri
        #EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=640x360,FRAME-RATE=30,CODECS="avc1.4d401f",STABLE-VARIANT-ID="360p30"
        $secondUri
    """.trimIndent()

    private fun cleanPlaylist(mediaSequence: Long = 100) = """
        #EXTM3U
        #EXT-X-MEDIA-SEQUENCE:$mediaSequence
        #EXT-X-DISCONTINUITY-SEQUENCE:1
        #EXTINF:2,
        one.ts
        #EXTINF:2,
        two.ts
        #EXTINF:2,
        three.ts
    """.trimIndent()

    private fun adPlaylist() = cleanPlaylist() + "\n" +
        "#EXT-X-DATERANGE:ID=\"stitched-ad-1\",CLASS=\"twitch-stitched-ad\""

    private fun emptyMediaPlaylist() = """
        #EXTM3U
        #EXT-X-MEDIA-SEQUENCE:100
    """.trimIndent()

    private companion object {
        const val ROOT = "https://usher.ttvnw.net/api/v2/channel/hls/test.m3u8?sig=s&token=t"
        const val FRESH_ROOT =
            "https://usher.ttvnw.net/api/v2/channel/hls/test.m3u8?sig=fresh&token=fresh"
        const val SECOND_FRESH_ROOT =
            "https://usher.ttvnw.net/api/v2/channel/hls/test.m3u8?sig=fresh2&token=fresh2"
        const val DIRECT_VARIANT = "https://video-weaver.direct.test/live.m3u8?token=d"
        const val DIRECT_SECOND_VARIANT = "https://video-weaver.direct.test/low.m3u8?token=d2"
        const val DIRECT_REPLACEMENT = "https://video-weaver.direct-new.test/live.m3u8?token=dn"
        const val PROXY_REPLACEMENT = "https://video-weaver.proxy.test/live.m3u8?token=p"
        const val UNKNOWN_VARIANT = "https://example.test/untrusted.m3u8"
    }
}
