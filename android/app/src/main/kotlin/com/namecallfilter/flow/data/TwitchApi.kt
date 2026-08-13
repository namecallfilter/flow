package com.namecallfilter.flow.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.security.SecureRandom
import java.time.Instant
import java.util.Locale

interface TwitchApi {
    suspend fun validateAccessToken(token: String): Boolean
    suspend fun fetchCurrentUser(): TwitchUser
    suspend fun fetchFollowedStreams(userId: String): List<TwitchFollowedStream>
    suspend fun fetchFollowedChannels(userId: String): List<TwitchFollowedChannel>
    suspend fun fetchUsersByIds(ids: List<String>): Map<String, TwitchUser>
    suspend fun fetchChannelInfoByBroadcasterIds(broadcasterIds: List<String>): Map<String, TwitchChannelInfo>
    suspend fun fetchTopCategories(first: Int = 12): List<TwitchCategory>
    suspend fun fetchTopCategoriesPage(first: Int = 12, cursor: String? = null): TwitchPage<TwitchCategory>
    suspend fun searchCategories(query: String, first: Int = 20): List<TwitchCategory>
    suspend fun searchCategoriesPage(
        query: String,
        first: Int = 20,
        cursor: String? = null,
    ): TwitchPage<TwitchCategory>
    suspend fun fetchLiveStreams(
        first: Int = 20,
        gameIds: List<String> = emptyList(),
        userLogins: List<String> = emptyList(),
    ): List<TwitchFollowedStream>
    suspend fun fetchLiveStreamsPage(
        first: Int = 20,
        gameIds: List<String> = emptyList(),
        userLogins: List<String> = emptyList(),
        cursor: String? = null,
    ): TwitchPage<TwitchFollowedStream>
    suspend fun searchLiveChannels(query: String, first: Int = 20): List<TwitchSearchChannel>
    suspend fun searchChannelsPage(
        query: String,
        first: Int = 20,
        cursor: String? = null,
        liveOnly: Boolean = false,
    ): TwitchPage<TwitchSearchChannel>
    suspend fun fetchChannelDetails(
        login: String,
        videosFirst: Int = 30,
        videosCursor: String? = null,
    ): TwitchChannelDetails
    suspend fun fetchLivePlaybackUri(login: String): URI
    suspend fun fetchChannelSubscriptionStatus(login: String): Boolean
}

