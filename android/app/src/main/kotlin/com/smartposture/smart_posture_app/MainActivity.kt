package com.smartposture.smart_posture_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationChannelName = "smart_posture_app/local_notifications"
    private val postureAlertChannelId = "posture_alerts"
    private val notificationPermissionRequestCode = 5317
    private var pendingNotification: LocalNotification? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createPostureAlertChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: System.currentTimeMillis().toInt()
                    val title = call.argument<String>("title") ?: "Posture Alert"
                    val message = call.argument<String>("message") ?: ""

                    showLocalNotification(id, title, message)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createPostureAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            postureAlertChannelId,
            "Posture Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Posture correction and movement break reminders"
            enableVibration(true)
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun showLocalNotification(id: Int, title: String, message: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) {
                pendingNotification = LocalNotification(id, title, message)
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    notificationPermissionRequestCode
                )
                return
            }
        }

        postLocalNotification(id, title, message)
    }

    private fun postLocalNotification(id: Int, title: String, message: String) {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, postureAlertChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setPriority(Notification.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, notification)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != notificationPermissionRequestCode) return
        val notification = pendingNotification
        pendingNotification = null

        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED &&
            notification != null
        ) {
            postLocalNotification(notification.id, notification.title, notification.message)
        }
    }

    private data class LocalNotification(
        val id: Int,
        val title: String,
        val message: String
    )
}
