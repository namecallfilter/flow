package com.namecallfilter.flow.data

import java.net.URI
import java.util.Locale

interface FlowPreferences {
    suspend fun readThemeMode(): FlowThemeMode
    suspend fun saveThemeMode(mode: FlowThemeMode)
    suspend fun readAdProxyEnabled(): Boolean
    suspend fun saveAdProxyEnabled(enabled: Boolean)
    suspend fun readAdProxyUrls(): List<String>
    suspend fun saveAdProxyUrls(urls: List<String>)
    suspend fun readAdProxyWhitelistedChannels(): List<String>
    suspend fun saveAdProxyWhitelistedChannels(channels: List<String>)
    suspend fun readAdProxySubscriptionChannels(): List<String>
    suspend fun saveAdProxySubscriptionChannels(channels: List<String>)
    suspend fun readBrowseSearchHistory(): List<String>
    suspend fun saveBrowseSearchHistory(history: List<String>)
    suspend fun clearBrowseSearchHistory()
    suspend fun readLoginOfferDismissed(): Boolean
    suspend fun saveLoginOfferDismissed(dismissed: Boolean)
}

interface FlowPreferencesStore {
    suspend fun getString(key: String): String?
    suspend fun putString(key: String, value: String)
    suspend fun getStringList(key: String): List<String>?
    suspend fun putStringList(key: String, value: List<String>)
    suspend fun remove(key: String)
}

class DefaultFlowPreferences(
    private val store: FlowPreferencesStore,
) : FlowPreferences {
    override suspend fun readThemeMode(): FlowThemeMode = themeModeFromPreference(
        store.getString(THEME_MODE_KEY),
    )

    override suspend fun saveThemeMode(mode: FlowThemeMode) {
        store.putString(THEME_MODE_KEY, themeModePreferenceValue(mode))
    }

    override suspend fun readAdProxyEnabled(): Boolean =
        store.getString(AD_PROXY_ENABLED_KEY) == "true"

    override suspend fun saveAdProxyEnabled(enabled: Boolean) {
        store.putString(AD_PROXY_ENABLED_KEY, enabled.toString())
    }

    override suspend fun readAdProxyUrls(): List<String> = normalizeAdProxyUrls(
        store.getStringList(AD_PROXY_URLS_KEY).orEmpty(),
    )

    override suspend fun saveAdProxyUrls(urls: List<String>) {
        store.putStringList(AD_PROXY_URLS_KEY, normalizeAdProxyUrls(urls))
    }

    override suspend fun readAdProxyWhitelistedChannels(): List<String> = normalizeChannelLogins(
        store.getStringList(AD_PROXY_WHITELISTED_CHANNELS_KEY).orEmpty(),
    )

    override suspend fun saveAdProxyWhitelistedChannels(channels: List<String>) {
        store.putStringList(AD_PROXY_WHITELISTED_CHANNELS_KEY, normalizeChannelLogins(channels))
    }

    override suspend fun readAdProxySubscriptionChannels(): List<String> = normalizeChannelLogins(
        store.getStringList(AD_PROXY_SUBSCRIPTION_CHANNELS_KEY).orEmpty(),
    )

    override suspend fun saveAdProxySubscriptionChannels(channels: List<String>) {
        store.putStringList(AD_PROXY_SUBSCRIPTION_CHANNELS_KEY, normalizeChannelLogins(channels))
    }

    override suspend fun readBrowseSearchHistory(): List<String> = normalizeBrowseSearchHistory(
        store.getStringList(BROWSE_SEARCH_HISTORY_KEY).orEmpty(),
    )

    override suspend fun saveBrowseSearchHistory(history: List<String>) {
        val normalized = normalizeBrowseSearchHistory(history)
        if (normalized.isEmpty()) {
            clearBrowseSearchHistory()
        } else {
            store.putStringList(BROWSE_SEARCH_HISTORY_KEY, normalized)
        }
    }

    override suspend fun clearBrowseSearchHistory() {
        store.remove(BROWSE_SEARCH_HISTORY_KEY)
    }

    override suspend fun readLoginOfferDismissed(): Boolean =
        store.getString(LOGIN_OFFER_DISMISSED_KEY) == "true"

    override suspend fun saveLoginOfferDismissed(dismissed: Boolean) {
        store.putString(LOGIN_OFFER_DISMISSED_KEY, dismissed.toString())
    }

    companion object {
        const val THEME_MODE_KEY = "flow_theme_mode"
        const val AD_PROXY_ENABLED_KEY = "ad_proxy_enabled"
        const val AD_PROXY_URLS_KEY = "ad_proxy_urls"
        const val AD_PROXY_WHITELISTED_CHANNELS_KEY = "ad_proxy_whitelisted_channels"
        const val AD_PROXY_SUBSCRIPTION_CHANNELS_KEY = "ad_proxy_subscription_channels"
        const val BROWSE_SEARCH_HISTORY_KEY = "browse_search_history"
        const val LOGIN_OFFER_DISMISSED_KEY = "login_offer_dismissed"
    }
}

