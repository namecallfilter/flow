package com.namecallfilter.flow

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener

@UnstableApi
internal data class ResolvedManifest(
    val bytes: ByteArray,
    val finalUri: Uri,
    val responseHeaders: Map<String, List<String>> = emptyMap(),
)

@UnstableApi
internal fun interface TwitchManifestResolver {
    fun resolve(dataSpec: DataSpec, transferListeners: List<TransferListener>): ResolvedManifest
}

@UnstableApi
internal class TwitchManifestDataSource(
    private val resolver: TwitchManifestResolver,
) : DataSource {
    private val transferListeners = linkedSetOf<TransferListener>()
    private var bytes: ByteArray? = null
    private var readPosition = 0
    private var resolvedUri: Uri? = null
    private var responseHeaders: Map<String, List<String>> = emptyMap()

    override fun addTransferListener(transferListener: TransferListener) {
        transferListeners.add(transferListener)
    }

    override fun open(dataSpec: DataSpec): Long {
        check(bytes == null) { "Data source is already open" }
        val resolved = resolver.resolve(dataSpec, transferListeners.toList())
        bytes = resolved.bytes
        readPosition = 0
        resolvedUri = resolved.finalUri
        responseHeaders = resolved.responseHeaders
        return resolved.bytes.size.toLong()
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) {
            return 0
        }
        val source = checkNotNull(bytes) { "Data source is not open" }
        if (readPosition == source.size) {
            return C.RESULT_END_OF_INPUT
        }
        val bytesToRead = minOf(length, source.size - readPosition)
        source.copyInto(buffer, offset, readPosition, readPosition + bytesToRead)
        readPosition += bytesToRead
        return bytesToRead
    }

    override fun getUri(): Uri? = resolvedUri

    override fun getResponseHeaders(): Map<String, List<String>> = responseHeaders

    override fun close() {
        bytes = null
        readPosition = 0
        resolvedUri = null
        responseHeaders = emptyMap()
    }
}
