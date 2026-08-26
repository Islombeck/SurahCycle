package dev.murajaah.murajaah.widget

import android.net.Uri
import org.json.JSONObject

internal const val WIDGET_SNAPSHOT_KEY = "murajaah_widget_snapshot"

internal data class NativeWidgetSnapshot(
    val rotation: NativeRotationProjection,
    val learning: NativeLearningProjection,
)

internal data class NativeRotationProjection(
    val items: List<NativeRotationItem>,
    val omittedCount: Int,
    val contextLabel: String?,
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
)

internal data class NativeRotationAction(
    val actionToken: String,
    val surahId: String,
    val rotationSchemeId: String,
    val partId: String?,
) {
    val uri: Uri
        get() =
            Uri.Builder()
                .scheme("murajaah-widget")
                .authority("recitation")
                .appendQueryParameter("schema", ACTION_SCHEMA_VERSION.toString())
                .appendQueryParameter("token", actionToken)
                .appendQueryParameter("surah", surahId)
                .appendQueryParameter("scheme", rotationSchemeId)
                .apply { partId?.let { appendQueryParameter("part", it) } }
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
    private const val PREVIOUS_SCHEMA_VERSION = 2
    private const val SCHEMA_VERSION = 3
    private const val MAX_ROTATION_ITEMS = 64
    private const val MAX_TEXT_LINES = 3
    // Mirrors Dart's domain-level maxRecommendationCount.
    private const val MAX_RECOMMENDATION_COUNT = 8

    fun parse(raw: String?): NativeWidgetSnapshot? {
        if (raw.isNullOrEmpty() || raw.length > 2_000_000) return null
        return runCatching {
            val root = JSONObject(raw)
            val schemaVersion = root.getInt("schemaVersion")
            require(schemaVersion == PREVIOUS_SCHEMA_VERSION || schemaVersion == SCHEMA_VERSION)
            requireText(root.getString("generatedAtUtc"), 128)
            requireText(root.getString("locale"), 32)
            NativeWidgetSnapshot(
                rotation = parseRotation(root.getJSONObject("rotation"), schemaVersion),
                learning = parseLearning(root.getJSONObject("learning"), schemaVersion),
            )
        }.getOrNull()
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
            require(remaining > 0)
            val debtLabel = item.getString("debtLabel")
            require(debtLabel.length <= 32)
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
                if (schemaVersion >= SCHEMA_VERSION && item.has("action")) {
                    require(!item.isNull("action"))
                    parseAction(item.getJSONObject("action"), surahId, partId).also {
                        require(actionTokens.add(it.actionToken))
                    }
                } else {
                    null
                }
            items +=
                NativeRotationItem(
                    id = id,
                    title = requireText(item.getString("title"), 512),
                    subtitle = item.optionalString("subtitle")?.let { requireText(it, 512) },
                    debtLabel = debtLabel,
                    recommendationRank = recommendationRank,
                    deepLink = deepLink,
                    action = action,
                )
        }
        return NativeRotationProjection(
            items = items,
            omittedCount = omittedCount,
            contextLabel =
                if (schemaVersion >= SCHEMA_VERSION) {
                    requireText(json.getString("contextLabel"), 256)
                } else {
                    null
                },
            statusMessage =
                if (schemaVersion >= SCHEMA_VERSION) {
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
        requireOnlyKeys(
            json,
            setOf("schemaVersion", "actionToken", "surahId", "rotationSchemeId", "partId"),
        )
        require(json.getInt("schemaVersion") == ACTION_SCHEMA_VERSION)
        val actionToken = requireText(json.getString("actionToken"), 36)
        require(UUID_V4.matches(actionToken))
        val surahId = requireSafeId(json.getString("surahId"))
        val schemeId = requireSafeId(json.getString("rotationSchemeId"))
        val partId = json.optionalString("partId")?.let(::requireSafeId)
        require(surahId == expectedSurahId && partId == expectedPartId)
        return NativeRotationAction(
            actionToken = actionToken.lowercase(),
            surahId = surahId,
            rotationSchemeId = schemeId,
            partId = partId,
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
        if (schemaVersion == PREVIOUS_SCHEMA_VERSION) {
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

internal const val ACTION_SCHEMA_VERSION = 1

internal fun stableWidgetItemId(value: String): Long {
    var hash = 1_125_899_906_842_597L
    for (character in value) hash = 31L * hash + character.code
    // Glance reserves the lowest quarter of Long values for generated lazy-list
    // IDs. Keep application-owned IDs non-negative so overflow can never enter
    // that reserved range.
    return hash and Long.MAX_VALUE
}
