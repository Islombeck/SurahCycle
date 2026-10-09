package dev.murajaah.murajaah.widget

import android.net.Uri
import org.json.JSONObject

internal const val WIDGET_SNAPSHOT_KEY = "murajaah_widget_snapshot"

internal data class NativeWidgetSnapshot(
    val snapshotRevision: Long,
    val rotation: NativeRotationProjection,
    val learning: NativeLearningProjection,
    val prayer: NativePrayerProjection,
)

internal data class NativePrayerProjection(
    val isAvailable: Boolean,
    val messageLabel: String?,
    val dateLabel: String?,
    val regionLabel: String?,
    val providerLabel: String?,
    val entries: List<NativePrayerEntry>,
    val windows: List<NativePrayerWindow>,
    val isStale: Boolean,
    val staleLabel: String?,
) {
    /**
     * Which row is current at [nowUtcMs], or null when nothing is.
     *
     * A comparison, not a judgement. Every decision that needed knowing
     * something about prayer — that Sunrise is a boundary and not a prayer,
     * that the hours before Fajr belong to last night's Isha — was made in
     * Dart and arrives here already expressed as intervals.
     *
     * Null outside every window, and that is the point: a snapshot written
     * yesterday covers yesterday. It used to carry "Asr is current" and the
     * launcher kept showing exactly that, for days.
     */
    fun currentIndexAt(nowUtcMs: Long): Int? =
        windows.firstOrNull { it.contains(nowUtcMs) }?.entryIndex?.takeIf { it >= 0 }

    /** The row whose prayer starts next, or null past the last window. */
    fun nextIndexAt(nowUtcMs: Long): Int? =
        windows
            .firstOrNull { it.startUtcMs > nowUtcMs && it.entryIndex >= 0 }
            ?.entryIndex

    /** When the answer above stops being true, or null past the last window. */
    fun windowEndsAt(nowUtcMs: Long): Long? =
        windows.firstOrNull { it.contains(nowUtcMs) }?.endUtcMs

    /**
     * The next instant at which another row becomes current — what a
     * countdown counts to — or null when this snapshot does not carry it.
     *
     * The start of the next window, not [windowEndsAt]. The two agree all
     * day except after Isha begins: the snapshot covers one calendar day, so
     * Isha's window ends at midnight, and a countdown to midnight counts to
     * nothing — Isha goes on. The real next boundary is tomorrow's Fajr,
     * which a snapshot of today does not have: null, and the strip says
     * nothing rather than guess.
     */
    fun nextBoundaryAt(nowUtcMs: Long): Long? = nextBoundaryWindow(nowUtcMs)?.startUtcMs

    /**
     * The row whose time is [nextBoundaryAt]. A window that names no prayer
     * begins at the boundary-only row — Sunrise, the end of Fajr's time —
     * because that is how Dart builds the day; it is read here, not decided.
     */
    fun nextBoundaryIndexAt(nowUtcMs: Long): Int? {
        val window = nextBoundaryWindow(nowUtcMs) ?: return null
        if (window.entryIndex >= 0) return window.entryIndex
        return entries.indexOfFirst { it.isBoundaryOnly }.takeIf { it >= 0 }
    }

    // Windows are contiguous (the parser requires it), so the window after
    // the one holding the clock begins exactly where the current one ends.
    private fun nextBoundaryWindow(nowUtcMs: Long): NativePrayerWindow? {
        val containing = windows.indexOfFirst { it.contains(nowUtcMs) }
        if (containing < 0) return null
        return windows.getOrNull(containing + 1)
    }
}

internal data class NativePrayerEntry(
    val label: String,
    val timeLabel: String,
    val isBoundaryOnly: Boolean,
)

/** A stretch of real time and the row that is current throughout it. */
internal data class NativePrayerWindow(
    val startUtcMs: Long,
    val endUtcMs: Long,
    val entryIndex: Int,
) {
    fun contains(instantUtcMs: Long): Boolean =
        instantUtcMs >= startUtcMs && instantUtcMs < endUtcMs
}

private val EMPTY_PRAYER_PROJECTION =
    NativePrayerProjection(
        isAvailable = false,
        messageLabel = null,
        dateLabel = null,
        regionLabel = null,
        providerLabel = null,
        entries = emptyList(),
        windows = emptyList(),
        isStale = false,
        staleLabel = null,
    )

