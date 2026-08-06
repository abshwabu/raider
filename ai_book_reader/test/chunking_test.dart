import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/chat_session.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/features/ai/chunking/text_chunker.dart';
import 'package:ai_book_reader/features/ai/chunking/chunking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late ChapterRepository chapterRepo;
  late ChunkRepository chunkRepo;
  late ChunkingService chunkingService;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chunking_test');
    isar = await Isar.open(
      [
        BookSchema,
        ChapterSchema,
        ChunkSchema,
        ChatSessionSchema,
        ChatMessageSchema,
      ],
      directory: tempDir.path,
    );
    chapterRepo = ChapterRepository(isar);
    chunkRepo = ChunkRepository(isar);
    chunkingService = ChunkingService(chapterRepo, chunkRepo);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TextChunker', () {
    final chunker = TextChunker();

    test('strips HTML tags cleanly into plain text', () {
      const htmlText = '<h1>Chapter Title</h1><p>This is a paragraph with <b>bold</b> text.</p>';
      final stripped = TextChunker.stripHtml(htmlText);
      expect(stripped, contains('Chapter Title'));
      expect(stripped, contains('This is a paragraph with bold text.'));
      expect(stripped, isNot(contains('<h1>')));
      expect(stripped, isNot(contains('<p>')));
      expect(stripped, isNot(contains('<b>')));
    });

    test('token count estimation', () {
      const text = 'One two three four five'; // 5 words -> 5 * 1.3 = 6.5 -> 7 tokens
      expect(TextChunker.estimateTokenCount(text), equals(7));
    });

    test('chunks text respecting sentence boundaries and target token limit', () {
      final sentences = List.generate(
        30,
        (i) => 'Sentence number $i contains several descriptive words to test chunking.',
      );
      final fullText = sentences.join(' ');

      final chunks = chunker.chunkText(fullText, targetTokens: 50, overlapTokens: 10);

      expect(chunks.length, greaterThan(1));

      for (final chunk in chunks) {
        // Confirm no mid-word or unclosed sentence splits (ends with period or final sentence)
        expect(chunk.trim().endsWith('.'), isTrue);
        expect(chunk, isNot(contains('<')));
      }
    });

    test('creates overlap between consecutive chunks', () {
      final sentences = List.generate(
        20,
        (i) => 'Distinct Sentence $i for testing overlap behavior.',
      );
      final fullText = sentences.join(' ');

      final chunks = chunker.chunkText(fullText, targetTokens: 30, overlapTokens: 10);
      expect(chunks.length, greaterThan(1));

      // Check if some content from end of chunk 0 appears at start of chunk 1
      final chunk0 = chunks[0];
      final chunk1 = chunks[1];

      final sentencesIn0 = chunk0.split('. ').map((s) => s.trim()).toList();
      final lastSentenceOf0 = sentencesIn0.last;

      expect(chunk1, contains(lastSentenceOf0.replaceAll('.', '')));
    });
  });

  group('ChunkingService', () {
    test('chunks book chapters into Chunk records with null embeddings and no duplicate runs', () async {
      const bookId = 1;

      // Add test chapters
      await chapterRepo.addChapters(bookId, [
        Chapter()
          ..bookId = bookId
          ..title = 'Chapter 1'
          ..order = 1
          ..content = '<div><p>First paragraph of chapter one.</p><p>Second paragraph of chapter one.</p></div>',
        Chapter()
          ..bookId = bookId
          ..title = 'Chapter 2'
          ..order = 2
          ..content = 'Plain text content of chapter two.',
      ]);

      await chunkingService.chunkBook(bookId);

      final chunks = await chunkRepo.getChunksForBook(bookId);
      expect(chunks, isNotEmpty);

      for (final chunk in chunks) {
        expect(chunk.bookId, equals(bookId));
        expect(chunk.text, isNot(contains('<p>')));
        expect(chunk.embedding, isNull);
      }

      final initialChunkCount = chunks.length;

      // Run chunkBook again -> should skip due to existing chunks
      await chunkingService.chunkBook(bookId);

      final reFetchedChunks = await chunkRepo.getChunksForBook(bookId);
      expect(reFetchedChunks.length, equals(initialChunkCount));
    });
  });
}
