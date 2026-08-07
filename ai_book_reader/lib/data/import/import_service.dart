import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/supported_formats.dart';
import '../../features/ai/chunking/chunking_service.dart';
import '../../features/reader/comic/comic_parser.dart';
import '../../features/reader/docx/docx_parser.dart';
import '../../features/reader/epub/epub_parser.dart';
import '../../features/reader/mobi/mobi_parser.dart';
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

/// A supported book file discovered on disk (not yet imported, or already in library).
class DiscoverableBook {
  final String path;
  final String title;
  final String format;
  final int sizeBytes;
  final bool alreadyImported;

  const DiscoverableBook({
    required this.path,
    required this.title,
    required this.format,
    required this.sizeBytes,
    this.alreadyImported = false,
  });
}

/// Result of scanning a user-selected folder for supported book files.
class FolderScanResult {
  final String folderPath;
  final List<DiscoverableBook> books;

  const FolderScanResult({
    required this.folderPath,
    required this.books,
  });
}

final importServiceProvider = Provider<ImportService>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final chapterRepo = ref.watch(chapterRepositoryProvider);
  final chunkingService = ref.watch(chunkingServiceProvider);
  return ImportService(bookRepo, chapterRepo, chunkingService: chunkingService);
});

class ImportService {
  final BookRepository bookRepository;
  final ChapterRepository chapterRepository;
  final ChunkingService? chunkingService;

  static const _skipDirNames = {
    '.',
    '..',
    'node_modules',
    '.git',
    '.cache',
    'cache',
    '__MACOSX',
  };

  ImportService(
    this.bookRepository,
    this.chapterRepository, {
    this.chunkingService,
  });

  static String formatTitleFromPath(String sourcePath) {
    final rawTitle = p.basenameWithoutExtension(sourcePath);
    final formatted = rawTitle
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return formatted.isEmpty ? 'Untitled Book' : formatted;
  }

  bool _isAlreadyImported(String sourcePath, List<Book> existingBooks) {
    final basename = p.basename(sourcePath);
    return existingBooks.any((book) {
      final storedName = p.basename(book.filePath);
      return storedName == basename || storedName.endsWith('_$basename');
    });
  }

  /// Recursively finds supported book files under [directoryPath].
  Future<List<DiscoverableBook>> scanDirectoryForBooks(
    String directoryPath, {
    int maxDepth = 6,
  }) async {
    final root = Directory(directoryPath);
    if (!await root.exists()) {
      return [];
    }

    final existingBooks = await bookRepository.getAllBooks();
    final found = <DiscoverableBook>[];

    Future<void> walk(Directory dir, int depth) async {
      if (depth > maxDepth) return;

      await for (final entity in dir.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          if (_skipDirNames.contains(name)) continue;
          await walk(entity, depth + 1);
          continue;
        }

        if (entity is! File) continue;

        final ext = p.extension(entity.path).replaceAll('.', '').toLowerCase();
        if (!SupportedFormats.isSupported(ext)) continue;

        int sizeBytes = 0;
        try {
          sizeBytes = await entity.length();
        } catch (_) {}

        found.add(
          DiscoverableBook(
            path: entity.path,
            title: formatTitleFromPath(entity.path),
            format: ext,
            sizeBytes: sizeBytes,
            alreadyImported: _isAlreadyImported(entity.path, existingBooks),
          ),
        );
      }
    }

    await walk(root, 0);
    found.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return found;
  }

  /// Opens a folder picker, then scans for supported book files.
  /// Returns null if the user cancels the folder picker.
  Future<FolderScanResult?> pickFolderAndDiscoverBooks() async {
    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a folder with books',
    );
    if (directoryPath == null) {
      return null;
    }
    final books = await scanDirectoryForBooks(directoryPath);
    return FolderScanResult(folderPath: directoryPath, books: books);
  }

  Future<List<Book>> importFiles(List<String> sourcePaths) async {
    final importedBooks = <Book>[];
    for (final path in sourcePaths) {
      try {
        final book = await importFile(path);
        importedBooks.add(book);
      } catch (_) {
        if (sourcePaths.length == 1) rethrow;
      }
    }
    return importedBooks;
  }

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

    final book = Book()
      ..title = formatTitleFromPath(sourcePath)
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
    } else if (ext == 'cbz' || ext == 'cbr') {
      try {
        await ComicParser.extractPageImagePaths(
          book: book,
          bookRepository: bookRepository,
        );
      } catch (_) {}
    } else if (ext == 'mobi' || ext == 'azw3') {
      try {
        await MobiParser.extractChapters(
          bookId: book.id,
          filePath: targetPath,
          chapterRepository: chapterRepository,
        );
      } on DrmProtectedException catch (e) {
        try {
          await bookRepository.deleteBook(book.id);
        } catch (_) {}
        throw UnsupportedFormatException(e.message);
      } catch (_) {}
    }

    if (ext != 'cbz' && ext != 'cbr' && chunkingService != null) {
      unawaited(chunkingService!.chunkBook(book.id));
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