internal data class NativeRotationProjection(
    val items: List<NativeRotationItem>,
    val omittedCount: Int,
    val contextLabel: String?,
    val currentPartLabel: String?,
    val slotProgressLabel: String?,
    val statusMessage: String?,
)

internal data class NativeRotationItem(
    val id: String,
    val title: String,
    val subtitle: String?,
    val debtLabel: String,
    val recommendationRank: Int?,
    val deepLink: Uri,
    val action: NativeRotationAction?,
    val isMarkedInCurrentPart: Boolean,
    val isActionInProgress: Boolean,
    val canMark: Boolean,
    val disabledReason: String?,
)

internal data class NativeRotationAction(
    val schemaVersion: Int,
    val actionToken: String,
    val surahId: String,
    val rotationSchemeId: String,
    val partId: String?,
    val prayerSessionId: String?,
    val prayerSessionPartId: String?,
    val slotIndex: Int?,
) {
    val uri: Uri
        get() =
            Uri.Builder()
                .scheme("murajaah-widget")
                .authority("recitation")
                .appendQueryParameter("schema", schemaVersion.toString())
                .appendQueryParameter("token", actionToken)
                .appendQueryParameter("surah", surahId)
                .appendQueryParameter("scheme", rotationSchemeId)
                .apply { partId?.let { appendQueryParameter("part", it) } }
                .apply { prayerSessionId?.let { appendQueryParameter("session", it) } }
                .apply { prayerSessionPartId?.let { appendQueryParameter("sessionPart", it) } }
                .apply { slotIndex?.let { appendQueryParameter("slot", it.toString()) } }
                .build()
}

internal data class NativeLearningProjection(val item: NativeLearningItem?)

internal data class NativeLearningItem(
    val title: String,
    val stageLabel: String,
    val rangeLabel: String,
    val unavailableTextLabel: String,
    val showArabic: Boolean,
    val showTransliteration: Boolean,
    val showTranslation: Boolean,
    val ayahLines: List<NativeLearningAyahLine>,
    val deepLink: Uri,
)

internal data class NativeLearningAyahLine(
    // Schema 2 had only Arabic strings. Nullable coordinates keep that old
    // display projection readable while schema 3 always supplies both values.
    val surahNumber: Int?,
    val ayahNumber: Int?,
    val arabic: String,
    val transliteration: String?,
    val translation: String?,
)

/**
 * Fail-closed decoder for the Dart-owned display projection.
 *
 * Any absent field, unknown schema version, unsafe link, duplicate identifier,
 * or unreasonable payload returns null. Widgets then render a localized safe
 * fallback instead of throwing from a launcher process.
 */
internal object NativeWidgetSnapshotParser {
    private const val LEGACY_SCHEMA_VERSION = 2
    private const val PREVIOUS_SCHEMA_VERSION = 3
    private const val INTERACTIVE_SCHEMA_VERSION = 4
    private const val PRAYER_SCHEMA_VERSION = 7
    private const val SCHEMA_VERSION = 7
    private const val PRAYER_WINDOW_COUNT_MAX = 8
    private const val MAX_ROTATION_ITEMS = 64
    private const val MAX_TEXT_LINES = 3
    private const val PRAYER_ENTRY_COUNT = 6
    // Mirrors Dart's domain-level maxRecommendationCount.
    private const val MAX_RECOMMENDATION_COUNT = 8

