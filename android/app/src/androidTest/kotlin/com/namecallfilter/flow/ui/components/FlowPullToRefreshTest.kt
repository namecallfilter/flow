package com.namecallfilter.flow.ui.components

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.dp
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.ui.theme.FlowTheme
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.util.concurrent.atomic.AtomicBoolean

class FlowPullToRefreshTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun activeRefresh_blocksListScrollingUntilRequestCompletes() {
        val allowRefreshToFinish = CompletableDeferred<Unit>()
        val refreshStarted = AtomicBoolean(false)
        val refreshFinished = AtomicBoolean(false)
        lateinit var listState: LazyListState

        composeRule.setContent {
            FlowTheme(mode = FlowThemeMode.LIGHT) {
                listState = rememberLazyListState()
                FlowPullToRefresh(
                    listState = listState,
                    indicatorStartTop = 0.dp,
                    indicatorMaxTravel = 96.dp,
                    onRefresh = {
                        refreshStarted.set(true)
                        allowRefreshToFinish.await()
                        refreshFinished.set(true)
                    },
                    modifier = Modifier.testTag("refresh-container"),
                ) {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize().testTag("refresh-list"),
                    ) {
                        items((0 until 100).toList()) { index ->
                            Text("Item $index", Modifier.fillMaxWidth().height(64.dp))
                        }
                    }
                }
            }
        }

        composeRule.onNodeWithTag("refresh-container").performTouchInput {
            swipe(
                start = Offset(center.x, height * 0.20f),
                end = Offset(center.x, height * 0.70f),
                durationMillis = 500,
            )
        }
        composeRule.waitUntil(5_000) { refreshStarted.get() }

        composeRule.onNodeWithTag("refresh-list").performTouchInput {
            swipe(
                start = Offset(center.x, height * 0.70f),
                end = Offset(center.x, height * 0.20f),
                durationMillis = 500,
            )
        }
        composeRule.runOnIdle {
            assertEquals(0, listState.firstVisibleItemIndex)
            assertEquals(0, listState.firstVisibleItemScrollOffset)
        }

        allowRefreshToFinish.complete(Unit)
        composeRule.waitUntil(5_000) { refreshFinished.get() }
        composeRule.onNodeWithTag("refresh-list").performTouchInput {
            swipe(
                start = Offset(center.x, height * 0.70f),
                end = Offset(center.x, height * 0.20f),
                durationMillis = 500,
            )
        }
        composeRule.waitUntil(5_000) {
            listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 0
        }
        composeRule.runOnIdle {
            assertTrue(listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 0)
        }
    }
}
