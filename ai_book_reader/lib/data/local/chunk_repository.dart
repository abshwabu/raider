import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/chunk.dart';
import 'isar_service.dart';

final chunkRepositoryProvider = Provider<ChunkRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return ChunkRepository(isar);
});

class ChunkRepository {
  final Isar isar;

  ChunkRepository(this.isar);

  Future<List<Chunk>> getChunksForBook(int bookId) async {
    return await isar.chunks
        .filter()
        .bookIdEqualTo(bookId)
        .sortByOrderInChapter()
        .findAll();
  }

  Future<List<Chunk>> getChunksForChapter(int bookId, int chapterId) async {
    return await isar.chunks
        .filter()
        .bookIdEqualTo(bookId)
        .chapterIdEqualTo(chapterId)
        .sortByOrderInChapter()
        .findAll();
  }

  Future<void> addChunks(List<Chunk> chunks) async {
    await isar.writeTxn(() async {
      await isar.chunks.putAll(chunks);
    });
  }

  Future<void> updateEmbedding(int chunkId, List<double> embedding) async {
    await isar.writeTxn(() async {
      final chunk = await isar.chunks.get(chunkId);
      if (chunk != null) {
        chunk.embedding = embedding;
        await isar.chunks.put(chunk);
      }
    });
  }

  Future<bool> hasEmbeddings(int bookId) async {
    final count = await isar.chunks
        .filter()
        .bookIdEqualTo(bookId)
        .embeddingIsNotNull()
        .count();
    return count > 0;
  }
}
