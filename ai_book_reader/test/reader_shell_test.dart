import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/isar_service.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/features/reader/reader_shell.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/chat_session.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';

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
  late String txtFilePath;
  late int bookId;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_shell_test');
    final docsDir = Directory('${tempDir.path}/documents');
    await docsDir.create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(docsDir.path);

    isar = await Isar.open(
      [
        BookSchema,
        ChapterSchema,
        ChunkSchema,
        ChatSessionSchema,
        ChatMessageSchema,
      ],
      directory: tempDir.path,
    );
    bookRepo = BookRepository(isar);
    chapterRepo = ChapterRepository(isar);

    final txtFile = File('${tempDir.path}/sample.txt');
    await txtFile.writeAsString('Chapter 1\nHello world content\nChapter 2\nSecond chapter text');
    txtFilePath = txtFile.path;

    final book = Book()
      ..title = 'Shell Test Book'
      ..format = 'txt'
      ..filePath = txtFilePath
      ..addedAt = DateTime.now();
    bookId = await bookRepo.addBook(book);

    await chapterRepo.addChapters(bookId, [
      Chapter()
        ..bookId = bookId
        ..title = 'Chapter 1'
        ..order = 1
        ..content = 'Hello world content',
      Chapter()
        ..bookId = bookId
        ..title = 'Chapter 2'
        ..order = 2
        ..content = 'Second chapter text',
    ]);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('ReaderShell renders common AppBar, Ask AI FAB, and Drawer', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(isar),
        ],
        child: MaterialApp(
          home: ReaderShell(bookId: bookId.toString()),
        ),
      ),
    );

    await tester.pump();
    await tester.idle();
    await tester.pump();

    // Verify AppBar title & Ask AI FAB
    expect(find.text('Shell Test Book'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);

    // Tap Ask AI FAB -> verify AiChatScreen bottom sheet opens
    await tester.tap(find.text('Ask AI'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Ask AI — Shell Test Book'), findsOneWidget);

    // Tap Table of Contents icon -> verify Drawer opens with chapters
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2 chapters / sections'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Chapter 2'), findsOneWidget);
  });
}