    fun parse(raw: String?): NativeWidgetSnapshot? {
        if (raw.isNullOrEmpty() || raw.length > 2_000_000) return null
        return runCatching {
            val root = JSONObject(raw)
            val schemaVersion = root.getInt("schemaVersion")
            // 6 is deliberately gone. It carried a frozen "this prayer is
            // current" flag, and accepting it would be accepting the stale
            // answer schema 7 exists to remove — the launcher would keep
            // highlighting whichever prayer was current when the app last ran.
            // A rejected snapshot renders the safe fallback, which is honest.
            require(
                    schemaVersion == LEGACY_SCHEMA_VERSION ||
                    schemaVersion == PREVIOUS_SCHEMA_VERSION ||
                    schemaVersion == INTERACTIVE_SCHEMA_VERSION ||
                    schemaVersion == 5 ||
                    schemaVersion == SCHEMA_VERSION
            )
            val rootKeys =
                mutableSetOf("schemaVersion", "generatedAtUtc", "locale", "rotation", "learning")
            if (schemaVersion >= INTERACTIVE_SCHEMA_VERSION) rootKeys += "snapshotRevision"
            if (schemaVersion >= PRAYER_SCHEMA_VERSION) rootKeys += "prayer"
            requireOnlyKeys(root, rootKeys)
            requireText(root.getString("generatedAtUtc"), 128)
            requireText(root.getString("locale"), 32)
            NativeWidgetSnapshot(
                snapshotRevision =
                    if (schemaVersion >= INTERACTIVE_SCHEMA_VERSION) {
                        root.getLong("snapshotRevision").also { require(it >= 0L) }
                    } else {
                        0L
                    },
                rotation = parseRotation(root.getJSONObject("rotation"), schemaVersion),
                learning = parseLearning(root.getJSONObject("learning"), schemaVersion),
                prayer =
                    if (schemaVersion >= PRAYER_SCHEMA_VERSION) {
                        parsePrayer(root.getJSONObject("prayer"))
                    } else {
                        EMPTY_PRAYER_PROJECTION
                    },
            )
        }.getOrNull()
    }

    private fun parsePrayer(json: JSONObject): NativePrayerProjection {
        val isAvailable = json.getBoolean("isAvailable")
        if (!isAvailable) {
            requireOnlyKeys(
                json,
                setOf("isAvailable", "messageLabel", "entries", "windows", "isStale"),
            )
            require(json.getJSONArray("entries").length() == 0)
            require(json.getJSONArray("windows").length() == 0)
            require(!json.getBoolean("isStale"))
            return NativePrayerProjection(
                isAvailable = false,
                messageLabel = requireText(json.getString("messageLabel"), 256),
                dateLabel = null,
                regionLabel = null,
                providerLabel = null,
                entries = emptyList(),
                windows = emptyList(),
                isStale = false,
                staleLabel = null,
            )
        }
        requireOnlyKeys(
            json,
            setOf(
                "isAvailable",
                "dateLabel",
                "regionLabel",
                "providerLabel",
                "entries",
                "windows",
                "isStale",
                "staleLabel",
            ),
        )
        val entriesJson = json.getJSONArray("entries")
        require(entriesJson.length() == PRAYER_ENTRY_COUNT)
        val entries = ArrayList<NativePrayerEntry>(entriesJson.length())
        for (index in 0 until entriesJson.length()) {
            val entry = entriesJson.getJSONObject(index)
            requireOnlyKeys(entry, setOf("label", "timeLabel", "isBoundaryOnly"))
            entries +=
                NativePrayerEntry(
                    label = requireText(entry.getString("label"), 64),
                    timeLabel = requireText(entry.getString("timeLabel"), 16),
                    isBoundaryOnly = entry.getBoolean("isBoundaryOnly"),
                )
        }
        // The same invariants Dart enforces when it builds them, checked again
        // rather than trusted: ordered, contiguous, never naming Sunrise. A
        // decoder more forgiving than the writer is how a widget comes to
        // render a state the app considers impossible.
        val windowsJson = json.getJSONArray("windows")
        require(windowsJson.length() in 1..PRAYER_WINDOW_COUNT_MAX)
        val windows = ArrayList<NativePrayerWindow>(windowsJson.length())
        for (index in 0 until windowsJson.length()) {
            val window = windowsJson.getJSONObject(index)
            requireOnlyKeys(window, setOf("startUtcMs", "endUtcMs", "entryIndex"))
            val start = window.getLong("startUtcMs")
            val end = window.getLong("endUtcMs")
            val entryIndex = window.getInt("entryIndex")
            require(end > start)
            require(entryIndex >= -1 && entryIndex < PRAYER_ENTRY_COUNT)
            require(entryIndex < 0 || !entries[entryIndex].isBoundaryOnly)
            require(index == 0 || windows[index - 1].endUtcMs == start)
            windows += NativePrayerWindow(start, end, entryIndex)
        }
        val isStale = json.getBoolean("isStale")
        return NativePrayerProjection(
            isAvailable = true,
            messageLabel = null,
            dateLabel = requireText(json.getString("dateLabel"), 128),
            regionLabel = requireText(json.getString("regionLabel"), 256),
            providerLabel = requireText(json.getString("providerLabel"), 256),
            entries = entries,
            windows = windows,
            isStale = isStale,
            staleLabel =
                if (isStale) {
                    requireText(json.getString("staleLabel"), 256)
                } else {
                    require(!json.has("staleLabel") || json.isNull("staleLabel"))
                    null
                },
        )
    }

