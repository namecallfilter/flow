package com.namecallfilter.flow.data

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.PrivateKey
import java.security.spec.MGF1ParameterSpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import javax.crypto.spec.SecretKeySpec

interface TwitchSecureStore {
    suspend fun savePendingState(state: String)
    suspend fun readPendingState(): String?
    suspend fun clearPendingState()
    suspend fun saveAccessToken(token: String)
    suspend fun readAccessToken(): String?
    suspend fun saveWebSessionToken(token: String)
    suspend fun readWebSessionToken(): String?
    suspend fun clearSession()
}

/**
 * Android-Keystore backed replacement for flutter_secure_storage.
 *
 * The first read imports the three keys written by flutter_secure_storage 10.x (and its
 * historical RSA/PKCS1 + AES/CBC format), then removes those legacy values. This makes an
 * installed Flutter build upgrade in place without leaving OAuth credentials in plaintext.
 */
class AndroidKeystoreTwitchSecureStore internal constructor(
    context: Context,
    nativePreferencesName: String = NATIVE_PREFS_NAME,
    private val nativeKeyAlias: String = NATIVE_KEY_ALIAS,
) : TwitchSecureStore {
    private val appContext = context.applicationContext ?: context
    private val preferences = appContext.getSharedPreferences(nativePreferencesName, Context.MODE_PRIVATE)
    private val legacy = LegacyFlutterSecureStorageDecoder(appContext)
    private val mutex = Mutex()

    override suspend fun savePendingState(state: String) = write(PENDING_STATE_KEY, state)

    override suspend fun readPendingState(): String? = read(PENDING_STATE_KEY)

    override suspend fun clearPendingState() = withContext(Dispatchers.IO) {
        mutex.withLock {
            migrateIfNeeded()
            check(preferences.edit().remove(PENDING_STATE_KEY).commit()) {
                "Unable to clear pending Twitch sign-in."
            }
            legacy.remove(PENDING_STATE_KEY)
        }
    }

    override suspend fun saveAccessToken(token: String) = write(ACCESS_TOKEN_KEY, token)

    override suspend fun readAccessToken(): String? = read(ACCESS_TOKEN_KEY)

    override suspend fun saveWebSessionToken(token: String) = write(WEB_SESSION_TOKEN_KEY, token)

    override suspend fun readWebSessionToken(): String? = read(WEB_SESSION_TOKEN_KEY)

    override suspend fun clearSession() = withContext(Dispatchers.IO) {
        mutex.withLock {
            // Sign-out must always win, including when legacy data is corrupt or migration never ran.
            check(preferences.edit()
                .remove(PENDING_STATE_KEY)
                .remove(ACCESS_TOKEN_KEY)
                .remove(WEB_SESSION_TOKEN_KEY)
                .putBoolean(MIGRATION_COMPLETE_KEY, true)
                .commit()) { "Unable to clear Twitch credentials." }
            legacy.removeAll(KEYS)
        }
    }

    private suspend fun read(key: String): String? = withContext(Dispatchers.IO) {
        mutex.withLock {
            migrateIfNeeded()
            preferences.getString(key, null)?.let(::decryptNative)
        }
    }

    private suspend fun write(key: String, value: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            migrateIfNeeded()
            check(preferences.edit().putString(key, encryptNative(value)).commit()) {
                "Unable to persist Twitch credentials."
            }
        }
    }

    private fun migrateIfNeeded() {
        if (preferences.getBoolean(MIGRATION_COMPLETE_KEY, false)) return

        val migrated = buildMap {
            for (key in KEYS) {
                if (preferences.contains(key)) continue
                legacy.read(key)?.let { put(key, it) }
            }
        }
        val editor = preferences.edit()
        migrated.forEach { (key, value) -> editor.putString(key, encryptNative(value)) }
        editor.putBoolean(MIGRATION_COMPLETE_KEY, true)
        check(editor.commit()) { "Unable to migrate Twitch credentials." }
        legacy.removeAll(KEYS)
    }

    private fun encryptNative(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        // Android Keystore keys with randomized encryption enabled must generate their own IV.
        // Supplying one here throws "Caller-provided IV not permitted" on real devices.
        cipher.init(Cipher.ENCRYPT_MODE, nativeKey())
        val encrypted = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        val iv = requireNotNull(cipher.iv) { "Android Keystore did not generate an encryption IV." }
        require(iv.size == GCM_IV_BYTES) { "Unexpected Android Keystore GCM IV length." }
        return Base64.encodeToString(iv + encrypted, Base64.NO_WRAP)
    }

    private fun decryptNative(encoded: String): String {
        val payload = Base64.decode(encoded, Base64.DEFAULT)
        require(payload.size > GCM_IV_BYTES) { "Invalid encrypted Twitch credential." }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            nativeKey(),
            GCMParameterSpec(GCM_TAG_BITS, payload.copyOfRange(0, GCM_IV_BYTES)),
        )
        return String(cipher.doFinal(payload.copyOfRange(GCM_IV_BYTES, payload.size)), StandardCharsets.UTF_8)
    }

    private fun nativeKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(nativeKeyAlias, null) as? SecretKey)?.let { return it }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                nativeKeyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        const val PENDING_STATE_KEY = "twitch_oauth_pending_state"
        const val ACCESS_TOKEN_KEY = "twitch_access_token"
        const val WEB_SESSION_TOKEN_KEY = "twitch_web_session_token"

        private const val NATIVE_PREFS_NAME = "FlowSecureStorage"
        private const val NATIVE_KEY_ALIAS = "com.namecallfilter.flow.FlowTokenKey"
        private const val MIGRATION_COMPLETE_KEY = "flutter_secure_storage_migrated_v1"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val GCM_IV_BYTES = 12
        private const val GCM_TAG_BITS = 128
        private val KEYS = listOf(PENDING_STATE_KEY, ACCESS_TOKEN_KEY, WEB_SESSION_TOKEN_KEY)
    }
}

