package com.namecallfilter.flow.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.LightMode
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.DialogWindowProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.namecallfilter.flow.data.AppSettingsRepository
import com.namecallfilter.flow.data.FlowThemeMode
import com.namecallfilter.flow.data.TwitchUser
import com.namecallfilter.flow.data.normalizeAdProxyUrl
import com.namecallfilter.flow.data.normalizeChannelLogins
import com.namecallfilter.flow.ui.components.FlowTooltip
import com.namecallfilter.flow.ui.components.FlowTooltipAction
import com.namecallfilter.flow.ui.components.PageHeaderTitle
import com.namecallfilter.flow.ui.components.ScrollReactiveChrome
import com.namecallfilter.flow.ui.theme.FlowLayout
import com.namecallfilter.flow.ui.theme.FlowRadius
import com.namecallfilter.flow.ui.theme.FlowSpacing
import kotlinx.coroutines.launch
import java.net.URI

private enum class SettingsPrompt { PROXY, CHANNEL }

@Composable
internal fun SettingsScreen(
    settingsRepository: AppSettingsRepository,
    account: TwitchUser?,
    onSwitchAccount: () -> Unit,
    onSignOut: () -> Unit,
    onOpenRepository: () -> Unit,
    onFooterHiddenChange: (Boolean) -> Unit,
) {
    val state by settingsRepository.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    var loadError by remember { mutableStateOf<String?>(null) }
    var prompt by remember { mutableStateOf<SettingsPrompt?>(null) }
    var promptValue by remember { mutableStateOf("") }
    var promptError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(settingsRepository) {
        runCatching { settingsRepository.load() }
            .onFailure { loadError = it.message ?: "Couldn't load settings." }
    }

    fun launchUpdate(block: suspend () -> Unit) {
        scope.launch {
            runCatching { block() }
        }
    }

    ScrollReactiveChrome(
        listState = listState,
        header = {
            PageHeaderTitle(
                title = "Settings",
                modifier = Modifier.padding(
                    start = FlowSpacing.Lg,
                    top = FlowSpacing.Lg,
                    end = FlowSpacing.Lg,
                    bottom = 20.5.dp,
                ),
            )
        },
        onFooterHiddenChange = onFooterHiddenChange,
    ) {
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(state.isLoaded) {
                    if (!state.isLoaded) {
                        awaitPointerEventScope {
                            while (true) {
                                awaitPointerEvent(PointerEventPass.Initial).changes.forEach { it.consume() }
                            }
                        }
                    }
                },
            contentPadding = PaddingValues(
                start = FlowSpacing.Lg,
                top = FlowLayout.SettingsContentTop + statusTop,
                end = FlowSpacing.Lg,
                bottom = FlowLayout.BottomNavigationScrollPadding,
            ),
        ) {
            if (account != null) {
                item(key = "account") {
                    SettingsGroup {
                        SettingsRow(
                            icon = Icons.Outlined.Person,
                            title = account.displayName,
                            subtitle = "@${account.login}",
                            trailing = { Text("Connected") },
                        )
                        SettingsDivider()
                        SettingsRow(
                            icon = Icons.Default.Sync,
                            title = "Switch Twitch account",
                            subtitle = "Log in with a different Twitch account.",
                            onClick = onSwitchAccount,
                            trailing = { Icon(Icons.Default.ChevronRight, contentDescription = null) },
                        )
                        SettingsDivider()
                        SettingsRow(
                            icon = Icons.AutoMirrored.Filled.Logout,
                            title = "Sign out of Twitch",
                            subtitle = "Continue without an account.",
                            onClick = onSignOut,
                            trailing = { Icon(Icons.Default.ChevronRight, contentDescription = null) },
                        )
                    }
                    Spacer(Modifier.height(FlowSpacing.Md))
                }
            }
            item(key = "theme") {
                SettingsGroup {
                    Column(Modifier.padding(horizontal = FlowSpacing.Lg, vertical = FlowSpacing.Md)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            SettingsIcon(
                                themeModeIcon(
                                    mode = state.themeMode,
                                    dark = MaterialTheme.colorScheme.background == Color.Black,
                                ),
                            )
                            Spacer(Modifier.width(FlowSpacing.Md))
                            Column(Modifier.weight(1f)) {
                                SettingsTitle("Theme")
                                Spacer(Modifier.height(3.dp))
                                SettingsSubtitle("Choose how Flow looks.")
                            }
                        }
                        Spacer(Modifier.height(FlowSpacing.Md))
                        ThemeModeControl(
                            mode = state.themeMode,
                            onSelect = { launchUpdate { settingsRepository.setThemeMode(it) } },
                        )
                    }
                }
                Spacer(Modifier.height(FlowSpacing.Md))
            }
            item(key = "ad_proxy_header") {
                SettingsGroup {
                    SettingsRow(
                        icon = Icons.Outlined.Shield,
                        title = "Ad proxying",
                        subtitle = "Proxy only Twitch ad-assignment requests; stream media stays direct.",
                        trailing = {
                            Switch(
                                checked = state.adProxyEnabled,
                                onCheckedChange = {
                                    launchUpdate { settingsRepository.setAdProxyEnabled(it) }
                                },
                            )
                        },
                    )
                    SettingsDivider()
                    SettingsListHeader("Proxies") {
                        promptValue = ""
                        promptError = null
                        prompt = SettingsPrompt.PROXY
                    }
                    if (state.adProxyUrls.isEmpty()) {
                        SettingsEmptyList("Add at least one HTTP proxy.")
                    } else {
                        state.adProxyUrls.forEachIndexed { index, url ->
                            ProxyRow(
                                index = index,
                                url = url,
                                count = state.adProxyUrls.size,
                                onMove = { offset ->
                                    val updated = state.adProxyUrls.toMutableList()
                                    val target = index + offset
                                    if (target in updated.indices) {
                                        val value = updated.removeAt(index)
                                        updated.add(target, value)
                                        launchUpdate { settingsRepository.setAdProxyUrls(updated) }
                                    }
                                },
                                onRemove = {
                                    launchUpdate {
                                        settingsRepository.setAdProxyUrls(
                                            state.adProxyUrls.toMutableList().also { it.removeAt(index) },
                                        )
                                    }
                                },
                            )
                        }
                    }
                    SettingsDivider()
                    SettingsListHeader("Whitelisted channels") {
                        promptValue = ""
                        promptError = null
                        prompt = SettingsPrompt.CHANNEL
                    }
                    val effective = state.adProxyEffectiveWhitelistedChannels
                    if (effective.isEmpty()) {
                        SettingsEmptyList("Subscribed channels are added automatically.")
                    } else {
                        effective.forEach { channel ->
                            WhitelistRow(
                                channel = channel,
                                subscribed = channel in state.adProxySubscriptionChannels,
                                managedAutomatically = channel in state.adProxySubscriptionChannels &&
                                    channel !in state.adProxyWhitelistedChannels,
                                onRemove = {
                                    launchUpdate {
                                        settingsRepository.setAdProxyWhitelistedChannels(
                                            state.adProxyWhitelistedChannels - channel,
                                        )
                                    }
                                },
                            )
                        }
                    }
                }
                Spacer(Modifier.height(FlowSpacing.Md))
            }
            item(key = "about") {
                SettingsGroup {
                    SettingsRow(
                        icon = Icons.Outlined.Info,
                        title = "About Flow",
                        subtitle = "Mobile Twitch client.",
                        onClick = onOpenRepository,
                        trailing = { Text("1.0.0") },
                    )
                }
            }
        }

        if (loadError != null) {
            Button(
                onClick = {
                    loadError = null
                    scope.launch {
                        runCatching { settingsRepository.load() }
                            .onFailure { loadError = it.message ?: "Couldn't load settings." }
                    }
                },
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(top = statusTop),
            ) {
                Icon(Icons.Default.Refresh, contentDescription = null)
                Spacer(Modifier.width(FlowSpacing.Sm))
                Text("Couldn't load settings. Retry")
            }
        }
    }

    if (prompt != null) {
        val currentPrompt = requireNotNull(prompt)
        val focusRequester = remember(currentPrompt) { FocusRequester() }
        val keyboard = LocalSoftwareKeyboardController.current
        val title = if (currentPrompt == SettingsPrompt.PROXY) "Add HTTP proxy" else "Whitelist channel"
        val hint = if (currentPrompt == SettingsPrompt.PROXY) "http://host:port" else "channel_login"
        fun submitPrompt() {
            when (currentPrompt) {
                SettingsPrompt.PROXY -> {
                    val normalized = normalizeAdProxyUrl(promptValue)
                    promptError = when {
                        normalized == null -> "Enter an HTTP proxy URL without a path."
                        normalized in state.adProxyUrls -> "That proxy is already in the list."
                        else -> null
                    }
                    if (promptError == null) {
                        prompt = null
                        launchUpdate {
                            settingsRepository.setAdProxyUrls(state.adProxyUrls + normalized!!)
                        }
                    }
                }
                SettingsPrompt.CHANNEL -> {
                    val normalized = normalizeChannelLogins(listOf(promptValue)).singleOrNull()
                    promptError = when {
                        normalized == null -> "Enter a valid Twitch channel login."
                        normalized in state.adProxyEffectiveWhitelistedChannels ->
                            "That channel is already whitelisted."
                        else -> null
                    }
                    if (promptError == null) {
                        prompt = null
                        launchUpdate {
                            settingsRepository.setAdProxyWhitelistedChannels(
                                state.adProxyWhitelistedChannels + normalized!!,
                            )
                        }
                    }
                }
            }
        }
        LaunchedEffect(currentPrompt) {
            focusRequester.requestFocus()
            keyboard?.show()
        }
        val dialogShape = RoundedCornerShape(16.dp)
        AlertDialog(
            onDismissRequest = { prompt = null },
            modifier = Modifier
                .width(280.dp)
                .border(
                    width = 0.5.dp,
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                    shape = dialogShape,
                ),
            shape = dialogShape,
            containerColor = MaterialTheme.colorScheme.background,
            tonalElevation = 0.dp,
            title = {
                FlutterDialogDimAmount()
                Text(title)
            },
            text = {
                SettingsPromptField(
                    value = promptValue,
                    onValueChange = {
                        promptValue = it
                        promptError = null
                    },
                    hint = hint,
                    error = promptError,
                    onSubmit = ::submitPrompt,
                    modifier = Modifier.focusRequester(focusRequester),
                )
            },
            dismissButton = { TextButton(onClick = { prompt = null }) { Text("Cancel") } },
            confirmButton = {
                Button(
                    onClick = ::submitPrompt,
                ) { Text("Add") }
            },
        )
    }
}

