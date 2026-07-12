package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.ByteArrayDataSource
import androidx.media3.datasource.DataSource
import org.junit.Assert.assertSame
import org.junit.Test

@UnstableApi
class ManifestOnlyHlsDataSourceFactoryTest {
    private val proxiedDataSource = ByteArrayDataSource(byteArrayOf(1))
    private val directDataSource = ByteArrayDataSource(byteArrayOf(2))
    private val factory = ManifestOnlyHlsDataSourceFactory(
        manifestFactory = DataSource.Factory { proxiedDataSource },
        directFactory = DataSource.Factory { directDataSource },
    )

    @Test
    fun manifestUsesProxiedDataSource() {
        assertSame(proxiedDataSource, factory.createDataSource(C.DATA_TYPE_MANIFEST))
    }

    @Test
    fun mediaUsesDirectDataSource() {
        assertSame(directDataSource, factory.createDataSource(C.DATA_TYPE_MEDIA))
    }

    @Test
    fun drmUsesDirectDataSource() {
        assertSame(directDataSource, factory.createDataSource(C.DATA_TYPE_DRM))
    }

    @Test
    fun unknownDataTypeUsesDirectDataSource() {
        assertSame(directDataSource, factory.createDataSource(Int.MAX_VALUE))
    }
}
