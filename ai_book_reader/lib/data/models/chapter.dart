import 'package:isar/isar.dart';

part 'chapter.g.dart';

@collection
class Chapter {
  Id id = Isar.autoIncrement;

  @Index()
  late int bookId;

  late String title;
  late int order;

  /// Normalized HTML or plain text content
  late String content;
}