    private fun parseRotation(
        json: JSONObject,
        schemaVersion: Int,
    ): NativeRotationProjection {
        val itemsJson = json.getJSONArray("items")
        require(itemsJson.length() <= MAX_ROTATION_ITEMS)
        val omittedCount = json.getInt("omittedCount")
        require(omittedCount >= 0)
        val ids = HashSet<String>(itemsJson.length())
        val stableIds = HashSet<Long>(itemsJson.length())
        val recommendationRanks = HashSet<Int>(MAX_RECOMMENDATION_COUNT)
        val actionTokens = HashSet<String>(itemsJson.length())
        val items = ArrayList<NativeRotationItem>(itemsJson.length())
        for (index in 0 until itemsJson.length()) {
            val item = itemsJson.getJSONObject(index)
            val id = requireText(item.getString("id"), 256)
            require(ids.add(id))
            require(stableIds.add(stableWidgetItemId(id)))
            val surahId = requireSafeId(item.getString("surahId"))
            val partId = item.optionalString("partId")?.let(::requireSafeId)
            val remaining = item.getInt("remaining")
            require(remaining >= 0)
            val debtLabel = item.getString("debtLabel")
            require(debtLabel.length <= 32)
            require(debtLabel == if (remaining > 1) "${remaining}×" else "")
            val recommendationRank =
                if (item.has("recommendationRank")) {
                    require(!item.isNull("recommendationRank"))
                    item.getInt("recommendationRank").also { rank ->
                        require(rank in 0 until MAX_RECOMMENDATION_COUNT)
                        require(recommendationRanks.add(rank))
                    }
                } else {
                    null
                }
            val deepLink = Uri.parse(item.getString("deepLink"))
            require(isSafeRotationLink(deepLink, surahId, partId))
            val action =
                if (schemaVersion >= PREVIOUS_SCHEMA_VERSION && item.has("action")) {
                    require(!item.isNull("action"))
                    parseAction(item.getJSONObject("action"), surahId, partId).also {
                        require(actionTokens.add(it.actionToken))
                    }
                } else {
                    null
                }
            val isMarked =
                if (schemaVersion >= INTERACTIVE_SCHEMA_VERSION) {
                    item.getBoolean("isMarkedInCurrentPart")
                } else {
                    false
                }
            val isProcessing =
                if (schemaVersion >= INTERACTIVE_SCHEMA_VERSION) {
                    item.getBoolean("isActionInProgress")
                } else {
                    false
                }
            val canMark =
                if (schemaVersion >= INTERACTIVE_SCHEMA_VERSION) {
                    item.getBoolean("canMark")
                } else {
                    action != null
                }
            val disabledReason =
                if (schemaVersion >= INTERACTIVE_SCHEMA_VERSION) {
                    item.optionalString("disabledReason")?.let { requireText(it, 256) }
                } else {
                    null
                }
            require(!canMark || action != null)
            require(!isMarked || !canMark)
            items +=
                NativeRotationItem(
                    id = id,
                    title = requireText(item.getString("title"), 512),
                    subtitle = item.optionalString("subtitle")?.let { requireText(it, 512) },
                    debtLabel = debtLabel,
                    recommendationRank = recommendationRank,
                    deepLink = deepLink,
                    action = action,
                    isMarkedInCurrentPart = isMarked,
                    isActionInProgress = isProcessing,
                    canMark = canMark,
                    disabledReason = disabledReason,
                )
        }
        return NativeRotationProjection(
            items = items,
            omittedCount = omittedCount,
            contextLabel =
                if (schemaVersion >= PREVIOUS_SCHEMA_VERSION) {
                    requireText(json.getString("contextLabel"), 256)
                } else {
                    null
                },
            currentPartLabel =
                if (schemaVersion >= SCHEMA_VERSION) {
                    json.optionalString("currentPartLabel")?.let { requireText(it, 256) }
                } else {
                    null
                },
            slotProgressLabel =
                if (schemaVersion >= SCHEMA_VERSION) {
                    json.optionalString("slotProgressLabel")?.let { requireText(it, 256) }
                } else {
                    null
                },
            statusMessage =
                if (schemaVersion >= PREVIOUS_SCHEMA_VERSION) {
                    json.optionalString("statusMessage")?.let { requireText(it, 512) }
                } else {
                    null
                },
        )
    }

