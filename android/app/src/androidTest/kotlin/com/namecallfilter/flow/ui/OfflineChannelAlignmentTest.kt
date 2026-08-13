package com.namecallfilter.flow.ui

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.data.OfflineChannel
import com.namecallfilter.flow.ui.components.AvatarRing
import com.namecallfilter.flow.ui.theme.FlowTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class OfflineChannelAlignmentTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun identityText_alignsWithUnchangedAvatarEdges() {
        val channel = OfflineChannel(
            name = "Creator",
            initials = "CR",
            lastLive = "Followed 1 year ago",
            category = "Just Chatting",
            avatarColors = listOf(0xFF2C203F.toInt(), 0xFFFFA3B1.toInt()),
        )
        composeRule.setContent {
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AvatarRing(
                        initials = channel.initials,
                        colors = channel.avatarColors,
                        size = 54.dp,
                        modifier = Modifier.testTag("offline-avatar"),
                    )
                    Spacer(Modifier.width(14.dp))
                    OfflineChannelIdentity(channel)
                }
            }
        }

        val avatar = composeRule.onNodeWithTag("offline-avatar").fetchSemanticsNode().boundsInRoot
        val name = composeRule.onNodeWithText(channel.name).fetchSemanticsNode().boundsInRoot
        val category = composeRule.onNodeWithText(channel.category).fetchSemanticsNode().boundsInRoot

        assertEquals(avatar.top, name.top, 1f)
        assertEquals(avatar.bottom, category.bottom, 1f)
    }
}
