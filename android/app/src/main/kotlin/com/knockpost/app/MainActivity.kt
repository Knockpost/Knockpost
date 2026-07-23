package com.knockpost.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // MUST be called before super.onCreate for true edge-to-edge
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val highChannel = NotificationChannel(
            "knockpost_high",
            "KnockPost Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Knocks, messages, replies, and mentions."
            enableVibration(true)
            setShowBadge(true)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }

        val mediumChannel = NotificationChannel(
            "knockpost_medium",
            "KnockPost Activity",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Reactions and friend activity."
            enableVibration(false)
            setShowBadge(true)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }

        val lowChannel = NotificationChannel(
            "knockpost_low",
            "KnockPost Catch-ups",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Gentle reminders when there is something new to see."
            enableVibration(false)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannels(listOf(highChannel, mediumChannel, lowChannel))
    }
}
