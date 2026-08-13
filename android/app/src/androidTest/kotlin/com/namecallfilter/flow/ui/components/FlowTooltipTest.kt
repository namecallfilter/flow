package com.namecallfilter.flow.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.ui.theme.FlowTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class FlowTooltipTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun longPress_keepsTooltipForFlutterTwoSecondDuration_thenDismisses() {
        assertEquals(2_000L, FlowTooltipDurationMillis)
        composeRule.setContent {
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                FlowTooltip(label = "Parity tooltip") {
                    Box(Modifier.size(48.dp).testTag("tooltip-anchor"))
                }
            }
        }

        composeRule.onNodeWithText("Parity tooltip").assertDoesNotExist()
        composeRule.mainClock.autoAdvance = false
        composeRule.onNodeWithTag("tooltip-anchor", useUnmergedTree = true)
            .performTouchInput { longClick() }
        composeRule.mainClock.advanceTimeByFrame()
        composeRule.onNodeWithText("Parity tooltip").assertExists()

        composeRule.mainClock.advanceTimeBy(FlowTooltipDurationMillis - 2L)
        composeRule.onNodeWithText("Parity tooltip").assertExists()

        // Advance through the 2-second dismissal and the short Material exit transition.
        composeRule.mainClock.advanceTimeBy(500L)
        composeRule.onNodeWithText("Parity tooltip").assertDoesNotExist()
    }
}
