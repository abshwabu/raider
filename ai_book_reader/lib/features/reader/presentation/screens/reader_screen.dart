import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/features/reader/epub/epub_reader_screen.dart';
import 'package:ai_book_reader/features/reader/pdf/pdf_reader_screen.dart';

class ReaderScreen extends ConsumerWidget {
  final String bookId;

  const ReaderScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(bookId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invalid Book')),
        body: const Center(child: Text('Invalid book ID provided.')),
      );
    }

    final bookRepo = ref.watch(bookRepositoryProvider);

    return FutureBuilder<Book?>(
      future: bookRepo.getBook(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading Book...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final book = snapshot.data;
        if (book == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Book Not Found')),
            body: const Center(child: Text('Book does not exist in library.')),
          );
        }

        switch (book.format.toLowerCase()) {
          case 'pdf':
            return PdfReaderScreen(bookId: bookId);
          case 'epub':
            return EpubReaderScreen(bookId: bookId);
          default:
            return Scaffold(
              appBar: AppBar(title: Text(book.title)),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reader for ${book.format.toUpperCase()} coming soon',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Book ID: ${book.id}'),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
