package com.aibookreader.ai_book_reader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ReadingReminderReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_HOURLY_TICK = "com.aibookreader.ai_book_reader.ACTION_HOURLY_TICK"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == ACTION_HOURLY_TICK || action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences(ReadingReminderManager.PREFS_NAME, Context.MODE_PRIVATE)

            val isEnabled = prefs.getBoolean("flutter.reading_hourly_reminder_enabled", true)
            if (!isEnabled) {
                return
            }

            val todayStr = ReadingReminderManager.getTodayDateString()
            val statDate = prefs.getString("flutter.reading_stat_date", "")

            var isGoalMet = false
            var currentMinutes = 0
            val goalMinutes = prefs.getInt("flutter.reading_goal_minutes", 30)

            if (statDate == todayStr) {
                isGoalMet = prefs.getBoolean("flutter.reading_goal_met_today", false)
                currentMinutes = prefs.getInt("flutter.reading_minutes_today", 0)
            }

            // Only fire reminder if today's goal is NOT yet met
            if (!isGoalMet && currentMinutes < goalMinutes) {
                ReadingReminderManager.showReminderNotification(context, currentMinutes, goalMinutes)
                // Reschedule for next hour
                ReadingReminderManager.scheduleHourlyReminder(context)
            } else {
                // Goal was met or already exceeded today, no hourly reminder needed today
            }
        }
    }
}
