import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/local/chunk_repository.dart';
import '../../../data/models/chapter.dart';
import '../../ai/chunking/chunking_service.dart';
import '../../ai/embedding/embedding_service.dart';
import 'ocr_service.dart';

class OcrScanResult {
  final bool success;
  final int pagesScanned;
  final int totalCharacters;
  final String? errorMessage;

  const OcrScanResult({
    required this.success,
    this.pagesScanned = 0,
    this.totalCharacters = 0,
    this.errorMessage,
  });
}

final bookOcrScannerProvider = Provider<BookOcrScanner>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final chapterRepo = ref.watch(chapterRepositoryProvider);
  final chunkRepo = ref.watch(chunkRepositoryProvider);
  final chunkingService = ref.watch(chunkingServiceProvider);
  final ocrService = ref.watch(ocrServiceProvider);
  final embeddingService = ref.watch(embeddingServiceProvider);

  return BookOcrScanner(
    bookRepo: bookRepo,
    chapterRepo: chapterRepo,
    chunkRepo: chunkRepo,
    chunkingService: chunkingService,
    ocrService: ocrService,
    embeddingService: embeddingService,
  );
});

class BookOcrScanner {
  final BookRepository bookRepo;
  final ChapterRepository chapterRepo;
  final ChunkRepository chunkRepo;
  final ChunkingService chunkingService;
  final OcrService ocrService;
  final EmbeddingService embeddingService;

  BookOcrScanner({
    required this.bookRepo,
    required this.chapterRepo,
    required this.chunkRepo,
    required this.chunkingService,
    required this.ocrService,
    required this.embeddingService,
  });

  /// Determines if a book appears to be a scanned document lacking real text.
  Future<bool> isBookScannedWithoutText(int bookId) async {
    final book = await bookRepo.getBook(bookId);
    if (book == null || book.format.toLowerCase() != 'pdf') {
      return false;
    }

    final chapters = await chapterRepo.getChaptersForBook(bookId);
    if (chapters.isEmpty) {
      return true;
    }

    int realCharCount = 0;
    for (final ch in chapters) {
      final text = ch.content.trim();
      if (text.isEmpty ||
          text.startsWith('Content for pages') ||
          text.startsWith('Pages ')) {
        continue;
      }
      final clean = text
          .replaceAll(
            RegExp(r'CamScanner|Scanned with|Watermark', caseSensitive: false),
            '',
          )
          .trim();
      realCharCount += clean.length;
    }

    return realCharCount < 50;
  }

  /// Scans the PDF with native OCR, replaces chapters with extracted text,
  /// re-chunks the document, and refreshes embeddings.
  Future<OcrScanResult> scanAndEnrichBook(
    int bookId, {
    void Function(int current, int total)? onProgress,
  }) async {
    final book = await bookRepo.getBook(bookId);
    if (book == null) {
      return const OcrScanResult(
        success: false,
        errorMessage: 'Book not found',
      );
    }

    final file = File(book.filePath);
    if (!await file.exists()) {
      return const OcrScanResult(
        success: false,
        errorMessage: 'Document file does not exist on disk',
      );
    }

    final isAvailable = await ocrService.isAvailable();
    if (!isAvailable) {
      return const OcrScanResult(
        success: false,
        errorMessage: 'OCR is not available on this platform',
      );
    }

    try {
      final ocrPages = await ocrService.ocrPdf(
        filePath: book.filePath,
        startPage: 0,
        endPage: -1,
      );

      if (ocrPages.isEmpty) {
        return const OcrScanResult(
          success: false,
          errorMessage: 'No text could be extracted from pages',
        );
      }

      int totalChars = 0;
      final newChapters = <Chapter>[];
      final totalPages = ocrPages.length;
      final pagesPerChapter = totalPages <= 20 ? 1 : 5;
      int order = 1;

      for (int start = 0; start < totalPages; start += pagesPerChapter) {
        final end = (start + pagesPerChapter - 1).clamp(0, totalPages - 1);
        final pageSublist = ocrPages.where(
          (p) => p.pageIndex >= start && p.pageIndex <= end && p.text.trim().isNotEmpty,
        );

        final text = pageSublist.map((p) => p.text.trim()).join('\n\n');
        totalChars += text.length;

        final title = (start == end)
            ? 'Page ${start + 1}'
            : 'Pages ${start + 1}–${end + 1}';

        newChapters.add(
          Chapter()
            ..bookId = bookId
            ..title = title
            ..order = order++
            ..content = text.isNotEmpty
                ? text
                : 'Pages ${start + 1} to ${end + 1}',
        );
      }

      if (newChapters.isNotEmpty) {
        await chapterRepo.replaceChapters(bookId, newChapters);
      }

      // Re-chunk with new OCR text
      await chunkingService.chunkBook(bookId, force: true);

      // Refresh embeddings in background if AI provider is active
      try {
        await embeddingService.ensureEmbeddingsGenerated(bookId, force: true);
      } catch (_) {
        // Embeddings generation may fail if no API key; chunks still exist for studio/chat
      }

      return OcrScanResult(
        success: true,
        pagesScanned: totalPages,
        totalCharacters: totalChars,
      );
    } catch (e) {
      return OcrScanResult(
        success: false,
        errorMessage: 'Error during OCR: $e',
      );
    }
  }
}
