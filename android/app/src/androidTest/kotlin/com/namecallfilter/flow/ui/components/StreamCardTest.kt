package com.namecallfilter.flow.ui.components

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.data.StreamChannel
import com.namecallfilter.flow.ui.theme.FlowTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class StreamCardTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun categoryClick_dispatchesCategoryActionWithoutOpeningStream() {
        var categoryClicks = 0
        var streamClicks = 0
        composeRule.setContent {
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                StreamCard(
                    channel = streamChannel(),
                    onOpenStream = { streamClicks += 1 },
                    onOpenChannel = {},
                    onOpenCategory = { categoryClicks += 1 },
                )
            }
        }

        composeRule.onNodeWithContentDescription("Open Game category")
            .assertHasClickAction()
            .performClick()

        composeRule.runOnIdle {
            assertEquals(1, categoryClicks)
            assertEquals(0, streamClicks)
        }
    }

    private fun streamChannel() = StreamChannel(
        id = "creator",
        login = "creator",
        name = "Creator",
        initials = "CR",
        title = "Live now",
        category = "Game",
        categoryId = "game-id",
        viewers = "42",
        avatarColors = emptyList(),
        thumbnailColors = emptyList(),
    )
}
