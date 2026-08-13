package com.namecallfilter.flow.ui.components

import androidx.compose.ui.graphics.Color
import com.namecallfilter.flow.ui.theme.FlowColors
import org.junit.Assert.assertEquals
import org.junit.Test

class FlowChromeStyleTest {
    @Test
    fun lightAndDarkChromeUseOneUniformOpacity() {
        val light = resolveFlowChromeColor(FlowColors.LightBackground)
        val dark = resolveFlowChromeColor(Color.Black)

        assertEquals(FlowColors.LightBackground.copy(alpha = FlowChromeTintAlpha), light)
        assertEquals(FlowColors.DarkChrome.copy(alpha = FlowChromeTintAlpha), dark)
        assertEquals(light.alpha, dark.alpha, 0.001f)
    }
}
