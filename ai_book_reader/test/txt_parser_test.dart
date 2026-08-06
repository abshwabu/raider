import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/features/reader/txt/txt_parser.dart';

void main() {
  late Isar isar;
  late BookRepository bookRepo;
  late ChapterRepository chapterRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('txt_parser_test');
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

  test('TxtParser splits text with explicit chapter headers correctly', () async {
    const rawTxt = '''
Chapter 1
This is the content of chapter 1.

Chapter 2
This is the content of chapter 2.
''';
    final txtFile = File('${tempDir.path}/test_with_headers.txt');
    await txtFile.writeAsString(rawTxt);

    final book = Book()
      ..title = 'Test Header TXT'
      ..format = 'txt'
      ..filePath = txtFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await TxtParser.extractChapters(
      bookId: bookId,
      filePath: txtFile.path,
      chapterRepository: chapterRepo,
    );

    expect(chapters.length, equals(2));
    expect(chapters[0].title, equals('Chapter 1'));
    expect(chapters[0].content, contains('content of chapter 1'));
    expect(chapters[1].title, equals('Chapter 2'));
    expect(chapters[1].content, contains('content of chapter 2'));

    final savedChapters = await chapterRepo.getChaptersForBook(bookId);
    expect(savedChapters.length, equals(2));
  });

  test('TxtParser creates synthetic sections for plain text without headers', () async {
    // Generate 4,000 words plain text
    final words = List.generate(4000, (i) => 'word$i');
    final rawTxt = words.join(' ');
    final txtFile = File('${tempDir.path}/test_no_headers.txt');
    await txtFile.writeAsString(rawTxt);

    final book = Book()
      ..title = 'Test Plain TXT'
      ..format = 'txt'
      ..filePath = txtFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await TxtParser.extractChapters(
      bookId: bookId,
      filePath: txtFile.path,
      chapterRepository: chapterRepo,
    );

    // 4000 words / 3000 words per section = 2 sections
    expect(chapters.length, equals(2));
    expect(chapters[0].title, contains('Section 1'));
    expect(chapters[1].title, contains('Section 2'));
  });
}
