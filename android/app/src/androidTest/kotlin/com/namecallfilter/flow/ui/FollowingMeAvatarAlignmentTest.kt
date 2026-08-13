package com.namecallfilter.flow.ui

import androidx.compose.foundation.layout.Row
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.ui.components.PageHeaderTitle
import com.namecallfilter.flow.ui.theme.FlowTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class FollowingMeAvatarAlignmentTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun meAvatarMatchesFlutterTopRightGeometryWithoutChangingItsSize() {
        lateinit var density: Density
        composeRule.setContent {
            density = LocalDensity.current
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                Row(verticalAlignment = Alignment.Top) {
                    PageHeaderTitle(
                        title = "Following",
                        modifier = Modifier.testTag("following-title"),
                    )
                    FollowingMeAvatarVisual(
                        userName = "Me",
                        userImageUrl = null,
                        modifier = Modifier.testTag("me-action-visual"),
                        avatarModifier = Modifier.testTag("me-avatar"),
                    )
                }
            }
        }

        val title = composeRule.onNodeWithTag("following-title").fetchSemanticsNode().boundsInRoot
        val action = composeRule.onNodeWithTag("me-action-visual").fetchSemanticsNode().boundsInRoot
        val avatar = composeRule.onNodeWithTag("me-avatar").fetchSemanticsNode().boundsInRoot
        val fourDp = with(density) { 4.dp.toPx() }
        val avatarSize = with(density) { 36.dp.toPx() }
        val actionSize = with(density) { 48.dp.toPx() }

        assertEquals(title.top, action.top, 1f)
        assertEquals(actionSize, action.width, 1f)
        assertEquals(actionSize, action.height, 1f)
        assertEquals(avatarSize, avatar.width, 1f)
        assertEquals(avatarSize, avatar.height, 1f)
        assertEquals(action.top + fourDp, avatar.top, 1f)
        assertEquals(action.right - fourDp, avatar.right, 1f)
    }
}
