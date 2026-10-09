package dev.murajaah.murajaah.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Wakes a prayer widget when the row it highlights stops being true.
 *
 * The snapshot carries the day as windows and the widget compares them with
 * its own clock, but a Glance widget only compares when something makes it
 * draw. `updatePeriodMillis` bounds that at thirty minutes; the strip's
 * countdown cannot live with thirty minutes, because a `Chronometer` counting
 * down does not stop at zero — it carries on into negative numbers until the
 * next redraw.
 *
 * So each update books one alarm at the end of the current window. It is
 * deliberately the cheap kind:
 *
 * - **inexact** (`setWindow`), so no `SCHEDULE_EXACT_ALARM` permission and no
 *   settings screen for him to visit. Android grants a window of at least
 *   [WINDOW_MS] to an app without that permission, so the redraw lands within
 *   ten minutes after the boundary, never before it;
 * - **plain `RTC`, never the waking kind**, so it never wakes a phone. A widget
 *   nobody is looking at has nothing to redraw for; the alarm is delivered
 *   when the screen next comes on.
 *
 * One alarm per receiver, replaced on every update and cancelled when the
 * last widget of that kind is removed. Nothing here decides anything about
 * prayer: the instant comes from [NativePrayerProjection.windowEndsAt].
 */
internal object PrayerWidgetRefresh {
    /** The shortest window Android grants an inexact alarm (API 31+). */
    internal const val WINDOW_MS = 10L * 60L * 1000L

    /**
     * When the drawing next changes, or null when nothing in the snapshot
     * will change it — no schedule, or a snapshot from another day.
     */
    fun nextRedrawAt(prayer: NativePrayerProjection?, nowUtcMs: Long): Long? =
        prayer
            ?.takeIf { it.isAvailable }
            ?.windowEndsAt(nowUtcMs)
            ?.takeIf { it > nowUtcMs }

    fun reschedule(context: Context, receiver: Class<*>) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val ids =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, receiver))
        val pending = pendingUpdate(context, receiver, ids)
        val at =
            if (ids.isEmpty()) {
                null
            } else {
                val snapshot =
                    NativeWidgetSnapshotParser.parse(
                        HomeWidgetPlugin.getData(context).getString(WIDGET_SNAPSHOT_KEY, null)
                    )
                nextRedrawAt(snapshot?.prayer, System.currentTimeMillis())
            }
        if (at == null) {
            alarms.cancel(pending)
            return
        }
        alarms.setWindow(AlarmManager.RTC, at, WINDOW_MS, pending)
    }

    fun cancel(context: Context, receiver: Class<*>) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        alarms.cancel(pendingUpdate(context, receiver, IntArray(0)))
    }

    // Extras are not part of PendingIntent identity, so the cancel above
    // matches whatever ids the scheduled one carried.
    private fun pendingUpdate(
        context: Context,
        receiver: Class<*>,
        ids: IntArray,
    ): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, receiver)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