class OkHttpTwitchApiClient(
    val clientId: String,
    val accessToken: String,
    graphQlClientId: String? = null,
    val gqlAccessToken: String? = null,
    private val httpClient: OkHttpClient = OkHttpClient(),
) : TwitchApi {
    val graphQlClientId: String = nonEmpty(graphQlClientId) ?: DEFAULT_GRAPHQL_CLIENT_ID

    override suspend fun validateAccessToken(token: String): Boolean = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("https://id.twitch.tv/oauth2/validate")
            .header("Authorization", "Bearer $token")
            .header("Client-ID", clientId)
            .get()
            .build()
        httpClient.newCall(request).execute().use { response ->
            if (response.code == 401) return@withContext false
            val body = response.body.string()
            if (!response.isSuccessful) {
                throw TwitchApiException(
                    "Twitch token validation failed (${response.code}): $body",
                )
            }
            true
        }
    }

    override suspend fun fetchCurrentUser(): TwitchUser {
        val data = query("FlowCurrentUser", TwitchGraphQlDocuments.currentUser, authenticated = true)
        val user = data.objectOrNull("currentUser")
            ?: throw TwitchApiException("Twitch returned no current user.")
        return userFromGraphQl(user)
    }

    override suspend fun fetchFollowedStreams(userId: String): List<TwitchFollowedStream> {
        val streams = mutableListOf<TwitchFollowedStream>()
        var after: String? = null
        do {
            val data = query(
                "FlowFollowedLiveUsers",
                TwitchGraphQlDocuments.followedLiveUsers,
                variables("first" to 100, "after" to after),
                authenticated = true,
            )
            val connection = data.objectOrNull("currentUser")?.objectOrNull("followedLiveUsers")
            edgeList(connection).forEach { edge ->
                val node = edge.objectOrNull("node")
                val stream = node?.objectOrNull("stream")
                if (node != null && stream != null) {
                    streams += streamFromGraphQl(stream, node)
                }
            }
            after = connectionCursor(connection)
        } while (!after.isNullOrEmpty())
        return streams
    }

    override suspend fun fetchFollowedChannels(userId: String): List<TwitchFollowedChannel> {
        val channels = mutableListOf<TwitchFollowedChannel>()
        var after: String? = null
        do {
            val data = query(
                "FlowFollowedUsers",
                TwitchGraphQlDocuments.followedUsers,
                variables("first" to 100, "after" to after),
                authenticated = true,
            )
            val connection = data.objectOrNull("currentUser")?.objectOrNull("follows")
            edgeList(connection).forEach { edge ->
                val node = edge.objectOrNull("node") ?: return@forEach
                channels += TwitchFollowedChannel(
                    broadcasterId = node.string("id"),
                    broadcasterLogin = node.string("login"),
                    broadcasterName = node.string("displayName"),
                    followedAt = instant(edge.valueOrNull("followedAt")),
                )
            }
            after = connectionCursor(connection)
        } while (!after.isNullOrEmpty())
        return channels
    }

    override suspend fun fetchUsersByIds(ids: List<String>): Map<String, TwitchUser> = buildMap {
        batches(ids).forEach { batch ->
            val data = query(
                "FlowUsers",
                TwitchGraphQlDocuments.users,
                variables("ids" to batch, "logins" to null),
            )
            data.objectList("users").forEach { value ->
                val user = userFromGraphQl(value)
                put(user.id, user)
            }
        }
    }

    override suspend fun fetchChannelInfoByBroadcasterIds(
        broadcasterIds: List<String>,
    ): Map<String, TwitchChannelInfo> = buildMap {
        batches(broadcasterIds).forEach { batch ->
            val data = query(
                "FlowUsers",
                TwitchGraphQlDocuments.users,
                variables("ids" to batch, "logins" to null),
            )
            data.objectList("users").forEach { item ->
                val settings = item.objectOrNull("broadcastSettings")
                val channel = TwitchChannelInfo(
                    broadcasterId = item.string("id"),
                    broadcasterName = item.string("displayName"),
                    gameName = settings?.objectOrNull("game")?.string("displayName").orEmpty(),
                    title = settings?.string("title").orEmpty(),
                )
                put(channel.broadcasterId, channel)
            }
        }
    }

    override suspend fun fetchTopCategories(first: Int): List<TwitchCategory> =
        fetchTopCategoriesPage(first).data

    override suspend fun fetchTopCategoriesPage(
        first: Int,
        cursor: String?,
    ): TwitchPage<TwitchCategory> {
        val data = query(
            "FlowTopGames",
            TwitchGraphQlDocuments.topGames,
            variables("first" to boundedFirst(first), "after" to nonEmpty(cursor)),
        )
        return categoryPage(data.objectOrNull("games"))
    }

    override suspend fun searchCategories(query: String, first: Int): List<TwitchCategory> =
        searchCategoriesPage(query, first).data

    override suspend fun searchCategoriesPage(
        query: String,
        first: Int,
        cursor: String?,
    ): TwitchPage<TwitchCategory> {
        val normalized = query.trim()
        if (normalized.isEmpty()) return TwitchPage(emptyList(), null)
        val data = query(
            "FlowSearchCategories",
            TwitchGraphQlDocuments.searchCategories,
            variables(
                "query" to normalized,
                "first" to boundedFirst(first),
                "after" to nonEmpty(cursor),
            ),
        )
        return categoryPage(data.objectOrNull("searchCategories"))
    }

    override suspend fun fetchLiveStreams(
        first: Int,
        gameIds: List<String>,
        userLogins: List<String>,
    ): List<TwitchFollowedStream> = fetchLiveStreamsPage(first, gameIds, userLogins).data

    override suspend fun fetchLiveStreamsPage(
        first: Int,
        gameIds: List<String>,
        userLogins: List<String>,
        cursor: String?,
    ): TwitchPage<TwitchFollowedStream> {
        val games = nonEmptyValues(gameIds)
        val logins = nonEmptyValues(userLogins)
        if (games.isNotEmpty()) {
            return fetchGameStreamsPage(games.first(), first, cursor, logins)
        }
        if (logins.isNotEmpty()) return fetchUserStreamsPage(logins)

        val data = query(
            "FlowTopStreams",
            TwitchGraphQlDocuments.topStreams,
            variables("first" to boundedFirst(first, MAX_TOP_STREAMS_PAGE), "after" to nonEmpty(cursor)),
        )
        return streamPage(data.objectOrNull("streams"))
    }

    override suspend fun searchLiveChannels(query: String, first: Int): List<TwitchSearchChannel> =
        searchChannelsPage(query, first = first, liveOnly = true).data

    override suspend fun searchChannelsPage(
        query: String,
        first: Int,
        cursor: String?,
        liveOnly: Boolean,
    ): TwitchPage<TwitchSearchChannel> {
        val normalized = query.trim()
        if (normalized.isEmpty()) return TwitchPage(emptyList(), null)
        val data = query(
            "FlowSearchChannels",
            TwitchGraphQlDocuments.searchChannels,
            variables(
                "queryFragment" to normalized,
                "requestID" to null,
                "withOfflineChannelContent" to !liveOnly,
            ),
        )
        val channels = mutableListOf<TwitchSearchChannel>()
        val suggestions = data.objectOrNull("searchSuggestions")
        edgeList(suggestions).forEach { edge ->
            val node = edge.objectOrNull("node")
            val content = node?.objectOrNull("content")
            if (content?.string("__typename") != "SearchSuggestionChannel") return@forEach
            val channel = searchChannelFromGraphQl(content, node.string("text"))
            if (!liveOnly || channel.isLive) channels += channel
            if (channels.size >= boundedFirst(first)) return@forEach
        }
        return TwitchPage(channels.take(boundedFirst(first)), null)
    }

    override suspend fun fetchChannelDetails(
        login: String,
        videosFirst: Int,
        videosCursor: String?,
    ): TwitchChannelDetails {
        val normalized = nonEmpty(login)
            ?: throw TwitchApiException("Channel login is required.")
        val data = query(
            "FlowChannelDetails",
            TwitchGraphQlDocuments.channelDetails,
            variables(
                "login" to normalized,
                "videosFirst" to boundedFirst(videosFirst),
                "videosAfter" to nonEmpty(videosCursor),
            ),
        )
        val user = data.objectOrNull("user")
            ?: throw TwitchApiException("Twitch returned no channel for $normalized.")
        return channelDetailsFromGraphQl(user)
    }

    override suspend fun fetchLivePlaybackUri(login: String): URI {
        val normalized = nonEmpty(login)
            ?: throw TwitchApiException("Channel login is required.")
        val data = fetchPlaybackAccessToken(normalized)
        val access = data.objectOrNull("streamPlaybackAccessToken")
        val authorization = access?.objectOrNull("authorization")
        if (authorization?.optBoolean("isForbidden") == true) {
            val reason = nonEmpty(authorization.nullableString("forbiddenReasonCode"))
            throw TwitchApiException(
                reason?.let { "This stream is not available ($it)." }
                    ?: "This stream is not available.",
            )
        }
        val token = nonEmpty(access?.nullableString("value"))
        val signature = nonEmpty(access?.nullableString("signature"))
        if (token == null || signature == null) {
            throw TwitchApiException("Twitch returned no playback access token for $normalized.")
        }
        val queryParameters = linkedMapOf(
            "allow_audio_only" to "true",
            "allow_source" to "true",
            "fast_bread" to "true",
            "playlist_include_framerate" to "true",
            "player" to "twitchweb",
            "p" to SecureRandom().nextInt(10_000_000).toString(),
            "sig" to signature,
            "token" to token,
            "type" to "any",
        ).entries.joinToString("&") { (key, value) -> "${urlEncode(key)}=${urlEncode(value)}" }
        return URI(
            "https://usher.ttvnw.net/api/v2/channel/hls/$normalized.m3u8?$queryParameters",
        )
    }

    override suspend fun fetchChannelSubscriptionStatus(login: String): Boolean {
        val normalized = nonEmpty(login)
            ?: throw TwitchApiException("Channel login is required.")
        val data = query(
            "FlowChannelSubscription",
            TwitchGraphQlDocuments.channelSubscription,
            variables("login" to normalized),
            authenticated = true,
        )
        return data.objectOrNull("user")
            ?.objectOrNull("self")
            ?.objectOrNull("subscriptionBenefit") != null
    }

    private suspend fun fetchGameStreamsPage(
        gameId: String,
        first: Int,
        cursor: String?,
        userLogins: List<String>,
    ): TwitchPage<TwitchFollowedStream> {
        val data = query(
            "FlowGameStreams",
            TwitchGraphQlDocuments.gameStreams,
            variables("id" to gameId, "first" to boundedFirst(first), "after" to nonEmpty(cursor)),
        )
        val page = streamPage(data.objectOrNull("game")?.objectOrNull("streams"))
        if (userLogins.isEmpty()) return page
        val allowed = userLogins.mapTo(mutableSetOf()) { it.lowercase(Locale.ROOT) }
        return page.copy(data = page.data.filter { it.userLogin.lowercase(Locale.ROOT) in allowed })
    }

    private suspend fun fetchUserStreamsPage(
        userLogins: List<String>,
    ): TwitchPage<TwitchFollowedStream> {
        val streams = mutableListOf<TwitchFollowedStream>()
        batches(userLogins).forEach { batch ->
            val data = query(
                "FlowUsers",
                TwitchGraphQlDocuments.users,
                variables("ids" to null, "logins" to batch),
            )
            data.objectList("users").forEach { user ->
                user.objectOrNull("stream")?.let { streams += streamFromGraphQl(it, user) }
            }
        }
        return TwitchPage(streams, null)
    }

    private suspend fun fetchPlaybackAccessToken(login: String): JSONObject {
        val variables = variables("login" to login, "platform" to "web", "playerType" to "site")
        if (nonEmpty(gqlAccessToken) == null) {
            return query(
                "FlowPlaybackAccessToken",
                TwitchGraphQlDocuments.playbackAccessToken,
                variables,
            )
        }
        return try {
            query(
                "FlowPlaybackAccessToken",
                TwitchGraphQlDocuments.playbackAccessToken,
                variables,
                authenticated = true,
            )
        } catch (_: TwitchApiException) {
            query(
                "FlowPlaybackAccessToken",
                TwitchGraphQlDocuments.playbackAccessToken,
                variables,
            )
        }
    }

    private suspend fun query(
        operationName: String,
        document: String,
        variables: JSONObject = JSONObject(),
        authenticated: Boolean = false,
    ): JSONObject = withContext(Dispatchers.IO) {
        val webToken = nonEmpty(gqlAccessToken)
        if (authenticated && webToken == null) {
            throw TwitchApiException("Twitch GraphQL auth token is missing.")
        }
        val body = JSONObject()
            .put("operationName", operationName)
            .put("query", document)
            .put("variables", variables)
            .toString()
            .toRequestBody(JSON_MEDIA_TYPE)
        val requestBuilder = Request.Builder()
            .url(GQL_ENDPOINT)
            .header("Client-Id", graphQlClientId)
            .header("Content-Type", "application/json")
            .post(body)
        if (authenticated) requestBuilder.header("Authorization", oauthHeader(webToken!!))

        try {
            httpClient.newCall(requestBuilder.build()).execute().use { response ->
                val responseBody = response.body.string()
                if (!response.isSuccessful) {
                    throw TwitchApiException(
                        "Twitch GraphQL $operationName failed: HTTP ${response.code}: $responseBody",
                    )
                }
                val root = try {
                    JSONObject(responseBody)
                } catch (error: Exception) {
                    throw TwitchApiException(
                        "Twitch GraphQL $operationName failed: invalid JSON response.",
                        error,
                    )
                }
                val errors = root.optJSONArray("errors")
                if (errors != null && errors.length() > 0) {
                    val messages = buildList {
                        for (index in 0 until errors.length()) {
                            val error = errors.optJSONObject(index)
                            add(error?.optString("message")?.takeIf(String::isNotEmpty) ?: errors.opt(index).toString())
                        }
                    }
                    throw TwitchApiException(
                        "Twitch GraphQL $operationName failed: ${messages.joinToString("; ")}",
                    )
                }
                root.objectOrNull("data")
                    ?: throw TwitchApiException("Twitch GraphQL $operationName returned no data.")
            }
        } catch (error: TwitchApiException) {
            throw error
        } catch (error: Exception) {
            throw TwitchApiException(
                "Twitch GraphQL $operationName failed: ${error.message ?: error}",
                error,
            )
        }
    }

    private fun categoryPage(connection: JSONObject?): TwitchPage<TwitchCategory> = TwitchPage(
        data = edgeList(connection).mapNotNull { edge ->
            edge.objectOrNull("node")?.let { node ->
                TwitchCategory(
                    id = node.string("id"),
                    name = node.string("displayName"),
                    boxArtUrl = node.nullableString("boxArtURL"),
                    viewerCount = node.int("viewersCount"),
                )
            }
        },
        cursor = connectionCursor(connection),
    )

    private fun streamPage(connection: JSONObject?): TwitchPage<TwitchFollowedStream> = TwitchPage(
        data = edgeList(connection).mapNotNull { it.objectOrNull("node")?.let(::streamFromGraphQl) },
        cursor = connectionCursor(connection),
    )

    private fun connectionCursor(connection: JSONObject?): String? {
        if (connection?.objectOrNull("pageInfo")?.optBoolean("hasNextPage") != true) return null
        val edges = edgeList(connection)
        return nonEmpty(edges.lastOrNull()?.nullableString("cursor"))
    }

    private fun userFromGraphQl(user: JSONObject) = TwitchUser(
        id = user.string("id"),
        login = user.string("login"),
        displayName = user.string("displayName"),
        profileImageUrl = user.nullableString("profileImageURL"),
    )

    private fun streamFromGraphQl(
        stream: JSONObject,
        fallbackBroadcaster: JSONObject? = null,
    ): TwitchFollowedStream {
        val broadcaster = mergeObjects(fallbackBroadcaster, stream.objectOrNull("broadcaster"))
        val settings = broadcaster.objectOrNull("broadcastSettings")
            ?: stream.objectOrNull("broadcastSettings")
        return TwitchFollowedStream(
            id = stream.string("id"),
            userId = broadcaster.string("id"),
            userLogin = broadcaster.string("login"),
            userName = broadcaster.string("displayName"),
            gameName = stream.objectOrNull("game")?.string("displayName").orEmpty(),
            title = settings?.string("title").orEmpty(),
            viewerCount = stream.int("viewersCount"),
            thumbnailUrl = stream.nullableString("previewImageURL"),
            startedAt = instant(stream.valueOrNull("createdAt")),
            tags = stream.objectList("freeformTags").mapNotNull { nonEmpty(it.nullableString("name")) },
            gameId = stream.objectOrNull("game")?.string("id").orEmpty(),
        )
    }

    private fun searchChannelFromGraphQl(content: JSONObject, fallbackDisplayName: String): TwitchSearchChannel {
        val user = content.objectOrNull("user")
        val stream = user?.objectOrNull("stream")
        val game = stream?.objectOrNull("game")
        val settings = stream?.objectOrNull("broadcaster")?.objectOrNull("broadcastSettings")
        val displayName = user?.valueOrNull("displayName")
            ?: fallbackDisplayName.ifEmpty { content.valueOrNull("login") }
        return TwitchSearchChannel(
            id = content.string("id"),
            broadcasterLogin = content.string("login"),
            displayName = displayName?.toString().orEmpty(),
            gameName = game?.string("displayName").orEmpty(),
            title = settings?.string("title").orEmpty(),
            isLive = content.optBoolean("isLive") || stream != null,
            thumbnailUrl = content.nullableString("profileImageURL"),
            startedAt = instant(stream?.valueOrNull("createdAt")),
        )
    }

    private fun channelDetailsFromGraphQl(user: JSONObject): TwitchChannelDetails {
        val videos = user.objectOrNull("videos")
        return TwitchChannelDetails(
            id = user.string("id"),
            login = user.string("login"),
            displayName = user.string("displayName"),
            description = user.string("description"),
            followers = user.objectOrNull("followers")?.int("totalCount") ?: 0,
            profileImageUrl = user.nullableString("profileImageURL"),
            liveStream = user.objectOrNull("stream")?.let(::channelLiveStreamFromGraphQl),
            pastBroadcasts = edgeList(videos).mapNotNull { edge ->
                edge.objectOrNull("node")?.let(::pastBroadcastFromGraphQl)
            },
            pastBroadcastsCursor = connectionCursor(videos),
        )
    }

    private fun channelLiveStreamFromGraphQl(stream: JSONObject): TwitchChannelLiveStream {
        val game = stream.objectOrNull("game")
        val title = stream.objectOrNull("broadcaster")
            ?.objectOrNull("broadcastSettings")
            ?.string("title")
            .orEmpty()
        return TwitchChannelLiveStream(
            id = stream.string("id"),
            title = title.ifEmpty { "Live now" },
            categoryId = game?.string("id").orEmpty(),
            category = gameName(game, "Live"),
            viewerCount = stream.int("viewersCount"),
            thumbnailUrl = stream.nullableString("previewImageURL"),
            startedAt = instant(stream.valueOrNull("createdAt")),
        )
    }

    private fun pastBroadcastFromGraphQl(video: JSONObject): TwitchPastBroadcast {
        val game = video.objectOrNull("game")
        return TwitchPastBroadcast(
            id = video.string("id"),
            title = video.string("title").ifEmpty { "Past broadcast" },
            categoryId = game?.string("id").orEmpty(),
            category = gameName(game, "Broadcast"),
            durationSeconds = video.long("lengthSeconds"),
            viewCount = video.int("viewCount"),
            thumbnailUrl = video.nullableString("previewThumbnailURL"),
            publishedAt = instant(video.valueOrNull("publishedAt")),
            createdAt = instant(video.valueOrNull("createdAt")),
        )
    }

    private fun gameName(game: JSONObject?, fallback: String): String =
        game?.string("displayName")?.takeIf(String::isNotEmpty)
            ?: game?.string("name")?.takeIf(String::isNotEmpty)
            ?: fallback

    companion object {
        const val DEFAULT_GRAPHQL_CLIENT_ID = "ue6666qo983tsx6so1t0vnawi233wa"
        private const val GQL_ENDPOINT = "https://gql.twitch.tv/gql/"
        private const val MAX_PAGE_SIZE = 100
        private const val MAX_TOP_STREAMS_PAGE = 30
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

        private fun boundedFirst(value: Int, max: Int = MAX_PAGE_SIZE) = value.coerceIn(1, max)
        private fun nonEmpty(value: String?): String? = value?.trim()?.takeIf(String::isNotEmpty)
        private fun nonEmptyValues(values: List<String>) = values.mapNotNull(::nonEmpty)
        private fun batches(values: List<String>): List<List<String>> = values
            .filter(String::isNotEmpty)
            .distinct()
            .chunked(MAX_PAGE_SIZE)
        private fun oauthHeader(token: String): String = token.trim().let {
            if (it.startsWith("oauth ", ignoreCase = true)) it else "OAuth $it"
        }
    }
}

