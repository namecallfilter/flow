package com.namecallfilter.flow.data

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import java.security.KeyStore

@RunWith(AndroidJUnit4::class)
class AndroidKeystoreTwitchSecureStoreTest {
    @Test fun generatedIvRoundTripsOnAndroidKeystore() = runBlocking {
        val testId = System.nanoTime().toString()
        val preferencesPrefix = "FlowSecureStoreRegression-$testId-"
        val testContext = object : ContextWrapper(
            InstrumentationRegistry.getInstrumentation().targetContext,
        ) {
            override fun getApplicationContext(): Context = this

            override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
                super.getSharedPreferences("$preferencesPrefix$name", mode)
        }
        val preferencesName = "FlowSecureStorageTest-$testId"
        val keyAlias = "com.namecallfilter.flow.FlowTokenKey.test.$testId"
        val preferences = testContext.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val store = AndroidKeystoreTwitchSecureStore(testContext, preferencesName, keyAlias)

        try {
            store.savePendingState("oauth-state")
            assertEquals("oauth-state", store.readPendingState())

            store.saveAccessToken("same-token")
            val firstCiphertext = preferences.getString(
                AndroidKeystoreTwitchSecureStore.ACCESS_TOKEN_KEY,
                null,
            )
            store.saveAccessToken("same-token")
            val secondCiphertext = preferences.getString(
                AndroidKeystoreTwitchSecureStore.ACCESS_TOKEN_KEY,
                null,
            )
            assertNotNull(firstCiphertext)
            assertNotNull(secondCiphertext)
            assertFalse(firstCiphertext == secondCiphertext)
            assertEquals("same-token", store.readAccessToken())

            store.saveWebSessionToken("web-token")
            assertEquals("web-token", store.readWebSessionToken())
            store.clearSession()
            assertNull(store.readPendingState())
            assertNull(store.readAccessToken())
            assertNull(store.readWebSessionToken())
        } finally {
            preferences.edit().clear().commit()
            KeyStore.getInstance("AndroidKeyStore").apply {
                load(null)
                if (containsAlias(keyAlias)) deleteEntry(keyAlias)
            }
        }
    }
}
