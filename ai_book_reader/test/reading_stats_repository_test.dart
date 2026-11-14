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
  });
}
