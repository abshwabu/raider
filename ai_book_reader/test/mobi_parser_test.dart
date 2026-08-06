import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/import/import_service.dart';
import 'package:ai_book_reader/features/reader/mobi/mobi_parser.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

List<int> createTestMobiFile({
  required String htmlContent,
  int compression = 1,
  int encryptionType = 0,
}) {
  final contentBytes = utf8.encode(htmlContent);

  const numRecords = 2;
  const rec0Offset = 78 + numRecords * 8;
  final rec1Offset = rec0Offset + 100;
  final totalLength = rec1Offset + contentBytes.length;

  final bytes = List<int>.filled(totalLength, 0);

  bytes[76] = (numRecords >> 8) & 0xFF;
  bytes[77] = numRecords & 0xFF;

  bytes[78] = (rec0Offset >> 24) & 0xFF;
  bytes[79] = (rec0Offset >> 16) & 0xFF;
  bytes[80] = (rec0Offset >> 8) & 0xFF;
  bytes[81] = rec0Offset & 0xFF;

  bytes[86] = (rec1Offset >> 24) & 0xFF;
  bytes[87] = (rec1Offset >> 16) & 0xFF;
  bytes[88] = (rec1Offset >> 8) & 0xFF;
  bytes[89] = rec1Offset & 0xFF;

  bytes[rec0Offset] = (compression >> 8) & 0xFF;
  bytes[rec0Offset + 1] = compression & 0xFF;

  bytes[rec0Offset + 8] = 0;
  bytes[rec0Offset + 9] = 1;

  bytes[rec0Offset + 12] = (encryptionType >> 8) & 0xFF;
  bytes[rec0Offset + 13] = encryptionType & 0xFF;

  for (int i = 0; i < contentBytes.length; i++) {
    bytes[rec1Offset + i] = contentBytes[i];
  }

  return bytes;
}

void main() {
  late Isar isar;
  late BookRepository bookRepo;
  late ChapterRepository chapterRepo;
  late ImportService importService;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mobi_parser_test');
    final docsDir = Directory('${tempDir.path}/documents');
    await docsDir.create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(docsDir.path);

    isar = await Isar.open(
      [BookSchema, ChapterSchema],
      directory: tempDir.path,
    );
    bookRepo = BookRepository(isar);
    chapterRepo = ChapterRepository(isar);
    importService = ImportService(bookRepo, chapterRepo);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('MobiParser.decompressPalmDoc decompresses PalmDOC LZ77 streams correctly', () {
    // PalmDOC LZ77 compressed representation of "Hello World"
    // 'H' (0x48), 'e' (0x65), 'l' (0x6C), 'l' (0x6C), 'o' (0x6F), ' ' (0x20) -> literal bytes 9..127
    final compressedBytes = [0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F, 0x72, 0x6C, 0x64];
    final decompressed = MobiParser.decompressPalmDoc(compressedBytes);
    expect(utf8.decode(decompressed), equals('Hello World'));
  });

  test('MobiParser extracts chapters from DRM-free MOBI file', () async {
    const rawHtml = '<h2>Chapter 1: Arrival</h2><p>Welcome to the world of MOBI.</p><h2>Chapter 2: Journey</h2><p>The story continues.</p>';
    final mobiBytes = createTestMobiFile(htmlContent: rawHtml);

    final mobiFile = File('${tempDir.path}/sample_drm_free.mobi');
    await mobiFile.writeAsBytes(mobiBytes);

    final book = Book()
      ..title = 'Sample MOBI'
      ..format = 'mobi'
      ..filePath = mobiFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await MobiParser.extractChapters(
      bookId: bookId,
      filePath: mobiFile.path,
      chapterRepository: chapterRepo,
    );

    expect(chapters.length, equals(2));
    expect(chapters[0].title, equals('Chapter 1: Arrival'));
    expect(chapters[0].content, contains('Welcome to the world of MOBI.'));
    expect(chapters[1].title, equals('Chapter 2: Journey'));
    expect(chapters[1].content, contains('The story continues.'));
  });

  test('MobiParser throws DrmProtectedException for encrypted DRM MOBI file', () async {
    final mobiBytes = createTestMobiFile(
      htmlContent: 'Encrypted content',
      encryptionType: 2, // DRM Protected
    );

    final mobiFile = File('${tempDir.path}/sample_drm.mobi');
    await mobiFile.writeAsBytes(mobiBytes);

    expect(
      () => MobiParser.extractChapters(
        bookId: 1,
        filePath: mobiFile.path,
      ),
      throwsA(isA<DrmProtectedException>()),
    );
  });

  test('ImportService fails cleanly and deletes database record when importing DRM MOBI file', () async {
    final mobiBytes = createTestMobiFile(
      htmlContent: 'Protected book',
      encryptionType: 2, // DRM Protected
    );

    final mobiFile = File('${tempDir.path}/sample_protected.azw3');
    await mobiFile.writeAsBytes(mobiBytes);

    await expectLater(
      () => importService.importFile(mobiFile.path),
      throwsA(isA<UnsupportedFormatException>().having(
        (e) => e.message,
        'message',
        contains('copy-protected'),
      )),
    );

    final allBooks = await bookRepo.getAllBooks();
    expect(allBooks, isEmpty);
  });
}
