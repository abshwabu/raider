import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';

void main() {
  late Isar isar;
  late BookRepository bookRepo;
  late ChapterRepository chapterRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_test');
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

  test('Book and Chapter repository CRUD operations test', () async {
    final book = Book()
      ..title = 'Test Book'
      ..author = 'Test Author'
      ..format = 'epub'
      ..filePath = '/path/to/test.epub'
      ..addedAt = DateTime.now();

    final bookId = await bookRepo.addBook(book);
    expect(bookId, greaterThan(0));

    final fetchedBook = await bookRepo.getBook(bookId);
    expect(fetchedBook, isNotNull);
    expect(fetchedBook!.title, equals('Test Book'));
    expect(fetchedBook.author, equals('Test Author'));

    // Test adding chapters
    final chapters = [
      Chapter()
        ..bookId = bookId
        ..title = 'Chapter 1'
        ..order = 1
        ..content = '<p>Hello world</p>',
      Chapter()
        ..bookId = bookId
        ..title = 'Chapter 2'
        ..order = 2
        ..content = '<p>Second chapter</p>',
    ];

    await chapterRepo.addChapters(bookId, chapters);
    final fetchedChapters = await chapterRepo.getChaptersForBook(bookId);
    expect(fetchedChapters.length, equals(2));
    expect(fetchedChapters[0].title, equals('Chapter 1'));
    expect(fetchedChapters[1].title, equals('Chapter 2'));

    // Update reading progress
    await bookRepo.updateReadingProgress(bookId, 0.5);
    final updatedBook = await bookRepo.getBook(bookId);
    expect(updatedBook!.readingProgress, equals(0.5));
    expect(updatedBook.lastOpenedAt, isNotNull);

    // Delete book & chapters
    await bookRepo.deleteBook(bookId);
    expect(await bookRepo.getBook(bookId), isNull);
    expect((await chapterRepo.getChaptersForBook(bookId)).isEmpty, isTrue);
  });
}
