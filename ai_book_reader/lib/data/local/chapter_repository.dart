import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/chapter.dart';
import 'isar_service.dart';

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return ChapterRepository(isar);
});

class ChapterRepository {
  final Isar isar;

  ChapterRepository(this.isar);

  Future<List<Chapter>> getChaptersForBook(int bookId) async {
    return await isar.chapters
        .filter()
        .bookIdEqualTo(bookId)
        .sortByOrder()
        .findAll();
  }

  Future<void> addChapters(int bookId, List<Chapter> chapters) async {
    await isar.writeTxn(() async {
      for (final chapter in chapters) {
        chapter.bookId = bookId;
      }
      await isar.chapters.putAll(chapters);
    });
  }
}
