package dev.murajaah.murajaah.widget

import android.service.dreams.DreamService
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import dev.murajaah.murajaah.R
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/**
 * An entirely optional, system-controlled screensaver.
 *
 * Android only starts this when the user has explicitly picked it under
 * Settings > Display > Screen saver; nothing in this app enables, schedules,
 * or wakes the screen for it, and there is no in-app control that turns it
 * on. It is read-only content: `isInteractive = false` means any touch lets
 * the system dismiss the dream through its own normal handling, and it never
 * asks to appear above the keyguard, requests a full-screen intent, or draws
 * any overlay above the lock screen — this is a screensaver, not a
 * lock-screen surface.
 *
 * Content reuses the exact same Dart-built [WIDGET_SNAPSHOT_KEY] projection
 * the Learning widget already reads; there is no separate resolver here.
 */
class MurajaahDreamService : DreamService() {
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isInteractive = false
        isFullscreen = true
        setContentView(buildContentView())
    }

    private fun buildContentView(): LinearLayout {
        val item = readSnapshot()?.learning?.item
        val line = item?.ayahLines?.firstOrNull()
        val root =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(DREAM_BACKGROUND_COLOR)
                setPadding(
                    CONTENT_PADDING_PX,
                    CONTENT_PADDING_PX,
                    CONTENT_PADDING_PX,
                    CONTENT_PADDING_PX,
                )
            }
        root.addView(
            TextView(this).apply {
                text = line?.arabic ?: getString(R.string.dream_service_empty)
                setTextColor(DREAM_PRIMARY_TEXT_COLOR)
                textSize = if (line != null) 28f else 16f
                gravity = Gravity.CENTER
            }
        )
        if (item != null) {
            root.addView(
                TextView(this).apply {
                    text = item.title
                    setTextColor(DREAM_SECONDARY_TEXT_COLOR)
                    textSize = 14f
                    gravity = Gravity.CENTER
                    setPadding(0, SUBTITLE_TOP_PADDING_PX, 0, 0)
                }
            )
        }
        return root
    }

    /** Read-only: mirrors what the Learning widget already displays. */
    private fun readSnapshot(): NativeWidgetSnapshot? =
        try {
            val preferences = runBlocking {
                HomeWidgetGlanceStateDefinition()
                    .getDataStore(applicationContext, "")
                    .data
                    .first()
                    .preferences
            }
            NativeWidgetSnapshotParser.parse(
                preferences.getString(WIDGET_SNAPSHOT_KEY, null)
            )
        } catch (_: Exception) {
            null
        }

    private companion object {
        const val DREAM_BACKGROUND_COLOR = 0xFF10120E.toInt()
        const val DREAM_PRIMARY_TEXT_COLOR = 0xFFEDE7D8.toInt()
        const val DREAM_SECONDARY_TEXT_COLOR = 0xFFB8AD8F.toInt()
        const val CONTENT_PADDING_PX = 48
        const val SUBTITLE_TOP_PADDING_PX = 24
    }
}
