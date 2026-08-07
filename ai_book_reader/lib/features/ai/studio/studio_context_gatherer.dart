import '../../../data/local/chunk_repository.dart';
import '../../../data/models/chunk.dart';
import '../retrieval/retrieval_service.dart';

class StudioContextGatherer {
  static const int defaultCharBudget = 12000;

  final ChunkRepository chunkRepository;
  final RetrievalService retrievalService;

  StudioContextGatherer({
    required this.chunkRepository,
    required this.retrievalService,
  });

  /// Collects grounded excerpts for studio generation within a character budget.
  Future<List<Chunk>> gather({
    required int bookId,
    int? chapterId,
    int charBudget = defaultCharBudget,
  }) async {
    if (chapterId != null) {
      final chapterChunks =
          await chunkRepository.getChunksForChapter(bookId, chapterId);
      return _capChunks(chapterChunks, charBudget);
    }

    final queries = [
      'main themes and thesis of the book',
      'key arguments, claims, and evidence',
      'important characters, people, or concepts',
      'structure, plot, or chapter progression',
      'conclusions, takeaways, and definitions',
    ];

    final byId = <int, Chunk>{};
    for (final query in queries) {
      try {
        final hits = await retrievalService.retrieveRelevantChunks(
          bookId: bookId,
          question: query,
          topK: 4,
        );
        for (final chunk in hits) {
          byId.putIfAbsent(chunk.id, () => chunk);
        }
      } catch (_) {
        // Fall through to sampling if retrieval fails for a query.
      }
    }

    if (byId.isEmpty) {
      final all = await chunkRepository.getChunksForBook(bookId);
      return _sampleAcrossBook(all, charBudget);
    }

    final ranked = byId.values.toList()
      ..sort((a, b) {
        final byChapter = a.chapterId.compareTo(b.chapterId);
        if (byChapter != 0) return byChapter;
        return a.orderInChapter.compareTo(b.orderInChapter);
      });

    final capped = _capChunks(ranked, charBudget);
    if (capped.isEmpty) {
      final all = await chunkRepository.getChunksForBook(bookId);
      return _sampleAcrossBook(all, charBudget);
    }
    return capped;
  }

  List<Chunk> _capChunks(List<Chunk> chunks, int charBudget) {
    final selected = <Chunk>[];
    var used = 0;
    for (final chunk in chunks) {
      final len = chunk.text.length;
      if (selected.isNotEmpty && used + len > charBudget) break;
      selected.add(chunk);
      used += len;
    }
    return selected;
  }

  List<Chunk> _sampleAcrossBook(List<Chunk> chunks, int charBudget) {
    if (chunks.isEmpty) return const [];
    if (chunks.length <= 12) return _capChunks(chunks, charBudget);

    final step = (chunks.length / 12).ceil();
    final sampled = <Chunk>[];
    for (var i = 0; i < chunks.length; i += step) {
      sampled.add(chunks[i]);
    }
    return _capChunks(sampled, charBudget);
  }
}
