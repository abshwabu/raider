import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/supported_formats.dart';
import '../local/book_repository.dart';
import '../models/book.dart';

class UnsupportedFormatException implements Exception {
  final String message;
  UnsupportedFormatException(this.message);

  @override
  String toString() => 'UnsupportedFormatException: $message';
}

final importServiceProvider = Provider<ImportService>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  return ImportService(bookRepo);
});

class ImportService {
  final BookRepository bookRepository;

  ImportService(this.bookRepository);

  Future<Book> importFile(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw FileSystemException('Source file does not exist', sourcePath);
    }

    final ext = p.extension(sourcePath).replaceAll('.', '').toLowerCase();
    if (!SupportedFormats.isSupported(ext)) {
      throw UnsupportedFormatException('Extension .$ext is not supported');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDocDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final filename = p.basename(sourcePath);
    final targetPath = p.join(booksDir.path, '${timestamp}_$filename');

    await file.copy(targetPath);

    String rawTitle = p.basenameWithoutExtension(sourcePath);
    String formattedTitle = rawTitle.replaceAll(RegExp(r'[_-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (formattedTitle.isEmpty) {
      formattedTitle = 'Untitled Book';
    }

    final book = Book()
      ..title = formattedTitle
      ..format = ext
      ..filePath = targetPath
      ..addedAt = DateTime.now()
      ..readingProgress = 0.0;

    final id = await bookRepository.addBook(book);
    book.id = id;

    return book;
  }

  Future<List<Book>> pickAndImportBooks() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: SupportedFormats.extensions,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final importedBooks = <Book>[];
    for (final file in result.files) {
      if (file.path != null) {
        final book = await importFile(file.path!);
        importedBooks.add(book);
      }
    }

    return importedBooks;
  }
}
