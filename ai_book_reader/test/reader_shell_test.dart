import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/annotation.dart';
import 'package:ai_book_reader/data/local/annotation_repository.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/data/local/reading_position_service.dart';
import 'package:ai_book_reader/features/reader/reader_shell.dart';

class FakeBookRepository extends Fake implements BookRepository {
  final Book book;
  FakeBookRepository(this.book);

  @override
  Future<Book?> getBook(int id) async => book;

  @override
  Future<void> updateReadingProgress(int bookId, double progress) async {}
}

class FakeChapterRepository extends Fake implements ChapterRepository {
  final List<Chapter> chapters;
  FakeChapterRepository(this.chapters);

  @override
  Future<List<Chapter>> getChaptersForBook(int bookId) async => chapters;
}

class FakeChunkRepository extends Fake implements ChunkRepository {
  @override
  Future<List<Chunk>> getChunksForBook(int bookId) async => [];

  @override
  Future<void> addChunks(List<Chunk> chunks) async {}
}

class FakeAnnotationRepository extends Fake implements AnnotationRepository {
  @override
  Future<List<Annotation>> getForChapter(int bookId, int chapterId) async => [];

  @override
  Future<List<Annotation>> getForBook(int bookId) async => [];
}

void main() {
  late Directory tempDir;
  late String txtFilePath;
  late Book testBook;
  late List<Chapter> testChapters;
  late FakeBookRepository fakeBookRepo;
  late FakeChapterRepository fakeChapterRepo;
  late FakeChunkRepository fakeChunkRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_shell_test');
    final txtFile = File('${tempDir.path}/sample.txt');
    await txtFile.writeAsString('Chapter 1\nHello world content\nChapter 2\nSecond chapter text');
    txtFilePath = txtFile.path;

    testBook = Book()
      ..id = 1
      ..title = 'Shell Test Book'
      ..format = 'txt'
      ..filePath = txtFilePath
      ..addedAt = DateTime.now();

    testChapters = [
      Chapter()
        ..id = 101
        ..bookId = 1
        ..title = 'Chapter 1'
        ..order = 1
        ..content = 'Hello world content',
      Chapter()
        ..id = 102
        ..bookId = 1
        ..title = 'Chapter 2'
        ..order = 2
        ..content = 'Second chapter text',
    ];

    fakeBookRepo = FakeBookRepository(testBook);
    fakeChapterRepo = FakeChapterRepository(testChapters);
    fakeChunkRepo = FakeChunkRepository();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget createReaderWidget() {
    return ProviderScope(
      overrides: [
        bookRepositoryProvider.overrideWithValue(fakeBookRepo),
        chapterRepositoryProvider.overrideWithValue(fakeChapterRepo),
        chunkRepositoryProvider.overrideWithValue(fakeChunkRepo),
        annotationRepositoryProvider.overrideWithValue(FakeAnnotationRepository()),
        readingPositionServiceProvider.overrideWithValue(ReadingPositionService(null)),
      ],
      child: const MaterialApp(
        home: ReaderShell(bookId: '1'),
      ),
    );
  }

  testWidgets('ReaderShell renders common AppBar, unified AI FAB, and Drawer', (WidgetTester tester) async {
    await tester.pumpWidget(createReaderWidget());
    await tester.pumpAndSettle();

    // Verify AppBar title & unified AI Speed Dial FAB
    expect(find.text('Shell Test Book'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

    // Tap unified AI FAB -> reveals Ask AI and Studio actions
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);

    // Tap Ask AI FAB -> verify AiChatScreen bottom sheet opens
    await tester.tap(find.text('Ask AI'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Ask AI — Shell Test Book'), findsOneWidget);

    // Dismiss bottom sheet
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Table of Contents icon -> verify Drawer opens with chapters
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();
    expect(find.text('2 chapters / sections'), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Chapter 1')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Chapter 2')), findsOneWidget);
  });

  testWidgets('Tapping content toggles chrome visibility and speed dial', (WidgetTester tester) async {
    await tester.pumpWidget(createReaderWidget());
    await tester.pumpAndSettle();

    // Initially AppBar is visible
    expect(find.text('Shell Test Book'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

    // Tap content body -> chrome hides
    await tester.tap(find.textContaining('Hello world content'));
    await tester.pumpAndSettle();

    // Speed dial FAB is hidden
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);

    // Tap again -> chrome returns
    await tester.tap(find.textContaining('Hello world content'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });
}
