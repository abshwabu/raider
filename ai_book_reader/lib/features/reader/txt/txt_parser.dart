import 'dart:convert';
import 'dart:io';
import '../../../core/utils/chapter_utils.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/chapter.dart';

class TxtParser {
  static Future<List<Chapter>> extractChapters({
    required int bookId,
    required String filePath,
    ChapterRepository? chapterRepository,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return [];
    }

    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (_) {
      final bytes = await file.readAsBytes();
      content = latin1.decode(bytes);
    }

    var chapters = <Chapter>[];
    final lines = content.split(RegExp(r'\r?\n'));

    final chapterHeaderRegex = RegExp(
      r'^\s*(chapter\s+(\d+|[ivxlcdm]+)|section\s+\d+|part\s+\d+)\b',
      caseSensitive: false,
    );

    List<String> currentChapterLines = [];
    String currentTitle = 'Chapter 1';
    int order = 1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      bool isHeader = false;
      if (trimmed.isNotEmpty) {
        if (chapterHeaderRegex.hasMatch(trimmed)) {
          isHeader = true;
        } else if (trimmed.length <= 40 &&
            RegExp(r'^[A-Z0-9\s\-_:]{3,40}$').hasMatch(trimmed) &&
            (i == 0 || lines[i - 1].trim().isEmpty) &&
            (i == lines.length - 1 || lines[i + 1].trim().isEmpty)) {
          isHeader = true;
        }
      }

      if (isHeader) {
        if (currentChapterLines.isNotEmpty) {
          final chapterText = currentChapterLines.join('\n').trim();
          if (chapterText.isNotEmpty) {
            chapters.add(
              Chapter()
                ..bookId = bookId
                ..title = currentTitle
                ..order = order++
                ..content = chapterText,
            );
          }
          currentChapterLines = [];
        }
        currentTitle = trimmed;
      } else {
        currentChapterLines.add(line);
      }
    }

    if (currentChapterLines.isNotEmpty) {
      final chapterText = currentChapterLines.join('\n').trim();
      if (chapterText.isNotEmpty) {
        chapters.add(
          Chapter()
            ..bookId = bookId
            ..title = currentTitle
            ..order = order++
            ..content = chapterText,
        );
      }
    }

    // Fallback: If heuristic detected 0 or 1 chapter for a large file, split every ~3000 words
    if (chapters.length <= 1) {
      chapters = chapterizeByWordCount(
        bookId: bookId,
        textContent: content,
      );
    }

    if (chapterRepository != null && chapters.isNotEmpty) {
      await chapterRepository.addChapters(bookId, chapters);
    }

    return chapters;
  }
}
