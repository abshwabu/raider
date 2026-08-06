import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/models/book.dart';

class ComicParser {
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
  };

  /// Natural numeric string comparison (e.g., page2.jpg before page10.jpg)
  static int naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+|\D+)');
    final matchesA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
    final matchesB = regExp.allMatches(b).map((m) => m.group(0)!).toList();

    final minLength = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;

    for (int i = 0; i < minLength; i++) {
      final chunkA = matchesA[i];
      final chunkB = matchesB[i];

      final numA = int.tryParse(chunkA);
      final numB = int.tryParse(chunkB);

      if (numA != null && numB != null) {
        if (numA != numB) {
          return numA.compareTo(numB);
        }
      } else {
        final comp = chunkA.toLowerCase().compareTo(chunkB.toLowerCase());
        if (comp != 0) {
          return comp;
        }
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  static Future<List<String>> extractPageImagePaths({
    required Book book,
    BookRepository? bookRepository,
  }) async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      return [];
    }

    final format = book.format.toLowerCase();

    // CBR (RAR archive) pure-Dart extraction is unreliable/unsupported
    if (format == 'cbr') {
      return [];
    }

    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return [];
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return [];
    }

    final imageFiles = <ArchiveFile>[];
    for (final f in archive) {
      if (!f.isFile) continue;
      final name = f.name;
      final filename = p.basename(name);

      // Skip OS metadata / hidden files
      if (filename.startsWith('.') || name.contains('__MACOSX')) continue;

      final ext = p.extension(filename).toLowerCase();
      if (_imageExtensions.contains(ext)) {
        imageFiles.add(f);
      }
    }

    imageFiles.sort((a, b) => naturalCompare(a.name, b.name));

    if (imageFiles.isEmpty) {
      return [];
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final comicDir = Directory(p.join(appDocDir.path, 'comics', '${book.id}'));
    if (!await comicDir.exists()) {
      await comicDir.create(recursive: true);
    }

    final pagePaths = <String>[];
    for (int i = 0; i < imageFiles.length; i++) {
      final imgFile = imageFiles[i];
      final ext = p.extension(imgFile.name).toLowerCase();
      final pageNumberStr = (i + 1).toString().padLeft(3, '0');
      final targetPath = p.join(comicDir.path, 'page_$pageNumberStr$ext');

      final content = imgFile.content as List<int>;
      await File(targetPath).writeAsBytes(content);
      pagePaths.add(targetPath);
    }

    book.pageImagePaths = pagePaths;
    if ((book.coverImagePath == null || book.coverImagePath!.isEmpty) && pagePaths.isNotEmpty) {
      book.coverImagePath = pagePaths.first;
    }

    if (bookRepository != null) {
      await bookRepository.updateBook(book);
    }

    return pagePaths;
  }
}
