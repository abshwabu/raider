import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import 'isar_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return ChatRepository(isar);
});

class ChatRepository {
  final Isar isar;

  ChatRepository(this.isar);

  Future<ChatSession> getOrCreateSession(int bookId) async {
    final existingSession = await isar.chatSessions
        .filter()
        .bookIdEqualTo(bookId)
        .findFirst();

    if (existingSession != null) {
      return existingSession;
    }

    final newSession = ChatSession()
      ..bookId = bookId
      ..createdAt = DateTime.now();

    await isar.writeTxn(() async {
      final id = await isar.chatSessions.put(newSession);
      newSession.id = id;
    });

    return newSession;
  }

  Future<List<ChatMessage>> getMessages(int sessionId) async {
    return await isar.chatMessages
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByCreatedAt()
        .findAll();
  }

  Future<void> addMessage(ChatMessage message) async {
    await isar.writeTxn(() async {
      await isar.chatMessages.put(message);
    });
  }
}
