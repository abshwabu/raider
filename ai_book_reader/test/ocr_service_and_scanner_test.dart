import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/features/ai/chunking/chunking_service.dart';
import 'package:ai_book_reader/features/ai/embedding/embedding_service.dart';
import 'package:ai_book_reader/features/ai/provider/ai_provider.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/features/reader/ocr/ocr_service.dart';
import 'package:ai_book_reader/features/reader/ocr/book_ocr_scanner.dart';
import 'package:ai_book_reader/features/reader/pdf/pdf_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class _FakeAiProvider implements AiProvider {
  @override
  Future<List<double>> embed(String text) async => [0.1, 0.2, 0.3];

  @override
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    yield 'Response';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late BookRepository bookRepo;
  late ChapterRepository chapterRepo;
  late ChunkRepository chunkRepo;
  late ChunkingService chunkingService;
  late EmbeddingService embeddingService;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocr_test');
    isar = await Isar.open(
      [BookSchema, ChapterSchema, ChunkSchema],
      directory: tempDir.path,
    );
    bookRepo = BookRepository(isar);
    chapterRepo = ChapterRepository(isar);
    chunkRepo = ChunkRepository(isar);
    chunkingService = ChunkingService(chapterRepo, chunkRepo);
    embeddingService = EmbeddingService(chunkRepo, _FakeAiProvider());
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('OcrService invokes method channel correctly', () async {
    const channel = MethodChannel('com.aibookreader.ai_book_reader/ocr_test_channel');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'isAvailable') {
        return true;
      }
      if (methodCall.method == 'ocrPdf') {
        return [
          {'pageIndex': 0, 'pageNumber': 1, 'text': 'Scanned Page 1 Text'},
          {'pageIndex': 1, 'pageNumber': 2, 'text': 'Scanned Page 2 Text'},
        ];
      }
      if (methodCall.method == 'ocrImage') {
        return 'Recognized image text';
      }
      return null;
    });

    final service = OcrService(channel: channel);

    final available = await service.isAvailable();
    expect(available, isTrue);

    final pdfPages = await service.ocrPdf(filePath: '/test/dummy.pdf');
    expect(pdfPages.length, equals(2));
    expect(pdfPages[0].text, equals('Scanned Page 1 Text'));
    expect(pdfPages[1].text, equals('Scanned Page 2 Text'));

    final imgText = await service.ocrImage('/test/dummy.jpg');
    expect(imgText, equals('Recognized image text'));
  });

  test('PdfParser falls back to OCR when PDF contains scanned image pages', () async {
    // Create a PDF with blank pages (no digital text)
    final pdfDoc = PdfDocument();
    pdfDoc.pages.add(); // Page 1
    pdfDoc.pages.add(); // Page 2

    final pdfPath = '${tempDir.path}/scanned_document.pdf';
    final bytes = await pdfDoc.save();
    await File(pdfPath).writeAsBytes(bytes);
    pdfDoc.dispose();

    const channel = MethodChannel('com.aibookreader.ai_book_reader/ocr_pdf_parser_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'ocrPdf') {
        return [
          {
            'pageIndex': 0,
            'pageNumber': 1,
            'text': 'Certificate of Completion for John Doe from Scanner'
          },
          {
            'pageIndex': 1,
            'pageNumber': 2,
            'text': 'Course Modules and Evaluation Results page 2'
          },
        ];
      }
      return null;
    });

    final ocrService = OcrService(channel: channel);

    final book = Book()
      ..title = 'Scanned Document'
      ..format = 'pdf'
      ..filePath = pdfPath
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await PdfParser.extractChapters(
      bookId: bookId,
      filePath: pdfPath,
      chapterRepository: chapterRepo,
      ocrService: ocrService,
    );

    expect(chapters.isNotEmpty, isTrue);
    expect(chapters[0].content, contains('Certificate of Completion for John Doe'));
    expect(chapters[1].content, contains('Course Modules and Evaluation Results'));

    final saved = await chapterRepo.getChaptersForBook(bookId);
    expect(saved.first.content, contains('Certificate of Completion'));
  });

  test('BookOcrScanner detects scanned PDF without text and enriches it', () async {
    final pdfDoc = PdfDocument();
    pdfDoc.pages.add();
    final pdfPath = '${tempDir.path}/empty_pdf.pdf';
    await File(pdfPath).writeAsBytes(await pdfDoc.save());
    pdfDoc.dispose();

    final book = Book()
      ..title = 'My Scanned Contract'
      ..format = 'pdf'
      ..filePath = pdfPath
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    // Initial chapter has placeholder text
    final placeholderChapter = Chapter()
      ..bookId = bookId
      ..title = 'Pages 1-1'
      ..order = 1
      ..content = 'Content for pages 1 to 1';
    await chapterRepo.addChapters(bookId, [placeholderChapter]);
    await chunkingService.chunkBook(bookId);

    const channel = MethodChannel('com.aibookreader.ai_book_reader/ocr_scanner_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'isAvailable') return true;
      if (methodCall.method == 'ocrPdf') {
        return [
          {
            'pageIndex': 0,
            'pageNumber': 1,
            'text': 'Confidential Agreement between Party A and Party B'
          }
        ];
      }
      return null;
    });

    final ocrService = OcrService(channel: channel);
    final scanner = BookOcrScanner(
      bookRepo: bookRepo,
      chapterRepo: chapterRepo,
      chunkRepo: chunkRepo,
      chunkingService: chunkingService,
      ocrService: ocrService,
      embeddingService: embeddingService,
    );

    // Verify it detects as scanned without text
    final isScanned = await scanner.isBookScannedWithoutText(bookId);
    expect(isScanned, isTrue);

    // Scan and enrich
    final result = await scanner.scanAndEnrichBook(bookId);
    expect(result.success, isTrue);
    expect(result.pagesScanned, equals(1));
    expect(result.totalCharacters, greaterThan(20));

    // Check chapters are updated with OCR text
    final updatedChapters = await chapterRepo.getChaptersForBook(bookId);
    expect(updatedChapters.first.content, contains('Confidential Agreement between Party A'));

    // Check chunks are generated with real text
    final chunks = await chunkRepo.getChunksForBook(bookId);
    expect(chunks.isNotEmpty, isTrue);
    expect(chunks.first.text, contains('Confidential Agreement between Party A'));
    expect(chunks.first.text.startsWith('Content for pages'), isFalse);

    // Verify it is no longer detected as scanned without text
    final isStillScanned = await scanner.isBookScannedWithoutText(bookId);
    expect(isStillScanned, isFalse);
  });
}
