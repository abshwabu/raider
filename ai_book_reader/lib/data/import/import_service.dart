import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/supported_formats.dart';
import '../../features/reader/docx/docx_parser.dart';
import '../../features/reader/epub/epub_parser.dart';
import '../../features/reader/pdf/pdf_parser.dart';
import '../../features/reader/txt/txt_parser.dart';
import '../local/book_repository.dart';
import '../local/chapter_repository.dart';
import '../models/book.dart';

class UnsupportedFormatException implements Exception {
  final String message;
  UnsupportedFormatException(this.message);

  @override
  String toString() => 'UnsupportedFormatException: $message';
}

final importServiceProvider = Provider<ImportService>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final chapterRepo = ref.watch(chapterRepositoryProvider);
  return ImportService(bookRepo, chapterRepo);
});

class ImportService {
  final BookRepository bookRepository;
  final ChapterRepository chapterRepository;

  ImportService(this.bookRepository, this.chapterRepository);

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

    if (ext == 'pdf') {
      try {
        await PdfParser.extractChapters(
          bookId: book.id,
          filePath: targetPath,
          chapterRepository: chapterRepository,
        );
      } catch (_) {}
    } else if (ext == 'epub') {
      try {
        await EpubParser.extractChapters(
          bookId: book.id,
          filePath: targetPath,
          chapterRepository: chapterRepository,
          bookRepository: bookRepository,
        );
      } catch (_) {}
    } else if (ext == 'txt') {
      try {
        await TxtParser.extractChapters(
          bookId: book.id,
          filePath: targetPath,
          chapterRepository: chapterRepository,
        );
      } catch (_) {}
    } else if (ext == 'docx') {
      try {
        await DocxParser.extractChapters(
          bookId: book.id,
          filePath: targetPath,
          chapterRepository: chapterRepository,
        );
      } catch (_) {}
    }

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
        try {
          final book = await importFile(file.path!);
          importedBooks.add(book);
        } catch (_) {
          if (result.files.length == 1) rethrow;
        }
      }
    }

    return importedBooks;
  }
}
