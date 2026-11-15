import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_reading_stat.dart';
import 'ai_settings_service.dart';
import 'isar_service.dart';

class ReadingStreakSummary {
  final int currentStreak;
  final int longestStreak;
  final int totalDaysRead;
  final int totalReadingSeconds;
  final int totalPagesRead;
  final int todaySeconds;
  final int todayPages;
  final int todayGoalMinutes;
  final bool isTodayGoalMet;

  const ReadingStreakSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysRead,
    required this.totalReadingSeconds,
    required this.totalPagesRead,
    required this.todaySeconds,
    required this.todayPages,
    required this.todayGoalMinutes,
    required this.isTodayGoalMet,
  });

  double get todayProgressFraction {
    if (todayGoalMinutes <= 0) return 1.0;
    final goalSeconds = todayGoalMinutes * 60;
    return (todaySeconds / goalSeconds).clamp(0.0, 1.0);
  }

  int get todayMinutes => todaySeconds ~/ 60;
}

abstract class ReadingStatsRepository {
  Future<DailyReadingStat?> getStatForDate(String dateStr);
  Future<DailyReadingStat> getOrCreateTodayStat({int? defaultGoalMinutes});
  Future<bool> recordReadingTime({
    required int seconds,
    required int bookId,
    int pagesIncrement = 0,
  });
  Future<void> recordPagesRead({
    required int pages,
    required int bookId,
  });
  Future<void> setDailyGoal(int minutes);
  Future<int> getDailyGoal();
  Future<List<DailyReadingStat>> getRecentStats({int days = 7});
  Future<List<DailyReadingStat>> getAllStats();
  Future<ReadingStreakSummary> getStreakSummary();
  Stream<DailyReadingStat?> watchTodayStat();
  Stream<ReadingStreakSummary> watchStreakSummary();
  void notifyStatsChanged();

  static ReadingStreakSummary calculateStreakSummary({
    required List<DailyReadingStat> allStats,
    required DailyReadingStat today,
    DateTime? now,
  }) {
    final currentNow = now ?? DateTime.now();
    int totalSeconds = 0;
    int totalPages = 0;
    final Set<String> activeDates = {};

    for (final s in allStats) {
      totalSeconds += s.activeSeconds;
      totalPages += s.pagesRead;
      if (s.activeSeconds >= 30 || s.pagesRead > 0) {
        activeDates.add(s.date);
      }
    }

    if (today.activeSeconds >= 30 || today.pagesRead > 0) {
      activeDates.add(today.date);
    }

    final todayStr = IsarReadingStatsRepository.formatDate(currentNow);
    final yesterdayDate = DateTime(currentNow.year, currentNow.month, currentNow.day - 1);
    final yesterdayStr = IsarReadingStatsRepository.formatDate(yesterdayDate);

    // Calculate current streak
    int currentStreak = 0;

    if (activeDates.contains(todayStr)) {
      // User has read today
      currentStreak = 1;
      var checkDate = DateTime(currentNow.year, currentNow.month, currentNow.day - 1);
      while (activeDates.contains(IsarReadingStatsRepository.formatDate(checkDate))) {
        currentStreak++;
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      }
    } else if (activeDates.contains(yesterdayStr)) {
      // User hasn't read today yet, but read yesterday.
      // Streak from yesterday is maintained until today ends.
      currentStreak = 1;
      var checkDate = DateTime(currentNow.year, currentNow.month, currentNow.day - 2);
      while (activeDates.contains(IsarReadingStatsRepository.formatDate(checkDate))) {
        currentStreak++;
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      }
    } else {
      currentStreak = 0;
    }

    // Calculate longest streak across all history
    int longestStreak = currentStreak;
    if (activeDates.isNotEmpty) {
      final sortedDates = activeDates.toList()..sort();
      int tempStreak = 0;
      DateTime? previousDate;

      for (final dStr in sortedDates) {
        final d = IsarReadingStatsRepository.parseDate(dStr);
        if (previousDate == null) {
          tempStreak = 1;
        } else {
          final expectedNext = DateTime(previousDate.year, previousDate.month, previousDate.day + 1);
          if (IsarReadingStatsRepository.formatDate(d) == IsarReadingStatsRepository.formatDate(expectedNext)) {
            tempStreak++;
          } else if (IsarReadingStatsRepository.formatDate(d) != IsarReadingStatsRepository.formatDate(previousDate)) {
            tempStreak = 1;
          }
        }
        previousDate = d;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      }
    }

    return ReadingStreakSummary(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDaysRead: activeDates.length,
      totalReadingSeconds: totalSeconds,
      totalPagesRead: totalPages,
      todaySeconds: today.activeSeconds,
      todayPages: today.pagesRead,
      todayGoalMinutes: today.goalMinutes,
      isTodayGoalMet: today.isGoalMet,
    );
  }
}