/** Flutter's default modal barrier is black at 54% opacity. */
@Composable
private fun FlutterDialogDimAmount() {
    val dialogView = LocalView.current
    SideEffect {
        (dialogView.parent as? DialogWindowProvider)?.window?.setDimAmount(0.54f)
    }
}

@Composable
private fun SettingsPromptField(
    value: String,
    onValueChange: (String) -> Unit,
    hint: String,
    error: String?,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val focused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(100.dp)
    val colors = TextFieldDefaults.colors(
        focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.6f),
        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.6f),
        disabledContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.6f),
        focusedIndicatorColor = Color.Transparent,
        unfocusedIndicatorColor = Color.Transparent,
        disabledIndicatorColor = Color.Transparent,
        cursorColor = MaterialTheme.colorScheme.primary,
    )
    Column {
        CompositionLocalProvider(LocalTextSelectionColors provides colors.textSelectionColors) {
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .border(
                        width = 1.5.dp,
                        color = if (focused) {
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.8f)
                        } else {
                            Color.Transparent
                        },
                        shape = shape,
                    ),
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge.copy(
                    color = MaterialTheme.colorScheme.onSurface,
                    platformStyle = PlatformTextStyle(includeFontPadding = false),
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { onSubmit() }),
                interactionSource = interactionSource,
                cursorBrush = SolidColor(colors.cursorColor),
                decorationBox = { innerTextField ->
                    TextFieldDefaults.DecorationBox(
                        value = value,
                        innerTextField = innerTextField,
                        enabled = true,
                        singleLine = true,
                        visualTransformation = VisualTransformation.None,
                        interactionSource = interactionSource,
                        placeholder = {
                            Text(
                                text = hint,
                                maxLines = 1,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                fontWeight = FontWeight.Normal,
                                style = MaterialTheme.typography.bodyLarge.copy(
                                    platformStyle = PlatformTextStyle(includeFontPadding = false),
                                ),
                            )
                        },
                        shape = shape,
                        colors = colors,
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    )
                },
            )
        }
        if (error != null) {
            Text(
                text = error,
                modifier = Modifier.padding(start = FlowSpacing.Lg, top = FlowSpacing.Xs),
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun SettingsGroup(content: @Composable ColumnScope.() -> Unit) {
    val isDark = MaterialTheme.colorScheme.background == Color.Black
    val shape = RoundedCornerShape(FlowRadius.Large)
    val shadowColor = Color.Black.copy(alpha = if (isDark) 0.20f else 0.05f)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 24.dp,
                shape = shape,
                clip = false,
                ambientColor = shadowColor,
                spotColor = shadowColor,
            )
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(
                BorderStroke(
                    1.dp,
                    MaterialTheme.colorScheme.outlineVariant.copy(
                        alpha = if (isDark) 0.14f else 0.42f,
                    ),
                ),
                shape,
            )
            .clip(shape),
        content = content,
    )
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (onClick != null) {
                    Modifier.clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        role = Role.Button,
                        onClick = onClick,
                    )
                } else {
                    Modifier
                },
            )
            .padding(horizontal = FlowSpacing.Lg, vertical = FlowSpacing.Md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SettingsIcon(icon)
        Spacer(Modifier.width(FlowSpacing.Md))
        Column(Modifier.weight(1f)) {
            SettingsTitle(title)
            Spacer(Modifier.height(3.dp))
            SettingsSubtitle(subtitle)
        }
        if (trailing != null) {
            Spacer(Modifier.width(FlowSpacing.Md))
            Box(contentAlignment = Alignment.Center) {
                val muted = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
                CompositionLocalProvider(LocalContentColor provides muted) {
                    androidx.compose.material3.ProvideTextStyle(
                        MaterialTheme.typography.bodyMedium.copy(
                            color = muted,
                            fontWeight = FontWeight.Bold,
                        ),
                        trailing,
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsIcon(icon: ImageVector) {
    Box(
        Modifier
            .size(36.dp)
            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.16f), RoundedCornerShape(FlowRadius.Small)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.9f),
        )
    }
}

@Composable
private fun SettingsTitle(text: String) = Text(
    text = text,
    maxLines = 1,
    overflow = TextOverflow.Ellipsis,
    color = MaterialTheme.colorScheme.onSurface,
    style = MaterialTheme.typography.titleMedium,
    fontWeight = FontWeight.ExtraBold,
)

@Composable
private fun SettingsSubtitle(text: String) = Text(
    text = text,
    maxLines = 2,
    overflow = TextOverflow.Ellipsis,
    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
    style = MaterialTheme.typography.bodyMedium,
    fontWeight = FontWeight.SemiBold,
)

@Composable
private fun SettingsDivider() = HorizontalDivider(
    modifier = Modifier.height(1.dp),
    thickness = 0.5.dp,
    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
)

@Composable
private fun ThemeModeControl(mode: FlowThemeMode, onSelect: (FlowThemeMode) -> Unit) {
    ExactSlidingSegmentedControl(
        options = FlowThemeMode.entries.map { option ->
            option to option.name.lowercase().replaceFirstChar(Char::uppercase)
        },
        selected = mode,
        onSelect = onSelect,
    )
}

private fun themeModeIcon(mode: FlowThemeMode, dark: Boolean): ImageVector = when (mode) {
    FlowThemeMode.LIGHT -> Icons.Outlined.LightMode
    FlowThemeMode.DARK -> Icons.Outlined.DarkMode
    FlowThemeMode.SYSTEM -> if (dark) Icons.Outlined.DarkMode else Icons.Outlined.LightMode
}

@Composable
private fun SettingsListHeader(title: String, onAdd: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(start = FlowSpacing.Lg, top = FlowSpacing.Sm, end = FlowSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.titleSmall,
        )
        FlowTooltipAction(
            label = "Add $title",
            onClick = onAdd,
            modifier = Modifier.size(48.dp),
        ) {
            Icon(
                Icons.Default.Add,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun SettingsEmptyList(message: String) = Text(
    text = message,
    modifier = Modifier.padding(start = FlowSpacing.Lg, end = FlowSpacing.Lg, bottom = FlowSpacing.Md),
    color = MaterialTheme.colorScheme.onSurfaceVariant,
    style = MaterialTheme.typography.bodySmall,
)

@Composable
private fun ProxyRow(
    index: Int,
    url: String,
    count: Int,
    onMove: (Int) -> Unit,
    onRemove: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().padding(start = FlowSpacing.Lg, bottom = FlowSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                text = if (index == 0) "Main" else "Fallback $index",
                color = MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontSize = 15.sp,
                    lineHeight = 22.5.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
            Text(
                text = displayProxyUrl(url),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp, lineHeight = 18.2.sp),
            )
        }
        FlowTooltipAction(
            label = "Move up",
            onClick = { onMove(-1) },
            modifier = Modifier.size(48.dp),
            enabled = index > 0,
        ) {
            Icon(
                Icons.Default.ArrowUpward,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            )
        }
        FlowTooltipAction(
            label = "Move down",
            onClick = { onMove(1) },
            modifier = Modifier.size(48.dp),
            enabled = index < count - 1,
        ) {
            Icon(
                Icons.Default.ArrowDownward,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            )
        }
        FlowTooltipAction(
            label = "Remove proxy",
            onClick = onRemove,
            modifier = Modifier.size(48.dp),
        ) {
            Icon(
                Icons.Default.DeleteOutline,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            )
        }
    }
}

@Composable
private fun WhitelistRow(
    channel: String,
    subscribed: Boolean,
    managedAutomatically: Boolean,
    onRemove: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().padding(start = FlowSpacing.Lg, bottom = FlowSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                text = channel,
                color = MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontSize = 15.sp,
                    lineHeight = 22.5.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
            if (subscribed) {
                Text(
                    text = "Subscribed channel",
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp, lineHeight = 18.2.sp),
                )
            }
        }
        if (managedAutomatically) {
            FlowTooltip("Managed automatically") {
                Icon(
                    Icons.Outlined.Lock,
                    contentDescription = "Managed automatically",
                    modifier = Modifier.padding(12.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                )
            }
        } else {
            FlowTooltipAction(
                label = "Remove channel",
                onClick = onRemove,
                modifier = Modifier.size(48.dp),
            ) {
                Icon(
                    Icons.Default.DeleteOutline,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                )
            }
        }
    }
}

private fun displayProxyUrl(value: String): String {
    val uri = runCatching { URI(value) }.getOrNull() ?: return value
    if (uri.userInfo.isNullOrEmpty()) return value
    return runCatching { URI(uri.scheme, null, uri.host, uri.port, uri.path, null, null).toString() }
        .getOrDefault(value)
}
