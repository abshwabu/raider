import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'isar_service.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return BookRepository(isar);
});

class BookRepository {
  final Isar isar;

  BookRepository(this.isar);

  Future<List<Book>> getAllBooks() async {
    return await isar.books.where().sortByAddedAtDesc().findAll();
  }

  Future<Book?> getBook(int id) async {
    return await isar.books.get(id);
  }

  Future<int> addBook(Book book) async {
    return await isar.writeTxn(() async {
      return await isar.books.put(book);
    });
  }

  Future<void> updateReadingProgress(int bookId, double progress) async {
    await isar.writeTxn(() async {
      final book = await isar.books.get(bookId);
      if (book != null) {
        book.readingProgress = progress;
        book.lastOpenedAt = DateTime.now();
        await isar.books.put(book);
      }
    });
  }

  Future<void> deleteBook(int id) async {
    await isar.writeTxn(() async {
      await isar.books.delete(id);
      await isar.chapters.filter().bookIdEqualTo(id).deleteAll();
    });
  }
}