final readingStatsRepositoryProvider = Provider<ReadingStatsRepository>((ref) {
  try {
    final isar = ref.watch(isarProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    return IsarReadingStatsRepository(isar, prefs);
  } catch (_) {
    // Fallback for widget/unit tests when Isar is not mocked
    return InMemoryReadingStatsRepository();
  }
});

class IsarReadingStatsRepository implements ReadingStatsRepository {
  final Isar _isar;
  final SharedPreferences? _prefs;
  final StreamController<void> _statsChangeController = StreamController<void>.broadcast();

  static const String _keyDailyGoal = 'reading_daily_goal_minutes';
  static const int defaultGoalMinutes = 30;

  IsarReadingStatsRepository(this._isar, this._prefs);

  @override
  void notifyStatsChanged() {
    if (!_statsChangeController.isClosed) {
      _statsChangeController.add(null);
    }
  }

  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseDate(String str) {
    final parts = str.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  Future<DailyReadingStat?> getStatForDate(String dateStr) async {
    return await _isar.dailyReadingStats.where().dateEqualTo(dateStr).findFirst();
  }

  @override
  Future<int> getDailyGoal() async {
    if (_prefs != null) {
      return _prefs!.getInt(_keyDailyGoal) ?? defaultGoalMinutes;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyGoal) ?? defaultGoalMinutes;
  }

  @override
  Future<void> setDailyGoal(int minutes) async {
    final goal = minutes > 0 ? minutes : defaultGoalMinutes;
    if (_prefs != null) {
      await _prefs!.setInt(_keyDailyGoal, goal);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyDailyGoal, goal);
    }

    final today = await getOrCreateTodayStat(defaultGoalMinutes: goal);
    await _isar.writeTxn(() async {
      today.goalMinutes = goal;
      if (today.activeSeconds >= goal * 60) {
        today.isGoalMet = true;
        today.goalMetAt ??= DateTime.now();
      } else {
        today.isGoalMet = false;
      }
      today.updatedAt = DateTime.now();
      await _isar.dailyReadingStats.put(today);
    });
    notifyStatsChanged();
  }

  @override
  Future<DailyReadingStat> getOrCreateTodayStat({int? defaultGoalMinutes}) async {
    final todayStr = formatDate(DateTime.now());
    final existing = await getStatForDate(todayStr);
    if (existing != null) return existing;

    final goal = defaultGoalMinutes ?? await getDailyGoal();
    final newStat = DailyReadingStat()
      ..date = todayStr
      ..goalMinutes = goal
      ..activeSeconds = 0
      ..pagesRead = 0
      ..sessionCount = 0
      ..bookIds = []
      ..isGoalMet = false
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.dailyReadingStats.put(newStat);
    });

    return (await getStatForDate(todayStr)) ?? newStat;
  }

  @override
  Future<bool> recordReadingTime({
    required int seconds,
    required int bookId,
    int pagesIncrement = 0,
  }) async {
    if (seconds <= 0 && pagesIncrement <= 0) return false;

    final today = await getOrCreateTodayStat();
    bool justReachedGoal = false;

    await _isar.writeTxn(() async {
      final wasGoalMet = today.isGoalMet;
      today.activeSeconds += seconds;
      today.pagesRead += pagesIncrement;
      today.sessionCount += 1;

      final updatedBookIds = List<int>.from(today.bookIds);
      if (!updatedBookIds.contains(bookId)) {
        updatedBookIds.add(bookId);
      }
      today.bookIds = updatedBookIds;

      final goalSeconds = today.goalMinutes * 60;
      if (today.activeSeconds >= goalSeconds) {
        today.isGoalMet = true;
        today.goalMetAt ??= DateTime.now();
        if (!wasGoalMet) {
          justReachedGoal = true;
        }
      }
      today.updatedAt = DateTime.now();
      await _isar.dailyReadingStats.put(today);
    });

    notifyStatsChanged();
    return justReachedGoal;
  }

  @override
  Future<void> recordPagesRead({
    required int pages,
    required int bookId,
  }) async {
    if (pages <= 0) return;
    final today = await getOrCreateTodayStat();

    await _isar.writeTxn(() async {
      today.pagesRead += pages;
      final updatedBookIds = List<int>.from(today.bookIds);
      if (!updatedBookIds.contains(bookId)) {
        updatedBookIds.add(bookId);
      }
      today.bookIds = updatedBookIds;
      today.updatedAt = DateTime.now();
      await _isar.dailyReadingStats.put(today);
    });

    notifyStatsChanged();
  }

  @override
  Future<List<DailyReadingStat>> getAllStats() async {
    return await _isar.dailyReadingStats.where().sortByDateDesc().findAll();
  }

  @override
  Future<List<DailyReadingStat>> getRecentStats({int days = 7}) async {
    final now = DateTime.now();
    final List<DailyReadingStat> result = [];
    final goal = await getDailyGoal();

    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dateStr = formatDate(d);
      final stat = await getStatForDate(dateStr);
      if (stat != null) {
        result.add(stat);
      } else {
        result.add(
          DailyReadingStat()
            ..date = dateStr
            ..goalMinutes = goal
            ..activeSeconds = 0
            ..pagesRead = 0
            ..sessionCount = 0
            ..bookIds = []
            ..isGoalMet = false,
        );
      }
    }
    return result;
  }

  @override
  Future<ReadingStreakSummary> getStreakSummary() async {
    final allStats = await getAllStats();
    final today = await getOrCreateTodayStat();
    return ReadingStatsRepository.calculateStreakSummary(
      allStats: allStats,
      today: today,
    );
  }

  @override
  Stream<ReadingStreakSummary> watchStreakSummary() {
    late StreamController<ReadingStreakSummary> controller;
    StreamSubscription? isarSub;
    StreamSubscription? changeSub;

    Future<void> emitLatest() async {
      if (controller.isClosed) return;
      try {
        final summary = await getStreakSummary();
        if (!controller.isClosed) {
          controller.add(summary);
        }
      } catch (_) {}
    }

    controller = StreamController<ReadingStreakSummary>.broadcast(
      onListen: () {
        emitLatest();
        isarSub = _isar.dailyReadingStats.watchLazy().listen((_) {
          emitLatest();
        });
        changeSub = _statsChangeController.stream.listen((_) {
          emitLatest();
        });
      },
      onCancel: () {
        isarSub?.cancel();
        changeSub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Stream<DailyReadingStat?> watchTodayStat() {
    final todayStr = formatDate(DateTime.now());
    return _isar.dailyReadingStats
        .where()
        .dateEqualTo(todayStr)
        .watch(fireImmediately: true)
        .map((list) => list.isNotEmpty ? list.first : null);
  }
}

class InMemoryReadingStatsRepository implements ReadingStatsRepository {
  final Map<String, DailyReadingStat> _stats = {};
  int _dailyGoal = 30;
  final StreamController<void> _changeController = StreamController<void>.broadcast();

  @override
  void notifyStatsChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  @override
  Future<DailyReadingStat?> getStatForDate(String dateStr) async => _stats[dateStr];

  @override
  Future<int> getDailyGoal() async => _dailyGoal;

  @override
  Future<void> setDailyGoal(int minutes) async {
    _dailyGoal = minutes;
    final today = await getOrCreateTodayStat();
    today.goalMinutes = minutes;
    today.isGoalMet = today.activeSeconds >= minutes * 60;
    notifyStatsChanged();
  }

  @override
  Future<DailyReadingStat> getOrCreateTodayStat({int? defaultGoalMinutes}) async {
    final todayStr = IsarReadingStatsRepository.formatDate(DateTime.now());
    return _stats.putIfAbsent(
      todayStr,
      () => DailyReadingStat()
        ..date = todayStr
        ..goalMinutes = defaultGoalMinutes ?? _dailyGoal
        ..activeSeconds = 0
        ..pagesRead = 0
        ..sessionCount = 0
        ..bookIds = []
        ..isGoalMet = false,
    );
  }

  @override
  Future<bool> recordReadingTime({
    required int seconds,
    required int bookId,
    int pagesIncrement = 0,
  }) async {
    final today = await getOrCreateTodayStat();
    final wasMet = today.isGoalMet;
    today.activeSeconds += seconds;
    today.pagesRead += pagesIncrement;
    today.sessionCount += 1;
    if (!today.bookIds.contains(bookId)) today.bookIds.add(bookId);
    if (today.activeSeconds >= today.goalMinutes * 60) {
      today.isGoalMet = true;
      today.goalMetAt ??= DateTime.now();
      notifyStatsChanged();
      return !wasMet;
    }
    notifyStatsChanged();
    return false;
  }

  @override
  Future<void> recordPagesRead({required int pages, required int bookId}) async {
    final today = await getOrCreateTodayStat();
    today.pagesRead += pages;
    if (!today.bookIds.contains(bookId)) today.bookIds.add(bookId);
    notifyStatsChanged();
  }

  @override
  Future<List<DailyReadingStat>> getAllStats() async => _stats.values.toList();

  @override
  Future<List<DailyReadingStat>> getRecentStats({int days = 7}) async {
    final now = DateTime.now();
    final List<DailyReadingStat> result = [];
    for (int i = days - 1; i >= 0; i--) {
      final dateStr = IsarReadingStatsRepository.formatDate(now.subtract(Duration(days: i)));
      result.add(_stats[dateStr] ?? (DailyReadingStat()
        ..date = dateStr
        ..goalMinutes = _dailyGoal));
    }
    return result;
  }

  @override
  Future<ReadingStreakSummary> getStreakSummary() async {
    final today = await getOrCreateTodayStat();
    return ReadingStatsRepository.calculateStreakSummary(
      allStats: _stats.values.toList(),
      today: today,
    );
  }

  @override
  Stream<DailyReadingStat?> watchTodayStat() =>
      Stream.value(_stats[IsarReadingStatsRepository.formatDate(DateTime.now())]);

  @override
  Stream<ReadingStreakSummary> watchStreakSummary() {
    late StreamController<ReadingStreakSummary> controller;
    StreamSubscription? sub;

    Future<void> emitLatest() async {
      if (controller.isClosed) return;
      try {
        final summary = await getStreakSummary();
        if (!controller.isClosed) {
          controller.add(summary);
        }
      } catch (_) {}
    }

    controller = StreamController<ReadingStreakSummary>.broadcast(
      onListen: () {
        emitLatest();
        sub = _changeController.stream.listen((_) => emitLatest());
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return controller.stream;
  }
}
