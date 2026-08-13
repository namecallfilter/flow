package com.namecallfilter.flow.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.ui.theme.FlowTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class FlowChromeBehaviorTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun scrollToTopBadge_isCenteredInChrome() {
        composeRule.setContent {
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                val listState = rememberLazyListState(initialFirstVisibleItemIndex = 20)
                ScrollReactiveChrome(
                    listState = listState,
                    header = { Box(Modifier.fillMaxWidth().height(80.dp)) },
                    modifier = Modifier.testTag("chrome"),
                ) {
                    LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                        items((0 until 100).toList()) { index ->
                            Text("Item $index", Modifier.fillMaxWidth().height(64.dp))
                        }
                    }
                }
            }
        }

        val chrome = composeRule.onNodeWithTag("chrome").fetchSemanticsNode().boundsInRoot
        val badge = composeRule.onNodeWithContentDescription("Scroll to top")
            .fetchSemanticsNode()
            .boundsInRoot

        assertEquals(chrome.center.x, badge.center.x, 1f)
    }
}
