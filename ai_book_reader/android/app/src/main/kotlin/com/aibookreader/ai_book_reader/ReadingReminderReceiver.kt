package com.aibookreader.ai_book_reader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ReadingReminderReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_HOURLY_TICK = "com.aibookreader.ai_book_reader.ACTION_HOURLY_TICK"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("ReadingReminder", "ReadingReminderReceiver.onReceive: action=$action")

        if (action == ACTION_HOURLY_TICK || action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences(ReadingReminderManager.PREFS_NAME, Context.MODE_PRIVATE)

            val isEnabled = ReadingReminderManager.getStoredIsEnabled(prefs)
            val todayStr = ReadingReminderManager.getTodayDateString()
            val statDate = ReadingReminderManager.getStoredStatDate(prefs)
            val isGoalMet = ReadingReminderManager.getStoredIsGoalMet(prefs, todayStr)
            val currentMinutes = ReadingReminderManager.getStoredCurrentMinutes(prefs, todayStr)
            val goalMinutes = ReadingReminderManager.getStoredGoalMinutes(prefs)

            Log.d(
                "ReadingReminder",
                "Receiver evaluated: isEnabled=$isEnabled, isGoalMet=$isGoalMet, currentMinutes=$currentMinutes, goalMinutes=$goalMinutes, statDate=$statDate, todayStr=$todayStr"
            )

            if (!isEnabled) {
                Log.d("ReadingReminder", "Reminders disabled, exiting.")
                return
            }

            // Only fire reminder if today's goal is NOT yet met
            if (!isGoalMet && currentMinutes < goalMinutes) {
                Log.d("ReadingReminder", "Posting reminder: $currentMinutes / $goalMinutes mins")
                ReadingReminderManager.showReminderNotification(context, currentMinutes, goalMinutes)
                // Reschedule for next hour
                ReadingReminderManager.scheduleHourlyReminder(context)
            } else {
                Log.d("ReadingReminder", "Goal already met or exceeded ($currentMinutes >= $goalMinutes), suppressing reminder.")
            }
        }
    }
}
