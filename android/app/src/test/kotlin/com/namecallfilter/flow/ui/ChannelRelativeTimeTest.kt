package com.namecallfilter.flow.ui

import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class ChannelRelativeTimeTest {
    private val now = Instant.parse("2026-08-04T16:00:00Z")

    @Test
    fun formatsFlutterChannelAgeUnitsAndPluralization() {
        assertAge("1 year ago", Duration.ofDays(365))
        assertAge("2 years ago", Duration.ofDays(730))
        assertAge("1 month ago", Duration.ofDays(30))
        assertAge("2 months ago", Duration.ofDays(60))
        assertAge("1 day ago", Duration.ofDays(1))
        assertAge("2 days ago", Duration.ofDays(2))
        assertAge("1 hour ago", Duration.ofHours(1))
        assertAge("2 hours ago", Duration.ofHours(2))
        assertAge("1 minute ago", Duration.ofMinutes(1))
        assertAge("2 minutes ago", Duration.ofMinutes(2))
    }

    @Test
    fun truncatesIntoTheLargestFlutterUnitAtEachBoundary() {
        assertAge("12 months ago", Duration.ofDays(364))
        assertAge("29 days ago", Duration.ofDays(29).plusHours(23))
        assertAge("23 hours ago", Duration.ofHours(23).plusMinutes(59))
        assertAge("59 minutes ago", Duration.ofMinutes(59).plusSeconds(59))
    }

    @Test
    fun reportsSubMinuteAndFutureTimestampsAsJustNow() {
        assertAge("just now", Duration.ZERO)
        assertAge("just now", Duration.ofSeconds(59))
        assertEquals("just now", channelRelativeTime(now.plusSeconds(1), now))
    }

    private fun assertAge(expected: String, elapsed: Duration) {
        assertEquals(expected, channelRelativeTime(now.minus(elapsed), now))
    }
}
