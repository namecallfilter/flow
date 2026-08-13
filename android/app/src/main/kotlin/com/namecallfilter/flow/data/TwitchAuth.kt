package com.namecallfilter.flow.data

import android.webkit.CookieManager
import com.namecallfilter.flow.BuildConfig
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.OkHttpClient
import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.security.SecureRandom
import java.util.Base64

data class TwitchAuthConfig(
    val clientId: String,
    val graphQlClientId: String = OkHttpTwitchApiClient.DEFAULT_GRAPHQL_CLIENT_ID,
    val redirectUri: String = DEFAULT_REDIRECT_URI,
    val scope: String = "user:read:follows",
) {
    val isConfigured: Boolean get() = clientId.isNotBlank()

    fun isRedirectUri(uri: URI): Boolean {
        val expected = runCatching { URI(redirectUri.trim()) }.getOrNull() ?: return false
        return uri.scheme == expected.scheme &&
            redirectHostsMatch(uri.host.orEmpty(), expected.host.orEmpty()) &&
            normalizeRedirectPath(uri.path.orEmpty()) == normalizeRedirectPath(expected.path.orEmpty())
    }

    fun authorizationUri(state: String): URI {
        val query = linkedMapOf(
            "client_id" to clientId.trim(),
            "redirect_uri" to redirectUri.trim(),
            "response_type" to "token",
            "scope" to scope,
            "force_verify" to "true",
            "state" to state,
        ).entries.joinToString("&") { (key, value) -> "${urlEncode(key)}=${urlEncode(value)}" }
        return URI("https://id.twitch.tv/oauth2/authorize?$query")
    }

    companion object {
        const val DEFAULT_REDIRECT_URI = "https://twitch.tv/login"

        fun fromBuildConfig(): TwitchAuthConfig = TwitchAuthConfig(
            clientId = BuildConfig.TWITCH_CLIENT_ID,
            graphQlClientId = BuildConfig.TWITCH_GQL_CLIENT_ID
                .takeIf(String::isNotBlank)
                ?: OkHttpTwitchApiClient.DEFAULT_GRAPHQL_CLIENT_ID,
            redirectUri = BuildConfig.TWITCH_REDIRECT_URI,
        )
    }
}

data class TwitchAuthCallback(
    val accessToken: String,
    val scope: String,
    val state: String,
) {
    companion object {
        fun parse(uri: URI, expectedState: String): TwitchAuthCallback {
            val parameters = callbackParameters(uri)
            parameters["error"]?.let { error ->
                throw TwitchAuthException(parameters["error_description"] ?: error)
            }
            val returnedState = parameters["state"]
            if (expectedState.isBlank() || returnedState != expectedState) {
                throw TwitchAuthException("OAuth state did not match.")
            }
            val token = parameters["access_token"]
            if (token.isNullOrEmpty()) {
                throw TwitchAuthException("Twitch callback did not include access token.")
            }
            return TwitchAuthCallback(
                accessToken = token,
                scope = parameters["scope"].orEmpty(),
                state = returnedState.orEmpty(),
            )
        }

        fun hasOAuthResponse(uri: URI): Boolean = callbackParameters(uri).let { parameters ->
            "access_token" in parameters || "error" in parameters
        }
    }
}

fun interface TwitchCookieExtractor {
    suspend fun extractTwitchAuthToken(): String?
}

class AndroidTwitchCookieExtractor(
    private val cookieManager: CookieManager = CookieManager.getInstance(),
) : TwitchCookieExtractor {
    override suspend fun extractTwitchAuthToken(): String? {
        val cookies = cookieManager.getCookie("https://twitch.tv")
            ?: cookieManager.getCookie("https://www.twitch.tv")
        return cookies
            ?.split(';')
            ?.asSequence()
            ?.map(String::trim)
            ?.firstOrNull { it.startsWith("auth-token=") }
            ?.substringAfter("auth-token=")
    }
}

interface TwitchApiClientFactory {
    fun create(accessToken: String, gqlAccessToken: String? = null): TwitchApi
}

class OkHttpTwitchApiClientFactory(
    private val config: TwitchAuthConfig,
    private val httpClient: OkHttpClient = OkHttpClient(),
) : TwitchApiClientFactory {
    override fun create(accessToken: String, gqlAccessToken: String?): TwitchApi =
        OkHttpTwitchApiClient(
            clientId = config.clientId,
            graphQlClientId = config.graphQlClientId,
            accessToken = accessToken,
            gqlAccessToken = gqlAccessToken,
            httpClient = httpClient,
        )
}