private fun variables(vararg entries: Pair<String, Any?>): JSONObject = JSONObject().apply {
    entries.forEach { (key, value) ->
        put(key, when (value) {
            null -> JSONObject.NULL
            is Iterable<*> -> JSONArray(value.toList())
            else -> value
        })
    }
}

private fun edgeList(connection: JSONObject?): List<JSONObject> = connection.objectList("edges")

private fun JSONObject?.objectList(key: String): List<JSONObject> {
    val array = this?.optJSONArray(key) ?: return emptyList()
    return buildList {
        for (index in 0 until array.length()) array.optJSONObject(index)?.let(::add)
    }
}

private fun JSONObject.objectOrNull(key: String): JSONObject? =
    if (has(key) && !isNull(key)) optJSONObject(key) else null

private fun JSONObject.valueOrNull(key: String): Any? =
    if (has(key) && !isNull(key)) opt(key) else null

private fun JSONObject.nullableString(key: String): String? =
    valueOrNull(key)?.toString()

private fun JSONObject.string(key: String): String = nullableString(key).orEmpty()

private fun JSONObject.int(key: String): Int = when (val value = valueOrNull(key)) {
    is Number -> value.toInt()
    else -> value?.toString()?.toIntOrNull() ?: 0
}

private fun JSONObject.long(key: String): Long = when (val value = valueOrNull(key)) {
    is Number -> value.toLong()
    else -> value?.toString()?.toLongOrNull() ?: 0L
}

private fun instant(value: Any?): Instant? = value?.toString()?.takeIf(String::isNotEmpty)?.let {
    runCatching { Instant.parse(it) }.getOrNull()
}

private fun mergeObjects(first: JSONObject?, second: JSONObject?): JSONObject = JSONObject().apply {
    listOfNotNull(first, second).forEach { source ->
        source.keys().forEach { key -> put(key, source.get(key)) }
    }
}

private fun urlEncode(value: String): String = java.net.URLEncoder
    .encode(value, Charsets.UTF_8.name())
    .replace("+", "%20")
