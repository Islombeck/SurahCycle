package dev.murajaah.murajaah.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import dev.murajaah.murajaah.MainActivity
import dev.murajaah.murajaah.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent

private const val WIDGET_LOG_TAG = "MurajaahWidget"

internal fun logWidgetCompositionError(
    context: Context,
    widgetType: String,
    appWidgetId: Int,
    throwable: Throwable,
) {
    if (!context.isDebuggable()) return
    Log.e(
        WIDGET_LOG_TAG,
        "widget=$widgetType " +
            "appWidgetId=$appWidgetId " +
            "throwable=${throwable.javaClass.name} " +
            "message=${throwable.message ?: "<no message>"}",
        throwable,
    )
}

/** Adds the home deep link after Glance has installed the static error layout. */
internal fun installWidgetErrorClick(context: Context, appWidgetId: Int, deepLink: Uri) {
    try {
        val views = RemoteViews(context.packageName, R.layout.widget_error)
        views.setOnClickPendingIntent(
            R.id.widget_error_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                deepLink,
            ),
        )
        AppWidgetManager.getInstance(context).updateAppWidget(appWidgetId, views)
    } catch (fallbackError: Exception) {
        // The non-clickable error layout installed by super.onCompositionError
        // remains visible even if adding the PendingIntent fails.
        Log.e(
            WIDGET_LOG_TAG,
            "Failed to attach widget error fallback click for appWidgetId=$appWidgetId",
            fallbackError,
        )
    }
}

internal fun logWidgetActionDispatch(context: Context, appWidgetId: Int, actionUri: String) {
    if (!context.isDebuggable()) return
    val uri = Uri.parse(actionUri)
    Log.d(
        WIDGET_LOG_TAG,
        "event=action_dispatch widget=RotationWidget appWidgetId=$appWidgetId " +
            "actionToken=${uri.getQueryParameter("token") ?: "<missing>"} " +
            "surah=${uri.getQueryParameter("surah") ?: "<missing>"} " +
            "part=${uri.getQueryParameter("part") ?: "<whole>"}",
    )
}

private fun Context.isDebuggable(): Boolean =
    applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
