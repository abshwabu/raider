import 'dart:io';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/chapter.dart';

class EpubParser {
  static Future<List<Chapter>> extractChapters({
    required int bookId,
    required String filePath,
    ChapterRepository? chapterRepository,
    BookRepository? bookRepository,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return [];
    }

    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    // 1. Extract cover image if present
    if (epubBook.CoverImage != null && bookRepository != null) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory(p.join(appDocDir.path, 'covers'));
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }
        final coverPath = p.join(coversDir.path, '${bookId}_cover.png');
        final pngBytes = img.encodePng(epubBook.CoverImage!);
        await File(coverPath).writeAsBytes(pngBytes);

        final book = await bookRepository.getBook(bookId);
        if (book != null) {
          book.coverImagePath = coverPath;
          await bookRepository.addBook(book);
        }
      } catch (_) {}
    }

    // 2. Extract chapters from TOC/Spine
    final chapters = <Chapter>[];
    if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
      _flattenEpubChapters(epubBook.Chapters!, chapters, bookId);
    }

    // 3. Fallback: Parse from Content.Html manifest items if TOC chapters are empty
    if (chapters.isEmpty && epubBook.Content?.Html != null) {
      int order = 1;
      for (final htmlFile in epubBook.Content!.Html!.values) {
        final content = htmlFile.Content;
        if (content != null && content.trim().isNotEmpty) {
          chapters.add(
            Chapter()
              ..bookId = bookId
              ..title = 'Section $order'
              ..order = order++
              ..content = content,
          );
        }
      }
    }

    if (chapterRepository != null && chapters.isNotEmpty) {
      await chapterRepository.addChapters(bookId, chapters);
    }

    return chapters;
  }

  static void _flattenEpubChapters(
    List<EpubChapter> epubChapters,
    List<Chapter> result,
    int bookId, {
    String prefix = '',
  }) {
    for (final ch in epubChapters) {
      final titleText = ch.Title?.trim();
      final title = (titleText != null && titleText.isNotEmpty)
          ? titleText
          : 'Chapter ${result.length + 1}';
      final fullTitle = prefix.isEmpty ? title : '$prefix - $title';

      String html = ch.HtmlContent ?? '';
      if (html.trim().isEmpty && ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        html = ch.SubChapters!
            .map((s) => s.HtmlContent ?? '')
            .where((s) => s.trim().isNotEmpty)
            .join('\n<hr/>\n');
      }

      if (html.trim().isNotEmpty) {
        result.add(
          Chapter()
            ..bookId = bookId
            ..title = fullTitle
            ..order = result.length + 1
            ..content = html,
        );
      }

      if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        _flattenEpubChapters(
          ch.SubChapters!,
          result,
          bookId,
          prefix: fullTitle,
        );
      }
    }
  }
}
