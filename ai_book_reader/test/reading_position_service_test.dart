import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_book_reader/data/local/reading_position_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ReadingPositionService saves and restores chapter and scroll offset', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = ReadingPositionService(prefs);

    const bookId = 42;
    const chapterIndex = 2;
    const scrollOffset = 350.0;
    const maxScrollExtent = 1000.0;
    const totalChapters = 5;

    await service.savePosition(
      bookId: bookId,
      chapterIndex: chapterIndex,
      scrollOffset: scrollOffset,
      maxScrollExtent: maxScrollExtent,
      totalChapters: totalChapters,
    );

    expect(service.getLastChapterIndexSync(bookId, totalChapters: totalChapters), 2);
    expect(service.getChapterScrollOffsetSync(bookId, chapterIndex), 350.0);
    expect(service.getChapterScrollFractionSync(bookId, chapterIndex), 0.35);

    // Other chapters default to 0.0
    expect(service.getChapterScrollOffsetSync(bookId, 0), 0.0);
    expect(service.getChapterScrollFractionSync(bookId, 0), 0.0);
  });

  test('ReadingPositionService calculates overall progress smoothly', () {
    // 35% through chapter 2 out of 5 chapters (chapters 0, 1, 2, 3, 4)
    final progress = ReadingPositionService.calculateOverallProgress(
      chapterIndex: 2,
      scrollOffset: 350.0,
      maxScrollExtent: 1000.0,
      totalChapters: 5,
    );

    // (2 + 0.35) / 5 = 0.47
    expect(progress, closeTo(0.47, 0.001));

    // At the end of the book: chapter 4 (last chapter), 100% scrolled
    final endProgress = ReadingPositionService.calculateOverallProgress(
      chapterIndex: 4,
      scrollOffset: 1000.0,
      maxScrollExtent: 1000.0,
      totalChapters: 5,
    );
    expect(endProgress, 1.0);
  });
}
