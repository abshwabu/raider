import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/chat_session.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/data/local/chat_repository.dart';
import 'package:ai_book_reader/data/local/ai_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late ChunkRepository chunkRepo;
  late ChatRepository chatRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_models_test');
    isar = await Isar.open(
      [
        BookSchema,
        ChapterSchema,
        ChunkSchema,
        ChatSessionSchema,
        ChatMessageSchema,
      ],
      directory: tempDir.path,
    );
    chunkRepo = ChunkRepository(isar);
    chatRepo = ChatRepository(isar);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ChunkRepository', () {
    test('addChunks, getChunksForBook, and hasEmbeddings', () async {
      const bookId = 42;
      expect(await chunkRepo.hasEmbeddings(bookId), isFalse);

      final chunks = [
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'Second chunk of text'
          ..orderInChapter = 2,
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'First chunk of text'
          ..orderInChapter = 1,
      ];

      await chunkRepo.addChunks(chunks);

      final fetched = await chunkRepo.getChunksForBook(bookId);
      expect(fetched.length, equals(2));
      expect(fetched[0].text, equals('First chunk of text'));
      expect(fetched[1].text, equals('Second chunk of text'));
      expect(await chunkRepo.hasEmbeddings(bookId), isFalse);

      final chunkToUpdate = fetched[0];
      await chunkRepo.updateEmbedding(chunkToUpdate.id, [0.1, 0.2, 0.3]);

      expect(await chunkRepo.hasEmbeddings(bookId), isTrue);

      final updatedChunks = await chunkRepo.getChunksForBook(bookId);
      final updated = updatedChunks.firstWhere((c) => c.id == chunkToUpdate.id);
      expect(updated.embedding, equals([0.1, 0.2, 0.3]));
    });
  });

  group('ChatRepository', () {
    test('getOrCreateSession, getMessages, and addMessage', () async {
      const bookId = 100;
      final session1 = await chatRepo.getOrCreateSession(bookId);
      expect(session1.id, greaterThan(0));
      expect(session1.bookId, equals(bookId));

      final session2 = await chatRepo.getOrCreateSession(bookId);
      expect(session2.id, equals(session1.id));

      final userMessage = ChatMessage()
        ..sessionId = session1.id
        ..role = ChatRole.user
        ..content = 'What is the theme of this book?'
        ..createdAt = DateTime.now();

      await chatRepo.addMessage(userMessage);

      final assistantMessage = ChatMessage()
        ..sessionId = session1.id
        ..role = ChatRole.assistant
        ..content = 'The theme revolves around courage and friendship.'
        ..citedChunkIds = [1, 2]
        ..createdAt = DateTime.now().add(const Duration(milliseconds: 100));

      await chatRepo.addMessage(assistantMessage);

      final messages = await chatRepo.getMessages(session1.id);
      expect(messages.length, equals(2));

      expect(messages[0].role, equals(ChatRole.user));
      expect(messages[0].content, equals('What is the theme of this book?'));
      expect(messages[0].citedChunkIds, isEmpty);

      expect(messages[1].role, equals(ChatRole.assistant));
      expect(messages[1].content, equals('The theme revolves around courage and friendship.'));
      expect(messages[1].citedChunkIds, equals([1, 2]));
    });
  });

  group('AiSettingsService', () {
    test('tier round-trip and secure storage BYOK key separation', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const mockStorage = FlutterSecureStorage();

      final settingsService = AiSettingsService(
        sharedPreferences: prefs,
        secureStorage: mockStorage,
      );

      expect(await settingsService.getAiTier(), equals('free'));
      await settingsService.setAiTier('premium');
      expect(await settingsService.getAiTier(), equals('premium'));

      expect(await settingsService.getByokProvider(), equals('gemini'));
      await settingsService.setByokProvider('gemini');
      expect(await settingsService.getByokProvider(), equals('gemini'));

      expect(await settingsService.getByokKey(), isNull);
      await settingsService.setByokKey('test_secret_api_key_123');
      expect(await settingsService.getByokKey(), equals('test_secret_api_key_123'));

      // Verify BYOK key is NOT in SharedPreferences
      expect(prefs.getKeys().contains('byok_gemini_api_key'), isFalse);
      expect(prefs.getString('byok_gemini_api_key'), isNull);

      await settingsService.clearByokKey();
      expect(await settingsService.getByokKey(), isNull);
    });
  });
}
