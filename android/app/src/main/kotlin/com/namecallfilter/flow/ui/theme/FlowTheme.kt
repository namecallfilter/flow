package com.namecallfilter.flow.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.sp
import com.namecallfilter.flow.data.FlowThemeMode

object FlowColors {
    val Seed = Color(0xFF9146FF)
    val PrimaryDark = Color(0xFFD5BBFC)
    val Live = Color(0xFFF44336)
    val LiveBadge = Color(0xFFE91916)
    val DarkBackground = Color.Black
    val DarkSurface = Color(0xFF1D1B20)
    val GeneratedDarkSurface = Color(0xFF151218)
    val DarkChrome = Color(0xFF08080A)
    val LightBackground = Color(0xFFF8F8F8)
    val Ink = Color(0xFF1D1B20)
}

internal val DarkFlowColors = darkColorScheme(
    primary = FlowColors.PrimaryDark,
    onPrimary = Color(0xFF3A255B),
    primaryContainer = Color(0xFF513C73),
    onPrimaryContainer = Color(0xFFECDCFF),
    secondary = Color(0xFFCEC2DB),
    onSecondary = Color(0xFF352D40),
    secondaryContainer = Color(0xFF4B4357),
    onSecondaryContainer = Color(0xFFEADEF7),
    tertiary = Color(0xFFF1B7C3),
    onTertiary = Color(0xFF4B252F),
    tertiaryContainer = Color(0xFF643B45),
    onTertiaryContainer = Color(0xFFFFD9E0),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = FlowColors.DarkBackground,
    onBackground = Color(0xFFE7E0E8),
    surface = FlowColors.GeneratedDarkSurface,
    onSurface = Color(0xFFE7E0E8),
    surfaceVariant = Color(0xFF49454E),
    onSurfaceVariant = Color(0xFFCBC4CF),
    outline = Color(0xFF958E99),
    outlineVariant = Color(0xFF49454E),
    inverseSurface = Color(0xFFE7E0E8),
    inverseOnSurface = Color(0xFF322F35),
    inversePrimary = Color(0xFF69548D),
    surfaceTint = FlowColors.PrimaryDark,
    surfaceDim = FlowColors.GeneratedDarkSurface,
    surfaceBright = Color(0xFF3B383E),
    surfaceContainerLowest = Color(0xFF0F0D12),
    surfaceContainerLow = Color(0xFF1D1A20),
    surfaceContainer = Color(0xFF211E24),
    surfaceContainerHigh = Color(0xFF2C292F),
    surfaceContainerHighest = Color(0xFF37333A),
)

internal val LightFlowColors = lightColorScheme(
    primary = Color(0xFF69548D),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFECDCFF),
    onPrimaryContainer = Color(0xFF513C73),
    secondary = Color(0xFF645B70),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFEADEF7),
    onSecondaryContainer = Color(0xFF4B4357),
    tertiary = Color(0xFF7F525C),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFFD9E0),
    onTertiaryContainer = Color(0xFF643B45),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF93000A),
    background = FlowColors.LightBackground,
    onBackground = Color(0xFF1D1A20),
    surface = Color(0xFFFEF7FF),
    onSurface = Color(0xFF1D1A20),
    surfaceVariant = Color(0xFFE8E0EB),
    onSurfaceVariant = Color(0xFF49454E),
    outline = Color(0xFF7B757F),
    outlineVariant = Color(0xFFCBC4CF),
    inverseSurface = Color(0xFF322F35),
    inverseOnSurface = Color(0xFFF6EEF7),
    inversePrimary = FlowColors.PrimaryDark,
    surfaceTint = Color(0xFF69548D),
    surfaceDim = Color(0xFFDED8E0),
    surfaceBright = Color(0xFFFEF7FF),
    surfaceContainerLowest = Color.White,
    surfaceContainerLow = Color(0xFFF8F1F9),
    surfaceContainer = Color(0xFFF3ECF4),
    surfaceContainerHigh = Color(0xFFEDE6EE),
    surfaceContainerHighest = Color(0xFFE7E0E8),
)

private val FlutterLineHeightStyle = LineHeightStyle(
    alignment = LineHeightStyle.Alignment.Center,
    trim = LineHeightStyle.Trim.None,
    mode = LineHeightStyle.Mode.Tight,
)

internal val FlowTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 57.sp,
        lineHeight = 63.84.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = (-0.25).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    displayMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 45.sp,
        lineHeight = 52.2.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    displaySmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 36.sp,
        lineHeight = 43.92.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    headlineLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 32.sp,
        lineHeight = 40.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    headlineMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 28.sp,
        lineHeight = 36.12.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    headlineSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 18.sp,
        lineHeight = 23.94.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = (-0.019).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 24.sp,
        lineHeight = 30.48.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = (-0.019).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = (-0.011).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    titleSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 16.sp,
        lineHeight = 22.88.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = (-0.011).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 14.sp,
        lineHeight = 20.02.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = (-0.006).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 12.sp,
        lineHeight = 15.96.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 11.sp,
        lineHeight = 15.95.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.005.sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = (-0.011).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 14.sp,
        lineHeight = 20.02.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = (-0.006).sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
    bodySmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 12.sp,
        lineHeight = 15.96.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.sp,
        lineHeightStyle = FlutterLineHeightStyle,
    ),
)

@Composable
fun FlowTheme(
    mode: FlowThemeMode = FlowThemeMode.SYSTEM,
    content: @Composable () -> Unit,
) {
    val dark = when (mode) {
        FlowThemeMode.LIGHT -> false
        FlowThemeMode.DARK -> true
        FlowThemeMode.SYSTEM -> isSystemInDarkTheme()
    }
    MaterialTheme(
        colorScheme = if (dark) DarkFlowColors else LightFlowColors,
        typography = FlowTypography,
        content = content,
    )
}
