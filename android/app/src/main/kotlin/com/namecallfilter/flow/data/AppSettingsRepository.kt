package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

data class AppSettingsState(
    val themeMode: FlowThemeMode = FlowThemeMode.SYSTEM,
    val adProxyEnabled: Boolean = false,
    val adProxyUrls: List<String> = emptyList(),
    val adProxyWhitelistedChannels: List<String> = emptyList(),
    val adProxySubscriptionChannels: List<String> = emptyList(),
    val isLoaded: Boolean = false,
) {
    val adProxyEffectiveWhitelistedChannels: List<String>
        get() = normalizeChannelLogins(
            adProxyWhitelistedChannels + adProxySubscriptionChannels,
        )
}

class AppSettingsRepository(val preferences: FlowPreferences) {
    private val loadLock = Any()
    private var activeLoad: CompletableDeferred<Unit>? = null
    private val subscriptionMutex = Mutex()
    private val mutableState = MutableStateFlow(AppSettingsState())
    val state: StateFlow<AppSettingsState> = mutableState.asStateFlow()

    suspend fun load() {
        val (operation, leader) = synchronized(loadLock) {
            if (mutableState.value.isLoaded) return
            activeLoad?.let { return@synchronized it to false }
            CompletableDeferred<Unit>().also { activeLoad = it } to true
        }
        if (!leader) {
            operation.await()
            return
        }

        var failure: Throwable? = null
        try {
            loadOnce()
        } catch (error: Throwable) {
            failure = error
            throw error
        } finally {
            synchronized(loadLock) {
                if (activeLoad === operation) activeLoad = null
            }
            if (failure == null) operation.complete(Unit) else operation.completeExceptionally(failure)
        }
    }

    private suspend fun loadOnce() = coroutineScope {
        val theme = async { preferences.readThemeMode() }
        val enabled = async { preferences.readAdProxyEnabled() }
        val urls = async { preferences.readAdProxyUrls() }
        val whitelist = async { preferences.readAdProxyWhitelistedChannels() }
        val subscriptions = async {
            subscriptionMutex.withLock {
                val channels = preferences.readAdProxySubscriptionChannels()
                mutableState.value = mutableState.value.copy(
                    adProxySubscriptionChannels = channels,
                )
            }
        }
        subscriptions.await()
        mutableState.value = mutableState.value.copy(
            themeMode = theme.await(),
            adProxyEnabled = enabled.await(),
            adProxyUrls = urls.await(),
            adProxyWhitelistedChannels = whitelist.await(),
            isLoaded = true,
        )
    }

    suspend fun setThemeMode(mode: FlowThemeMode) {
        if (mutableState.value.themeMode == mode) return
        mutableState.value = mutableState.value.copy(themeMode = mode)
        preferences.saveThemeMode(mode)
    }

    suspend fun setAdProxyEnabled(enabled: Boolean) {
        mutableState.value = mutableState.value.copy(adProxyEnabled = enabled)
        preferences.saveAdProxyEnabled(enabled)
    }

    suspend fun setAdProxyUrls(urls: List<String>) {
        val normalized = normalizeAdProxyUrls(urls)
        mutableState.value = mutableState.value.copy(adProxyUrls = normalized)
        preferences.saveAdProxyUrls(normalized)
    }

    suspend fun setAdProxyWhitelistedChannels(channels: List<String>) {
        val normalized = normalizeChannelLogins(channels)
        mutableState.value = mutableState.value.copy(adProxyWhitelistedChannels = normalized)
        preferences.saveAdProxyWhitelistedChannels(normalized)
    }

    suspend fun syncAdProxySubscriptionChannel(login: String, isSubscribed: Boolean) =
        subscriptionMutex.withLock {
            val normalizedLogin = normalizeChannelLogins(listOf(login)).singleOrNull()
                ?: return@withLock
            val channels = mutableState.value.adProxySubscriptionChannels.toMutableList()
            val contains = normalizedLogin in channels
            if (contains != isSubscribed) {
                if (isSubscribed) channels += normalizedLogin else channels.remove(normalizedLogin)
            }
            val normalized = normalizeChannelLogins(channels)
            if (contains != isSubscribed) preferences.saveAdProxySubscriptionChannels(normalized)
            mutableState.value = mutableState.value.copy(adProxySubscriptionChannels = normalized)
        }
}
