import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_book_reader/data/local/reading_stats_repository.dart';
import 'package:ai_book_reader/data/models/daily_reading_stat.dart';
import 'package:ai_book_reader/features/stats/presentation/screens/reading_stats_screen.dart';
import 'package:ai_book_reader/features/stats/services/reading_reminder_service.dart';

class MockReadingStatsRepository extends Fake implements ReadingStatsRepository {
  int goal = 30;
  int seconds = 1200; // 20m
  int pages = 18;

  @override
  Future<ReadingStreakSummary> getStreakSummary() async {
    return ReadingStreakSummary(
      currentStreak: 3,
      longestStreak: 7,
      totalDaysRead: 14,
      totalReadingSeconds: 7200,
      totalPagesRead: 145,
      todaySeconds: seconds,
      todayPages: pages,
      todayGoalMinutes: goal,
      isTodayGoalMet: seconds >= goal * 60,
    );
  }

  @override
  Future<List<DailyReadingStat>> getRecentStats({int days = 7}) async {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final d = now.subtract(Duration(days: days - 1 - i));
      return DailyReadingStat()
        ..date = IsarReadingStatsRepository.formatDate(d)
        ..goalMinutes = goal
        ..activeSeconds = i == days - 1 ? seconds : 1800
        ..pagesRead = 15
        ..isGoalMet = i % 2 == 0;
    });
  }

  @override
  Future<int> getDailyGoal() async => goal;

  @override
  Future<void> setDailyGoal(int minutes) async {
    goal = minutes;
  }

  @override
  void notifyStatsChanged() {}

  @override
  Stream<ReadingStreakSummary> watchStreakSummary() => Stream.fromFuture(getStreakSummary());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aibookreader.ai_book_reader/reading_reminder'),
      (MethodCall call) async {
        return true;
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

  testWidgets('ReadingStatsScreen renders streak hero, today goal, reminders, and activity cards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      ReadingReminderService.keyReminderEnabled: true,
    });
    final prefs = await SharedPreferences.getInstance();

    final mockRepo = MockReadingStatsRepository();
    final reminderService = ReadingReminderService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingStatsRepositoryProvider.overrideWithValue(mockRepo),
          readingReminderServiceProvider.overrideWithValue(reminderService),
        ],
        child: const MaterialApp(
          home: ReadingStatsScreen(),
        ),
      ),
    );

    // Pump past initial frame and load future
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify AppBar
    expect(find.text('Reading Goals & Stats'), findsOneWidget);

    // 2. Verify Streak Hero Card
    expect(find.text('3 Day Reading Streak!'), findsOneWidget);
    expect(find.text('7 days'), findsWidgets); // Best streak
    expect(find.text('14 days'), findsWidgets); // Total days (in hero card and milestones)

    // 3. Verify Today's Goal Card
    expect(find.text("Today's Reading Goal"), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // todayMinutes
    expect(find.text(' / 30 mins'), findsOneWidget);
    expect(find.text('18 pages read today'), findsOneWidget);

    // 4. Verify Hourly Reminder Card
    expect(find.text('Hourly Reminder'), findsOneWidget);
    expect(find.text('Remind every hour until goal is met'), findsOneWidget);
    expect(find.text('Morning Start Time'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Send Test Reminder'), findsOneWidget);

    // 5. Verify Past 7 Days Activity
    expect(find.text('Past 7 Days Activity'), findsOneWidget);

    // 6. Verify All-Time Milestones Card
    expect(find.text('All-Time Reading Milestones'), findsOneWidget);
    expect(find.text('Total Read Time'), findsOneWidget);
    expect(find.text('Total Pages Read'), findsOneWidget);
  });
}
