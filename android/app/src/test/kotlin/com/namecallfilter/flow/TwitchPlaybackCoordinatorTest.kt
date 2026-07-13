package com.namecallfilter.flow

import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class TwitchPlaybackCoordinatorTest {
    @Test
    fun cleanPlaybackUsesNoProxyRequests() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        val routes = mutableListOf<TwitchManifestRoute>()
        val fetch: (TwitchManifestRoute, String) -> TwitchManifestPayload = { route, uri ->
            routes += route
            payload(if (uri == ROOT) directMaster() else cleanPlaylist(), uri)
        }

        session.resolve(ROOT, fetch)
        session.resolve(DIRECT_VARIANT, fetch)

        assertEquals(listOf(TwitchManifestRoute.Direct, TwitchManifestRoute.Direct), routes)
    }

    @Test
    fun adPlaylistRetriesSameUriThroughProxyOnce() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            payload(if (route == TwitchManifestRoute.Direct) adPlaylist() else cleanPlaylist(), uri)
        }

        assertFalse(containsTwitchStitchedAd(result.text))
        assertEquals(
            listOf(
                TwitchManifestRoute.Direct to DIRECT_VARIANT,
                TwitchManifestRoute.Proxy(0) to DIRECT_VARIANT,
            ),
            requests,
        )
    }

    @Test
    fun persistentAdCreatesMatchingReplacementAndMapsLaterRefreshes() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()
        val firstRequest = "$DIRECT_VARIANT&_HLS_msn=12&_HLS_part=1"

        val first = session.resolve(firstRequest) { route, uri ->
            requests += route to uri
            when {
                route is TwitchManifestRoute.Proxy && uri == ROOT -> payload(proxyMaster(), ROOT)
                route is TwitchManifestRoute.Proxy && uri == PROXY_VARIANT ->
                    payload(cleanPlaylist(mediaSequence = 101), PROXY_VARIANT)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(PROXY_VARIANT, first.finalUri)
        assertEquals(
            listOf(
                TwitchManifestRoute.Direct to firstRequest,
                TwitchManifestRoute.Proxy(0) to firstRequest,
                TwitchManifestRoute.Proxy(0) to ROOT,
                TwitchManifestRoute.Proxy(0) to PROXY_VARIANT,
            ),
            requests,
        )

        requests.clear()
        val laterRequest = "$DIRECT_VARIANT&_HLS_msn=13&_HLS_skip=YES"
        val later = session.resolve(laterRequest) { route, uri ->
            requests += route to uri
            payload(cleanPlaylist(mediaSequence = 102), uri)
        }

        val expectedUri = "$PROXY_VARIANT&_HLS_msn=13&_HLS_skip=YES"
        assertEquals(expectedUri, later.finalUri)
        assertEquals(listOf(TwitchManifestRoute.Direct to expectedUri), requests)
    }

    @Test
    fun unknownManifestIsNeverSentToProxy() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }

        val result = session.resolve("https://example.test/untrusted.m3u8") { route, uri ->
            assertEquals(TwitchManifestRoute.Direct, route)
            payload(adPlaylist(), uri)
        }

        assertTrue(containsTwitchStitchedAd(result.text))
    }

    @Test
    fun separateRenditionFailsOpenWithoutVariantRemapping() {
        val audioUri = "https://video-weaver.direct.test/audio.m3u8?token=d"
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri ->
            payload(
                "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"English\",URI=\"$audioUri\"\n" +
                    directMaster(),
                uri,
            )
        }
        val requests = mutableListOf<TwitchManifestRoute>()

        val result = session.resolve(audioUri) { route, uri ->
            requests += route
            payload(adPlaylist(), uri)
        }

        assertEquals(listOf(TwitchManifestRoute.Direct, TwitchManifestRoute.Proxy(0)), requests)
        assertEquals(audioUri, result.finalUri)
    }

    @Test
    fun missingReplacementQualityFallsBackWithoutDowngrading() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            when {
                route is TwitchManifestRoute.Proxy && uri == ROOT -> payload(
                    proxyMaster(resolution = "640x360", stableId = "360p30"),
                    ROOT,
                )
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(DIRECT_VARIANT, result.finalUri)
        assertTrue(containsTwitchStitchedAd(result.text))
    }

    @Test
    fun replacementFailureStillThrowsWhenDirectPlaylistCouldNotLoad() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }

        assertThrows(IOException::class.java) {
            session.resolve(DIRECT_VARIANT) { route, uri ->
                when {
                    route == TwitchManifestRoute.Direct -> throw IOException("direct failed")
                    uri == ROOT -> payload(
                        proxyMaster(resolution = "640x360", stableId = "360p30"),
                        ROOT,
                    )
                    else -> payload(adPlaylist(), uri)
                }
            }
        }
    }

    @Test
    fun missingReplacementQualityTriesTheNextProxy() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 2)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        val result = session.resolve(DIRECT_VARIANT) { route, uri ->
            requests += route to uri
            when {
                route == TwitchManifestRoute.Proxy(0) && uri == ROOT -> payload(
                    proxyMaster(resolution = "640x360", stableId = "360p30"),
                    ROOT,
                )
                route == TwitchManifestRoute.Proxy(1) && uri == ROOT -> payload(
                    proxyMaster(uri = PROXY_VARIANT_2),
                    ROOT,
                )
                route == TwitchManifestRoute.Proxy(1) && uri == PROXY_VARIANT_2 ->
                    payload(cleanPlaylist(), PROXY_VARIANT_2)
                else -> payload(adPlaylist(), uri)
            }
        }

        assertEquals(PROXY_VARIANT_2, result.finalUri)
        assertTrue(requests.contains(TwitchManifestRoute.Proxy(0) to ROOT))
        assertTrue(requests.contains(TwitchManifestRoute.Proxy(1) to ROOT))
    }

    @Test
    fun expiredReplacementRebasesOnAFullDirectPlaylist() {
        val session = TwitchPlaybackSession(ROOT, proxyCount = 1)
        session.resolve(ROOT) { _, uri -> payload(directMaster(), uri) }
        session.resolve(DIRECT_VARIANT) { route, uri ->
            when {
                route is TwitchManifestRoute.Proxy && uri == ROOT -> payload(proxyMaster(), ROOT)
                route is TwitchManifestRoute.Proxy && uri == PROXY_VARIANT ->
                    payload(cleanPlaylist(), PROXY_VARIANT)
                else -> payload(adPlaylist(), uri)
            }
        }
        val requests = mutableListOf<Pair<TwitchManifestRoute, String>>()

        val result = session.resolve("$DIRECT_VARIANT&_HLS_msn=120") { route, uri ->
            requests += route to uri
            if (uri.startsWith(PROXY_VARIANT)) {
                throw IOException("replacement expired")
            }
            payload(cleanPlaylist(mediaSequence = 120), uri)
        }

        assertEquals(DIRECT_VARIANT, result.finalUri)
        assertEquals(
            listOf(
                TwitchManifestRoute.Direct to "$PROXY_VARIANT&_HLS_msn=120",
                TwitchManifestRoute.Direct to DIRECT_VARIANT,
            ),
            requests,
        )
    }

    @Test
    fun replacementRequiresAnOverlappingPlaylistWindow() {
        assertTrue(twitchMediaPlaylistsOverlap(cleanPlaylist(100), cleanPlaylist(102)))
        assertFalse(twitchMediaPlaylistsOverlap(cleanPlaylist(100), cleanPlaylist(200)))
        assertFalse(
            twitchMediaPlaylistsOverlap(
                cleanPlaylist(100, discontinuitySequence = 2),
                cleanPlaylist(100, discontinuitySequence = 3),
            ),
        )
    }

    private fun payload(text: String, uri: String) = TwitchManifestPayload(
        bytes = text.toByteArray(),
        finalUri = uri,
    )

    private fun directMaster() = master(DIRECT_VARIANT, "1280x720", "720p60")

    private fun proxyMaster(
        resolution: String = "1280x720",
        stableId: String = "720p60",
        uri: String = PROXY_VARIANT,
    ) = master(uri, resolution, stableId)

    private fun master(uri: String, resolution: String, stableId: String) = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=$resolution,FRAME-RATE=60,CODECS="avc1.640020",STABLE-VARIANT-ID="$stableId"
        $uri
    """.trimIndent()

    private fun cleanPlaylist(
        mediaSequence: Long = 100,
        discontinuitySequence: Long = 1,
    ) = """
        #EXTM3U
        #EXT-X-MEDIA-SEQUENCE:$mediaSequence
        #EXT-X-DISCONTINUITY-SEQUENCE:$discontinuitySequence
        #EXTINF:2,
        one.ts
        #EXTINF:2,
        two.ts
        #EXTINF:2,
        three.ts
    """.trimIndent()

    private fun adPlaylist() = cleanPlaylist() + "\n" +
        "#EXT-X-DATERANGE:ID=\"stitched-ad-1\",CLASS=\"twitch-stitched-ad\""

    private companion object {
        const val ROOT = "https://usher.ttvnw.net/api/v2/channel/hls/test.m3u8?sig=s&token=t"
        const val DIRECT_VARIANT = "https://video-weaver.direct.test/live.m3u8?token=d"
        const val PROXY_VARIANT = "https://video-weaver.proxy.test/live.m3u8?token=p"
        const val PROXY_VARIANT_2 = "https://video-weaver.fallback.test/live.m3u8?token=p2"
    }
}