private class LegacyFlutterSecureStorageDecoder(private val context: Context) {
    private val data: SharedPreferences =
        context.getSharedPreferences(DATA_PREFS_NAME, Context.MODE_PRIVATE)
    private val keyStorage: SharedPreferences =
        context.getSharedPreferences(KEY_STORAGE_PREFS_NAME, Context.MODE_PRIVATE)
    private val namespacedConfig: SharedPreferences =
        context.getSharedPreferences("$CONFIG_PREFS_NAME:$DATA_PREFS_NAME", Context.MODE_PRIVATE)
    private val globalConfig: SharedPreferences =
        context.getSharedPreferences(CONFIG_PREFS_NAME, Context.MODE_PRIVATE)

    fun read(logicalKey: String): String? {
        val encoded = data.getString(prefixed(logicalKey), null) ?: return null
        val savedKeyAlgorithm = config(KEY_ALGORITHM_MARKER)
        val savedStorageAlgorithm = config(STORAGE_ALGORITHM_MARKER)
        val keyAlgorithm: String
        val storageAlgorithm: String
        if (savedKeyAlgorithm == null || savedStorageAlgorithm == null) {
            // flutter_secure_storage treats either missing marker as the pre-marker format.
            keyAlgorithm = HISTORICAL_KEY_ALGORITHM
            storageAlgorithm = HISTORICAL_STORAGE_ALGORITHM
        } else {
            keyAlgorithm = savedKeyAlgorithm
            storageAlgorithm = savedStorageAlgorithm
        }
        val aesKey = unwrapAesKey(keyAlgorithm, storageAlgorithm)
        val encrypted = Base64.decode(encoded, Base64.DEFAULT)
        val clear = when (storageAlgorithm) {
            "AES_GCM_NoPadding", "AES_GCM_NoPadding_BIOMETRIC" -> decryptGcm(encrypted, aesKey)
            "AES_CBC_PKCS7Padding" -> decryptCbc(encrypted, aesKey)
            else -> throw TwitchAuthException("Unsupported legacy secure-storage cipher: $storageAlgorithm")
        }
        return String(clear, StandardCharsets.UTF_8)
    }

    fun remove(logicalKey: String) {
        check(data.edit().remove(prefixed(logicalKey)).commit()) {
            "Unable to clear legacy Twitch credential."
        }
    }

    fun removeAll(logicalKeys: Iterable<String>) {
        val editor = data.edit()
        logicalKeys.forEach { editor.remove(prefixed(it)) }
        check(editor.commit()) { "Unable to clear legacy Twitch credentials." }
    }

    private fun config(key: String): String? =
        namespacedConfig.getString(key, null) ?: globalConfig.getString(key, null)