fun themeModeFromPreference(value: String?): FlowThemeMode = when (value) {
    "light" -> FlowThemeMode.LIGHT
    "dark" -> FlowThemeMode.DARK
    else -> FlowThemeMode.SYSTEM
}

fun themeModePreferenceValue(mode: FlowThemeMode): String = when (mode) {
    FlowThemeMode.LIGHT -> "light"
    FlowThemeMode.DARK -> "dark"
    FlowThemeMode.SYSTEM -> "system"
}

fun normalizeBrowseSearchHistory(values: Iterable<String>): List<String> {
    val seen = mutableSetOf<String>()
    val result = mutableListOf<String>()
    for (rawValue in values) {
        val value = rawValue.trim()
        if (value.isEmpty() || !seen.add(value.lowercase(Locale.ROOT))) continue
        result += value
        if (result.size == 8) break
    }
    return result
}

fun normalizeAdProxyUrls(values: Iterable<String>): List<String> {
    val seen = mutableSetOf<String>()
    return buildList {
        for (rawValue in values) {
            val value = normalizeAdProxyUrl(rawValue) ?: continue
            if (seen.add(value.lowercase(Locale.ROOT))) add(value)
        }
    }
}

fun normalizeAdProxyUrl(value: String): String? {
    val trimmed = value.trim()
    val uri = runCatching { URI(trimmed) }.getOrNull() ?: return null
    if (!uri.scheme.equals("http", ignoreCase = true) || uri.host.isNullOrEmpty()) return null
    if (uri.rawQuery != null || uri.rawFragment != null) return null
    if (!uri.rawPath.isNullOrEmpty() && uri.rawPath != "/") return null
    if (uri.rawAuthority?.contains('@') == true) {
        val username = uri.rawUserInfo.orEmpty().substringBefore(':')
        if (username.isEmpty()) return null
    }
    val port = if (uri.port == -1) 80 else uri.port
    if (port !in 1..65_535) return null
    return try {
        val host = uri.host!!.lowercase(Locale.ROOT)
        val renderedHost = if (host.startsWith('[')) host else host
        val authority = buildString {
            uri.rawUserInfo?.let { append(it).append('@') }
            append(renderedHost)
            if (uri.port != -1) append(':').append(port)
        }
        // Build from the already-escaped authority so percent-encoded proxy credentials are
        // preserved rather than encoded a second time by the component URI constructor.
        URI("http://$authority").toASCIIString()
    } catch (_: Exception) {
        null
    }
}

fun normalizeChannelLogins(values: Iterable<String>): List<String> {
    val seen = mutableSetOf<String>()
    val pattern = Regex("^[a-z0-9_]{1,25}$")
    return buildList {
        for (rawValue in values) {
            val value = rawValue.trim().lowercase(Locale.ROOT)
            if (pattern.matches(value) && seen.add(value)) add(value)
        }
    }
}
