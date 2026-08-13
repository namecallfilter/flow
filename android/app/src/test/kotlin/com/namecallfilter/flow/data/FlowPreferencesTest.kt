package com.namecallfilter.flow.data

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FlowPreferencesTest {
    @Test fun `normalizes history and retains only eight unique values`() = runTest {
        val store = MemoryPreferencesStore()
        val preferences = DefaultFlowPreferences(store)
        preferences.saveBrowseSearchHistory(
            listOf(" mine ", "Mine", "", "VALORANT", "just chatting", "apex", "Dota",
                "counter-strike", "retro", "music"),
        )
        assertEquals(
            listOf("mine", "VALORANT", "just chatting", "apex", "Dota", "counter-strike", "retro", "music"),
            preferences.readBrowseSearchHistory(),
        )
        preferences.clearBrowseSearchHistory()
        assertTrue(preferences.readBrowseSearchHistory().isEmpty())
    }

    @Test fun `uses exact Flutter keys and normalizes proxy settings`() = runTest {
        val store = MemoryPreferencesStore()
        val preferences = DefaultFlowPreferences(store)
        preferences.saveAdProxyEnabled(true)
        preferences.saveAdProxyUrls(
            listOf(
                " http://main.example:8080 ", "https://not-http.example",
                "http://fallback.example:3128/", "HTTP://MAIN.EXAMPLE:8080",
                "http://proxy.example/path", "http://proxy.example:99999",
                "http://:password@proxy.example:8080",
                "http://user%20name:pass%40word@Proxy.Example:8080",
            ),
        )
        preferences.saveAdProxyWhitelistedChannels(
            listOf(" Creator ", "creator", "other_channel", "invalid-channel"),
        )
        assertEquals("true", store.strings[DefaultFlowPreferences.AD_PROXY_ENABLED_KEY])
        assertTrue(preferences.readAdProxyEnabled())
        assertEquals(
            listOf(
                "http://main.example:8080",
                "http://fallback.example:3128",
                "http://user%20name:pass%40word@proxy.example:8080",
            ),
            preferences.readAdProxyUrls(),
        )
        assertEquals(listOf("creator", "other_channel"), preferences.readAdProxyWhitelistedChannels())
        assertFalse(preferences.readLoginOfferDismissed())
    }

    @Test fun `theme values are compatible with Flutter`() = runTest {
        val store = MemoryPreferencesStore()
        val preferences = DefaultFlowPreferences(store)
        preferences.saveThemeMode(FlowThemeMode.DARK)
        assertEquals("dark", store.strings[DefaultFlowPreferences.THEME_MODE_KEY])
        assertEquals(FlowThemeMode.DARK, preferences.readThemeMode())
    }
}

private class MemoryPreferencesStore : FlowPreferencesStore {
    val strings = mutableMapOf<String, String>()
    val lists = mutableMapOf<String, List<String>>()
    override suspend fun getString(key: String) = strings[key]
    override suspend fun putString(key: String, value: String) { strings[key] = value }
    override suspend fun getStringList(key: String) = lists[key]?.toList()
    override suspend fun putStringList(key: String, value: List<String>) { lists[key] = value.toList() }
    override suspend fun remove(key: String) { strings.remove(key); lists.remove(key) }
}
