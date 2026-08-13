package com.namecallfilter.flow.ui

import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasProgressBarRangeInfo
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.ui.theme.FlowTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class LoginOfferScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun idleOffer_exposesOneActionOfEachKind_andDispatchesClicks() {
        var loginClicks = 0
        var continueClicks = 0
        composeRule.setContent {
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                TwitchLoginOfferScreen(
                    statusMessage = "Please try again.",
                    showCloseButton = true,
                    loginBusy = false,
                    continueBusy = false,
                    onLogin = { loginClicks += 1 },
                    onContinue = { continueClicks += 1 },
                )
            }
        }

        // The invisible layout-balancing copy must never leak into accessibility.
        composeRule.onAllNodesWithText("Log in with Twitch").assertCountEquals(1)
        composeRule.onAllNodesWithText("Continue without an account").assertCountEquals(1)
        composeRule.onNodeWithText("Please try again.").assertExists()

        composeRule.onNodeWithText("Log in with Twitch")
            .assertHasClickAction()
            .assertIsEnabled()
            .performClick()
        composeRule.onNodeWithText("Continue without an account")
            .assertHasClickAction()
            .assertIsEnabled()
            .performClick()
        composeRule.onNodeWithContentDescription("Close")
            .assertHasClickAction()
            .assertIsEnabled()
            .performClick()

        composeRule.runOnIdle {
            assertEquals(1, loginClicks)
            assertEquals(2, continueClicks)
        }
    }

    @Test
    fun eitherBusyState_disablesLoginContinueAndClose_andOnlyLoginShowsProgress() {
        val loginBusy = mutableStateOf(false)
        val continueBusy = mutableStateOf(false)
        composeRule.setContent {
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                TwitchLoginOfferScreen(
                    statusMessage = null,
                    showCloseButton = true,
                    loginBusy = loginBusy.value,
                    continueBusy = continueBusy.value,
                    onLogin = {},
                    onContinue = {},
                )
            }
        }

        composeRule.runOnIdle { loginBusy.value = true }
        assertAllActionsDisabled()
        composeRule.onAllNodes(
            hasProgressBarRangeInfo(ProgressBarRangeInfo.Indeterminate),
        ).assertCountEquals(1)

        composeRule.runOnIdle {
            loginBusy.value = false
            continueBusy.value = true
        }
        assertAllActionsDisabled()
        composeRule.onAllNodes(
            hasProgressBarRangeInfo(ProgressBarRangeInfo.Indeterminate),
        ).assertCountEquals(0)
    }

    private fun assertAllActionsDisabled() {
        composeRule.onNodeWithText("Log in with Twitch").assertIsNotEnabled()
        composeRule.onNodeWithText("Continue without an account").assertIsNotEnabled()
        composeRule.onNodeWithContentDescription("Close").assertIsNotEnabled()
    }
}
