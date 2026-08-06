import 'package:isar/isar.dart';

part 'chunk.g.dart';

@collection
class Chunk {
  Id id = Isar.autoIncrement;
  late int bookId;
  late int chapterId;
  late String text;
  late int orderInChapter;
  List<double>? embedding;
}
