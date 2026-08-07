import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_book_reader/data/import/import_service.dart';
import 'package:ai_book_reader/features/library/presentation/widgets/browse_books_sheet.dart';

void main() {
  testWidgets('BrowseBooksSheet lists books and returns selected paths', (tester) async {
    final books = [
      const DiscoverableBook(
        path: '/books/Alpha.pdf',
        title: 'Alpha',
        format: 'pdf',
        sizeBytes: 1024,
      ),
      const DiscoverableBook(
        path: '/books/Beta.epub',
        title: 'Beta',
        format: 'epub',
        sizeBytes: 2048,
        alreadyImported: true,
      ),
      const DiscoverableBook(
        path: '/books/Gamma.txt',
        title: 'Gamma',
        format: 'txt',
        sizeBytes: 512,
      ),
    ];

    List<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await BrowseBooksSheet.show(
                  context,
                  books: books,
                  folderName: 'books',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Available books'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.textContaining('Already in library'), findsOneWidget);

    // Deselect Gamma (pre-selected new books), keep Alpha.
    await tester.tap(find.text('Gamma'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add 1 to library'));
    await tester.pumpAndSettle();

    expect(result, equals(['/books/Alpha.pdf']));
  });
}
