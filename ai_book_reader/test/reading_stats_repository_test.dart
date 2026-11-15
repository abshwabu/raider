import 'package:flutter_test/flutter_test.dart';
import 'package:ai_book_reader/data/local/reading_stats_repository.dart';
import 'package:ai_book_reader/data/models/daily_reading_stat.dart';

void main() {
  group('InMemoryReadingStatsRepository Tests', () {
    late InMemoryReadingStatsRepository repo;

    setUp(() {
      repo = InMemoryReadingStatsRepository();
    });

    test('getOrCreateTodayStat creates default stat with 30 min goal', () async {
      final stat = await repo.getOrCreateTodayStat();
      expect(stat.goalMinutes, equals(30));
      expect(stat.activeSeconds, equals(0));
      expect(stat.pagesRead, equals(0));
      expect(stat.isGoalMet, isFalse);
    });

    test('recordReadingTime accumulates seconds and detects goal completion', () async {
      // Record 10 minutes (600s) -> goal not met
      final met1 = await repo.recordReadingTime(seconds: 600, bookId: 1);
      expect(met1, isFalse);

      var stat = await repo.getOrCreateTodayStat();
      expect(stat.activeSeconds, equals(600));
      expect(stat.isGoalMet, isFalse);
      expect(stat.bookIds, contains(1));

      // Record another 20 minutes (1200s) -> total 1800s (30m) -> goal met!
      final met2 = await repo.recordReadingTime(seconds: 1200, bookId: 1);
      expect(met2, isTrue);

      stat = await repo.getOrCreateTodayStat();
      expect(stat.activeSeconds, equals(1800));
      expect(stat.isGoalMet, isTrue);
      expect(stat.goalMetAt, isNotNull);

      // Recording further seconds keeps goal met but returns false for justReached
      final met3 = await repo.recordReadingTime(seconds: 300, bookId: 2);
      expect(met3, isFalse);
      stat = await repo.getOrCreateTodayStat();
      expect(stat.activeSeconds, equals(2100));
      expect(stat.isGoalMet, isTrue);
      expect(stat.bookIds, containsAll([1, 2]));
    });

    test('recordPagesRead increments pages and logs book ID', () async {
      await repo.recordPagesRead(pages: 15, bookId: 42);
      final stat = await repo.getOrCreateTodayStat();
      expect(stat.pagesRead, equals(15));
      expect(stat.bookIds, contains(42));
    });

    test('setDailyGoal updates target and re-evaluates isGoalMet', () async {
      await repo.recordReadingTime(seconds: 900, bookId: 1); // 15 mins
      var stat = await repo.getOrCreateTodayStat();
      expect(stat.isGoalMet, isFalse);

      // Lower goal to 15 mins -> now met!
      await repo.setDailyGoal(15);
      expect(await repo.getDailyGoal(), equals(15));

      stat = await repo.getOrCreateTodayStat();
      expect(stat.goalMinutes, equals(15));
      expect(stat.isGoalMet, isTrue);

      // Raise goal to 45 mins -> no longer met
      await repo.setDailyGoal(45);
      stat = await repo.getOrCreateTodayStat();
      expect(stat.goalMinutes, equals(45));
      expect(stat.isGoalMet, isFalse);
    });

    test('getRecentStats returns 7-day chronological sequence', () async {
      final recent = await repo.getRecentStats(days: 7);
      expect(recent.length, equals(7));
      final todayStr = IsarReadingStatsRepository.formatDate(DateTime.now());
      expect(recent.last.date, equals(todayStr));
    });

    test('ReadingStreakSummary calculates progress fraction accurately', () {
      const summary1 = ReadingStreakSummary(
        currentStreak: 2,
        longestStreak: 5,
        totalDaysRead: 10,
        totalReadingSeconds: 900, // 15 mins
        totalPagesRead: 30,
        todaySeconds: 900,
        todayPages: 12,
        todayGoalMinutes: 30,
        isTodayGoalMet: false,
      );

      expect(summary1.todayMinutes, equals(15));
      expect(summary1.todayProgressFraction, closeTo(0.5, 0.001));

      const summary2 = ReadingStreakSummary(
        currentStreak: 3,
        longestStreak: 5,
        totalDaysRead: 11,
        totalReadingSeconds: 2400, // 40 mins
        totalPagesRead: 50,
        todaySeconds: 2400,
        todayPages: 25,
        todayGoalMinutes: 30,
        isTodayGoalMet: true,
      );

      expect(summary2.todayMinutes, equals(40));
      expect(summary2.todayProgressFraction, equals(1.0)); // Clamped to 1.0
    });

    test('calculateStreakSummary preserves yesterday streak on day 2 morning and increments after reading', () {
      final day1 = DateTime(2026, 11, 14);
      final day2 = DateTime(2026, 11, 15);

      final statDay1 = DailyReadingStat()
        ..date = '2026-11-14'
        ..goalMinutes = 30
        ..activeSeconds = 360 // 6 mins
        ..pagesRead = 10;

      // Day 2 morning: user hasn't read yet today, but goal was changed to 10 mins
      final statDay2Morning = DailyReadingStat()
        ..date = '2026-11-15'
        ..goalMinutes = 10
        ..activeSeconds = 0
        ..pagesRead = 0;

      final summaryDay2Morning = ReadingStatsRepository.calculateStreakSummary(
        allStats: [statDay1],
        today: statDay2Morning,
        now: day2,
      );

      // Streak from yesterday is maintained today!
      expect(summaryDay2Morning.currentStreak, equals(1));
      expect(summaryDay2Morning.todayMinutes, equals(0));
      expect(summaryDay2Morning.todayGoalMinutes, equals(10));
      expect(summaryDay2Morning.isTodayGoalMet, isFalse);

      // Day 2 afternoon: user reads 3 minutes (180s)
      final statDay2Afternoon = DailyReadingStat()
        ..date = '2026-11-15'
        ..goalMinutes = 10
        ..activeSeconds = 180 // 3 mins
        ..pagesRead = 5;

      final summaryDay2Afternoon = ReadingStatsRepository.calculateStreakSummary(
        allStats: [statDay1, statDay2Afternoon],
        today: statDay2Afternoon,
        now: day2,
      );

      // Streak becomes 2 days!
      expect(summaryDay2Afternoon.currentStreak, equals(2));
      expect(summaryDay2Afternoon.todayMinutes, equals(3));
      expect(summaryDay2Afternoon.todayGoalMinutes, equals(10));
      expect(summaryDay2Afternoon.todayProgressFraction, closeTo(0.3, 0.01));
    });

    test('watchStreakSummary stream emits updates upon setDailyGoal and recordReadingTime', () async {
      final emissions = <ReadingStreakSummary>[];
      final sub = repo.watchStreakSummary().listen(emissions.add);

      // Give event loop time to emit initial value
      await Future.delayed(const Duration(milliseconds: 20));
      expect(emissions.length, equals(1));
      expect(emissions.first.todayGoalMinutes, equals(30));

      // Change goal to 10 mins
      await repo.setDailyGoal(10);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.todayGoalMinutes, equals(10));

      // Record 3 minutes of reading
      await repo.recordReadingTime(seconds: 180, bookId: 1);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(emissions.last.todayMinutes, equals(3));
      expect(emissions.last.todayGoalMinutes, equals(10));

      await sub.cancel();
    });
  });
}
