package com.namecallfilter.flow.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class DisplayMappersTest {
    @Test fun `offline channels exclude live and sort newest first`() {
        val connection = TwitchAuthConnection(
            user = TwitchUser("viewer", "viewer", "Viewer"),
            followedStreams = listOf(
                TwitchFollowedStream("s", "live", "live", "Live", "Game", "Title", 1),
            ),
            followedChannels = listOf(
                TwitchFollowedChannel("old", "old", "Old", Instant.parse("2023-01-01T00:00:00Z")),
                TwitchFollowedChannel("live", "live", "Live", Instant.parse("2026-01-01T00:00:00Z")),
                TwitchFollowedChannel("new", "new", "New", Instant.parse("2025-01-01T00:00:00Z")),
                TwitchFollowedChannel("unknown", "unknown", "Unknown"),
            ),
        )
        val names = offlineChannelsFromConnection(
            connection,
            Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC),
        ).map(OfflineChannel::name)
        assertEquals(listOf("New", "Old", "Unknown"), names)
    }

    @Test fun `compact counts relative time and artwork match Flutter`() {
        assertEquals("4.2K", formatCompactCount(4_200))
        assertEquals("1M", formatCompactCount(1_000_000))
        val clock = Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC)
        assertEquals("1 year ago", relativeTime(Instant.parse("2025-01-01T00:00:00Z"), clock))
        assertEquals(
            "https://example.com/box-300x400.jpg",
            twitchBoxArtUrl("https://example.com/box-52x72.jpg"),
        )
        assertNull(twitchBoxArtUrl(null))
    }

    @Test fun `stream mapping retains playback metadata`() {
        val started = Instant.parse("2026-07-09T20:30:00Z")
        val result = streamChannelFromStream(
            TwitchFollowedStream("s", "u", "creator", "Creator", "", "", 1_234,
                thumbnailUrl = "https://x/{width}x{height}", startedAt = started),
        )
        assertEquals("Live now", result.title)
        assertEquals("Live", result.category)
        assertEquals("1.2K", result.viewers)
        assertEquals("https://x/320x180", result.thumbnailUrl)
        assertEquals(started, result.startedAt)
    }

    @Test fun `stream mapping retains category identity for navigation`() {
        val result = streamChannelFromStream(
            TwitchFollowedStream(
                id = "stream",
                userId = "creator",
                userLogin = "creator",
                userName = "Creator",
                gameName = "Game",
                title = "Live",
                viewerCount = 42,
                gameId = "game-id",
            ),
        )

        assertEquals("game-id", result.categoryId)
        val category = requireNotNull(browseCategoryFromStream(result))
        assertEquals("game-id", category.id)
        assertEquals("Game", category.name)
        assertNull(browseCategoryFromStream(result.copy(categoryId = "")))
        assertNull(browseCategoryFromStream(result.copy(category = "")))
    }
}
