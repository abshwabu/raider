import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/chapter.dart';

class _BookmarkInfo {
  final String title;
  final int pageIndex;
  _BookmarkInfo(this.title, this.pageIndex);
}

class PdfParser {
  static Future<List<Chapter>> extractChapters({
    required int bookId,
    required String filePath,
    ChapterRepository? chapterRepository,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return [];
    }

    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final totalPages = document.pages.count;

    if (totalPages == 0) {
      document.dispose();
      return [];
    }

    final chapters = <Chapter>[];
    final extractor = PdfTextExtractor(document);

    final bookmarks = document.bookmarks;

    if (bookmarks.count > 0) {
      final bookmarkList = <_BookmarkInfo>[];
      for (int i = 0; i < bookmarks.count; i++) {
        final bookmark = bookmarks[i];
        final page = bookmark.destination?.page;
        int pageIndex = 0;
        if (page != null) {
          pageIndex = document.pages.indexOf(page);
          if (pageIndex < 0) pageIndex = 0;
        }
        bookmarkList.add(_BookmarkInfo(
          bookmark.title.isNotEmpty ? bookmark.title : 'Chapter ${i + 1}',
          pageIndex,
        ));
      }

      bookmarkList.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

      for (int i = 0; i < bookmarkList.length; i++) {
        final current = bookmarkList[i];
        final startPage = current.pageIndex;
        final endPage = (i < bookmarkList.length - 1)
            ? (bookmarkList[i + 1].pageIndex - 1).clamp(startPage, totalPages - 1)
            : totalPages - 1;

        String extractedText = '';
        try {
          extractedText = extractor.extractText(
            startPageIndex: startPage,
            endPageIndex: endPage,
          );
        } catch (_) {
          extractedText = '';
        }

        chapters.add(
          Chapter()
            ..bookId = bookId
            ..title = '${current.title} (p. ${startPage + 1})'
            ..order = i + 1
            ..content = extractedText.isNotEmpty
                ? extractedText
                : 'Pages ${startPage + 1} to ${endPage + 1}',
        );
      }
    }

    // Fallback if no bookmarks found or empty result
    if (chapters.isEmpty) {
      const pagesPerChapter = 10;
      int order = 1;
      for (int start = 0; start < totalPages; start += pagesPerChapter) {
        final end = (start + pagesPerChapter - 1).clamp(0, totalPages - 1);
        String extractedText = '';
        try {
          extractedText = extractor.extractText(
            startPageIndex: start,
            endPageIndex: end,
          );
        } catch (_) {
          extractedText = '';
        }

        chapters.add(
          Chapter()
            ..bookId = bookId
            ..title = 'Pages ${start + 1}–${end + 1}'
            ..order = order++
            ..content = extractedText.isNotEmpty
                ? extractedText
                : 'Content for pages ${start + 1} to ${end + 1}',
        );
      }
    }

    document.dispose();

    if (chapterRepository != null && chapters.isNotEmpty) {
      await chapterRepository.addChapters(bookId, chapters);
    }

    return chapters;
  }
}
