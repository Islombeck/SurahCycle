package dev.murajaah.murajaah.widget

import android.net.Uri
import org.json.JSONObject

internal const val WIDGET_SNAPSHOT_KEY = "murajaah_widget_snapshot"

internal data class NativeWidgetSnapshot(
    val rotation: NativeRotationProjection,
    val learning: NativeLearningProjection,
)

internal data class NativeRotationProjection(val items: List<NativeRotationItem>)

internal data class NativeRotationItem(
    val id: String,
    val title: String,
    val subtitle: String?,
    val debtLabel: String,
    val isRecommended: Boolean,
    val deepLink: Uri,
)

internal data class NativeLearningProjection(val item: NativeLearningItem?)

internal data class NativeLearningItem(
    val title: String,
    val stageLabel: String,
    val rangeLabel: String,
    val unavailableTextLabel: String,
    val verifiedTextLines: List<String>,
    val deepLink: Uri,
)

/**
 * Fail-closed decoder for the Dart-owned display projection.
 *
 * Any absent field, unknown schema version, unsafe link, duplicate identifier,
 * or unreasonable payload returns null. Widgets then render a localized safe
 * fallback instead of throwing from a launcher process.
 */
internal object NativeWidgetSnapshotParser {
    private const val SCHEMA_VERSION = 1
    private const val MAX_ROTATION_ITEMS = 512
    private const val MAX_TEXT_LINES = 286

    fun parse(raw: String?): NativeWidgetSnapshot? {
        if (raw.isNullOrEmpty() || raw.length > 2_000_000) return null
        return runCatching {
            val root = JSONObject(raw)
            require(root.getInt("schemaVersion") == SCHEMA_VERSION)
            requireText(root.getString("generatedAtUtc"), 128)
            requireText(root.getString("locale"), 32)
            NativeWidgetSnapshot(
                rotation = parseRotation(root.getJSONObject("rotation")),
                learning = parseLearning(root.getJSONObject("learning")),
            )
        }.getOrNull()
    }

    private fun parseRotation(json: JSONObject): NativeRotationProjection {
        val itemsJson = json.getJSONArray("items")
        require(itemsJson.length() <= MAX_ROTATION_ITEMS)
        val ids = HashSet<String>(itemsJson.length())
        val items = ArrayList<NativeRotationItem>(itemsJson.length())
        for (index in 0 until itemsJson.length()) {
            val item = itemsJson.getJSONObject(index)
            val id = requireText(item.getString("id"), 256)
            require(ids.add(id))
            val surahId = requireSafeId(item.getString("surahId"))
            val partId = item.optionalString("partId")?.let(::requireSafeId)
            val remaining = item.getInt("remaining")
            require(remaining > 0)
            val debtLabel = item.getString("debtLabel")
            require(debtLabel.length <= 32)
            val deepLink = Uri.parse(item.getString("deepLink"))
            require(isSafeRotationLink(deepLink, surahId, partId))
            items +=
                NativeRotationItem(
                    id = id,
                    title = requireText(item.getString("title"), 512),
                    subtitle = item.optionalString("subtitle")?.let { requireText(it, 512) },
                    debtLabel = debtLabel,
                    isRecommended = item.getBoolean("isRecommended"),
                    deepLink = deepLink,
                )
        }
        return NativeRotationProjection(items)
    }

    private fun parseLearning(json: JSONObject): NativeLearningProjection {
        if (!json.has("item") || json.isNull("item")) {
            return NativeLearningProjection(item = null)
        }
        val item = json.getJSONObject("item")
        val surahId = requireSafeId(item.getString("surahId"))
        val deepLink = Uri.parse(item.getString("deepLink"))
        require(isSafeLearningLink(deepLink, surahId))
        val linesJson = item.getJSONArray("verifiedTextLines")
        require(linesJson.length() <= MAX_TEXT_LINES)
        val lines = ArrayList<String>(linesJson.length())
        for (index in 0 until linesJson.length()) {
            // No trim/normalization: these are exact verified cache strings.
            lines += requireText(linesJson.getString(index), 8192)
        }
        return NativeLearningProjection(
            NativeLearningItem(
                title = requireText(item.getString("title"), 512),
                stageLabel = requireText(item.getString("stageLabel"), 256),
                rangeLabel = requireText(item.getString("rangeLabel"), 256),
                unavailableTextLabel =
                    requireText(item.getString("unavailableTextLabel"), 512),
                verifiedTextLines = lines,
                deepLink = deepLink,
            )
        )
    }

    private fun JSONObject.optionalString(key: String): String? =
        if (has(key) && !isNull(key)) getString(key) else null

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
}

internal fun stableWidgetItemId(value: String): Long {
    var hash = 1_125_899_906_842_597L
    for (character in value) hash = 31L * hash + character.code
    return hash
}
