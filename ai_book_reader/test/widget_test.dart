import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_book_reader/app.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/models/book.dart';

class FakeBookRepository extends Fake implements BookRepository {
  final Map<int, Book> books = {};

  @override
  Future<Book?> getBook(int id) async => books[id];

  @override
  Future<List<Book>> getAllBooks() async => books.values.toList();

  @override
  Stream<List<Book>> watchAllBooks() => Stream.value(books.values.toList());
}

void main() {
  late FakeBookRepository fakeBookRepo;

  setUp(() {
    fakeBookRepo = FakeBookRepository();
  });

  testWidgets('App loads LibraryScreen empty state smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          booksStreamProvider.overrideWith((ref) => Stream.value(<Book>[])),
        ],
        child: const App(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the splash screen displays the Raider brand
    expect(find.text('RAIDER'), findsOneWidget);
    expect(find.text('AI BOOK READER'), findsOneWidget);

    // Pump past the splash duration to transition to LibraryScreen
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify that the Library title and empty state text appear
    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('No books yet'), findsOneWidget);
    expect(find.text('Add Books'), findsOneWidget); // FAB
    expect(find.text('Browse books'), findsOneWidget); // Empty state CTA
  });
}