data class TwitchSavedTokens(
    val accessToken: String?,
    val webSessionToken: String?,
)

/** OAuth/session orchestration with revision checks so cancel/sign-out always wins races. */
class TwitchAuthController(
    val config: TwitchAuthConfig,
    val secureStore: TwitchSecureStore,
    val apiClientFactory: TwitchApiClientFactory,
    val cookieExtractor: TwitchCookieExtractor,
    private val stateGenerator: () -> String = ::generateOAuthState,
) {
    private val stateLock = Any()
    private val storageMutex = Mutex()
    private var sessionRevision = 0
    private var pendingAuthRevision: Int? = null
    private var pendingAuthState: String? = null

    suspend fun createAuthorizationUri(): URI {
        if (!config.isConfigured) {
            throw TwitchAuthException("Set TWITCH_CLIENT_ID to start Twitch auth.")
        }
        val state = stateGenerator()
        val revision = synchronized(stateLock) {
            sessionRevision += 1
            sessionRevision.also {
                pendingAuthRevision = it
                pendingAuthState = state
            }
        }
        try {
            storageMutex.withLock {
                ensurePendingAuthCurrent(revision)
                secureStore.savePendingState(state)
                ensurePendingAuthCurrent(revision)
            }
        } catch (error: Throwable) {
            synchronized(stateLock) {
                if (pendingAuthRevision == revision) {
                    pendingAuthRevision = null
                    pendingAuthState = null
                }
            }
            throw error
        }
        return config.authorizationUri(state)
    }

    suspend fun completeAuth(callbackUri: URI): TwitchAuthConnection {
        val revision = synchronized(stateLock) { pendingAuthRevision }
            ?: throw TwitchAuthException("Twitch sign-in was canceled.")
        ensurePendingAuthCurrent(revision)
        val expectedState = secureStore.readPendingState()
        ensurePendingAuthCurrent(revision)
        val callback = TwitchAuthCallback.parse(callbackUri, expectedState.orEmpty())

        val validationClient = apiClientFactory.create(callback.accessToken)
        val isValid = validationClient.validateAccessToken(callback.accessToken)
        ensurePendingAuthCurrent(revision)
        if (!isValid) throw TwitchAuthException("Twitch access token is invalid.")

        val webToken = cookieExtractor.extractTwitchAuthToken()?.trim()
        ensurePendingAuthCurrent(revision)
        if (webToken.isNullOrEmpty()) {
            throw TwitchAuthException("Twitch web session token is missing.")
        }
        val client = apiClientFactory.create(callback.accessToken, webToken)
        val connection = fetchConnection(client)
        ensurePendingAuthCurrent(revision)

        try {
            storageMutex.withLock {
                var replacementStarted = false
                var oldAccessToken: String? = null
                var oldWebToken: String? = null
                try {
                    ensurePendingAuthCurrent(revision)
                    oldAccessToken = secureStore.readAccessToken()
                    ensurePendingAuthCurrent(revision)
                    oldWebToken = secureStore.readWebSessionToken()
                    ensurePendingAuthCurrent(revision)
                    replacementStarted = true
                    secureStore.clearSession()
                    ensurePendingAuthCurrent(revision)
                    secureStore.saveAccessToken(callback.accessToken)
                    ensurePendingAuthCurrent(revision)
                    secureStore.saveWebSessionToken(webToken)
                    ensurePendingAuthCurrent(revision)
                } catch (error: Throwable) {
                    if (replacementStarted) {
                        runCatching {
                            secureStore.clearSession()
                            if (!oldAccessToken.isNullOrEmpty() && !oldWebToken.isNullOrEmpty()) {
                                secureStore.saveAccessToken(oldAccessToken)
                                secureStore.saveWebSessionToken(oldWebToken)
                            }
                        }
                    }
                    throw error
                }
            }
        } catch (error: Throwable) {
            clearPendingIfRevision(revision)
            throw error
        }
        clearPendingIfRevision(revision)
        return connection
    }

    suspend fun loadSavedConnection(): TwitchAuthConnection? {
        if (!config.isConfigured) return null
        val revision = synchronized(stateLock) { sessionRevision }
        val credentials = storageMutex.withLock {
            if (!sessionCanRestore(revision)) return@withLock null
            val accessToken = secureStore.readAccessToken()
            if (!sessionCanRestore(revision)) return@withLock null
            val webToken = secureStore.readWebSessionToken()
            if (!sessionCanRestore(revision)) return@withLock null
            if (accessToken.isNullOrEmpty() || webToken.isNullOrBlank()) {
                secureStore.clearSession()
                return@withLock null
            }
            accessToken to webToken
        } ?: return null

        val client = apiClientFactory.create(credentials.first, credentials.second)
        val valid = client.validateAccessToken(credentials.first)
        if (!revisionIsCurrent(revision)) return null
        if (!valid) {
            clearSessionIfCurrent(revision)
            return null
        }
        val connection = fetchConnection(client)
        return connection.takeIf { revisionIsCurrent(revision) }
    }

    suspend fun cancelPendingAuth(state: String) {
        val revision = synchronized(stateLock) {
            if (pendingAuthRevision == null || pendingAuthState != state) return
            sessionRevision += 1
            pendingAuthRevision = null
            pendingAuthState = null
            sessionRevision
        }
        storageMutex.withLock {
            val clear = synchronized(stateLock) {
                revision == sessionRevision && pendingAuthRevision == null
            }
            if (clear) secureStore.clearPendingState()
        }
    }

    suspend fun signOut() {
        synchronized(stateLock) {
            sessionRevision += 1
            pendingAuthRevision = null
            pendingAuthState = null
        }
        storageMutex.withLock { secureStore.clearSession() }
    }

    suspend fun readSavedTokens(): TwitchSavedTokens = storageMutex.withLock {
        TwitchSavedTokens(
            accessToken = secureStore.readAccessToken(),
            webSessionToken = secureStore.readWebSessionToken(),
        )
    }

    private suspend fun clearSessionIfCurrent(revision: Int) = storageMutex.withLock {
        if (revisionIsCurrent(revision)) secureStore.clearSession()
    }

    private fun ensurePendingAuthCurrent(revision: Int) {
        val current = synchronized(stateLock) {
            revision == sessionRevision && pendingAuthRevision == revision
        }
        if (!current) throw TwitchAuthException("Twitch sign-in was canceled.")
    }

    private fun sessionCanRestore(revision: Int): Boolean = synchronized(stateLock) {
        revision == sessionRevision && pendingAuthRevision == null
    }

    private fun revisionIsCurrent(revision: Int): Boolean = synchronized(stateLock) {
        revision == sessionRevision
    }

    private fun clearPendingIfRevision(revision: Int) = synchronized(stateLock) {
        if (pendingAuthRevision == revision) {
            pendingAuthRevision = null
            pendingAuthState = null
        }
    }

    private suspend fun fetchConnection(client: TwitchApi): TwitchAuthConnection {
        val user = client.fetchCurrentUser()
        val streams = client.fetchFollowedStreams(user.id)
        val channels = client.fetchFollowedChannels(user.id)
        val users = client.fetchUsersByIds(
            buildList {
                add(user.id)
                streams.forEach { add(it.userId) }
                channels.forEach { add(it.broadcasterId) }
            },
        )
        val channelInfo = client.fetchChannelInfoByBroadcasterIds(
            channels.map(TwitchFollowedChannel::broadcasterId),
        )
        return TwitchAuthConnection(user, streams, channels, users, channelInfo)
    }
}

