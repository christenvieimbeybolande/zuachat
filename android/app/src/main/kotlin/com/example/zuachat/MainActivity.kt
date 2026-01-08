package com.cimstudiodev.zuachat

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 🔔 ANDROID 8+ : CHANNEL OBLIGATOIRE POUR LE SON
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channelId = "zuachat_default"
            val channelName = "ZuaChat Notifications"
            val channelDescription = "Notifications de ZuaChat"

            val soundUri = RingtoneManager.getDefaultUri(
                RingtoneManager.TYPE_NOTIFICATION
            )

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = channelDescription
                enableVibration(true)
                setSound(soundUri, audioAttributes)
            }

            val notificationManager =
                getSystemService(NotificationManager::class.java)

            notificationManager.createNotificationChannel(channel)
        }
    }
}
