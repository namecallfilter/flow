package com.namecallfilter.flow

import androidx.media3.common.C
import java.util.GregorianCalendar
import java.util.TimeZone
import kotlin.math.roundToLong

internal data class TwitchAdCue(
    val id: String,
    val startEpochMs: Long,
    val durationMs: Long,
    val podPosition: Int,
    val podLength: Int,
    val rollType: String?,
    val podId: String = id,
    val podFilledDurationMs: Long? = null,
) {
    val endEpochMs: Long
        get() = startEpochMs + durationMs
}

internal data class TwitchAdProgress(
    val cue: TwitchAdCue,
    val current: Int,
    val total: Int,
    val currentDurationMs: Long,
    val currentRemainingMs: Long,
    val podDurationMs: Long,
    val podRemainingMs: Long,
)

internal fun parseTwitchAdCue(tag: String): TwitchAdCue? {
    if (!tag.startsWith(DATE_RANGE_PREFIX, ignoreCase = true)) {
        return null
    }
    val attributes = parseHlsAttributeList(tag)
    val id = attributes["ID"]?.trim().orEmpty()
    val rangeClass = attributes["CLASS"]?.trim().orEmpty()
    if (
        rangeClass.equals(TWITCH_AD_QUARTILE_CLASS, ignoreCase = true) ||
        attributes.containsKey(TWITCH_AD_QUARTILE_ATTRIBUTE)
    ) {
        return null
    }
    // Twitch also emits short `twitch-ad-quartile` date ranges carrying an
    // X-TV-TWITCH-AD-QUARTILE attribute. Those are tracking markers, not ad
    // creatives. Treating every Twitch ad-prefixed attribute as a creative
    // makes the counter repeatedly reset to "Ad 1 of 1" for two seconds.
    val isTwitchAd = id.startsWith("stitched-ad-", ignoreCase = true) ||
        rangeClass.equals(TWITCH_STITCHED_AD_CLASS, ignoreCase = true)
    if (!isTwitchAd || id.isEmpty()) {
        return null
    }

    val startEpochMs = attributes["START-DATE"]?.let(::parseIso8601EpochMs) ?: return null
    val explicitDurationMs = sequenceOf(
        attributes["DURATION"],
        attributes["PLANNED-DURATION"],
        attributes["X-TV-TWITCH-AD-DURATION"],
    ).mapNotNull(::secondsToMilliseconds).firstOrNull()
    val endDurationMs = attributes["END-DATE"]
        ?.let(::parseIso8601EpochMs)
        ?.minus(startEpochMs)
        ?.takeIf { it in 1..MAX_AD_DURATION_MS }
    val durationMs = explicitDurationMs ?: endDurationMs ?: return null

    val podLength = attributes["X-TV-TWITCH-AD-POD-LENGTH"]
        ?.toIntOrNull()
        ?.takeIf { it in 1..MAX_AD_COUNT }
        ?: 1
    val podPosition = attributes["X-TV-TWITCH-AD-POD-POSITION"]
        ?.toIntOrNull()
        ?.takeIf { it in 0 until podLength }
        ?: 0
    val podId = sequenceOf(
        attributes["X-TV-TWITCH-AD-AD-SESSION-ID"],
        attributes["X-TV-TWITCH-AD-RADS-TOKEN"],
        attributes["X-TV-TWITCH-AD-COMMERCIAL-ID"],
        attributes["COMMERCIAL-ID"],
    ).mapNotNull { value -> value?.trim()?.takeIf(String::isNotEmpty) }
        .firstOrNull()
        ?: id
    return TwitchAdCue(
        id = id,
        startEpochMs = startEpochMs,
        durationMs = durationMs,
        podPosition = podPosition,
        podLength = podLength,
        rollType = attributes["X-TV-TWITCH-AD-ROLL-TYPE"]?.trim()?.takeIf(String::isNotEmpty),
        podId = podId,
        podFilledDurationMs = secondsToMilliseconds(
            attributes["X-TV-TWITCH-AD-POD-FILLED-DURATION"],
        ),
    )
}

