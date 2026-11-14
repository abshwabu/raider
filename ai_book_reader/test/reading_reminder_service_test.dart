import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_book_reader/features/stats/services/reading_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingReminderService Tests', () {
    late ReadingReminderService service;
    late List<MethodCall> channelCalls;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        ReadingReminderService.keyReminderEnabled: true,
      });
      final prefs = await SharedPreferences.getInstance();
      service = ReadingReminderService(prefs);
      channelCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.aibookreader.ai_book_reader/reading_reminder'),
        (MethodCall call) async {
          channelCalls.add(call);
          switch (call.method) {
            case 'scheduleHourlyReminder':
            case 'cancelHourlyReminder':
            case 'updateGoalStatus':
            case 'showTestNotification':
            case 'checkNotificationPermission':
            case 'requestNotificationPermission':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.aibookreader.ai_book_reader/reading_reminder'),
        null,
      );
    });

    test('isEnabled returns true by default and can be toggled', () async {
      expect(await service.isEnabled(), isTrue);

      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);
      expect(channelCalls.any((c) => c.method == 'cancelHourlyReminder'), isTrue);

      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
      expect(channelCalls.any((c) => c.method == 'scheduleHourlyReminder'), isTrue);
    });

    test('syncGoalStatus writes persistent keys and invokes native update', () async {
      await service.syncGoalStatus(
        isGoalMet: true,
        activeSeconds: 1800,
        goalMinutes: 30,
      );

      final call = channelCalls.firstWhere((c) => c.method == 'updateGoalStatus');
      expect(call.arguments['isGoalMet'], isTrue);
      expect(call.arguments['currentMinutes'], equals(30));
      expect(call.arguments['goalMinutes'], equals(30));
    });

    test('sendTestReminder invokes native showTestNotification', () async {
      final res = await service.sendTestReminder();
      expect(res, isTrue);
      expect(channelCalls.any((c) => c.method == 'showTestNotification'), isTrue);
    });
  });
}