    private fun parseAction(
        json: JSONObject,
        expectedSurahId: String,
        expectedPartId: String?,
    ): NativeRotationAction {
        val actionSchemaVersion = json.getInt("schemaVersion")
        require(
            actionSchemaVersion == LEGACY_ACTION_SCHEMA_VERSION ||
                actionSchemaVersion == ACTION_SCHEMA_VERSION
        )
        val allowedKeys =
            mutableSetOf(
                "schemaVersion",
                "actionToken",
                "surahId",
                "rotationSchemeId",
                "partId",
            )
        if (actionSchemaVersion >= ACTION_SCHEMA_VERSION) {
            allowedKeys += "prayerSessionId"
            allowedKeys += "prayerSessionPartId"
            allowedKeys += "slotIndex"
        }
        requireOnlyKeys(
            json,
            allowedKeys,
        )
        val actionToken = requireText(json.getString("actionToken"), 36)
        require(UUID_V4.matches(actionToken))
        val surahId = requireSafeId(json.getString("surahId"))
        val schemeId = requireSafeId(json.getString("rotationSchemeId"))
        val partId = json.optionalString("partId")?.let(::requireSafeId)
        val prayerSessionId =
            json.optionalString("prayerSessionId")?.let(::requireSafeId)
        val prayerSessionPartId =
            json.optionalString("prayerSessionPartId")?.let(::requireSafeId)
        val slotIndex =
            if (json.has("slotIndex") && !json.isNull("slotIndex")) {
                json.getInt("slotIndex").also { require(it in 0..MAX_PRAYER_SLOT_INDEX) }
            } else {
                null
            }
        val hasAnySlotTarget =
            prayerSessionId != null || prayerSessionPartId != null || slotIndex != null
        val hasCompleteSlotTarget =
            prayerSessionId != null && prayerSessionPartId != null && slotIndex != null
        require(hasAnySlotTarget == hasCompleteSlotTarget)
        require(surahId == expectedSurahId && partId == expectedPartId)
        return NativeRotationAction(
            schemaVersion = actionSchemaVersion,
            actionToken = actionToken.lowercase(),
            surahId = surahId,
            rotationSchemeId = schemeId,
            partId = partId,
            prayerSessionId = prayerSessionId,
            prayerSessionPartId = prayerSessionPartId,
            slotIndex = slotIndex,
        )
    }

