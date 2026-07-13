package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.ByteArrayDataSource
import androidx.media3.datasource.DataSource
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class AdaptiveTwitchHlsDataSourceFactoryTest {
    private val directDataSource = ByteArrayDataSource(byteArrayOf(1))
    private val factory = AdaptiveTwitchHlsDataSourceFactory(
        manifestResolver = TwitchManifestResolver { _, _ -> error("not opened") },
        directFactory = DataSource.Factory { directDataSource },
    )

    @Test
    fun manifestUsesAdaptiveDataSource() {
        assertTrue(factory.createDataSource(C.DATA_TYPE_MANIFEST) is TwitchManifestDataSource)
    }

    @Test
    fun mediaAndKeysRemainDirect() {
        assertSame(directDataSource, factory.createDataSource(C.DATA_TYPE_MEDIA))
        assertSame(directDataSource, factory.createDataSource(C.DATA_TYPE_DRM))
        assertSame(directDataSource, factory.createDataSource(Int.MAX_VALUE))
    }
}
