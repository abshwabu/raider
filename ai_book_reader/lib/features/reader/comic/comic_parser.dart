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
    '.jfif',
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

    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return [];
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final comicDir = Directory(p.join(appDocDir.path, 'comics', '${book.id}'));
    if (!await comicDir.exists()) {
      await comicDir.create(recursive: true);
    }

    List<({String name, List<int> bytes})> extractedEntries = [];

    // Attempt 1: Try decoding as ZIP archive (works for CBZ and zip-renamed CBR)
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive) {
        if (!f.isFile) continue;
        final name = f.name;
        final filename = p.basename(name);

        if (filename.startsWith('.') || name.contains('__MACOSX')) continue;

        final ext = p.extension(filename).toLowerCase();
        if (_imageExtensions.contains(ext)) {
          List<int> imageBytes;
          final dynamic content = f.content;
          if (content is List<int>) {
            imageBytes = content;
          } else if (content is InputStream) {
            imageBytes = content.toUint8List();
          } else {
            imageBytes = List<int>.from(content as Iterable);
          }
          extractedEntries.add((name: name, bytes: imageBytes));
        }
      }
    } catch (_) {
      // Zip decoding failed
    }

    // Attempt 2: Try parsing as RAR archive (RAR4 / RAR5) if ZIP yielded nothing
    if (extractedEntries.isEmpty) {
      try {
        final rarEntries = _RarParser.parse(bytes);
        for (final entry in rarEntries) {
          final filename = p.basename(entry.name);
          if (filename.startsWith('.') || entry.name.contains('__MACOSX')) continue;

          final ext = p.extension(filename).toLowerCase();
          if (_imageExtensions.contains(ext)) {
            extractedEntries.add((name: entry.name, bytes: entry.bytes));
          }
        }
      } catch (_) {}
    }

    // Attempt 3: Carve images directly from raw binary stream if still empty
    if (extractedEntries.isEmpty) {
      try {
        final carvedEntries = _carveImages(bytes);
        for (final entry in carvedEntries) {
          extractedEntries.add((name: entry.name, bytes: entry.bytes));
        }
      } catch (_) {}
    }

    if (extractedEntries.isEmpty) {
      return [];
    }

    extractedEntries.sort((a, b) => naturalCompare(a.name, b.name));

    final pagePaths = <String>[];
    for (int i = 0; i < extractedEntries.length; i++) {
      final entry = extractedEntries[i];
      var ext = p.extension(entry.name).toLowerCase();
      if (ext.isEmpty || !_imageExtensions.contains(ext)) {
        ext = '.jpg';
      }
      final pageNumberStr = (i + 1).toString().padLeft(3, '0');
      final targetPath = p.join(comicDir.path, 'page_$pageNumberStr$ext');

      await File(targetPath).writeAsBytes(entry.bytes);
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

  static List<({String name, List<int> bytes})> _carveImages(List<int> bytes, {String prefix = 'carved_page'}) {
    final entries = <({String name, List<int> bytes})>[];
    int count = 1;

    for (int i = 0; i < bytes.length - 8; i++) {
      // JPEG check: 0xFF 0xD8 0xFF
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF) {
        int end = -1;
        for (int j = i + 2; j < bytes.length - 1; j++) {
          if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
            end = j + 2;
            break;
          }
        }
        if (end != -1 && (end - i) >= 100) {
          final imgData = bytes.sublist(i, end);
          final numStr = count.toString().padLeft(3, '0');
          entries.add((name: '${prefix}_$numStr.jpg', bytes: imgData));
          count++;
          i = end - 1;
          continue;
        }
      }

      // PNG check: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      if (bytes[i] == 0x89 && bytes[i + 1] == 0x50 && bytes[i + 2] == 0x4E && bytes[i + 3] == 0x47 &&
          bytes[i + 4] == 0x0D && bytes[i + 5] == 0x0A && bytes[i + 6] == 0x1A && bytes[i + 7] == 0x0A) {
        int end = -1;
        for (int j = i + 8; j < bytes.length - 7; j++) {
          if (bytes[j] == 0x49 && bytes[j + 1] == 0x45 && bytes[j + 2] == 0x4E && bytes[j + 3] == 0x44) {
            end = j + 8;
            break;
          }
        }
        if (end != -1 && end <= bytes.length && (end - i) >= 60) {
          final imgData = bytes.sublist(i, end);
          final numStr = count.toString().padLeft(3, '0');
          entries.add((name: '${prefix}_$numStr.png', bytes: imgData));
          count++;
          i = end - 1;
          continue;
        }
      }

      // WEBP check: 'RIFF' + 4 bytes + 'WEBP'
      if (bytes[i] == 0x52 && bytes[i + 1] == 0x49 && bytes[i + 2] == 0x46 && bytes[i + 3] == 0x46) {
        if (i + 12 <= bytes.length &&
            bytes[i + 8] == 0x57 && bytes[i + 9] == 0x45 && bytes[i + 10] == 0x42 && bytes[i + 11] == 0x50) {
          int riffSize = bytes[i + 4] | (bytes[i + 5] << 8) | (bytes[i + 6] << 16) | (bytes[i + 7] << 24);
          int end = i + 8 + riffSize;
          if (end <= bytes.length && riffSize >= 30) {
            final imgData = bytes.sublist(i, end);
            final numStr = count.toString().padLeft(3, '0');
            entries.add((name: '${prefix}_$numStr.webp', bytes: imgData));
            count++;
            i = end - 1;
            continue;
          }
        }
      }
    }

    return entries;
  }
}

