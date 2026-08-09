import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/annotation.dart';
import 'isar_service.dart';

final annotationRepositoryProvider = Provider<AnnotationRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return AnnotationRepository(isar);
});

class AnnotationRepository {
  final Isar isar;

  AnnotationRepository(this.isar);

  Future<List<Annotation>> getForChapter(int bookId, int chapterId) async {
    return await isar.annotations
        .filter()
        .bookIdEqualTo(bookId)
        .chapterIdEqualTo(chapterId)
        .sortByStartOffset()
        .findAll();
  }

  Future<List<Annotation>> getForBook(int bookId) async {
    return await isar.annotations
        .filter()
        .bookIdEqualTo(bookId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<Annotation> save(Annotation annotation) async {
    annotation.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      final id = await isar.annotations.put(annotation);
      annotation.id = id;
    });
    return annotation;
  }

  Future<void> delete(int id) async {
    await isar.writeTxn(() async {
      await isar.annotations.delete(id);
    });
  }

  Future<Annotation?> getById(int id) async {
    return await isar.annotations.get(id);
  }
}
