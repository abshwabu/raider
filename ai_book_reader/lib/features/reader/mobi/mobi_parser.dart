import 'dart:convert';
import 'dart:io';
import '../../../core/utils/chapter_utils.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/chapter.dart';

class DrmProtectedException implements Exception {
  final String message;
  DrmProtectedException([this.message = 'This file is copy-protected (DRM) and cannot be imported.']);

  @override
  String toString() => 'DrmProtectedException: $message';
}

class MobiParser {
  static List<int> decompressPalmDoc(List<int> input) {
    final output = <int>[];
    int i = 0;

    while (i < input.length) {
      final byte = input[i++];

      if (byte == 0x00) {
        output.add(0x00);
      } else if (byte >= 1 && byte <= 8) {
        final count = byte;
        for (int k = 0; k < count && i < input.length; k++) {
          output.add(input[i++]);
        }
      } else if (byte >= 9 && byte <= 0x7F) {
        output.add(byte);
      } else if (byte >= 0x80 && byte <= 0xBF) {
        if (i >= input.length) break;
        final nextByte = input[i++];
        final distance = ((byte & 0x3F) << 5) | (nextByte >> 3);
        final length = (nextByte & 0x07) + 3;

        for (int k = 0; k < length; k++) {
          if (output.length >= distance && distance > 0) {
            output.add(output[output.length - distance]);
          } else {
            output.add(0x20);
          }
        }
      } else if (byte >= 0xC0) {
        output.add(0x20);
        output.add(byte ^ 0x80);
      }
    }

    return output;
  }

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
    if (bytes.length < 78) {
      return [];
    }

    final numRecords = (bytes[76] << 8) | bytes[77];
    if (numRecords == 0 || bytes.length < 78 + numRecords * 8) {
      return [];
    }

    final recordOffsets = <int>[];
    for (int i = 0; i < numRecords; i++) {
      final offsetPos = 78 + i * 8;
      final offset = (bytes[offsetPos] << 24) |
          (bytes[offsetPos + 1] << 16) |
          (bytes[offsetPos + 2] << 8) |
          bytes[offsetPos + 3];
      recordOffsets.add(offset);
    }

    final rec0Offset = recordOffsets[0];
    if (rec0Offset + 16 > bytes.length) {
      return [];
    }

    final compression = (bytes[rec0Offset] << 8) | bytes[rec0Offset + 1];
    final textRecordCount = (bytes[rec0Offset + 8] << 8) | bytes[rec0Offset + 9];
    final encryptionType = (bytes[rec0Offset + 12] << 8) | bytes[rec0Offset + 13];

    if (encryptionType != 0) {
      throw DrmProtectedException('This file is copy-protected and cannot be imported. Try a DRM-free version.');
    }

    if (rec0Offset + 16 + 48 <= bytes.length) {
      final magic = String.fromCharCodes(bytes.sublist(rec0Offset + 16, rec0Offset + 20));
      if (magic == 'MOBI') {
        final drmOffset = (bytes[rec0Offset + 16 + 40] << 24) |
            (bytes[rec0Offset + 16 + 41] << 16) |
            (bytes[rec0Offset + 16 + 42] << 8) |
            bytes[rec0Offset + 16 + 43];
        final drmCount = (bytes[rec0Offset + 16 + 44] << 24) |
            (bytes[rec0Offset + 16 + 45] << 16) |
            (bytes[rec0Offset + 16 + 46] << 8) |
            bytes[rec0Offset + 16 + 47];

        if (drmCount != 0 && drmOffset != 0xFFFFFFFF) {
          throw DrmProtectedException('This file is copy-protected and cannot be imported. Try a DRM-free version.');
        }
      }
    }

    final allTextBytes = <int>[];
    final maxTextRecord = (textRecordCount > 0 && textRecordCount < numRecords)
        ? textRecordCount
        : numRecords - 1;

    for (int i = 1; i <= maxTextRecord; i++) {
      final start = recordOffsets[i];
      final end = (i + 1 < recordOffsets.length) ? recordOffsets[i + 1] : bytes.length;
      if (start >= bytes.length || start >= end) continue;

      final recordBytes = bytes.sublist(start, end);
      if (compression == 2) {
        allTextBytes.addAll(decompressPalmDoc(recordBytes));
      } else if (compression == 1) {
        allTextBytes.addAll(recordBytes);
      } else {
        allTextBytes.addAll(recordBytes);
      }
    }

    final rawHtml = utf8.decode(allTextBytes, allowMalformed: true);
    final chapters = <Chapter>[];

    final headingRegex = RegExp(
      r'<(h[1-3]|mbp:pagebreak)[^>]*>(.*?)</\1>|<mbp:pagebreak/?>',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = headingRegex.allMatches(rawHtml).toList();

    if (matches.isNotEmpty) {
      int order = 1;
      int lastPos = 0;
      String currentTitle = 'Chapter 1';

      for (int i = 0; i < matches.length; i++) {
        final match = matches[i];
        final matchStart = match.start;

        if (matchStart > lastPos) {
          final contentChunk = rawHtml.substring(lastPos, matchStart).trim();
          if (contentChunk.isNotEmpty) {
            chapters.add(
              Chapter()
                ..bookId = bookId
                ..title = currentTitle
                ..order = order++
                ..content = contentChunk,
            );
          }
        }

        final matchedTagText = match.group(0) ?? '';
        final cleanTitle = matchedTagText
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim();
        currentTitle = cleanTitle.isNotEmpty ? cleanTitle : 'Chapter $order';
        lastPos = match.end;
      }

      if (lastPos < rawHtml.length) {
        final contentChunk = rawHtml.substring(lastPos).trim();
        if (contentChunk.isNotEmpty) {
          chapters.add(
            Chapter()
              ..bookId = bookId
              ..title = currentTitle
              ..order = order++
              ..content = contentChunk,
          );
        }
      }
    }

    List<Chapter> finalChapters = chapters;

    if (finalChapters.length <= 1) {
      final plainText = rawHtml.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (plainText.isNotEmpty) {
        finalChapters = chapterizeByWordCount(
          bookId: bookId,
          textContent: plainText,
          formatAsHtml: true,
        );
      }
    }

    if (chapterRepository != null && finalChapters.isNotEmpty) {
      await chapterRepository.addChapters(bookId, finalChapters);
    }

    return finalChapters;
  }
}