class _RarParser {
  static List<({String name, List<int> bytes})> parse(List<int> bytes) {
    if (bytes.length >= 7 &&
        bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 &&
        bytes[3] == 0x21 && bytes[4] == 0x1A && bytes[5] == 0x07 && bytes[6] == 0x00) {
      return _parseRar4(bytes);
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 &&
        bytes[3] == 0x21 && bytes[4] == 0x1A && bytes[5] == 0x07 && bytes[6] == 0x01 && bytes[7] == 0x00) {
      return _parseRar5(bytes);
    }
    return [];
  }

  static List<({String name, List<int> bytes})> _parseRar4(List<int> bytes) {
    final entries = <({String name, List<int> bytes})>[];
    int pos = 7;

    while (pos + 7 <= bytes.length) {
      int headType = bytes[pos + 2];
      int flags = bytes[pos + 3] | (bytes[pos + 4] << 8);
      int headSize = bytes[pos + 5] | (bytes[pos + 6] << 8);

      if (headSize < 7) break;
      if (pos + headSize > bytes.length) break;

      if (headType == 0x74) { // FILE_HEAD
        if (pos + 32 <= bytes.length) {
          int packSize = bytes[pos + 7] | (bytes[pos + 8] << 8) | (bytes[pos + 9] << 16) | (bytes[pos + 10] << 24);
          int method = bytes[pos + 25];
          int nameSize = bytes[pos + 26] | (bytes[pos + 27] << 8);

          int nameOffset = pos + 32;
          if ((flags & 0x0100) != 0) {
            if (pos + 40 <= bytes.length) {
              int highPackSize = bytes[pos + 32] | (bytes[pos + 33] << 8) | (bytes[pos + 34] << 16) | (bytes[pos + 35] << 24);
              packSize += highPackSize * 4294967296;
              nameOffset += 8;
            }
          }

          if (nameOffset + nameSize <= pos + headSize) {
            final fileName = String.fromCharCodes(bytes.sublist(nameOffset, nameOffset + nameSize));
            final dataStart = pos + headSize;
            if (dataStart + packSize <= bytes.length) {
              final fileData = bytes.sublist(dataStart, dataStart + packSize);
              if (method == 0x30) {
                entries.add((name: fileName, bytes: fileData));
              } else {
                final carved = ComicParser._carveImages(fileData, prefix: fileName);
                entries.addAll(carved);
              }
            }
          }
          pos += headSize + packSize;
          continue;
        }
      }

      if (headType == 0x7B) break;

      int packSize = 0;
      if ((flags & 0x8000) != 0 && pos + 11 <= bytes.length) {
        packSize = bytes[pos + 7] | (bytes[pos + 8] << 8) | (bytes[pos + 9] << 16) | (bytes[pos + 10] << 24);
      }
      pos += headSize + packSize;
    }

    return entries;
  }

  static List<({String name, List<int> bytes})> _parseRar5(List<int> bytes) {
    final entries = <({String name, List<int> bytes})>[];
    int pos = 8;

    while (pos < bytes.length) {
      if (pos + 4 > bytes.length) break;
      pos += 4; // skip crc32

      final (headerSize, len1) = _readVint(bytes, pos);
      if (len1 == 0 || pos + len1 > bytes.length) break;
      final bodyStart = pos + len1;
      final bodyEnd = bodyStart + headerSize;
      if (bodyEnd > bytes.length) break;

      pos = bodyStart;
      final (headerType, len2) = _readVint(bytes, pos);
      pos += len2;
      final (headerFlags, len3) = _readVint(bytes, pos);
      pos += len3;

      if (headerType == 5) break; // End of archive

      int packSize = 0;
      if (headerType == 2) { // File header
        if ((headerFlags & 1) != 0) {
          final (_, l) = _readVint(bytes, pos); pos += l;
        }
        if ((headerFlags & 2) != 0) {
          final (v, l) = _readVint(bytes, pos);
          packSize = v; pos += l;
        }
        final (_, lUnp) = _readVint(bytes, pos); pos += lUnp;
        final (_, lAttr) = _readVint(bytes, pos); pos += lAttr;

        if ((headerFlags & 4) != 0) pos += 4;
        if ((headerFlags & 8) != 0) pos += 4;

        final (compInfo, lComp) = _readVint(bytes, pos); pos += lComp;
        final method = (compInfo >> 7) & 7;

        final (_, lHost) = _readVint(bytes, pos); pos += lHost;
        final (nameLen, lName) = _readVint(bytes, pos); pos += lName;

        if (pos + nameLen <= bodyEnd) {
          final fileName = String.fromCharCodes(bytes.sublist(pos, pos + nameLen));
          final dataStart = bodyEnd;
          if (dataStart + packSize <= bytes.length) {
            final fileData = bytes.sublist(dataStart, dataStart + packSize);
            if (method == 0) {
              entries.add((name: fileName, bytes: fileData));
            } else {
              final carved = ComicParser._carveImages(fileData, prefix: fileName);
              entries.addAll(carved);
            }
          }
        }
      }

      pos = bodyEnd + packSize;
    }

    return entries;
  }

  static (int, int) _readVint(List<int> bytes, int offset) {
    int value = 0;
    int shift = 0;
    int bytesRead = 0;
    while (offset + bytesRead < bytes.length && bytesRead < 10) {
      int b = bytes[offset + bytesRead];
      bytesRead++;
      value |= (b & 0x7F) << shift;
      shift += 7;
      if ((b & 0x80) == 0) break;
    }
    return (value, bytesRead);
  }
}

