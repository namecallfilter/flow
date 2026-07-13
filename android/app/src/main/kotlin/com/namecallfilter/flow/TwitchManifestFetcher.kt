package com.namecallfilter.flow

import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import java.io.ByteArrayOutputStream

@UnstableApi
internal fun interface TwitchManifestFetcher {
    fun fetch(
        factory: DataSource.Factory,
        dataSpec: DataSpec,
        transferListeners: List<TransferListener>,
    ): ResolvedManifest
}

@UnstableApi
internal object Media3TwitchManifestFetcher : TwitchManifestFetcher {
    override fun fetch(
        factory: DataSource.Factory,
        dataSpec: DataSpec,
        transferListeners: List<TransferListener>,
    ): ResolvedManifest {
        val source = factory.createDataSource()
        transferListeners.forEach(source::addTransferListener)
        return try {
            source.open(dataSpec)
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            val output = ByteArrayOutputStream()
            while (true) {
                val bytesRead = source.read(buffer, 0, buffer.size)
                if (bytesRead == C.RESULT_END_OF_INPUT) {
                    break
                }
                output.write(buffer, 0, bytesRead)
            }
            ResolvedManifest(
                bytes = output.toByteArray(),
                finalUri = source.uri ?: dataSpec.uri,
                responseHeaders = source.responseHeaders,
            )
        } finally {
            source.close()
        }
    }
}
