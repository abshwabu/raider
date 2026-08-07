import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/local/isar_service.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/features/library/presentation/screens/library_screen.dart';
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
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('library_screen_test');
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

  testWidgets('LibraryScreen renders empty state when no books exist', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(isar),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('No books yet'), findsOneWidget);
    expect(
      find.text('Browse supported book files, then add the ones you want'),
      findsOneWidget,
    );
    expect(find.text('Browse books'), findsOneWidget);
  });

  testWidgets('LibraryScreen displays book cards when books exist', (WidgetTester tester) async {
    final book1 = Book()
      ..title = 'Alpha PDF'
      ..author = 'Author Alpha'
      ..format = 'pdf'
      ..filePath = '${tempDir.path}/alpha.pdf'
      ..addedAt = DateTime.now()
      ..readingProgress = 0.45;

    final book2 = Book()
      ..title = 'Beta EPUB'
      ..author = 'Author Beta'
      ..format = 'epub'
      ..filePath = '${tempDir.path}/beta.epub'
      ..addedAt = DateTime.now().add(const Duration(minutes: 1))
      ..readingProgress = 0.0;

    await bookRepo.addBook(book1);
    await bookRepo.addBook(book2);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(isar),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Alpha PDF'), findsOneWidget);
    expect(find.text('Author Alpha'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);

    expect(find.text('Beta EPUB'), findsOneWidget);
    expect(find.text('Author Beta'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('EPUB'), findsOneWidget);
  });

  testWidgets('Deleting a book removes it from grid after confirmation', (WidgetTester tester) async {
    final book = Book()
      ..title = 'Book To Delete'
      ..format = 'txt'
      ..filePath = '${tempDir.path}/delete_me.txt'
      ..addedAt = DateTime.now();

    final id = await bookRepo.addBook(book);
    book.id = id;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(isar),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Book To Delete'), findsOneWidget);

    // Open overflow menu for the book
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Delete option
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Confirm dialog appears
    expect(find.text('Delete Book'), findsOneWidget);
    expect(find.text("Are you sure you want to delete 'Book To Delete'? This will remove the book and its chapters."), findsOneWidget);

    // Tap Delete in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify book is removed from Isar & grid
    expect(find.text('Book To Delete'), findsNothing);
    final savedBook = await bookRepo.getBook(id);
    expect(savedBook, isNull);
  });
}
