import 'package:isar/isar.dart';

part 'chat_session.g.dart';

@collection
class ChatSession {
  Id id = Isar.autoIncrement;
  late int bookId;
  late DateTime createdAt;
}
