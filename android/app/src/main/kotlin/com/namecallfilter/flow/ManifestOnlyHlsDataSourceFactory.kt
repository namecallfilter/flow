package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.exoplayer.hls.HlsDataSourceFactory

@UnstableApi
internal class ManifestOnlyHlsDataSourceFactory(
    private val manifestFactory: DataSource.Factory,
    private val directFactory: DataSource.Factory,
) : HlsDataSourceFactory {
    override fun createDataSource(dataType: Int): DataSource =
        if (dataType == C.DATA_TYPE_MANIFEST) {
            manifestFactory.createDataSource()
        } else {
            directFactory.createDataSource()
        }
}
