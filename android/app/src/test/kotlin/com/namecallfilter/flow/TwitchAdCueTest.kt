package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class TwitchAdCueTest {
    @Test
    fun parsesStitchedAdCountPositionDurationAndQuotedCommas() {
        val tag = "#EXT-X-DATERANGE:" +
                "ID=\"stitched-ad-123\"," +
                "CLASS=\"twitch-stitched-ad\"," +
                "START-DATE=\"2026-07-10T05:05:39.621Z\"," +
                "DURATION=15.164," +
                "X-TV-TWITCH-AD-POD-FILLED-DURATION=45," +
                "X-TV-TWITCH-AD-POD-LENGTH=\"3\"," +
                "X-TV-TWITCH-AD-POD-POSITION=\"1\"," +
                "X-TV-TWITCH-AD-AD-SESSION-ID=\"pod-abc\"," +
                "X-TV-TWITCH-AD-ROLL-TYPE=\"PREROLL\"," +
                "X-TV-TWITCH-AD-URL=\"https://example.com/a,b\""
        val attributes = parseHlsAttributeList(tag)
        assertEquals("stitched-ad-123", attributes["ID"])
        assertEquals("2026-07-10T05:05:39.621Z", attributes["START-DATE"])
        assertEquals("15.164", attributes["DURATION"])

        val cue = parseTwitchAdCue(tag)

        requireNotNull(cue)
        assertEquals("stitched-ad-123", cue.id)
        assertEquals(15_164L, cue.durationMs)
        assertEquals(1, cue.podPosition)
        assertEquals(3, cue.podLength)
        assertEquals("pod-abc", cue.podId)
        assertEquals(45_000L, cue.podFilledDurationMs)
        assertEquals("PREROLL", cue.rollType)
        assertEquals("https://example.com/a,b", parseHlsAttributeList(
            "#EXT-X-DATERANGE:X-TV-TWITCH-AD-URL=\"https://example.com/a,b\"",
        )["X-TV-TWITCH-AD-URL"])
    }

    @Test
    fun rejectsNonAdsAndInvalidOrMissingTiming() {
        assertNull(
            parseTwitchAdCue(
                "#EXT-X-DATERANGE:ID=\"chapter-1\",START-DATE=\"2026-07-10T05:05:39Z\",DURATION=10",
            ),
        )
        assertNull(
            parseTwitchAdCue(
                "#EXT-X-DATERANGE:ID=\"stitched-ad-1\",START-DATE=\"bad\",DURATION=10",
            ),
        )
        assertNull(
            parseTwitchAdCue(
                "#EXT-X-DATERANGE:ID=\"stitched-ad-1\",START-DATE=\"2026-07-10T05:05:39Z\"",
            ),
        )
        assertNull(
            parseTwitchAdCue(
                "#EXT-X-DATERANGE:ID=\"stitched-ad-quartile-trap\"," +
                    "CLASS=\"twitch-ad-quartile\"," +
                    "START-DATE=\"2026-07-10T05:05:39Z\"," +
                    "DURATION=2,X-TV-TWITCH-AD-QUARTILE=0",
            ),
        )
        assertNull(
            parseTwitchAdCue(
                "#EXT-X-DATERANGE:ID=\"stitched-ad-quartile-trap-2\"," +
                    "CLASS=\"twitch-stitched-ad\"," +
                    "START-DATE=\"2026-07-10T05:05:39Z\"," +
                    "DURATION=2,X-TV-TWITCH-AD-QUARTILE=1",
            ),
        )
        assertNull(
            parseTwitchAdCue(
                "#EXT-X-DATERANGE:ID=\"tracking-1\"," +
                    "START-DATE=\"2026-07-10T05:05:39Z\"," +
                    "DURATION=2,X-TV-TWITCH-AD-TRACKING=1",
            ),
        )
    }

    @Test
    fun selectsCueFromPlaybackTimestampAndCalculatesAdLatencyFallback() {
        val first = TwitchAdCue("first", 10_000L, 15_000L, 0, 2, "PREROLL")
        val second = TwitchAdCue("second", 25_000L, 30_000L, 1, 2, "PREROLL")

        assertSame(first, activeTwitchAdCue(listOf(first, second), 24_999L))
        assertSame(second, activeTwitchAdCue(listOf(first, second), 25_000L))
        assertNull(activeTwitchAdCue(listOf(first, second), 55_000L))
        assertEquals(1_750L, adFallbackLatencyMs(50_000L, 250L, 48_500L))
        assertNull(adFallbackLatencyMs(48_000L, 250L, 48_500L))
        assertNull(adFallbackLatencyMs(50_000L, null, 48_500L))
        assertEquals(48_500L, playbackEpochMs(40_000L, 8_500L))
        assertNull(playbackEpochMs(C.TIME_UNSET, 8_500L))
        assertEquals(2_000L, roundRemainingAdTimeMs(1_001L))
    }

    @Test
    fun stitchedAdLatencyFallbackSurvivesEarlyCueEndUntilPrimaryReturns() {
        val fallback = StitchedAdLatencyFallback()

        assertFalse(fallback.shouldUseTimeline(primaryLatencyIsFresh = false))
        fallback.onAdProgress(isActive = true)
        assertTrue(fallback.shouldUseTimeline(primaryLatencyIsFresh = false))
        assertFalse(fallback.shouldUseTimeline(primaryLatencyIsFresh = true))

        // The playlist can say the ad ended before the last stitched creative.
        // With no current transc_r yet, the ad timeline remains authoritative.
        assertTrue(fallback.shouldUseTimeline(primaryLatencyIsFresh = false))
        assertTrue(fallback.onAcceptedPrimaryLatency())
        assertFalse(fallback.shouldUseTimeline(primaryLatencyIsFresh = false))
        assertFalse(fallback.onAcceptedPrimaryLatency())
        // A later ticker update for the same cue cannot replace transc_r.
        fallback.onAdProgress(isActive = true)
        assertFalse(fallback.shouldUseTimeline(primaryLatencyIsFresh = false))

        fallback.onAdProgress(isActive = false)
        fallback.onAdProgress(isActive = true)
        assertTrue(fallback.shouldUseTimeline(primaryLatencyIsFresh = false))
        fallback.reset()
        assertFalse(fallback.shouldUseTimeline(primaryLatencyIsFresh = false))
    }

    @Test
    fun reportsCurrentCreativeAndRemainingTimeAcrossTheWholePod() {
        val first = TwitchAdCue(
            id = "first",
            startEpochMs = 10_000L,
            durationMs = 20_000L,
            podPosition = 0,
            podLength = 2,
            rollType = "MIDROLL",
            podId = "pod-1",
            podFilledDurationMs = 45_000L,
        )
        val second = TwitchAdCue(
            id = "second",
            startEpochMs = 30_000L,
            durationMs = 25_250L,
            podPosition = 1,
            podLength = 2,
            rollType = "MIDROLL",
            podId = "pod-1",
            podFilledDurationMs = 45_000L,
        )

        val duringFirst = twitchAdProgress(listOf(first, second), 15_000L)
        requireNotNull(duringFirst)
        assertEquals(1, duringFirst.current)
        assertEquals(2, duringFirst.total)
        assertEquals(15_000L, duringFirst.currentRemainingMs)
        assertEquals(40_000L, duringFirst.podRemainingMs)
        assertEquals(45_000L, duringFirst.podDurationMs)

        val duringSecond = twitchAdProgress(listOf(first, second), 35_000L)
        requireNotNull(duringSecond)
        assertEquals(2, duringSecond.current)
        assertEquals(2, duringSecond.total)
        assertEquals(21_000L, duringSecond.currentRemainingMs)
        assertEquals(20_000L, duringSecond.podRemainingMs)
    }

    @Test
    fun groupsCreativesBySharedRadsTokenWhenSessionIdIsMissing() {
        val first = parseTwitchAdCue(
            "#EXT-X-DATERANGE:ID=\"stitched-ad-first\"," +
                "CLASS=\"twitch-stitched-ad\"," +
                "START-DATE=\"2026-07-10T05:05:00Z\",DURATION=20," +
                "X-TV-TWITCH-AD-POD-FILLED-DURATION=45," +
                "X-TV-TWITCH-AD-POD-LENGTH=2,X-TV-TWITCH-AD-POD-POSITION=0," +
                "X-TV-TWITCH-AD-RADS-TOKEN=\"shared-pod-token\"",
        )
        val second = parseTwitchAdCue(
            "#EXT-X-DATERANGE:ID=\"stitched-ad-second\"," +
                "CLASS=\"twitch-stitched-ad\"," +
                "START-DATE=\"2026-07-10T05:05:20Z\",DURATION=25," +
                "X-TV-TWITCH-AD-POD-FILLED-DURATION=45," +
                "X-TV-TWITCH-AD-POD-LENGTH=2,X-TV-TWITCH-AD-POD-POSITION=1," +
                "X-TV-TWITCH-AD-RADS-TOKEN=\"shared-pod-token\"",
        )
        requireNotNull(first)
        requireNotNull(second)

        assertEquals("shared-pod-token", first.podId)
        assertEquals(first.podId, second.podId)
        val progress = twitchAdProgress(listOf(first, second), second.startEpochMs + 5_000L)
        requireNotNull(progress)
        assertEquals(2, progress.current)
        assertEquals(2, progress.total)
        assertEquals(20_000L, progress.podRemainingMs)
    }

    @Test
    fun recognizesBothCurrentTwitchServerTimeTagForms() {
        assertEquals(
            1_783_659_939.38,
            parseTwitchServerTimeSeconds(
                "#EXT-X-SESSION-DATA:DATA-ID=\"SERVER-TIME\",VALUE=\"1783659939.38\"",
            )!!,
            0.0001,
        )
        assertEquals(
            1_783_659_939.62,
            parseTwitchServerTimeSeconds(
                "#EXT-X-DATERANGE:ID=\"playlist-creation\",X-SERVER-TIME=\"1783659939.62\"",
            )!!,
            0.0001,
        )
    }

    @Test
    fun rewritesOnlyLiveTwitchTargetAndPrefetchLines() {
        val playlist = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-MEDIA-SEQUENCE:40
            #EXTINF:2.000,live
            segment-40.ts
            #EXT-X-DATERANGE:ID="stitched-ad-1",CLASS="twitch-stitched-ad"
            #EXT-X-TWITCH-PREFETCH:segment-41.ts
            #EXT-X-TWITCH-PREFETCH:segment-42.ts
        """.trimIndent()

        val rewritten = rewriteTwitchLowLatencyPlaylist(playlist)

        assertTrue(rewritten.contains("#EXT-X-TARGETDURATION:2"))
        assertEquals(3, "#EXTINF:2.000,".toRegex().findAll(rewritten).count())
        assertTrue(rewritten.contains("segment-41.ts\n#EXTINF:2.000,\nsegment-42.ts"))
        assertTrue(rewritten.contains("ID=\"stitched-ad-1\""))
        assertFalse(rewritten.contains("#EXT-X-TWITCH-PREFETCH:"))

        val vod = "$playlist\n#EXT-X-ENDLIST"
        assertEquals(vod, rewriteTwitchLowLatencyPlaylist(vod))
        val alreadyNormalized = playlist.replace("TARGETDURATION:6", "TARGETDURATION:2")
            .replace("#EXT-X-TWITCH-PREFETCH:segment-41.ts\n", "")
            .replace("#EXT-X-TWITCH-PREFETCH:segment-42.ts", "")
        assertEquals(alreadyNormalized, rewriteTwitchLowLatencyPlaylist(alreadyNormalized))
    }
}
