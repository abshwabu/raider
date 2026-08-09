import 'package:isar/isar.dart';

part 'annotation.g.dart';

enum AnnotationColor {
  yellow,
  green,
  blue,
  pink,
}

@collection
class Annotation {
  Id id = Isar.autoIncrement;

  @Index()
  late int bookId;

  @Index()
  late int chapterId;

  late String selectedText;
  late int startOffset;
  late int endOffset;

  @enumerated
  late AnnotationColor color;

  String? comment;
  late DateTime createdAt;
  late DateTime updatedAt;
}
