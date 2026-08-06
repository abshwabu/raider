import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/chat_session.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/data/local/ai_settings_service.dart';
import 'package:ai_book_reader/features/ai/provider/ai_provider.dart';
import 'package:ai_book_reader/features/ai/provider/gemini_direct_provider.dart';
import 'package:ai_book_reader/features/ai/provider/ai_provider_factory.dart';
import 'package:ai_book_reader/features/ai/embedding/embedding_service.dart';

class MockAiProvider implements AiProvider {
  int embedCallCount = 0;

  @override
  Future<List<double>> embed(String text) async {
    embedCallCount++;
    return [0.1, 0.2, 0.3, 0.4];
  }

  @override
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    yield 'Response chunk 1 ';
    yield 'Response chunk 2';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late ChunkRepository chunkRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('embedding_test');
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
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('GeminiDirectProvider & Exceptions', () {
    test('throws NoApiKeyException cleanly when key is missing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsService = AiSettingsService(sharedPreferences: prefs);
      final provider = GeminiDirectProvider(settingsService);

      expect(() => provider.embed('test'), throwsA(isA<NoApiKeyException>()));
    });
  });

  group('AiProviderFactory', () {
    test('returns GeminiDirectProvider for free tier and throws UnimplementedError for premium', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsService = AiSettingsService(sharedPreferences: prefs);

      final provider = AiProviderFactory.create(settingsService);
      expect(provider, isA<GeminiDirectProvider>());

      await settingsService.setAiTier('premium');
      expect(
        () async => await AiProviderFactory.createAsync(settingsService),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('EmbeddingService Lazy Embedding Generation', () {
    test('populates all chunk embeddings and skips duplicate calls on repeat run', () async {
      const bookId = 42;
      final mockProvider = MockAiProvider();
      final embeddingService = EmbeddingService(chunkRepo, mockProvider);

      // Add test chunks
      await chunkRepo.addChunks([
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'First chunk for testing'
          ..orderInChapter = 1,
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'Second chunk for testing'
          ..orderInChapter = 2,
      ]);

      expect(await chunkRepo.hasEmbeddings(bookId), isFalse);

      final progressReports = <(int, int)>[];
      await embeddingService.ensureEmbeddingsGenerated(
        bookId,
        onProgress: (current, total) {
          progressReports.add((current, total));
        },
      );

      expect(mockProvider.embedCallCount, equals(2));
      expect(await chunkRepo.hasEmbeddings(bookId), isTrue);
      expect(progressReports, equals([(1, 2), (2, 2)]));

      final chunks = await chunkRepo.getChunksForBook(bookId);
      for (final chunk in chunks) {
        expect(chunk.embedding, equals([0.1, 0.2, 0.3, 0.4]));
      }

      // Repeat call on same book -> should do 0 API calls
      await embeddingService.ensureEmbeddingsGenerated(bookId);
      expect(mockProvider.embedCallCount, equals(2)); // Still 2, no extra API calls!
    });
  });
}
