package com.namecallfilter.flow.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import org.junit.Assert.assertEquals
import org.junit.Test

class FlowThemeParityTest {
    @Test
    fun lightSchemeMatchesFlutterSeedSchemeAndScaffoldOverride() {
        with(LightFlowColors) {
            assertColor(0xFF69548D, primary)
            assertColor(0xFFECDCFF, primaryContainer)
            assertColor(0xFF513C73, onPrimaryContainer)
            assertColor(0xFF645B70, secondary)
            assertColor(0xFFEADEF7, secondaryContainer)
            assertColor(0xFFF8F8F8, background)
            assertColor(0xFFFEF7FF, surface)
            assertColor(0xFF1D1A20, onSurface)
            assertColor(0xFFE7E0E8, surfaceContainerHighest)
            assertColor(0xFF49454E, onSurfaceVariant)
            assertColor(0xFF7B757F, outline)
            assertColor(0xFFCBC4CF, outlineVariant)
            assertColor(0xFFD5BBFC, inversePrimary)
        }
    }

    @Test
    fun darkSchemeMatchesFlutterSeedSchemeAndScaffoldOverride() {
        with(DarkFlowColors) {
            assertColor(0xFFD5BBFC, primary)
            assertColor(0xFF3A255B, onPrimary)
            assertColor(0xFF513C73, primaryContainer)
            assertColor(0xFFECDCFF, onPrimaryContainer)
            assertColor(0xFFCEC2DB, secondary)
            assertColor(0xFF4B4357, secondaryContainer)
            assertColor(0xFF000000, background)
            assertColor(0xFF151218, surface)
            assertColor(0xFFE7E0E8, onSurface)
            assertColor(0xFF37333A, surfaceContainerHighest)
            assertColor(0xFFCBC4CF, onSurfaceVariant)
            assertColor(0xFF958E99, outline)
            assertColor(0xFF49454E, outlineVariant)
            assertColor(0xFF69548D, inversePrimary)
        }
    }

    @Test
    fun typographyMatchesFlutterMaterialThreeMetrics() {
        assertTextStyle(FlowTypography.displayLarge, 57.sp, 63.84.sp, FontWeight.Normal, (-0.25).sp)
        assertTextStyle(FlowTypography.displayMedium, 45.sp, 52.2.sp, FontWeight.Normal, 0.sp)
        assertTextStyle(FlowTypography.displaySmall, 36.sp, 43.92.sp, FontWeight.Normal, 0.sp)
        assertTextStyle(FlowTypography.headlineLarge, 32.sp, 40.sp, FontWeight.Normal, 0.sp)
        assertTextStyle(FlowTypography.headlineMedium, 28.sp, 36.12.sp, FontWeight.Normal, 0.sp)
        assertTextStyle(FlowTypography.headlineSmall, 18.sp, 23.94.sp, FontWeight.SemiBold, (-0.019).sp)
        assertTextStyle(FlowTypography.titleLarge, 24.sp, 30.48.sp, FontWeight.SemiBold, (-0.019).sp)
        assertTextStyle(FlowTypography.titleMedium, 16.sp, 24.sp, FontWeight.SemiBold, (-0.011).sp)
        assertTextStyle(FlowTypography.titleSmall, 16.sp, 22.88.sp, FontWeight.SemiBold, (-0.011).sp)
        assertTextStyle(FlowTypography.labelLarge, 14.sp, 20.02.sp, FontWeight.Medium, (-0.006).sp)
        assertTextStyle(FlowTypography.labelMedium, 12.sp, 15.96.sp, FontWeight.Medium, 0.sp)
        assertTextStyle(FlowTypography.labelSmall, 11.sp, 15.95.sp, FontWeight.Medium, 0.005.sp)
        assertTextStyle(FlowTypography.bodyLarge, 16.sp, 24.sp, FontWeight.Medium, (-0.011).sp)
        assertTextStyle(FlowTypography.bodyMedium, 14.sp, 20.02.sp, FontWeight.Normal, (-0.006).sp)
        assertTextStyle(FlowTypography.bodySmall, 12.sp, 15.96.sp, FontWeight.Normal, 0.sp)
    }

    private fun assertColor(expected: Long, actual: Color) {
        assertEquals(Color(expected), actual)
    }

    private fun assertTextStyle(
        actual: TextStyle,
        expectedFontSize: TextUnit,
        expectedLineHeight: TextUnit,
        expectedFontWeight: FontWeight,
        expectedLetterSpacing: TextUnit,
    ) {
        assertEquals(FontFamily.SansSerif, actual.fontFamily)
        assertEquals(expectedFontSize, actual.fontSize)
        assertEquals(expectedLineHeight, actual.lineHeight)
        assertEquals(expectedFontWeight, actual.fontWeight)
        assertEquals(expectedLetterSpacing, actual.letterSpacing)

        assertEquals(
            LineHeightStyle(
                alignment = LineHeightStyle.Alignment.Center,
                trim = LineHeightStyle.Trim.None,
                mode = LineHeightStyle.Mode.Tight,
            ),
            actual.lineHeightStyle,
        )
    }
}
