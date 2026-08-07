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

  static String? extensionOf(String filePath) {
    final name = p.basename(filePath);
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot >= name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase().trim();
  }

  static String normalizeFsPath(String rawPath) {
    var path = rawPath.trim();
    if (path.startsWith('file://')) {
      path = Uri.parse(path).toFilePath();
    }
    return p.normalize(path);
  }

  bool _isAlreadyImported(String sourcePath, List<Book> existingBooks) {
    final basename = p.basename(sourcePath);
    return existingBooks.any((book) {
      final storedName = p.basename(book.filePath);
      return storedName == basename || storedName.endsWith('_$basename');
    });
  }

  Future<DiscoverableBook?> _toDiscoverableBook(
    String sourcePath,
    List<Book> existingBooks,
  ) async {
    final path = normalizeFsPath(sourcePath);
    final ext = extensionOf(path);
    if (ext == null || !SupportedFormats.isSupported(ext)) {
      return null;
    }

    int sizeBytes = 0;
    try {
      final file = File(path);
      if (await file.exists()) {
        sizeBytes = await file.length();
      }
    } catch (_) {}

    return DiscoverableBook(
      path: path,
      title: formatTitleFromPath(path),
      format: ext,
      sizeBytes: sizeBytes,
      alreadyImported: _isAlreadyImported(path, existingBooks),
    );
  }

  /// Recursively finds supported book files under [directoryPath].
  Future<List<DiscoverableBook>> scanDirectoryForBooks(
    String directoryPath, {
    int maxDepth = 8,
  }) async {
    final rootPath = normalizeFsPath(directoryPath);
    final root = Directory(rootPath);
    if (!await root.exists()) {
      return [];
    }

    final existingBooks = await bookRepository.getAllBooks();
    final found = <DiscoverableBook>[];
    final rootParts = p.split(rootPath);

    try {
      await for (final entity in root.list(recursive: true, followLinks: true)) {
        final parts = p.split(entity.path);
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;

        // Skip known noisy directories under the chosen root only.
        final relativeParts = parts.length > rootParts.length
            ? parts.sublist(rootParts.length)
            : const <String>[];
        if (relativeParts.any(_skipDirNames.contains)) continue;

        // Limit how deep we walk relative to the chosen root.
        final depth = parts.length - rootParts.length;
        if (depth > maxDepth) continue;

        final isFile = await FileSystemEntity.isFile(entity.path);
        if (!isFile) continue;

        final book = await _toDiscoverableBook(entity.path, existingBooks);
        if (book != null) {
          found.add(book);
        }
      }
    } on FileSystemException {
      // Common on Android scoped storage / sandboxed folders.
      return found;
    }

    found.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return found;
  }

  /// Opens a multi-select dialog filtered to supported book types.
  /// This is the reliable cross-platform way to "see available books".
  Future<FolderScanResult?> pickSupportedBooks() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: SupportedFormats.extensions,
      dialogTitle: 'Select books to add',
    );

    if (result == null) {
      return null;
    }

    final existingBooks = await bookRepository.getAllBooks();
    final books = <DiscoverableBook>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null || path.trim().isEmpty) continue;
      final book = await _toDiscoverableBook(path, existingBooks);
      if (book != null) {
        books.add(book);
      }
    }

    books.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final folderPath = books.isEmpty ? 'selection' : p.dirname(books.first.path);
    return FolderScanResult(folderPath: folderPath, books: books);
  }

  /// Opens a folder picker and scans for supported books.
  /// If the OS won't let us list the folder (common on Android), falls back to
  /// a multi-select file picker filtered to supported types.
  Future<FolderScanResult?> pickFolderAndDiscoverBooks({
    bool allowFilePickerFallback = true,
  }) async {
    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a folder with books',
    );
    if (directoryPath == null) {
      return null;
    }

    final normalized = normalizeFsPath(directoryPath);
    final books = await scanDirectoryForBooks(normalized);
    if (books.isNotEmpty) {
      return FolderScanResult(folderPath: normalized, books: books);
    }

    if (!allowFilePickerFallback) {
      return FolderScanResult(folderPath: normalized, books: const []);
    }

    // Folder path may be unreadable (scoped storage / portals). Let the user
    // pick supported files from that location via the system file dialog.
    final fallback = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: SupportedFormats.extensions,
      initialDirectory: normalized,
      dialogTitle: 'Select books from folder',
    );
    if (fallback == null) {
      return FolderScanResult(folderPath: normalized, books: const []);
    }

    final existingBooks = await bookRepository.getAllBooks();
    final discovered = <DiscoverableBook>[];
    for (final file in fallback.files) {
      final path = file.path;
      if (path == null || path.trim().isEmpty) continue;
      final book = await _toDiscoverableBook(path, existingBooks);
      if (book != null) {
        discovered.add(book);
      }
    }
    discovered.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return FolderScanResult(folderPath: normalized, books: discovered);
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

    final ext = extensionOf(sourcePath);
    if (ext == null || !SupportedFormats.isSupported(ext)) {
      throw UnsupportedFormatException('Extension .${ext ?? '?'} is not supported');
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
