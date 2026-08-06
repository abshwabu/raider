import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/features/reader/epub/epub_parser.dart';
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
  late ChapterRepository chapterRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('epub_parser_test');
    final docsDir = Directory('${tempDir.path}/documents');
    await docsDir.create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(docsDir.path);

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

  test('EpubParser extracts chapters from EPUB container file', () async {
    // Create a minimal valid EPUB archive in memory
    final archive = Archive();
    
    // 1. mimetype
    archive.addFile(ArchiveFile('mimetype', 20, 'application/epub+zip'.codeUnits));
    
    // 2. META-INF/container.xml
    const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    archive.addFile(ArchiveFile('META-INF/container.xml', containerXml.length, containerXml.codeUnits));

    // 3. OEBPS/content.opf
    const contentOpf = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Sample EPUB</dc:title>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.html" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''';
    archive.addFile(ArchiveFile('OEBPS/content.opf', contentOpf.length, contentOpf.codeUnits));

    // 4. OEBPS/toc.ncx
    const tocNcx = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="BookId"/>
  </head>
  <docTitle><text>Sample EPUB</text></docTitle>
  <navMap>
    <navPoint id="navpoint-1" playOrder="1">
      <navLabel><text>Chapter 1: The Beginning</text></navLabel>
      <content src="ch1.html"/>
    </navPoint>
    <navPoint id="navpoint-2" playOrder="2">
      <navLabel><text>Chapter 2: The Journey</text></navLabel>
      <content src="ch2.html"/>
    </navPoint>
  </navMap>
</ncx>''';
    archive.addFile(ArchiveFile('OEBPS/toc.ncx', tocNcx.length, tocNcx.codeUnits));

    // 5. Chapter HTML files
    const ch1Html = '<html><body><h1>The Beginning</h1><p>First chapter body text.</p></body></html>';
    const ch2Html = '<html><body><h1>The Journey</h1><p>Second chapter body text.</p></body></html>';
    archive.addFile(ArchiveFile('OEBPS/ch1.html', ch1Html.length, ch1Html.codeUnits));
    archive.addFile(ArchiveFile('OEBPS/ch2.html', ch2Html.length, ch2Html.codeUnits));

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive)!;

    final epubPath = '${tempDir.path}/sample.epub';
    await File(epubPath).writeAsBytes(zipBytes);

    final book = Book()
      ..title = 'Sample EPUB'
      ..format = 'epub'
      ..filePath = epubPath
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await EpubParser.extractChapters(
      bookId: bookId,
      filePath: epubPath,
      chapterRepository: chapterRepo,
      bookRepository: bookRepo,
    );

    expect(chapters.length, greaterThanOrEqualTo(1));
    expect(chapters[0].content, contains('The Beginning'));

    final savedChapters = await chapterRepo.getChaptersForBook(bookId);
    expect(savedChapters.length, equals(chapters.length));
  });
}
