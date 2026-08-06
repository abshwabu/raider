import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../../core/utils/chapter_utils.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/chapter.dart';

class DocxParser {
  static Future<List<Chapter>> extractChapters({
    required int bookId,
    required String filePath,
    ChapterRepository? chapterRepository,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
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

    ArchiveFile? documentFile;
    ArchiveFile? stylesFile;

    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        documentFile = f;
      } else if (f.name == 'word/styles.xml') {
        stylesFile = f;
      }
    }

    if (documentFile == null) {
      return [];
    }

    final headingStyleIds = <String>{
      'heading1',
      'heading 1',
      'heading2',
      'heading 2',
      'title',
    };

    if (stylesFile != null) {
      try {
        final stylesContent = utf8.decode(stylesFile.content as List<int>);
        final stylesXml = XmlDocument.parse(stylesContent);
        for (final styleElem in stylesXml.findAllElements('w:style')) {
          final styleId = styleElem.getAttribute('w:styleId') ?? '';
          final nameElem = styleElem.findElements('w:name').firstOrNull;
          final nameVal = nameElem?.getAttribute('w:val') ?? '';

          if (styleId.toLowerCase().startsWith('heading') ||
              styleId.toLowerCase() == 'title' ||
              nameVal.toLowerCase().startsWith('heading') ||
              nameVal.toLowerCase() == 'title') {
            if (styleId.isNotEmpty) {
              headingStyleIds.add(styleId.toLowerCase());
            }
          }
        }
      } catch (_) {}
    }

    String docContent;
    try {
      docContent = utf8.decode(documentFile.content as List<int>);
    } catch (_) {
      docContent = latin1.decode(documentFile.content as List<int>);
    }

    XmlDocument documentXml;
    try {
      documentXml = XmlDocument.parse(docContent);
    } catch (_) {
      return [];
    }

    final paragraphs = documentXml.findAllElements('w:p');

    bool isHeadingParagraph(XmlElement pElem) {
      final pPr = pElem.findElements('w:pPr').firstOrNull;
      if (pPr == null) return false;
      final pStyle = pPr.findElements('w:pStyle').firstOrNull;
      if (pStyle == null) return false;
      final styleVal = pStyle.getAttribute('w:val');
      if (styleVal == null || styleVal.isEmpty) return false;

      final lowerVal = styleVal.toLowerCase();
      return headingStyleIds.contains(lowerVal) ||
          lowerVal.startsWith('heading') ||
          lowerVal == 'title';
    }

    String getParagraphText(XmlElement pElem) {
      final buffer = StringBuffer();
      for (final tElem in pElem.findAllElements('w:t')) {
        buffer.write(tElem.innerText);
      }
      return buffer.toString().trim();
    }

    final rawParagraphs = <_ParsedParagraph>[];
    bool hasHeadings = false;

    for (final p in paragraphs) {
      final text = getParagraphText(p);
      if (text.isEmpty) continue;
      final isHeading = isHeadingParagraph(p);
      if (isHeading) {
        hasHeadings = true;
      }
      rawParagraphs.add(_ParsedParagraph(text: text, isHeading: isHeading));
    }

    List<Chapter> chapters = [];

    if (hasHeadings) {
      String? currentTitle;
      final currentParagraphs = <String>[];
      int order = 1;

      void addChapter() {
        if (currentTitle != null || currentParagraphs.isNotEmpty) {
          final title = (currentTitle != null && currentTitle!.isNotEmpty)
              ? currentTitle!
              : 'Chapter $order';

          final contentBuffer = StringBuffer();
          if (currentTitle != null && currentTitle!.isNotEmpty) {
            contentBuffer.writeln('<h2>${htmlEscape.convert(currentTitle!)}</h2>');
          }
          for (final pText in currentParagraphs) {
            contentBuffer.writeln('<p>${htmlEscape.convert(pText)}</p>');
          }

          chapters.add(
            Chapter()
              ..bookId = bookId
              ..title = title
              ..order = order++
              ..content = contentBuffer.toString().trim(),
          );
          currentParagraphs.clear();
        }
      }

      for (final item in rawParagraphs) {
        if (item.isHeading) {
          addChapter();
          currentTitle = item.text;
        } else {
          currentParagraphs.add(item.text);
        }
      }
      addChapter();
    }

    if (chapters.isEmpty) {
      final fullText = rawParagraphs.map((p) => p.text).join('\n\n');
      if (fullText.trim().isNotEmpty) {
        chapters = chapterizeByWordCount(
          bookId: bookId,
          textContent: fullText,
          formatAsHtml: true,
        );
      }
    }

    if (chapterRepository != null && chapters.isNotEmpty) {
      await chapterRepository.addChapters(bookId, chapters);
    }

    return chapters;
  }
}

class _ParsedParagraph {
  final String text;
  final bool isHeading;

  _ParsedParagraph({required this.text, required this.isHeading});
}