fun generateOAuthState(): String {
    val bytes = ByteArray(32).also(SecureRandom()::nextBytes)
    return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
}

private fun callbackParameters(uri: URI): Map<String, String> = buildMap {
    parseParameters(uri.rawQuery).forEach(::put)
    parseParameters(uri.rawFragment).forEach(::put)
}

private fun parseParameters(value: String?): Map<String, String> {
    if (value.isNullOrEmpty()) return emptyMap()
    return buildMap {
        value.split('&').forEach { component ->
            if (component.isEmpty()) return@forEach
            val parts = component.split('=', limit = 2)
            put(urlDecode(parts[0]), urlDecode(parts.getOrElse(1) { "" }))
        }
    }
}

private fun redirectHostsMatch(actualHost: String, expectedHost: String): Boolean {
    val actual = actualHost.lowercase()
    val expected = expectedHost.lowercase()
    if (actual == expected) return true
    return withoutWww(actual) == "twitch.tv" && withoutWww(actual) == withoutWww(expected)
}

private fun withoutWww(host: String) = host.removePrefix("www.")

private fun normalizeRedirectPath(path: String): String = when {
    path.isEmpty() -> "/"
    path.length > 1 && path.endsWith('/') -> path.dropLast(1)
    else -> path
}

private fun urlEncode(value: String): String =
    URLEncoder.encode(value, StandardCharsets.UTF_8.name()).replace("+", "%20")

private fun urlDecode(value: String): String =
    URLDecoder.decode(value, StandardCharsets.UTF_8.name())