    private fun unwrapAesKey(keyAlgorithm: String, storageAlgorithm: String): SecretKey {
        val wrappedKeyName = when (storageAlgorithm) {
            "AES_GCM_NoPadding", "AES_GCM_NoPadding_BIOMETRIC" -> GCM_WRAPPED_KEY
            else -> CBC_WRAPPED_KEY
        }
        val wrapped = keyStorage.getString(wrappedKeyName, null)
            ?: throw TwitchAuthException("Legacy Twitch credential key is missing.")
        val alias = when (keyAlgorithm) {
            "RSA_ECB_OAEPwithSHA_256andMGF1Padding" ->
                context.packageName + ".FlutterSecureStoragePluginKeyOAEP"
            "RSA_ECB_PKCS1Padding" -> context.packageName + ".FlutterSecureStoragePluginKey"
            else -> throw TwitchAuthException("Unsupported legacy secure-storage key cipher: $keyAlgorithm")
        }
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val privateKey = keyStore.getKey(alias, null) as? PrivateKey
            ?: throw TwitchAuthException("Legacy Twitch credential key is unavailable.")
        val cipher = when (keyAlgorithm) {
            "RSA_ECB_OAEPwithSHA_256andMGF1Padding" -> Cipher.getInstance(
                "RSA/ECB/OAEPPadding",
                ANDROID_KEYSTORE_RSA_PROVIDER,
            ).apply {
                val spec = OAEPParameterSpec(
                    "SHA-256",
                    "MGF1",
                    MGF1ParameterSpec.SHA1,
                    PSource.PSpecified.DEFAULT,
                )
                init(Cipher.DECRYPT_MODE, privateKey, spec)
            }
            else -> Cipher.getInstance(
                "RSA/ECB/PKCS1Padding",
                ANDROID_KEYSTORE_RSA_PROVIDER,
            ).apply {
                init(Cipher.DECRYPT_MODE, privateKey)
            }
        }
        val rawKey = cipher.doFinal(Base64.decode(wrapped, Base64.DEFAULT))
        return SecretKeySpec(rawKey, "AES")
    }

    private fun decryptGcm(payload: ByteArray, key: SecretKey): ByteArray {
        require(Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) // GCMParameterSpec is API 19.
        require(payload.size > GCM_IV_BYTES) { "Invalid legacy encrypted credential." }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            key,
            GCMParameterSpec(GCM_TAG_BITS, payload.copyOfRange(0, GCM_IV_BYTES)),
        )
        return cipher.doFinal(payload.copyOfRange(GCM_IV_BYTES, payload.size))
    }

    private fun decryptCbc(payload: ByteArray, key: SecretKey): ByteArray {
        require(payload.size > CBC_IV_BYTES) { "Invalid legacy encrypted credential." }
        val cipher = Cipher.getInstance("AES/CBC/PKCS7Padding")
        cipher.init(Cipher.DECRYPT_MODE, key, IvParameterSpec(payload.copyOfRange(0, CBC_IV_BYTES)))
        return cipher.doFinal(payload.copyOfRange(CBC_IV_BYTES, payload.size))
    }

    private fun prefixed(key: String) = "${LEGACY_KEY_PREFIX}_$key"

    companion object {
        private const val DATA_PREFS_NAME = "FlutterSecureStorage"
        private const val KEY_STORAGE_PREFS_NAME = "FlutterSecureKeyStorage"
        private const val CONFIG_PREFS_NAME = "FlutterSecureStorageConfiguration"
        private const val KEY_ALGORITHM_MARKER = "FlutterSecureSAlgorithmKey"
        private const val STORAGE_ALGORITHM_MARKER = "FlutterSecureSAlgorithmStorage"
        private const val HISTORICAL_KEY_ALGORITHM = "RSA_ECB_PKCS1Padding"
        private const val HISTORICAL_STORAGE_ALGORITHM = "AES_CBC_PKCS7Padding"
        private const val LEGACY_KEY_PREFIX =
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg"
        private const val GCM_WRAPPED_KEY =
            "AESVGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK"
        private const val CBC_WRAPPED_KEY =
            "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val ANDROID_KEYSTORE_RSA_PROVIDER = "AndroidKeyStoreBCWorkaround"
        private const val GCM_IV_BYTES = 12
        private const val CBC_IV_BYTES = 16
        private const val GCM_TAG_BITS = 128
    }
}
