import 'package:isar/isar.dart';

part 'chat_message.g.dart';

enum ChatRole { user, assistant }

@collection
class ChatMessage {
  Id id = Isar.autoIncrement;
  late int sessionId;

  @enumerated
  late ChatRole role;

  late String content;
  List<int> citedChunkIds = [];
  late DateTime createdAt;
}