    private fun parseLearning(
        json: JSONObject,
        schemaVersion: Int,
    ): NativeLearningProjection {
        if (!json.has("item") || json.isNull("item")) {
            return NativeLearningProjection(item = null)
        }
        val item = json.getJSONObject("item")
        val surahId = requireSafeId(item.getString("surahId"))
        val deepLink = Uri.parse(item.getString("deepLink"))
        require(isSafeLearningLink(deepLink, surahId))
        val lines: List<NativeLearningAyahLine>
        val showArabic: Boolean
        val showTransliteration: Boolean
        val showTranslation: Boolean
        if (schemaVersion == LEGACY_SCHEMA_VERSION) {
            val linesJson = item.getJSONArray("verifiedTextLines")
            require(linesJson.length() <= MAX_TEXT_LINES)
            lines =
                List(linesJson.length()) { index ->
                    // No trim/normalization: these are exact verified cache strings.
                    NativeLearningAyahLine(
                        surahNumber = null,
                        ayahNumber = null,
                        arabic = requireText(linesJson.getString(index), 8192),
                        transliteration = null,
                        translation = null,
                    )
                }
            showArabic = true
            showTransliteration = false
            showTranslation = false
        } else {
            val surahNumber = item.getInt("surahNumber")
            val startAyah = item.getInt("startAyah")
            val endAyah = item.getInt("endAyah")
            require(surahNumber > 0 && startAyah > 0 && endAyah >= startAyah)
            showArabic = item.getBoolean("showArabic")
            showTransliteration = item.getBoolean("showTransliteration")
            showTranslation = item.getBoolean("showTranslation")
            val linesJson = item.getJSONArray("ayahLines")
            require(linesJson.length() <= MAX_TEXT_LINES)
            var previousAyah = 0
            lines =
                List(linesJson.length()) { index ->
                    val line = linesJson.getJSONObject(index)
                    val lineSurah = line.getInt("surah")
                    val lineAyah = line.getInt("ayah")
                    require(
                        lineSurah == surahNumber &&
                            lineAyah in startAyah..endAyah &&
                            lineAyah > previousAyah
                    )
                    previousAyah = lineAyah
                    NativeLearningAyahLine(
                        surahNumber = lineSurah,
                        ayahNumber = lineAyah,
                        arabic = requireText(line.getString("arabic"), 8192),
                        transliteration =
                            line.optionalString("transliteration")?.let {
                                requireText(it, 8192)
                            },
                        translation =
                            line.optionalString("translation")?.let {
                                requireText(it, 8192)
                            },
                    )
                }
        }
        return NativeLearningProjection(
            NativeLearningItem(
                title = requireText(item.getString("title"), 512),
                stageLabel = requireText(item.getString("stageLabel"), 256),
                rangeLabel = requireText(item.getString("rangeLabel"), 256),
                unavailableTextLabel =
                    requireText(item.getString("unavailableTextLabel"), 512),
                showArabic = showArabic,
                showTransliteration = showTransliteration,
                showTranslation = showTranslation,
                ayahLines = lines,
                deepLink = deepLink,
            )
        )
    }

    private fun JSONObject.optionalString(key: String): String? =
        if (has(key) && !isNull(key)) getString(key) else null

    private fun requireOnlyKeys(json: JSONObject, allowed: Set<String>) {
        val keys = json.keys()
        while (keys.hasNext()) require(keys.next() in allowed)
    }

    private fun requireText(value: String, maxLength: Int): String {
        require(value.isNotEmpty() && value.length <= maxLength)
        return value
    }

    private fun requireSafeId(value: String): String {
        require(value.length in 1..128 && SAFE_ID.matches(value))
        return value
    }

    private fun isSafeRotationLink(uri: Uri, surahId: String, partId: String?): Boolean {
        if (!hasSafeBase(uri) || uri.pathSegments != listOf("surah", surahId)) return false
        if (uri.queryParameterNames.any { it != "part" }) return false
        val linkPartId = uri.getQueryParameter("part")
        return if (partId == null) {
            linkPartId == null && uri.queryParameterNames.isEmpty()
        } else {
            linkPartId == partId && uri.getQueryParameters("part").size == 1
        }
    }

    private fun isSafeLearningLink(uri: Uri, surahId: String): Boolean =
        hasSafeBase(uri) &&
            uri.pathSegments == listOf("learning", surahId) &&
            uri.queryParameterNames.isEmpty()

    private fun hasSafeBase(uri: Uri): Boolean =
        uri.scheme == "murajaah" &&
            uri.host == "app" &&
            uri.userInfo == null &&
            uri.port == -1 &&
            uri.fragment == null

    private val SAFE_ID = Regex("^[A-Za-z0-9._~:-]+$")
    private val UUID_V4 =
        Regex(
            "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-" +
                "[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
        )
}

internal const val LEGACY_ACTION_SCHEMA_VERSION = 1
internal const val ACTION_SCHEMA_VERSION = 2
private const val MAX_PRAYER_SLOT_INDEX = 1023

internal fun stableWidgetItemId(value: String): Long {
    var hash = 1_125_899_906_842_597L
    for (character in value) hash = 31L * hash + character.code
    // Glance reserves the lowest quarter of Long values for generated lazy-list
    // IDs. Keep application-owned IDs non-negative so overflow can never enter
    // that reserved range.
    return hash and Long.MAX_VALUE
}
