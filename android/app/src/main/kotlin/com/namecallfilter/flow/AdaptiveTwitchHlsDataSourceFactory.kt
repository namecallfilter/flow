package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.exoplayer.hls.HlsDataSourceFactory

@UnstableApi
internal class AdaptiveTwitchHlsDataSourceFactory(
    private val manifestResolver: TwitchManifestResolver,
    private val directFactory: DataSource.Factory,
) : HlsDataSourceFactory {
    override fun createDataSource(dataType: Int): DataSource =
        if (dataType == C.DATA_TYPE_MANIFEST) {
            TwitchManifestDataSource(manifestResolver)
        } else {
            directFactory.createDataSource()
        }
}
