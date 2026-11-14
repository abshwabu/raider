import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_book_reader/data/import/import_service.dart';
import 'package:ai_book_reader/data/import/incoming_file_service.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:path/path.dart' as p;

class FakeBookRepository extends Fake implements BookRepository {
  final List<Book> books = [];
  int _nextId = 1;

  @override
  Future<int> addBook(Book book) async {
    book.id = _nextId++;
    books.add(book);
    return book.id;
  }

  @override
  Future<List<Book>> getAllBooks() async => List.from(books);

  @override
  Future<Book?> getBook(int id) async =>
      books.where((b) => b.id == id).firstOrNull;

  @override
  Future<void> updateBook(Book book) async {
    final idx = books.indexWhere((b) => b.id == book.id);
    if (idx != -1) books[idx] = book;
  }

  @override
  Future<void> deleteBook(int id) async {
    books.removeWhere((b) => b.id == id);
  }

  @override
  Stream<List<Book>> watchAllBooks() => Stream.value(books);
}

class FakeChapterRepository extends Fake implements ChapterRepository {
  @override
  Future<void> addChapters(int bookId, List<Chapter> chapters) async {}
  @override
  Future<List<Chapter>> getChaptersForBook(int bookId) async => [];
  @override
  Future<void> deleteChaptersForBook(int bookId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeBookRepository fakeBookRepo;
  late FakeChapterRepository fakeChapterRepo;
  late ImportService importService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('incoming_file_test');
    fakeBookRepo = FakeBookRepository();
    fakeChapterRepo = FakeChapterRepository();
    importService = ImportService(fakeBookRepo, fakeChapterRepo);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('IncomingFileService Platform Channel Integration', () {
    const channel = MethodChannel(IncomingFileService.channelName);

    test('getInitialFiles queries platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialFiles') {
          return ['/sdcard/Download/test_book.epub'];
        }
        return null;
      });

      final service = IncomingFileService(
        importService: importService,
        channel: channel,
      );

      final files = await service.getInitialFiles();
      expect(files, equals(['/sdcard/Download/test_book.epub']));
    });

    test('setFileOpenListener triggers callback on onFilesOpened call', () async {
      final service = IncomingFileService(
        importService: importService,
        channel: channel,
      );

      List<String>? receivedPaths;
      service.setFileOpenListener((paths) {
        receivedPaths = paths;
      });

      // Simulate platform invoking onFilesOpened
      final byteData = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onFilesOpened', ['/storage/Download/comic.cbz']),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        IncomingFileService.channelName,
        byteData,
        (data) {},
      );

      expect(receivedPaths, equals(['/storage/Download/comic.cbz']));
    });
  });

  group('ImportService importOrGetExisting', () {
    test('returns existing book if matching file is already imported', () async {
      final existingFile = File(p.join(tempDir.path, 'sample_novel.txt'));
      await existingFile.writeAsString('Hello Novel Content');

      final existingBook = Book()
        ..title = 'Sample Novel'
        ..format = 'txt'
        ..filePath = existingFile.path
        ..addedAt = DateTime.now();
      await fakeBookRepo.addBook(existingBook);

      final result = await importService.importOrGetExisting(existingFile.path);

      expect(result.id, equals(existingBook.id));
      expect(result.title, equals('Sample Novel'));
      // No duplicate added
      expect((await fakeBookRepo.getAllBooks()).length, equals(1));
    });

    test('throws UnsupportedFormatException on unsupported extension', () async {
      final badFile = File(p.join(tempDir.path, 'notes.exe'));
      await badFile.writeAsString('binary');

      expect(
        () => importService.importOrGetExisting(badFile.path),
        throwsA(isA<UnsupportedFormatException>()),
      );
    });

    test('throws FileSystemException when source file does not exist', () async {
      expect(
        () => importService.importOrGetExisting(p.join(tempDir.path, 'missing.epub')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('IncomingFileService processFiles', () {
    test('cleans up temporary incoming_books cache file after import', () async {
      final cacheIncomingDir = Directory(p.join(tempDir.path, 'incoming_books'));
      await cacheIncomingDir.create(recursive: true);

      final incomingFile = File(p.join(cacheIncomingDir.path, 'cached_read.txt'));
      await incomingFile.writeAsString('Book content in cache');

      final existingBook = Book()
        ..title = 'Cached Read'
        ..format = 'txt'
        ..filePath = incomingFile.path
        ..addedAt = DateTime.now();
      await fakeBookRepo.addBook(existingBook);

      final service = IncomingFileService(
        importService: importService,
      );

      final processed = await service.processFiles([incomingFile.path]);

      expect(processed.length, equals(1));
      expect(processed.first.title, equals('Cached Read'));
      // The incoming_books temporary file was deleted
      expect(await incomingFile.exists(), isFalse);
    });
  });
}
