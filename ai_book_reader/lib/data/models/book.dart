import 'package:isar/isar.dart';

part 'book.g.dart';

@collection
class Book {
  Id id = Isar.autoIncrement;

  late String title;
  String? author;

  /// Format type: 'pdf' | 'epub' | 'txt' | 'docx' | 'cbz' | 'cbr' | 'mobi' | 'azw3'
  late String format;

  /// Local path to the original imported file
  late String filePath;

  String? coverImagePath;

  late DateTime addedAt;
  DateTime? lastOpenedAt;

  /// Reading progress from 0.0 to 1.0
  double readingProgress = 0.0;
}
