package com.namecallfilter.flow.data

import kotlinx.coroutines.test.runTest
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TwitchApiTest {
    @Test fun `top categories uses raw operation and maps pagination`() = runTest {
        var operation: JSONObject? = null
        var clientId: String? = null
        val http = client { request ->
            clientId = request.header("Client-Id")
            operation = request.body?.let { body ->
                Buffer().also(body::writeTo).use { JSONObject(it.readUtf8()) }
            }
            """{
              "data":{"games":{"edges":[
                {"cursor":"next","node":{"id":"27471","displayName":"Minecraft",
                 "boxArtURL":"https://box/{width}x{height}.jpg","viewersCount":4200}}
              ],"pageInfo":{"hasNextPage":true}}}
            }""" to 200
        }
        val api = OkHttpTwitchApiClient("helix-client", "access", httpClient = http)
        val page = api.fetchTopCategoriesPage(first = 200)
        assertEquals(OkHttpTwitchApiClient.DEFAULT_GRAPHQL_CLIENT_ID, clientId)
        assertEquals("FlowTopGames", operation?.getString("operationName"))
        assertTrue(operation?.getString("query")?.contains("query FlowTopGames") == true)
        assertEquals(100, operation?.getJSONObject("variables")?.getInt("first"))
        assertEquals("Minecraft", page.data.single().name)
        assertEquals(4_200, page.data.single().viewerCount)
        assertEquals("next", page.cursor)
    }

    @Test fun `top streams retain category id for navigation`() = runTest {
        val http = client {
            """{
              "data":{"streams":{"edges":[
                {"cursor":"stream-next","node":{"id":"stream-1","viewersCount":42,
                 "broadcaster":{"id":"creator-1","login":"creator","displayName":"Creator",
                  "broadcastSettings":{"title":"Live now"}},
                 "game":{"id":"game-1","displayName":"Game"}}}
              ],"pageInfo":{"hasNextPage":false}}}
            }""" to 200
        }
        val api = OkHttpTwitchApiClient("client", "access", httpClient = http)

        val stream = api.fetchLiveStreamsPage().data.single()

        assertEquals("game-1", stream.gameId)
        assertEquals("Game", stream.gameName)
    }

    @Test fun `authenticated operations use OAuth header without duplicating prefix`() = runTest {
        var authorization: String? = null
        val http = client { request ->
            authorization = request.header("Authorization")
            """{"data":{"currentUser":{"id":"1","login":"viewer","displayName":"Viewer",
                "profileImageURL":"https://avatar"}}}""" to 200
        }
        val api = OkHttpTwitchApiClient("client", "access", gqlAccessToken = "OAuth web", httpClient = http)
        assertEquals("viewer", api.fetchCurrentUser().login)
        assertEquals("OAuth web", authorization)
    }

    @Test fun `playback retries without web auth and creates usher URI`() = runTest {
        val authorizations = mutableListOf<String?>()
        val http = client { request ->
            authorizations += request.header("Authorization")
            if (authorizations.size == 1) {
                """{"errors":[{"message":"session expired"}]}""" to 200
            } else {
                """{"data":{"streamPlaybackAccessToken":{"value":"token value","signature":"sig",
                    "authorization":{"isForbidden":false,"forbiddenReasonCode":null}}}}""" to 200
            }
        }
        val api = OkHttpTwitchApiClient("client", "access", gqlAccessToken = "web", httpClient = http)
        val uri = api.fetchLivePlaybackUri("creator")
        assertEquals(listOf("OAuth web", null), authorizations)
        assertEquals("usher.ttvnw.net", uri.host)
        assertTrue(uri.path.endsWith("/creator.m3u8"))
        assertTrue(uri.rawQuery.contains("token=token%20value"))
    }

    @Test fun `validate returns false only for 401`() = runTest {
        val api = OkHttpTwitchApiClient(
            "client", "access",
            httpClient = client { "" to 401 },
        )
        assertFalse(api.validateAccessToken("expired"))
    }

    private fun client(response: (okhttp3.Request) -> Pair<String, Int>): OkHttpClient =
        OkHttpClient.Builder().addInterceptor(Interceptor { chain ->
            val (body, code) = response(chain.request())
            Response.Builder()
                .request(chain.request())
                .protocol(Protocol.HTTP_1_1)
                .code(code)
                .message(if (code in 200..299) "OK" else "Error")
                .body(body.toResponseBody("application/json".toMediaType()))
                .build()
        }).build()
}