internal fun activeTwitchAdCue(
    cues: Collection<TwitchAdCue>,
    playbackEpochMs: Long,
): TwitchAdCue? = cues.asSequence()
    .filter { playbackEpochMs >= it.startEpochMs && playbackEpochMs < it.endEpochMs }
    .sortedWith(compareByDescending<TwitchAdCue> { it.startEpochMs }.thenBy { it.podPosition })
    .firstOrNull()

internal fun twitchAdProgress(
    cues: Collection<TwitchAdCue>,
    playbackEpochMs: Long,
): TwitchAdProgress? {
    val activeCue = activeTwitchAdCue(cues, playbackEpochMs) ?: return null
    val podCues = cues.filter { it.podId == activeCue.podId }
    val podStartMs = podCues
        .filter { it.podPosition == 0 }
        .minOfOrNull(TwitchAdCue::startEpochMs)
        ?: podCues.minOfOrNull(TwitchAdCue::startEpochMs)
        ?: activeCue.startEpochMs
    val total = maxOf(
        activeCue.podLength,
        podCues.maxOfOrNull { it.podLength } ?: 1,
        (podCues.maxOfOrNull { it.podPosition } ?: 0) + 1,
    )
    val filledDurationMs = podCues.mapNotNull(TwitchAdCue::podFilledDurationMs).maxOrNull()
    val knownPodDurationMs = podCues.maxOfOrNull(TwitchAdCue::endEpochMs)
        ?.minus(podStartMs)
        ?.takeIf { it > 0 }
        ?: activeCue.durationMs
    val podDurationMs = filledDurationMs ?: knownPodDurationMs
    val currentRemainingMs = roundRemainingAdTimeMs(activeCue.endEpochMs - playbackEpochMs)
    // POD-FILLED-DURATION is Twitch's duration for the complete break. It is
    // authoritative whole-break metadata. Creative ranges can include a
    // fractional segment tail, so keep one visible second while one is active.
    val rawPodRemainingMs = podStartMs + podDurationMs - playbackEpochMs
    val podRemainingMs = roundRemainingAdTimeMs(
        if (currentRemainingMs > 0) maxOf(1L, rawPodRemainingMs) else rawPodRemainingMs,
    )
    return TwitchAdProgress(
        cue = activeCue,
        current = activeCue.podPosition + 1,
        total = total,
        currentDurationMs = activeCue.durationMs,
        currentRemainingMs = currentRemainingMs,
        podDurationMs = podDurationMs,
        podRemainingMs = podRemainingMs,
    )
}

internal fun playbackEpochMs(windowStartTimeMs: Long, positionMs: Long): Long? {
    if (windowStartTimeMs == C.TIME_UNSET || positionMs < 0) {
        return null
    }
    return runCatching { Math.addExact(windowStartTimeMs, positionMs) }.getOrNull()
}

internal fun adFallbackLatencyMs(
    clientNowMs: Long,
    serverOffsetMs: Long?,
    playbackEpochMs: Long,
): Long? {
    val offsetMs = serverOffsetMs ?: return null
    val serverNowMs = runCatching { Math.addExact(clientNowMs, offsetMs) }.getOrNull() ?: return null
    val latencyMs = serverNowMs - playbackEpochMs
    return latencyMs.takeIf { it in 0..MAX_VALID_LATENCY_MS }
}

/**
 * Keeps the stitched-ad timeline fallback alive across inaccurate playlist cue
 * boundaries. Twitch can remove/end a DATERANGE before the final stitched
 * creative and its queued metadata have finished playing. A current, accepted
 * transc_r sample is the authoritative signal that normal live content has
 * resumed.
 */
internal class StitchedAdLatencyFallback {
    private var active = false
    private var cueActive = false

    fun onAdProgress(isActive: Boolean) {
        // Arm only on a cue's rising edge. Once a valid primary sample releases
        // this fallback, repeated ticks for that same cue must not re-arm it.
        if (isActive && !cueActive) {
            active = true
        }
        cueActive = isActive
    }

