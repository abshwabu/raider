import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/ai_settings_service.dart';
import 'package:ai_book_reader/features/library/presentation/screens/library_screen.dart';

class FakeBookRepository extends Fake implements BookRepository {
  final Map<int, Book> books = {};
  final List<int> deletedIds = [];

  @override
  Future<Book?> getBook(int id) async => books[id];

  @override
  Future<int> addBook(Book book) async {
    final id = book.id > 0 ? book.id : books.length + 1;
    book.id = id;
    books[id] = book;
    return id;
  }

  @override
  Future<void> deleteBook(int id) async {
    deletedIds.add(id);
    books.remove(id);
  }
}

void main() {
  late FakeBookRepository fakeBookRepo;

  setUp(() {
    fakeBookRepo = FakeBookRepository();
  });

  testWidgets('LibraryScreen renders empty state when no books exist', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          booksStreamProvider.overrideWith((ref) => Stream.value(<Book>[])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('Your reading journey starts here'), findsOneWidget);
    expect(
      find.text('Browse and add books from your device to get started'),
      findsOneWidget,
    );
    expect(find.text('Browse Books'), findsOneWidget);
  });

  testWidgets('LibraryScreen displays book cards when books exist', (WidgetTester tester) async {
    final book1 = Book()
      ..id = 1
      ..title = 'Alpha PDF'
      ..author = 'Author Alpha'
      ..format = 'pdf'
      ..filePath = '/fake/alpha.pdf'
      ..addedAt = DateTime.now()
      ..readingProgress = 0.45;

    final book2 = Book()
      ..id = 2
      ..title = 'Beta EPUB'
      ..author = 'Author Beta'
      ..format = 'epub'
      ..filePath = '/fake/beta.epub'
      ..addedAt = DateTime.now().add(const Duration(minutes: 1))
      ..readingProgress = 0.0;

    await fakeBookRepo.addBook(book1);
    await fakeBookRepo.addBook(book2);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          booksStreamProvider.overrideWith((ref) => Stream.value([book1, book2])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    // Verify title appears on cover and card
    expect(find.text('Alpha PDF'), findsWidgets);
    expect(find.text('Author Alpha'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);

    expect(find.text('Beta EPUB'), findsWidgets);
    expect(find.text('Author Beta'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('EPUB'), findsOneWidget);
  });

  testWidgets('Deleting a book removes it from grid after confirmation', (WidgetTester tester) async {
    final book = Book()
      ..id = 1
      ..title = 'Book To Delete'
      ..format = 'txt'
      ..filePath = '/fake/delete_me.txt'
      ..addedAt = DateTime.now();

    await fakeBookRepo.addBook(book);

    final controller = StreamController<List<Book>>();
    controller.add([book]);
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          booksStreamProvider.overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(find.text('Book To Delete'), findsWidgets);

    // Open overflow menu for the book
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap Delete option
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Delete Book'), findsOneWidget);
    expect(find.text("Are you sure you want to delete 'Book To Delete'? This will remove the book and its chapters."), findsOneWidget);

    // Tap Delete in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Simulate stream updating after deletion
    controller.add([]);
    await tester.pump();
    await tester.pump();

    // Verify book is removed from grid and deleted from repository
    expect(find.text('Book To Delete'), findsNothing);
    expect(fakeBookRepo.deletedIds, contains(1));
    expect(await fakeBookRepo.getBook(1), isNull);
  });

  testWidgets('Can toggle between grid and list view with the switch button', (WidgetTester tester) async {
    final book1 = Book()
      ..id = 1
      ..title = 'Alpha PDF'
      ..author = 'Author Alpha'
      ..format = 'pdf'
      ..filePath = '/fake/alpha.pdf'
      ..addedAt = DateTime.now()
      ..readingProgress = 0.45;

    await fakeBookRepo.addBook(book1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          booksStreamProvider.overrideWith((ref) => Stream.value([book1])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    // Defaults to grid view
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);

    // Button icon indicates switching to list view
    final switchButtonFinder = find.byKey(const Key('switch_view_mode_button'));
    expect(switchButtonFinder, findsOneWidget);
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    expect(find.byTooltip('Switch to list view'), findsOneWidget);

    // Tap the switch button to change to list view
    await tester.tap(switchButtonFinder);
    await tester.pumpAndSettle();

    // Now in list view
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);

    // Button icon now indicates switching to grid view
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.byTooltip('Switch to grid view'), findsOneWidget);

    // Book details are visible in list view
    expect(find.text('Alpha PDF'), findsOneWidget);
    expect(find.text('Author Alpha'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);

    // Tap again to switch back to grid view
    await tester.tap(switchButtonFinder);
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
  });

  testWidgets('Deleting a book removes it from list view after confirmation', (WidgetTester tester) async {
    final book = Book()
      ..id = 10
      ..title = 'Book To Delete in List'
      ..format = 'epub'
      ..filePath = '/fake/delete_in_list.epub'
      ..addedAt = DateTime.now();

    await fakeBookRepo.addBook(book);

    final controller = StreamController<List<Book>>();
    controller.add([book]);
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          booksStreamProvider.overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    // Switch to list view
    await tester.tap(find.byKey(const Key('switch_view_mode_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Book To Delete in List'), findsOneWidget);

    // Open options menu in list item
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap Delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Delete Book'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Simulate stream update
    controller.add([]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Book To Delete in List'), findsNothing);
    expect(fakeBookRepo.deletedIds, contains(10));
    expect(await fakeBookRepo.getBook(10), isNull);
  });

  testWidgets('Persists view mode choice in SharedPreferences when available', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'library_view_mode': 'grid'});
    final prefs = await SharedPreferences.getInstance();

    final book = Book()
      ..id = 1
      ..title = 'Sample Book'
      ..format = 'txt'
      ..filePath = '/fake/sample.txt'
      ..addedAt = DateTime.now();

    await fakeBookRepo.addBook(book);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          booksStreamProvider.overrideWith((ref) => Stream.value([book])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    // Initially grid
    expect(find.byType(GridView), findsOneWidget);

    // Switch to list
    await tester.tap(find.byKey(const Key('switch_view_mode_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(prefs.getString('library_view_mode'), 'list');

    // Switch back to grid
    await tester.tap(find.byKey(const Key('switch_view_mode_button')));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(prefs.getString('library_view_mode'), 'grid');
  });
}
