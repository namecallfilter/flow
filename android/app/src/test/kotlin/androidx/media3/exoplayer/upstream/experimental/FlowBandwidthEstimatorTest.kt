package androidx.media3.exoplayer.upstream.experimental

import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.ByteArrayDataSource
import org.junit.Assert.assertEquals
import org.junit.Test

@UnstableApi
class FlowBandwidthEstimatorTest {
    @Test
    fun firstCompletedSegmentProvidesAnEstimateBelowTheOldStartupThreshold() {
        var nowMs = 0L
        val clock = object : Clock by Clock.DEFAULT {
            override fun elapsedRealtime() = nowMs
        }
        // Use the same native estimator as ExperimentalBandwidthMeter's default.
        val statistic = SlidingWeightedAverageBandwidthStatistic(
            SlidingWeightedAverageBandwidthStatistic.getMaxCountEvictionFunction(
                SlidingWeightedAverageBandwidthStatistic.DEFAULT_MAX_SAMPLES_COUNT.toLong(),
            ),
            clock,
        )
        val estimator = SplitParallelSampleBandwidthEstimator.Builder()
            .setClock(clock)
            .setBandwidthStatistic(statistic)
            .build()
        val source = ByteArrayDataSource(byteArrayOf(1))

        estimator.onTransferStart(source)
        estimator.onBytesTransferred(source, 100_000)
        nowMs = 20L
        estimator.onTransferEnd(source)

        assertEquals(40_000_000L, estimator.bandwidthEstimate)
    }
}
