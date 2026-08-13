package com.namecallfilter.flow.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Test

class TwitchApiCacheTest {
    @Test fun `coalesces identical in-flight requests and caches result`() = runTest {
        val gate = CompletableDeferred<Unit>()
        var calls = 0
        val page = TwitchPage(listOf(TwitchCategory("1", "One", null, 1)), null)
        val api = object : FakeTwitchApi() {
            override suspend fun fetchTopCategoriesPage(first: Int, cursor: String?): TwitchPage<TwitchCategory> {
                calls += 1
                gate.await()
                return page
            }
        }
        val cache = TwitchApiCache({ api })
        val first = async { cache.fetchTopCategoriesPage() }
        val second = async { cache.fetchTopCategoriesPage() }
        testScheduler.runCurrent()
        assertEquals(1, calls)
        gate.complete(Unit)
        assertSame(page, first.await())
        assertSame(page, second.await())
        assertSame(page, cache.fetchTopCategoriesPage())
        assertEquals(1, calls)
    }

    @Test fun `refresh bypasses cached value`() = runTest {
        var calls = 0
        val api = object : FakeTwitchApi() {
            override suspend fun fetchTopCategoriesPage(first: Int, cursor: String?) =
                TwitchPage(listOf(TwitchCategory((++calls).toString(), "Category", null, calls)), null)
        }
        val cache = TwitchApiCache({ api })
        val first = cache.fetchTopCategoriesPage()
        val cached = cache.fetchTopCategoriesPage()
        val refreshed = cache.fetchTopCategoriesPage(refresh = true)
        assertSame(first, cached)
        assertNotSame(first, refreshed)
        assertEquals(2, calls)
    }

    @Test fun `clear prevents an old request from repopulating cache`() = runTest {
        val gates = mutableListOf<CompletableDeferred<Unit>>()
        var calls = 0
        val api = object : FakeTwitchApi() {
            override suspend fun fetchTopCategoriesPage(first: Int, cursor: String?): TwitchPage<TwitchCategory> {
                calls += 1
                val gate = CompletableDeferred<Unit>().also(gates::add)
                gate.await()
                return TwitchPage(listOf(TwitchCategory(calls.toString(), "Category", null, calls)), null)
            }
        }
        val cache = TwitchApiCache({ api })
        val old = async { cache.fetchTopCategoriesPage() }
        testScheduler.runCurrent()
        cache.clear()
        gates[0].complete(Unit)
        old.await()
        val fresh = async { cache.fetchTopCategoriesPage() }
        testScheduler.runCurrent()
        assertEquals(2, calls)
        gates[1].complete(Unit)
        fresh.await()
    }

    @Test fun `cache keys normalize iterable order`() {
        assertEquals(
            cacheKey("users", mapOf("ids" to listOf(" b ", "a"))),
            cacheKey("users", mapOf("ids" to listOf("a", "b"))),
        )
    }
}
