import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/features/reader/pdf/pdf_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late Isar isar;
  late BookRepository bookRepo;
  late ChapterRepository chapterRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_parser_test');
    isar = await Isar.open(
      [BookSchema, ChapterSchema],
      directory: tempDir.path,
    );
    bookRepo = BookRepository(isar);
    chapterRepo = ChapterRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('PdfParser extracts bookmarks as chapters when present', () async {
    final pdfDoc = PdfDocument();
    final page1 = pdfDoc.pages.add();
    page1.graphics.drawString(
      'Chapter 1 Content',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    final page2 = pdfDoc.pages.add();
    page2.graphics.drawString(
      'Chapter 2 Content',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    final bookmark1 = pdfDoc.bookmarks.add('Introduction');
    bookmark1.destination = PdfDestination(page1);

    final bookmark2 = pdfDoc.bookmarks.add('Advanced Topics');
    bookmark2.destination = PdfDestination(page2);

    final pdfPath = '${tempDir.path}/test_with_bookmarks.pdf';
    final bytes = await pdfDoc.save();
    await File(pdfPath).writeAsBytes(bytes);
    pdfDoc.dispose();

    final book = Book()
      ..title = 'Test Bookmark PDF'
      ..format = 'pdf'
      ..filePath = pdfPath
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await PdfParser.extractChapters(
      bookId: bookId,
      filePath: pdfPath,
      chapterRepository: chapterRepo,
    );

    expect(chapters.length, equals(2));
    expect(chapters[0].title, contains('Introduction'));
    expect(chapters[1].title, contains('Advanced Topics'));

    final savedChapters = await chapterRepo.getChaptersForBook(bookId);
    expect(savedChapters.length, equals(2));
  });

  test('PdfParser creates synthetic chapters when no bookmarks exist', () async {
    final pdfDoc = PdfDocument();
    for (int i = 0; i < 15; i++) {
      final page = pdfDoc.pages.add();
      page.graphics.drawString(
        'Page ${i + 1} Content',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
      );
    }

    final pdfPath = '${tempDir.path}/test_without_bookmarks.pdf';
    final bytes = await pdfDoc.save();
    await File(pdfPath).writeAsBytes(bytes);
    pdfDoc.dispose();

    final book = Book()
      ..title = 'Test Synthetic PDF'
      ..format = 'pdf'
      ..filePath = pdfPath
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await PdfParser.extractChapters(
      bookId: bookId,
      filePath: pdfPath,
      chapterRepository: chapterRepo,
    );

    // 15 pages with 10 pages per synthetic chapter = 2 chapters
    expect(chapters.length, equals(2));
    expect(chapters[0].title, contains('Pages 1–10'));
    expect(chapters[1].title, contains('Pages 11–15'));
  });
}