    /** Returns true when a latched fallback was released. */
    fun onAcceptedPrimaryLatency(): Boolean {
        val wasActive = active
        active = false
        return wasActive
    }

    fun shouldUseTimeline(primaryLatencyIsFresh: Boolean): Boolean =
        active && !primaryLatencyIsFresh

    fun reset() {
        active = false
        cueActive = false
    }
}

internal fun parseHlsAttributeList(tag: String): Map<String, String> {
    val attributes = linkedMapOf<String, String>()
    val value = tag.substringAfter(':', missingDelimiterValue = "")
    var index = 0
    while (index < value.length) {
        while (index < value.length && (value[index] == ',' || value[index].isWhitespace())) {
            index++
        }
        val keyStart = index
        while (index < value.length && value[index] != '=' && value[index] != ',') {
            index++
        }
        if (index >= value.length || value[index] != '=') {
            while (index < value.length && value[index] != ',') index++
            continue
        }
        val key = value.substring(keyStart, index).trim().uppercase()
        index++
        while (index < value.length && value[index].isWhitespace()) index++

        val attributeValue = if (index < value.length && value[index] == '"') {
            index++
            buildString {
                while (index < value.length) {
                    val character = value[index++]
                    if (character == '"') {
                        break
                    }
                    if (character == '\\' && index < value.length) {
                        append(value[index++])
                    } else {
                        append(character)
                    }
                }
            }
        } else {
            val valueStart = index
            while (index < value.length && value[index] != ',') index++
            value.substring(valueStart, index).trim()
        }
        if (key.isNotEmpty()) {
            attributes[key] = attributeValue
        }
        while (index < value.length && value[index] != ',') index++
    }
    return attributes
}

private fun secondsToMilliseconds(value: String?): Long? {
    val seconds = value?.toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 } ?: return null
    return (seconds * C.MILLIS_PER_SECOND)
        .roundToLong()
        .takeIf { it in 1..MAX_AD_DURATION_MS }
}

internal fun parseIso8601EpochMs(value: String): Long? {
    val match = ISO_8601_DATE_TIME.matchEntire(value.trim()) ?: return null
    return runCatching {
        val fraction = match.groupValues[7].padEnd(3, '0').take(3)
        val calendar = GregorianCalendar(UTC).apply {
            isLenient = false
            clear()
            set(
                match.groupValues[1].toInt(),
                match.groupValues[2].toInt() - 1,
                match.groupValues[3].toInt(),
                match.groupValues[4].toInt(),
                match.groupValues[5].toInt(),
                match.groupValues[6].toInt(),
            )
            set(GregorianCalendar.MILLISECOND, fraction.ifEmpty { "0" }.toInt())
        }
        val timezone = match.groupValues[8]
        val offsetMinutes = if (timezone.equals("Z", ignoreCase = true)) {
            0
        } else {
            val sign = if (match.groupValues[9] == "-") -1 else 1
            sign * (match.groupValues[10].toInt() * 60 + match.groupValues[11].toInt())
        }
        calendar.timeInMillis - offsetMinutes * 60_000L
    }.getOrNull()
}

private const val DATE_RANGE_PREFIX = "#EXT-X-DATERANGE:"
private const val TWITCH_STITCHED_AD_CLASS = "twitch-stitched-ad"
private const val TWITCH_AD_QUARTILE_CLASS = "twitch-ad-quartile"
private const val TWITCH_AD_QUARTILE_ATTRIBUTE = "X-TV-TWITCH-AD-QUARTILE"
private const val MAX_AD_COUNT = 100
private const val MAX_AD_DURATION_MS = 30 * 60 * 1000L
private const val MAX_VALID_LATENCY_MS = 10 * 60 * 1000L
private val UTC = TimeZone.getTimeZone("UTC")
private val ISO_8601_DATE_TIME = Regex(
    """^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|([+-])(\d{2}):?(\d{2}))$""",
    RegexOption.IGNORE_CASE,
)
