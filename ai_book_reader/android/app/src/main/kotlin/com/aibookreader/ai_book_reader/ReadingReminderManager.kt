package com.aibookreader.ai_book_reader

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object ReadingReminderManager {
    const val CHANNEL_ID = "reading_reminders_channel"
    const val NOTIFICATION_ID = 2001
    const val ALARM_REQUEST_CODE = 3001
    const val PREFS_NAME = "FlutterSharedPreferences"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Reading Goals & Reminders"
            val descriptionText = "Hourly reminders and notifications to help you reach your daily reading goal"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun scheduleHourlyReminder(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ReadingReminderReceiver::class.java).apply {
            action = ReadingReminderReceiver.ACTION_HOURLY_TICK
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            flags
        )

        // Schedule next alarm for 1 hour from now
        val calendar = Calendar.getInstance().apply {
            add(Calendar.HOUR_OF_DAY, 1)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        } catch (e: Exception) {
            Log.w("ReadingReminder", "Fallback scheduling alarm", e)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } catch (e2: Exception) {
                Log.e("ReadingReminder", "Failed to schedule alarm", e2)
            }
        }
    }

    fun cancelHourlyReminder(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ReadingReminderReceiver::class.java).apply {
            action = ReadingReminderReceiver.ACTION_HOURLY_TICK
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            flags
        )
        alarmManager.cancel(pendingIntent)
    }

    fun showReminderNotification(
        context: Context,
        currentMinutes: Int,
        goalMinutes: Int
    ) {
        createNotificationChannel(context)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            flags
        )

        val remainingMinutes = (goalMinutes - currentMinutes).coerceAtLeast(1)
        val title = "Time to Read! 📖"
        val message = if (currentMinutes <= 0) {
            "You haven't read yet today. Take a quick reading break to start your $goalMinutes min goal!"
        } else {
            "You've read $currentMinutes mins today. Only $remainingMinutes mins left to hit your $goalMinutes min goal! 🔥"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_reading_reminder)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            Log.d("ReadingReminder", "Posting reminder notification ID $NOTIFICATION_ID...")
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        } catch (e: Exception) {
            Log.e("ReadingReminder", "Failed to post reminder notification", e)
        }
    }

    fun showGoalMetNotification(context: Context, goalMinutes: Int) {
        createNotificationChannel(context)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, flags)

        val title = "🎉 Daily Reading Goal Achieved!"
        val message = "Great job! You reached your $goalMinutes minute reading goal today. Your reading streak is safe! 🔥"

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_reading_reminder)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            Log.d("ReadingReminder", "Posting goal met notification...")
            notificationManager.notify(NOTIFICATION_ID + 1, builder.build())
        } catch (e: Exception) {
            Log.e("ReadingReminder", "Failed to post goal met notification", e)
        }
    }

    fun showTestNotification(context: Context) {
        createNotificationChannel(context)

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val goalMinutes = getStoredGoalMinutes(prefs)
        val todayStr = getTodayDateString()
        val currentMinutes = getStoredCurrentMinutes(prefs, todayStr)
        val remaining = (goalMinutes - currentMinutes).coerceAtLeast(1)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, flags)

        val title = "Reading Reminder Active 📖"
        val message = if (currentMinutes > 0) {
            "Hourly reminders are active! You've read $currentMinutes mins of your $goalMinutes min goal ($remaining mins left)."
        } else {
            "Hourly reminders are active! We'll nudge you every hour until your $goalMinutes min goal is met."
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_reading_reminder)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            Log.d("ReadingReminder", "Posting test notification ID ${NOTIFICATION_ID + 2}...")
            notificationManager.notify(NOTIFICATION_ID + 2, builder.build())
        } catch (e: Exception) {
            Log.e("ReadingReminder", "Failed to post test notification", e)
        }
    }

    fun getTodayDateString(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        return sdf.format(Date())
    }

    fun getPrefInt(prefs: android.content.SharedPreferences, key: String, defValue: Int): Int {
        return try {
            if (prefs.contains(key)) {
                try {
                    prefs.getInt(key, defValue)
                } catch (e: ClassCastException) {
                    prefs.getLong(key, defValue.toLong()).toInt()
                }
            } else {
                defValue
            }
        } catch (e: Exception) {
            defValue
        }
    }

    fun getPrefBoolean(prefs: android.content.SharedPreferences, key: String, defValue: Boolean): Boolean {
        return try {
            prefs.getBoolean(key, defValue)
        } catch (e: Exception) {
            defValue
        }
    }

    fun getPrefString(prefs: android.content.SharedPreferences, key: String, defValue: String): String {
        return try {
            prefs.getString(key, defValue) ?: defValue
        } catch (e: Exception) {
            defValue
        }
    }

    fun getStoredGoalMinutes(prefs: android.content.SharedPreferences): Int {
        val keys = listOf(
            "reading_goal_minutes",
            "flutter.reading_goal_minutes",
            "reading_daily_goal_minutes",
            "flutter.reading_daily_goal_minutes",
            "flutter.flutter.reading_goal_minutes"
        )
        for (k in keys) {
            if (prefs.contains(k)) {
                val v = getPrefInt(prefs, k, -1)
                if (v > 0) return v
            }
        }
        return 30
    }

    fun getStoredStatDate(prefs: android.content.SharedPreferences): String {
        val keys = listOf(
            "reading_stat_date",
            "flutter.reading_stat_date",
            "flutter.flutter.reading_stat_date"
        )
        for (k in keys) {
            if (prefs.contains(k)) {
                val str = getPrefString(prefs, k, "")
                if (str.isNotEmpty()) return str
            }
        }
        return ""
    }

    fun getStoredCurrentMinutes(prefs: android.content.SharedPreferences, todayStr: String): Int {
        val statDate = getStoredStatDate(prefs)
        if (statDate != todayStr) return 0
        val keys = listOf(
            "reading_minutes_today",
            "flutter.reading_minutes_today",
            "flutter.flutter.reading_minutes_today"
        )
        for (k in keys) {
            if (prefs.contains(k)) {
                return getPrefInt(prefs, k, 0)
            }
        }
        return 0
    }

    fun getStoredIsGoalMet(prefs: android.content.SharedPreferences, todayStr: String): Boolean {
        val statDate = getStoredStatDate(prefs)
        if (statDate != todayStr) return false
        val keys = listOf(
            "reading_goal_met_today",
            "flutter.reading_goal_met_today",
            "flutter.flutter.reading_goal_met_today"
        )
        for (k in keys) {
            if (prefs.contains(k)) {
                return getPrefBoolean(prefs, k, false)
            }
        }
        return false
    }

    fun getStoredIsEnabled(prefs: android.content.SharedPreferences): Boolean {
        val keys = listOf(
            "reading_hourly_reminder_enabled",
            "flutter.reading_hourly_reminder_enabled"
        )
        for (k in keys) {
            if (prefs.contains(k)) {
                return getPrefBoolean(prefs, k, true)
            }
        }
        return true
    }

    fun saveGoalStatus(
        context: Context,
        isGoalMet: Boolean,
        currentMinutes: Int,
        goalMinutes: Int,
        statDate: String,
        isEnabled: Boolean
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("flutter.reading_goal_met_today", isGoalMet)
            putBoolean("reading_goal_met_today", isGoalMet)
            putInt("flutter.reading_minutes_today", currentMinutes)
            putInt("reading_minutes_today", currentMinutes)
            putLong("flutter.reading_minutes_today", currentMinutes.toLong())
            putInt("flutter.reading_goal_minutes", goalMinutes)
            putInt("reading_goal_minutes", goalMinutes)
            putLong("flutter.reading_goal_minutes", goalMinutes.toLong())
            putString("flutter.reading_stat_date", statDate)
            putString("reading_stat_date", statDate)
            putBoolean("flutter.reading_hourly_reminder_enabled", isEnabled)
            putBoolean("reading_hourly_reminder_enabled", isEnabled)
            apply()
        }
    }
}
