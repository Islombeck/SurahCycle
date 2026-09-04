package dev.murajaah.murajaah.widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import dev.murajaah.murajaah.MainActivity
import dev.murajaah.murajaah.R

/**
 * The optional, silent "what's next in Learning" notification.
 *
 * This is strictly opt-in: [show] is only ever called by Dart after the user
 * has explicitly enabled the feature in Settings, and only after
 * `POST_NOTIFICATIONS` was granted through that same explicit action. The
 * channel is [NotificationManager.IMPORTANCE_LOW] — no sound, no vibration,
 * no heads-up — matching "quiet" in the product spec. Tapping it opens the
 * app to Learning; it never bypasses the lock screen or uses a full-screen
 * intent.
 */
internal object LearningNotificationManager {
    private const val CHANNEL_ID = "learning_quiet"
    private const val NOTIFICATION_ID = 7001

    fun show(context: Context, title: String, text: String) {
        ensureChannel(context)
        val contentIntent =
            PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("murajaah://app/learning")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val notification =
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_widget_mark)
                .setContentTitle(title)
                .setContentText(text)
                .setContentIntent(contentIntent)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(false)
                .build()
        runCatching {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        }
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.learning_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.getString(R.string.learning_notification_channel_description)
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
        manager.createNotificationChannel(channel)
    }
}
