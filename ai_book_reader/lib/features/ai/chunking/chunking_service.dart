import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/local/chunk_repository.dart';
import '../../../data/models/chunk.dart';
import 'text_chunker.dart';

final chunkingServiceProvider = Provider<ChunkingService>((ref) {
  final chapterRepo = ref.watch(chapterRepositoryProvider);
  final chunkRepo = ref.watch(chunkRepositoryProvider);
  return ChunkingService(chapterRepo, chunkRepo);
});

class ChunkingService {
  final ChapterRepository chapterRepository;
  final ChunkRepository chunkRepository;
  final TextChunker textChunker;

  ChunkingService(
    this.chapterRepository,
    this.chunkRepository, {
    TextChunker? textChunker,
  }) : textChunker = textChunker ?? TextChunker();

  Future<void> chunkBook(int bookId) async {
    // Skip chunking if chunks already exist for this book (avoid duplicate work)
    final existingChunks = await chunkRepository.getChunksForBook(bookId);
    if (existingChunks.isNotEmpty) {
      return;
    }

    final chapters = await chapterRepository.getChaptersForBook(bookId);
    if (chapters.isEmpty) {
      return;
    }

    final chunksToAdd = <Chunk>[];

    for (final chapter in chapters) {
      final rawText = chapter.content;
      if (rawText.trim().isEmpty) continue;

      final chunkTexts = textChunker.chunkText(rawText);

      for (int i = 0; i < chunkTexts.length; i++) {
        final chunk = Chunk()
          ..bookId = bookId
          ..chapterId = chapter.id
          ..text = chunkTexts[i]
          ..orderInChapter = i + 1
          ..embedding = null;

        chunksToAdd.add(chunk);
      }
    }

    if (chunksToAdd.isNotEmpty) {
      await chunkRepository.addChunks(chunksToAdd);
    }
  }
}
