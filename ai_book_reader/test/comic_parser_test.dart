import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/isar_service.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/features/reader/comic/comic_parser.dart';
import 'package:ai_book_reader/features/reader/comic/comic_reader_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

List<int> createTestCbzArchive(List<String> filenames) {
  final archive = Archive();
  // Dummy 1x1 transparent PNG bytes
  final dummyPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  for (final filename in filenames) {
    archive.addFile(ArchiveFile(filename, dummyPngBytes.length, dummyPngBytes));
  }

  return ZipEncoder().encode(archive)!;
}

void main() {
  late Isar isar;
  late BookRepository bookRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('comic_parser_test');
    final docsDir = Directory('${tempDir.path}/documents');
    await docsDir.create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(docsDir.path);

    isar = await Isar.open(
      [BookSchema, ChapterSchema],
      directory: tempDir.path,
    );
    bookRepo = BookRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ComicParser.naturalCompare sorts filenames numerically', () {
    final list = ['page10.jpg', 'page2.jpg', 'page1.jpg', 'page20.jpg'];
    list.sort(ComicParser.naturalCompare);
    expect(list, equals(['page1.jpg', 'page2.jpg', 'page10.jpg', 'page20.jpg']));
  });

  test('ComicParser extracts pages in natural order and sets cover image', () async {
    final cbzBytes = createTestCbzArchive([
      '__MACOSX/._page1.png',
      'page10.png',
      'page2.png',
      'page1.png',
    ]);

    final cbzFile = File('${tempDir.path}/test_comic.cbz');
    await cbzFile.writeAsBytes(cbzBytes);

    final book = Book()
      ..title = 'Test Comic'
      ..format = 'cbz'
      ..filePath = cbzFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);
    book.id = bookId;

    final extractedPaths = await ComicParser.extractPageImagePaths(
      book: book,
      bookRepository: bookRepo,
    );

    expect(extractedPaths.length, equals(3));
    expect(book.pageImagePaths.length, equals(3));
    expect(book.coverImagePath, equals(extractedPaths.first));
    expect(File(extractedPaths.first).existsSync(), isTrue);

    final updatedBook = await bookRepo.getBook(bookId);
    expect(updatedBook!.pageImagePaths.length, equals(3));
    expect(updatedBook.coverImagePath, isNotNull);
  });

  test('ComicParser handles CBR files gracefully by returning empty page list', () async {
    final cbrFile = File('${tempDir.path}/test_comic.cbr');
    await cbrFile.writeAsString('Dummy RAR content');

    final book = Book()
      ..title = 'Test CBR Comic'
      ..format = 'cbr'
      ..filePath = cbrFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);
    book.id = bookId;

    final extractedPaths = await ComicParser.extractPageImagePaths(
      book: book,
      bookRepository: bookRepo,
    );

    expect(extractedPaths, isEmpty);
  });

  testWidgets('ComicReaderScreen displays clear unsupported message for CBR format', (WidgetTester tester) async {
    final book = Book()
      ..title = 'Sample CBR Comic'
      ..format = 'cbr'
      ..filePath = '/path/to/sample.cbr'
      ..addedAt = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(isar),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ComicReaderScreen(
              book: book,
              pagePaths: const [],
            ),
          ),
        ),
      ),
    );

    expect(find.text('CBR format is not supported yet'), findsOneWidget);
    expect(find.textContaining('Please convert your RAR-compressed comic'), findsOneWidget);
  });
}
