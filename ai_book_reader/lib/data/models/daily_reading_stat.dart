import 'package:isar/isar.dart';

part 'daily_reading_stat.g.dart';

@collection
class DailyReadingStat {
  Id id = Isar.autoIncrement;

  /// Normalized date string in 'YYYY-MM-DD' format (e.g. '2026-11-14')
  @Index(unique: true)
  late String date;

  /// Active reading time accumulated on this date in seconds
  int activeSeconds = 0;

  /// Number of pages or sections turned/read on this date
  int pagesRead = 0;

  /// Daily target goal in minutes for this date (e.g. 30)
  int goalMinutes = 30;

  /// IDs of books read on this date
  List<int> bookIds = [];

  /// Number of distinct reading sessions logged on this date
  int sessionCount = 0;

  /// Whether the daily reading goal was completed on this date
  bool isGoalMet = false;

  /// Timestamp when the goal was achieved, if completed
  DateTime? goalMetAt;

  DateTime? updatedAt;
}
