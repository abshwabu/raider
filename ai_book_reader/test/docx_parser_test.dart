import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/features/reader/docx/docx_parser.dart';

List<int> createTestDocx({
  required List<({String text, String? style})> paragraphs,
  Map<String, String>? styleIdToName,
}) {
  final archive = Archive();

  final docBuffer = StringBuffer();
  docBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  docBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
  docBuffer.writeln('<w:body>');

  for (final p in paragraphs) {
    docBuffer.writeln('<w:p>');
    if (p.style != null) {
      docBuffer.writeln('<w:pPr><w:pStyle w:val="${p.style}"/></w:pPr>');
    }
    docBuffer.writeln('<w:r><w:t>${p.text}</w:t></w:r>');
    docBuffer.writeln('</w:p>');
  }

  docBuffer.writeln('</w:body></w:document>');

  final docBytes = utf8.encode(docBuffer.toString());
  archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));

  if (styleIdToName != null) {
    final styleBuffer = StringBuffer();
    styleBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    styleBuffer.writeln('<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    styleIdToName.forEach((id, name) {
      styleBuffer.writeln('<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$name"/></w:style>');
    });
    styleBuffer.writeln('</w:styles>');
    final styleBytes = utf8.encode(styleBuffer.toString());
    archive.addFile(ArchiveFile('word/styles.xml', styleBytes.length, styleBytes));
  }

  return ZipEncoder().encode(archive)!;
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
    tempDir = await Directory.systemTemp.createTemp('docx_parser_test');
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

  test('DocxParser extracts chapters using heading styles correctly', () async {
    final docxBytes = createTestDocx(
      paragraphs: [
        (text: 'Chapter 1: The Beginning', style: 'Heading1'),
        (text: 'This is the first paragraph of chapter 1.', style: null),
        (text: 'This is the second paragraph of chapter 1.', style: null),
        (text: 'Chapter 2: The Adventure Begins', style: 'Heading1'),
        (text: 'This is chapter 2 paragraph.', style: null),
      ],
    );

    final docxFile = File('${tempDir.path}/test_with_headings.docx');
    await docxFile.writeAsBytes(docxBytes);

    final book = Book()
      ..title = 'Test DOCX'
      ..format = 'docx'
      ..filePath = docxFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await DocxParser.extractChapters(
      bookId: bookId,
      filePath: docxFile.path,
      chapterRepository: chapterRepo,
    );

    expect(chapters.length, equals(2));
    expect(chapters[0].title, equals('Chapter 1: The Beginning'));
    expect(chapters[0].content, contains('<h2>Chapter 1: The Beginning</h2>'));
    expect(chapters[0].content, contains('<p>This is the first paragraph of chapter 1.</p>'));
    expect(chapters[1].title, equals('Chapter 2: The Adventure Begins'));
    expect(chapters[1].content, contains('<p>This is chapter 2 paragraph.</p>'));

    final savedChapters = await chapterRepo.getChaptersForBook(bookId);
    expect(savedChapters.length, equals(2));
  });

  test('DocxParser creates synthetic sections for docx without heading styles', () async {
    final paragraphs = <({String text, String? style})>[];
    for (int i = 0; i < 40; i++) {
      final words = List.generate(100, (j) => 'word_${i}_$j');
      paragraphs.add((text: words.join(' '), style: null));
    }

    final docxBytes = createTestDocx(paragraphs: paragraphs);
    final docxFile = File('${tempDir.path}/test_no_headings.docx');
    await docxFile.writeAsBytes(docxBytes);

    final book = Book()
      ..title = 'Test Plain DOCX'
      ..format = 'docx'
      ..filePath = docxFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await DocxParser.extractChapters(
      bookId: bookId,
      filePath: docxFile.path,
      chapterRepository: chapterRepo,
    );

    // 4000 words / 3000 words per section = 2 sections
    expect(chapters.length, equals(2));
    expect(chapters[0].title, contains('Section 1'));
    expect(chapters[0].content, contains('<p>'));
    expect(chapters[1].title, contains('Section 2'));
  });

  test('DocxParser uses word/styles.xml for custom heading style IDs', () async {
    final docxBytes = createTestDocx(
      styleIdToName: {'custom_h1': 'heading 1'},
      paragraphs: [
        (text: 'Custom Title', style: 'custom_h1'),
        (text: 'Some body text under custom heading.', style: null),
      ],
    );

    final docxFile = File('${tempDir.path}/test_custom_styles.docx');
    await docxFile.writeAsBytes(docxBytes);

    final book = Book()
      ..title = 'Test Custom Style DOCX'
      ..format = 'docx'
      ..filePath = docxFile.path
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapters = await DocxParser.extractChapters(
      bookId: bookId,
      filePath: docxFile.path,
      chapterRepository: chapterRepo,
    );

    expect(chapters.length, equals(1));
    expect(chapters[0].title, equals('Custom Title'));
  });
}
