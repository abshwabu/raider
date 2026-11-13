import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_settings_service.dart';

final readingPositionServiceProvider = Provider<ReadingPositionService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ReadingPositionService(prefs);
});

class ReadingPositionService {
  final SharedPreferences? _prefs;

  ReadingPositionService(this._prefs);

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    return await SharedPreferences.getInstance();
  }

  static String _keyLastChapter(int bookId) => 'book_pos_${bookId}_chapter';
  static String _keyLastOffset(int bookId) => 'book_pos_${bookId}_offset';
  static String _keyLastFraction(int bookId) => 'book_pos_${bookId}_fraction';

  static String _keyChapterOffset(int bookId, int chapterIndex) =>
      'book_pos_${bookId}_ch_${chapterIndex}_offset';
  static String _keyChapterFraction(int bookId, int chapterIndex) =>
      'book_pos_${bookId}_ch_${chapterIndex}_fraction';

  /// Save current reading position for a book and its chapter.
  Future<void> savePosition({
    required int bookId,
    required int chapterIndex,
    required double scrollOffset,
    required double maxScrollExtent,
    required int totalChapters,
  }) async {
    final prefs = await _getPrefs();
    final fraction = maxScrollExtent > 0 ? (scrollOffset / maxScrollExtent).clamp(0.0, 1.0) : 0.0;

    await prefs.setInt(_keyLastChapter(bookId), chapterIndex);
    await prefs.setDouble(_keyLastOffset(bookId), scrollOffset);
    await prefs.setDouble(_keyLastFraction(bookId), fraction);

    await prefs.setDouble(_keyChapterOffset(bookId, chapterIndex), scrollOffset);
    await prefs.setDouble(_keyChapterFraction(bookId, chapterIndex), fraction);
  }

  /// Synchronously save position if SharedPreferences instance is already available.
  void savePositionSync({
    required int bookId,
    required int chapterIndex,
    required double scrollOffset,
    required double maxScrollExtent,
    required int totalChapters,
  }) {
    if (_prefs == null) return;
    final fraction = maxScrollExtent > 0 ? (scrollOffset / maxScrollExtent).clamp(0.0, 1.0) : 0.0;

    _prefs!.setInt(_keyLastChapter(bookId), chapterIndex);
    _prefs!.setDouble(_keyLastOffset(bookId), scrollOffset);
    _prefs!.setDouble(_keyLastFraction(bookId), fraction);

    _prefs!.setDouble(_keyChapterOffset(bookId, chapterIndex), scrollOffset);
    _prefs!.setDouble(_keyChapterFraction(bookId, chapterIndex), fraction);
  }

  /// Get the last read chapter index, with fallback to readingProgress.
  int getLastChapterIndexSync(int bookId, {double fallbackProgress = 0.0, int totalChapters = 1}) {
    if (_prefs != null) {
      final saved = _prefs!.getInt(_keyLastChapter(bookId));
      if (saved != null && saved >= 0 && saved < totalChapters) {
        return saved;
      }
    }
    if (totalChapters > 0 && fallbackProgress > 0) {
      return (fallbackProgress * totalChapters).floor().clamp(0, totalChapters - 1);
    }
    return 0;
  }

  /// Get the saved scroll offset in pixels for a chapter.
  double getChapterScrollOffsetSync(int bookId, int chapterIndex) {
    return _prefs?.getDouble(_keyChapterOffset(bookId, chapterIndex)) ?? 0.0;
  }

  /// Get the saved scroll fraction (0.0 to 1.0) for a chapter.
  double getChapterScrollFractionSync(int bookId, int chapterIndex) {
    return _prefs?.getDouble(_keyChapterFraction(bookId, chapterIndex)) ?? 0.0;
  }

  /// Calculate continuous book reading progress (0.0 to 1.0).
  static double calculateOverallProgress({
    required int chapterIndex,
    required double scrollOffset,
    required double maxScrollExtent,
    required int totalChapters,
  }) {
    if (totalChapters <= 0) return 0.0;
    final inChapterFraction = maxScrollExtent > 0
        ? (scrollOffset / maxScrollExtent).clamp(0.0, 1.0)
        : 0.0;
    return ((chapterIndex + inChapterFraction) / totalChapters).clamp(0.0, 1.0);
  }
}
