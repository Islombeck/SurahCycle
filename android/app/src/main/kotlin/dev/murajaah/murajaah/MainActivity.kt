package dev.murajaah.murajaah

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import dev.murajaah.murajaah.widget.LearningNotificationManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.murajaah.murajaah/media_permissions",
        ).setMethodCallHandler { call, result ->
            if (call.method != "requestMediaNotifications") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            requestNotificationPermission(result) { granted, res -> res.success(granted) }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.murajaah.murajaah/learning_notifications",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" ->
                    requestNotificationPermission(result) { granted, res ->
                        res.success(granted)
                    }
                "show" -> {
                    val title = call.argument<String>("title")
                    val text = call.argument<String>("text")
                    if (title.isNullOrEmpty() || text.isNullOrEmpty()) {
                        result.error("invalid_argument", "title/text required", null)
                        return@setMethodCallHandler
                    }
                    LearningNotificationManager.show(applicationContext, title, text)
                    result.success(null)
                }
                "cancel" -> {
                    LearningNotificationManager.cancel(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Shared POST_NOTIFICATIONS flow: on API < 33 or already-granted, resolves
     * immediately. Otherwise prompts once; a second call while one prompt is
     * pending resolves `false` rather than queuing a duplicate prompt.
     */
    private fun requestNotificationPermission(
        result: MethodChannel.Result,
        onResolved: (Boolean, MethodChannel.Result) -> Unit,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            onResolved(true, result)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            onResolved(false, result)
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingNotificationPermissionResult?.success(granted)
        pendingNotificationPermissionResult = null
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4301
    }
}
