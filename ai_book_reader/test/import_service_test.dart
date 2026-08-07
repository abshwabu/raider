import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/import/import_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Isar isar;
  late BookRepository bookRepo;
  late ImportService importService;
  late Directory tempDir;
  late Directory docsDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_service_test');
    docsDir = Directory('${tempDir.path}/documents');
    await docsDir.create(recursive: true);

    PathProviderPlatform.instance = FakePathProviderPlatform(docsDir.path);

    isar = await Isar.open(
      [BookSchema, ChapterSchema],
      directory: tempDir.path,
    );
    bookRepo = BookRepository(isar);
    final chapterRepo = ChapterRepository(isar);
    importService = ImportService(bookRepo, chapterRepo);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('importFile imports supported PDF file successfully', () async {
    final sourceFile = File('${tempDir.path}/My_Great_Book-sample.pdf');
    await sourceFile.writeAsString('Dummy PDF content');

    final book = await importService.importFile(sourceFile.path);

    expect(book.id, greaterThan(0));
    expect(book.title, equals('My Great Book sample'));
    expect(book.format, equals('pdf'));
    expect(File(book.filePath).existsSync(), isTrue);

    final savedBook = await bookRepo.getBook(book.id);
    expect(savedBook, isNotNull);
    expect(savedBook!.format, equals('pdf'));
  });

  test('importFile throws UnsupportedFormatException on invalid extension', () async {
    final invalidFile = File('${tempDir.path}/test_file.exe');
    await invalidFile.writeAsString('Executable content');

    expect(
      () => importService.importFile(invalidFile.path),
      throwsA(isA<UnsupportedFormatException>()),
    );
  });

  test('Multiple file import creates multiple Book records', () async {
    final file1 = File('${tempDir.path}/book_one.epub');
    final file2 = File('${tempDir.path}/book_two.txt');
    final file3 = File('${tempDir.path}/book_three.docx');
    await file1.writeAsString('epub content');
    await file2.writeAsString('txt content');
    await file3.writeAsString('docx content');

    await importService.importFile(file1.path);
    await importService.importFile(file2.path);
    await importService.importFile(file3.path);

    final allBooks = await bookRepo.getAllBooks();
    expect(allBooks.length, equals(3));
    expect(allBooks.map((b) => b.format), containsAll(['epub', 'txt', 'docx']));
  });

  test('scanDirectoryForBooks finds supported files and skips unsupported', () async {
    final booksDir = Directory('${tempDir.path}/my_books');
    final nested = Directory('${booksDir.path}/fiction');
    await nested.create(recursive: true);

    await File('${booksDir.path}/Alpha.pdf').writeAsString('pdf');
    await File('${nested.path}/Beta.epub').writeAsString('epub');
    await File('${booksDir.path}/notes.md').writeAsString('markdown');
    await File('${booksDir.path}/readme.txt').writeAsString('txt');

    final found = await importService.scanDirectoryForBooks(booksDir.path);

    expect(found.length, equals(3));
    expect(found.map((b) => b.format), containsAll(['pdf', 'epub', 'txt']));
    expect(found.every((b) => !b.alreadyImported), isTrue);
    expect(found.first.title, equals('Alpha')); // sorted A-Z
  });

  test('scanDirectoryForBooks marks already imported files', () async {
    final booksDir = Directory('${tempDir.path}/library_scan');
    await booksDir.create(recursive: true);
    final source = File('${booksDir.path}/Known Book.pdf');
    await source.writeAsString('pdf');

    await importService.importFile(source.path);

    final found = await importService.scanDirectoryForBooks(booksDir.path);
    expect(found.length, equals(1));
    expect(found.single.alreadyImported, isTrue);
  });

  test('importFiles imports multiple selected paths', () async {
    final file1 = File('${tempDir.path}/one.pdf');
    final file2 = File('${tempDir.path}/two.epub');
    await file1.writeAsString('pdf');
    await file2.writeAsString('epub');

    final imported = await importService.importFiles([file1.path, file2.path]);
    expect(imported.length, equals(2));

    final allBooks = await bookRepo.getAllBooks();
    expect(allBooks.length, equals(2));
  });
}
