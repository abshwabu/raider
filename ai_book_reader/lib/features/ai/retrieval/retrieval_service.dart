import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/chunk_repository.dart';
import '../../../data/models/chunk.dart';
import '../provider/ai_provider.dart';
import '../provider/ai_provider_factory.dart';

class EmbeddingsNotReadyException implements Exception {
  final String message;
  EmbeddingsNotReadyException([this.message = 'Embeddings have not been generated for this book yet.']);

  @override
  String toString() => 'EmbeddingsNotReadyException: $message';
}

final retrievalServiceProvider = Provider<RetrievalService>((ref) {
  final chunkRepo = ref.watch(chunkRepositoryProvider);
  final provider = ref.watch(aiProvider);
  return RetrievalService(chunkRepo, provider);
});

class RetrievalService {
  final ChunkRepository chunkRepository;
  final AiProvider aiProvider;

  RetrievalService(this.chunkRepository, this.aiProvider);

  /// Computes cosine similarity between two vector embeddings.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Embeds the user question and retrieves top-K relevant chunks for the book.
  Future<List<Chunk>> retrieveRelevantChunks({
    required int bookId,
    required String question,
    int topK = 6,
  }) async {
    // 1. Fetch all chunks for the book
    final chunks = await chunkRepository.getChunksForBook(bookId);

    // 2. Filter chunks that have valid embeddings
    final embeddedChunks = chunks.where((c) => c.embedding != null && c.embedding!.isNotEmpty).toList();

    if (embeddedChunks.isEmpty) {
      throw EmbeddingsNotReadyException();
    }

    // 3. Embed the user's question
    final questionEmbedding = await aiProvider.embed(question);

    // 4. Compute similarity score for each chunk
    final scoredChunks = <({Chunk chunk, double score})>[];
    for (final chunk in embeddedChunks) {
      final score = cosineSimilarity(questionEmbedding, chunk.embedding!);
      scoredChunks.add((chunk: chunk, score: score));
    }

    // 5. Sort by similarity score descending
    scoredChunks.sort((a, b) => b.score.compareTo(a.score));

    // 6. Return top-K chunks
    return scoredChunks.take(topK).map((item) => item.chunk).toList();
  }
}
