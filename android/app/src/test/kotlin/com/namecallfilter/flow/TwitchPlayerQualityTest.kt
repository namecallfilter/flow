package com.namecallfilter.flow

import org.junit.Assert.assertEquals
import org.junit.Test

class TwitchPlayerQualityTest {
    @Test
    fun selectedDuplicateRemainsVisible() {
        val visible = deduplicateQualities(
            qualities = listOf(
                quality("first", height = 720, fps = 60.0, bitrate = 3_000_000),
                quality("selected", height = 720, fps = 60.0, bitrate = 3_000_000),
                quality("lower", height = 480, fps = 30.0, bitrate = 1_000_000),
            ),
            selectedQualityId = "selected",
        )

        assertEquals(listOf("selected", "lower"), visible.map { it["id"] })
    }

    private fun quality(
        id: String,
        height: Int,
        fps: Double,
        bitrate: Int,
    ): Map<String, Any?> = mapOf(
        "id" to id,
        "height" to height,
        "fps" to fps,
        "bitrate" to bitrate,
    )
}
