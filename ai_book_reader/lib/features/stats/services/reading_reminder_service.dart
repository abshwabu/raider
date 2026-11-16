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
  static const String keyStartMinute = 'reading_reminder_start_minute';
  static const String keyEndHour = 'reading_reminder_end_hour';

  static const int defaultStartHour = 8;
  static const int defaultStartMinute = 0;
  static const int defaultEndHour = 21;

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

  /// Morning start hour for reminders (0-23, defaults to 8)
  Future<int> getStartHour() async {
    final prefs = await _getPrefs();
    return prefs.getInt(keyStartHour) ?? defaultStartHour;
  }

  /// Morning start minute for reminders (0-59, defaults to 0)
  Future<int> getStartMinute() async {
    final prefs = await _getPrefs();
    return prefs.getInt(keyStartMinute) ?? defaultStartMinute;
  }

  /// Evening end hour for reminders (defaults to 21 / 9 PM)
  Future<int> getEndHour() async {
    final prefs = await _getPrefs();
    return prefs.getInt(keyEndHour) ?? defaultEndHour;
  }

  /// Configure morning start time for reminders (e.g. 8:00 AM)
  Future<void> setStartTime({required int hour, required int minute}) async {
    final prefs = await _getPrefs();
    await prefs.setInt(keyStartHour, hour);
    await prefs.setInt(keyStartMinute, minute);

    final enabled = prefs.getBool(keyReminderEnabled) ?? true;
    final endHour = prefs.getInt(keyEndHour) ?? defaultEndHour;
    final isGoalMet = prefs.getBool(keyNativeGoalMet) ?? false;
    final currentMinutes = prefs.getInt(keyNativeMinutesRead) ?? 0;
    final goalMinutes = prefs.getInt(keyNativeGoalMinutes) ?? 30;

    await _invokeNative('updateReminderSettings', {
      'enabled': enabled,
      'startHour': hour,
      'startMinute': minute,
      'endHour': endHour,
      'isGoalMet': isGoalMet,
      'currentMinutes': currentMinutes,
      'goalMinutes': goalMinutes,
    });
  }

  /// Toggle or update hourly reminders
  Future<void> setEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyReminderEnabled, enabled);

    final startHour = prefs.getInt(keyStartHour) ?? defaultStartHour;
    final startMinute = prefs.getInt(keyStartMinute) ?? defaultStartMinute;
    final endHour = prefs.getInt(keyEndHour) ?? defaultEndHour;

    if (enabled) {
      final isGoalMet = prefs.getBool(keyNativeGoalMet) ?? false;
      final minutesRead = prefs.getInt(keyNativeMinutesRead) ?? 0;
      final goalMinutes = prefs.getInt(keyNativeGoalMinutes) ?? 30;

      await _invokeNative('scheduleHourlyReminder', {
        'isGoalMet': isGoalMet,
        'currentMinutes': minutesRead,
        'goalMinutes': goalMinutes,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
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
    final startHour = prefs.getInt(keyStartHour) ?? defaultStartHour;
    final startMinute = prefs.getInt(keyStartMinute) ?? defaultStartMinute;
    final endHour = prefs.getInt(keyEndHour) ?? defaultEndHour;

    await _invokeNative('updateGoalStatus', {
      'isGoalMet': isGoalMet,
      'currentMinutes': currentMinutes,
      'goalMinutes': goalMinutes,
      'date': todayStr,
      'enabled': enabled,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
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
