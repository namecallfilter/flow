package com.namecallfilter.flow.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * Compose counterpart to Flutter's TickerMode for retained/offstage destinations.
 *
 * Retained screens keep their data and scroll state, while infinite visual clocks stop whenever
 * the destination is covered. This avoids spending frames on shimmer and refresh animations that
 * cannot be seen.
 */
internal val LocalFlowVisualsActive = staticCompositionLocalOf { true }

@Composable
internal fun FlowVisualsActive(
    active: Boolean,
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(LocalFlowVisualsActive provides active, content = content)
}
