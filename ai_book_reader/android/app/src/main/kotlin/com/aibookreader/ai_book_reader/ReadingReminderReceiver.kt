package com.aibookreader.ai_book_reader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

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
            if (!isEnabled) {
                Log.d("ReadingReminder", "Reminders disabled, exiting.")
                return
            }

            val todayStr = ReadingReminderManager.getTodayDateString()
            val statDate = ReadingReminderManager.getStoredStatDate(prefs)
            val isGoalMet = ReadingReminderManager.getStoredIsGoalMet(prefs, todayStr)
            val currentMinutes = ReadingReminderManager.getStoredCurrentMinutes(prefs, todayStr)
            val goalMinutes = ReadingReminderManager.getStoredGoalMinutes(prefs)

            val startHour = ReadingReminderManager.getStoredStartHour(prefs)
            val startMinute = ReadingReminderManager.getStoredStartMinute(prefs)
            var endHour = ReadingReminderManager.getStoredEndHour(prefs)
            if (endHour <= startHour) {
                endHour = 22
            }

            val now = Calendar.getInstance()
            val todayStart = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, startHour)
                set(Calendar.MINUTE, startMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val todayEnd = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, endHour)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            Log.d(
                "ReadingReminder",
                "Receiver evaluated: action=$action, isEnabled=$isEnabled, isGoalMet=$isGoalMet, currentMinutes=$currentMinutes, goalMinutes=$goalMinutes, statDate=$statDate, todayStr=$todayStr, start=${startHour}:${startMinute}, end=$endHour"
            )

            // Active reminder window check: between (start - 1min) and (end + 1min)
            val isWithinActiveHours = now.timeInMillis >= (todayStart.timeInMillis - 60_000L) &&
                    now.timeInMillis <= (todayEnd.timeInMillis + 60_000L)

            // Only fire notification on tick during active hours if goal is NOT yet met
            if (action == ACTION_HOURLY_TICK && isWithinActiveHours && !isGoalMet && currentMinutes < goalMinutes) {
                Log.d("ReadingReminder", "Posting reminder: $currentMinutes / $goalMinutes mins")
                ReadingReminderManager.showReminderNotification(context, currentMinutes, goalMinutes)
            } else {
                Log.d("ReadingReminder", "Suppressed notification: action=$action, withinActive=$isWithinActiveHours, goalMet=$isGoalMet, mins=$currentMinutes/$goalMinutes")
            }

            // Always reschedule the next alarm (next hour or tomorrow morning at start time)
            ReadingReminderManager.scheduleNextReminder(context)
        }
    }
}
