import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/local/ai_settings_service.dart';
import '../../../data/local/reading_stats_repository.dart';

final readingReminderServiceProvider = Provider<ReadingReminderService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ReadingReminderService(prefs);
});

class ReadingReminderService {
  final SharedPreferences? _prefs;
  static const MethodChannel _channel =
      MethodChannel('com.aibookreader.ai_book_reader/reading_reminder');

  static const String keyReminderEnabled = 'reading_hourly_reminder_enabled';
  static const String keyStartHour = 'reading_reminder_start_hour';
  static const String keyEndHour = 'reading_reminder_end_hour';

  // Flutter-native sync keys used by background Android receiver
  static const String keyNativeGoalMet = 'reading_goal_met_today';
  static const String keyNativeMinutesRead = 'reading_minutes_today';
  static const String keyNativeGoalMinutes = 'reading_goal_minutes';
  static const String keyNativeStatDate = 'reading_stat_date';

  ReadingReminderService(this._prefs);

  Future<SharedPreferences> _getPrefs() async {
    final prefs = _prefs;
    if (prefs != null) return prefs;
    return await SharedPreferences.getInstance();
  }

  /// Whether hourly reminders are enabled (defaults to true)
  Future<bool> isEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(keyReminderEnabled) ?? true;
  }

  /// Toggle or update hourly reminders
  Future<void> setEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyReminderEnabled, enabled);

    if (enabled) {
      final isGoalMet = prefs.getBool(keyNativeGoalMet) ?? false;
      final minutesRead = prefs.getInt(keyNativeMinutesRead) ?? 0;
      final goalMinutes = prefs.getInt(keyNativeGoalMinutes) ?? 30;

      await _invokeNative('scheduleHourlyReminder', {
        'isGoalMet': isGoalMet,
        'currentMinutes': minutesRead,
        'goalMinutes': goalMinutes,
      });
    } else {
      await _invokeNative('cancelHourlyReminder', {});
    }
  }

  /// Sync today's reading status with persistent prefs and native Android AlarmManager
  Future<void> syncGoalStatus({
    required bool isGoalMet,
    required int activeSeconds,
    required int goalMinutes,
  }) async {
    final prefs = await _getPrefs();
    final todayStr = IsarReadingStatsRepository.formatDate(DateTime.now());
    final currentMinutes = activeSeconds ~/ 60;

    await prefs.setBool(keyNativeGoalMet, isGoalMet);
    await prefs.setInt(keyNativeMinutesRead, currentMinutes);
    await prefs.setInt(keyNativeGoalMinutes, goalMinutes);
    await prefs.setString(keyNativeStatDate, todayStr);

    final enabled = prefs.getBool(keyReminderEnabled) ?? true;

    await _invokeNative('updateGoalStatus', {
      'isGoalMet': isGoalMet,
      'currentMinutes': currentMinutes,
      'goalMinutes': goalMinutes,
      'date': todayStr,
      'enabled': enabled,
    });
  }

  /// Trigger an instant test notification for verification
  Future<bool> sendTestReminder() async {
    final res = await _invokeNative('showTestNotification', {});
    return res == true;
  }

  /// Check whether the Android app has POST_NOTIFICATIONS permission
  Future<bool> hasNotificationPermission() async {
    final res = await _invokeNative('checkNotificationPermission', {});
    return res == true;
  }

  /// Prompt user for notification permission if needed (Android 13+)
  Future<bool> requestNotificationPermission() async {
    final res = await _invokeNative('requestNotificationPermission', {});
    return res == true;
  }

  Future<dynamic> _invokeNative(String method, Map<String, dynamic> arguments) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _channel.invokeMethod(method, arguments);
      }
    } catch (e) {
      debugPrint('ReadingReminderService native call error ($method): $e');
    }
    return null;
  }
}
