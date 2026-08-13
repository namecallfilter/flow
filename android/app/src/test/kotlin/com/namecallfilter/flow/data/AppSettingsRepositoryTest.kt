package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class AppSettingsRepositoryTest {
    @Test fun `concurrent failed loads share one operation and one failure`() = runTest {
        val store = RecordingPreferencesStore().apply {
            blockThemeRead = true
            failThemeRead = true
        }
        val repository = AppSettingsRepository(DefaultFlowPreferences(store))

        val first = async { runCatching { repository.load() }.exceptionOrNull() }
        store.themeReadStarted.await()
        val second = async { runCatching { repository.load() }.exceptionOrNull() }
        runCurrent()
        assertEquals(1, store.themeReads)

        store.releaseThemeRead.complete(Unit)
        assertTrue(first.await() is IOException)
        assertTrue(second.await() is IOException)
        assertEquals(1, store.themeReads)
    }

    @Test fun `subscription updates are serialized and the second update sees the first`() = runTest {
        val store = RecordingPreferencesStore().apply { blockFirstSubscriptionWrite = true }
        val repository = AppSettingsRepository(DefaultFlowPreferences(store))
        repository.load()

        val first = async { repository.syncAdProxySubscriptionChannel(" first ", true) }
        store.firstSubscriptionWriteStarted.await()
        val second = async { repository.syncAdProxySubscriptionChannel("SECOND", true) }
        runCurrent()
        assertEquals(listOf(listOf("first")), store.subscriptionWrites)

        store.releaseFirstSubscriptionWrite.complete(Unit)
        first.await()
        second.await()

        assertEquals(
            listOf(listOf("first"), listOf("first", "second")),
            store.subscriptionWrites,
        )
        assertEquals(listOf("first", "second"), repository.state.value.adProxySubscriptionChannels)
    }

    @Test fun `failed subscription persistence leaves observable state unchanged`() = runTest {
        val store = RecordingPreferencesStore().apply {
            lists[DefaultFlowPreferences.AD_PROXY_SUBSCRIPTION_CHANNELS_KEY] = listOf("existing")
        }
        val repository = AppSettingsRepository(DefaultFlowPreferences(store))
        repository.load()
        store.failNextSubscriptionWrite = true

        val failure = runCatching {
            repository.syncAdProxySubscriptionChannel("new_channel", true)
        }.exceptionOrNull()

        assertTrue(failure is IOException)
        assertEquals(listOf("existing"), repository.state.value.adProxySubscriptionChannels)
        assertEquals(
            listOf("existing"),
            store.lists[DefaultFlowPreferences.AD_PROXY_SUBSCRIPTION_CHANNELS_KEY],
        )
    }

    @Test fun `ordinary setting writes remain optimistic when persistence fails`() = runTest {
        val store = RecordingPreferencesStore()
        val repository = AppSettingsRepository(DefaultFlowPreferences(store))
        repository.load()
        store.failNextStringWrite = true

        val failure = runCatching { repository.setThemeMode(FlowThemeMode.DARK) }.exceptionOrNull()

        assertTrue(failure is IOException)
        assertEquals(FlowThemeMode.DARK, repository.state.value.themeMode)
    }

    private class RecordingPreferencesStore : FlowPreferencesStore {
        val strings = mutableMapOf<String, String>()
        val lists = mutableMapOf<String, List<String>>()
        val subscriptionWrites = mutableListOf<List<String>>()
        val firstSubscriptionWriteStarted = CompletableDeferred<Unit>()
        val releaseFirstSubscriptionWrite = CompletableDeferred<Unit>()
        val themeReadStarted = CompletableDeferred<Unit>()
        val releaseThemeRead = CompletableDeferred<Unit>()
        var blockFirstSubscriptionWrite = false
        var blockThemeRead = false
        var failThemeRead = false
        var failNextSubscriptionWrite = false
        var failNextStringWrite = false
        var themeReads = 0

        override suspend fun getString(key: String): String? {
            if (key == DefaultFlowPreferences.THEME_MODE_KEY) {
                themeReads += 1
                if (blockThemeRead) {
                    themeReadStarted.complete(Unit)
                    releaseThemeRead.await()
                }
                if (failThemeRead) throw IOException("theme read failed")
            }
            return strings[key]
        }

        override suspend fun putString(key: String, value: String) {
            if (failNextStringWrite) {
                failNextStringWrite = false
                throw IOException("string write failed")
            }
            strings[key] = value
        }

        override suspend fun getStringList(key: String): List<String>? = lists[key]?.toList()

        override suspend fun putStringList(key: String, value: List<String>) {
            if (key == DefaultFlowPreferences.AD_PROXY_SUBSCRIPTION_CHANNELS_KEY) {
                subscriptionWrites += value.toList()
                if (failNextSubscriptionWrite) {
                    failNextSubscriptionWrite = false
                    throw IOException("subscription write failed")
                }
                if (blockFirstSubscriptionWrite && subscriptionWrites.size == 1) {
                    firstSubscriptionWriteStarted.complete(Unit)
                    releaseFirstSubscriptionWrite.await()
                }
            }
            lists[key] = value.toList()
        }

        override suspend fun remove(key: String) {
            strings.remove(key)
            lists.remove(key)
        }
    }
}
