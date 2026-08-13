package com.namecallfilter.flow.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import org.json.JSONArray

private const val FLUTTER_DATASTORE_NAME = "FlutterSharedPreferences"
private const val FLUTTER_LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"
private const val FLUTTER_JSON_LIST_PREFIX = "$FLUTTER_LIST_PREFIX!"

private val Context.flowFlutterPreferencesDataStore: DataStore<Preferences> by preferencesDataStore(
    name = FLUTTER_DATASTORE_NAME,
)

/**
 * Reads the exact DataStore file and JSON-list encoding used by
 * shared_preferences_android 2.4.26's SharedPreferencesAsync backend. Keeping the same
 * application id and this store name makes the Compose rewrite an in-place upgrade.
 */
class AndroidFlowPreferencesStore(context: Context) : FlowPreferencesStore {
    private val dataStore = context.applicationContext.flowFlutterPreferencesDataStore

    override suspend fun getString(key: String): String? =
        dataStore.data.first()[stringPreferencesKey(key)]

    override suspend fun putString(key: String, value: String) {
        require(!value.startsWith(FLUTTER_LIST_PREFIX)) {
            "String value collides with the Flutter string-list marker"
        }
        dataStore.edit { it[stringPreferencesKey(key)] = value }
    }

    override suspend fun getStringList(key: String): List<String>? {
        val raw = getString(key) ?: return null
        if (!raw.startsWith(FLUTTER_JSON_LIST_PREFIX)) return null
        val array = JSONArray(raw.substring(FLUTTER_JSON_LIST_PREFIX.length))
        return List(array.length()) { index -> array.getString(index) }
    }

    override suspend fun putStringList(key: String, value: List<String>) {
        val array = JSONArray()
        value.forEach(array::put)
        dataStore.edit {
            it[stringPreferencesKey(key)] = FLUTTER_JSON_LIST_PREFIX + array.toString()
        }
    }

    override suspend fun remove(key: String) {
        dataStore.edit { it.remove(stringPreferencesKey(key)) }
    }
}
