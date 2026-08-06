import '../../data/models/chapter.dart';

/// Splits raw text into synthetic chapters by word count when no natural chapter headings are found.
List<Chapter> chapterizeByWordCount({
  required int bookId,
  required String textContent,
  int wordsPerChapter = 3000,
  String titlePrefix = 'Section',
  bool formatAsHtml = false,
}) {
  final chapters = <Chapter>[];
  final words = textContent.split(RegExp(r'\s+'));
  if (words.isEmpty || textContent.trim().isEmpty) return chapters;

  int syntheticOrder = 1;
  for (int i = 0; i < words.length; i += wordsPerChapter) {
    final end = (i + wordsPerChapter < words.length) ? i + wordsPerChapter : words.length;
    final chunkText = words.sublist(i, end).join(' ').trim();

    if (chunkText.isNotEmpty) {
      String finalContent = chunkText;
      if (formatAsHtml) {
        final paragraphs = chunkText
            .split(RegExp(r'\r?\n\s*\r?\n|\r?\n'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty);
        if (paragraphs.isNotEmpty) {
          finalContent = paragraphs.map((p) => '<p>$p</p>').join('\n');
        } else {
          finalContent = '<p>$chunkText</p>';
        }
      }

      chapters.add(
        Chapter()
          ..bookId = bookId
          ..title = '$titlePrefix $syntheticOrder (Words ${i + 1}–$end)'
          ..order = syntheticOrder++
          ..content = finalContent,
      );
    }
  }
  return chapters;
}
