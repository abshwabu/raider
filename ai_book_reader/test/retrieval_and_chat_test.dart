import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/chat_session.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/data/local/chat_repository.dart';
import 'package:ai_book_reader/features/ai/provider/ai_provider.dart';
import 'package:ai_book_reader/features/ai/retrieval/retrieval_service.dart';
import 'package:ai_book_reader/features/ai/chat/prompt_builder.dart';
import 'package:ai_book_reader/features/ai/chat/chat_service.dart';

class MockAiProvider implements AiProvider {
  @override
  Future<List<double>> embed(String text) async {
    // Return distinct embeddings based on text content
    if (text.contains('dragon')) return [1.0, 0.0, 0.0];
    if (text.contains('star')) return [0.0, 1.0, 0.0];
    return [0.5, 0.5, 0.0];
  }

  @override
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    yield 'Dragons are magical ';
    yield 'creatures described in chapter 1.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late BookRepository bookRepo;
  late ChunkRepository chunkRepo;
  late ChatRepository chatRepo;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retrieval_chat_test');
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
    bookRepo = BookRepository(isar);
    chunkRepo = ChunkRepository(isar);
    chatRepo = ChatRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RetrievalService & Cosine Similarity', () {
    test('cosineSimilarity computes vector dot product similarity', () {
      expect(RetrievalService.cosineSimilarity([1.0, 0.0], [1.0, 0.0]), closeTo(1.0, 0.0001));
      expect(RetrievalService.cosineSimilarity([1.0, 0.0], [0.0, 1.0]), closeTo(0.0, 0.0001));
    });

    test('throws EmbeddingsNotReadyException when no chunks have embeddings', () async {
      const bookId = 10;
      final mockProvider = MockAiProvider();
      final retrievalService = RetrievalService(chunkRepo, mockProvider);

      await chunkRepo.addChunks([
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'Unembedded chunk'
          ..orderInChapter = 1
          ..embedding = null,
      ]);

      expect(
        () => retrievalService.retrieveRelevantChunks(
          bookId: bookId,
          question: 'What is a dragon?',
        ),
        throwsA(isA<EmbeddingsNotReadyException>()),
      );
    });

    test('retrieves top-K chunks sorted by relevance', () async {
      const bookId = 20;
      final mockProvider = MockAiProvider();
      final retrievalService = RetrievalService(chunkRepo, mockProvider);

      await chunkRepo.addChunks([
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'Excerpt about stars in the night sky'
          ..orderInChapter = 1
          ..embedding = [0.0, 1.0, 0.0],
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'Excerpt about fire-breathing dragons'
          ..orderInChapter = 2
          ..embedding = [1.0, 0.0, 0.0],
      ]);

      final relevant = await retrievalService.retrieveRelevantChunks(
        bookId: bookId,
        question: 'Tell me about dragons',
        topK: 1,
      );

      expect(relevant.length, equals(1));
      expect(relevant.first.text, contains('dragons'));
    });
  });

  group('PromptBuilder', () {
    final builder = PromptBuilder();

    test('builds system prompt constraining model to excerpts', () {
      final book = Book()
        ..title = 'The Hobbit'
        ..author = 'J.R.R. Tolkien'
        ..format = 'epub'
        ..filePath = '/test.epub'
        ..addedAt = DateTime.now();

      final systemPrompt = builder.buildSystemPrompt(book: book);

      expect(systemPrompt, contains('The Hobbit'));
      expect(systemPrompt, contains('J.R.R. Tolkien'));
      expect(systemPrompt, contains('ONLY on the provided book excerpts'));
      expect(systemPrompt, contains("I don't have enough information"));
    });

    test('builds user turn with formatted chunk context', () {
      final chunks = [
        Chunk()
          ..id = 101
          ..bookId = 1
          ..chapterId = 5
          ..text = 'In a hole in the ground there lived a hobbit.'
          ..orderInChapter = 1,
      ];

      final userTurn = builder.buildUserTurnWithContext(
        question: 'Where did the hobbit live?',
        retrievedChunks: chunks,
      );

      expect(userTurn, contains('[Excerpt 1 | Chunk ID: 101 | Chapter ID: 5]'));
      expect(userTurn, contains('In a hole in the ground there lived a hobbit.'));
      expect(userTurn, contains('Where did the hobbit live?'));
    });
  });

  group('ChatService', () {
    test('sendMessage retrieves chunks, streams response, and persists chat messages with citedChunkIds', () async {
      final mockProvider = MockAiProvider();
      final retrievalService = RetrievalService(chunkRepo, mockProvider);

      final chatService = ChatService(
        bookRepository: bookRepo,
        chatRepository: chatRepo,
        retrievalService: retrievalService,
        aiProvider: mockProvider,
      );

      final book = Book()
        ..title = 'Fantasy Realm'
        ..format = 'txt'
        ..filePath = '/fantasy.txt'
        ..addedAt = DateTime.now();

      final bookId = await bookRepo.addBook(book);

      await chunkRepo.addChunks([
        Chunk()
          ..bookId = bookId
          ..chapterId = 1
          ..text = 'Ancient dragons guard the mountain pass.'
          ..orderInChapter = 1
          ..embedding = [1.0, 0.0, 0.0],
      ]);

      final streamedChunks = <String>[];
      await for (final chunkText in chatService.sendMessage(
        bookId: bookId,
        question: 'What guards the mountain?',
      )) {
        streamedChunks.add(chunkText);
      }

      expect(streamedChunks.join(), equals('Dragons are magical creatures described in chapter 1.'));

      final session = await chatRepo.getOrCreateSession(bookId);
      final messages = await chatRepo.getMessages(session.id);

      expect(messages.length, equals(2));
      expect(messages[0].role, equals(ChatRole.user));
      expect(messages[0].content, equals('What guards the mountain?'));

      expect(messages[1].role, equals(ChatRole.assistant));
      expect(messages[1].content, equals('Dragons are magical creatures described in chapter 1.'));
      expect(messages[1].citedChunkIds, isNotEmpty);
    });
  });
}
