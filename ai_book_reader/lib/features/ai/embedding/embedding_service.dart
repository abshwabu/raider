import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/chunk_repository.dart';
import '../provider/ai_provider.dart';
import '../provider/ai_provider_factory.dart';

final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  final chunkRepo = ref.watch(chunkRepositoryProvider);
  final provider = ref.watch(aiProvider);
  return EmbeddingService(chunkRepo, provider);
});

class EmbeddingService {
  final ChunkRepository chunkRepository;
  final AiProvider aiProvider;

  EmbeddingService(this.chunkRepository, this.aiProvider);

  Future<void> ensureEmbeddingsGenerated(
    int bookId, {
    void Function(int current, int total)? onProgress,
  }) async {
    final hasExisting = await chunkRepository.hasEmbeddings(bookId);
    if (hasExisting) {
      return;
    }

    final chunks = await chunkRepository.getChunksForBook(bookId);
    if (chunks.isEmpty) {
      return;
    }

    final total = chunks.length;
    int processed = 0;

    for (final chunk in chunks) {
      if (chunk.embedding != null && chunk.embedding!.isNotEmpty) {
        processed++;
        onProgress?.call(processed, total);
        continue;
      }

      final embedding = await aiProvider.embed(chunk.text);
      await chunkRepository.updateEmbedding(chunk.id, embedding);

      processed++;
      onProgress?.call(processed, total);
    }
  }
}
