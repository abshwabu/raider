import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/data/local/studio_artifact_repository.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/studio_artifact.dart';
import 'package:ai_book_reader/features/ai/provider/ai_provider.dart';
import 'package:ai_book_reader/features/ai/retrieval/retrieval_service.dart';
import 'package:ai_book_reader/features/ai/studio/studio_service.dart';

class _FakeAiProvider implements AiProvider {
  _FakeAiProvider(this.response);

  String response;
  int completeCalls = 0;

  @override
  Future<List<double>> embed(String text) async => List.filled(8, 0.1);

  @override
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    completeCalls++;
    yield response;
  }
}

void main() {
  late Isar isar;
  late Directory tempDir;
  late BookRepository bookRepo;
  late ChapterRepository chapterRepo;
  late ChunkRepository chunkRepo;
  late StudioArtifactRepository artifactRepo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('studio_service_test');
    isar = await Isar.open(
      [
        BookSchema,
        ChapterSchema,
        ChunkSchema,
        StudioArtifactSchema,
      ],
      directory: tempDir.path,
    );
    bookRepo = BookRepository(isar);
    chapterRepo = ChapterRepository(isar);
    chunkRepo = ChunkRepository(isar);
    artifactRepo = StudioArtifactRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<int> seedBook() async {
    final book = Book()
      ..title = 'Studio Book'
      ..format = 'txt'
      ..filePath = '${tempDir.path}/studio.txt'
      ..addedAt = DateTime.now();
    final bookId = await bookRepo.addBook(book);

    final chapter = Chapter()
      ..bookId = bookId
      ..title = 'Chapter One'
      ..order = 0
      ..content = 'Freedom is the core theme of this text.';
    await chapterRepo.addChapters(bookId, [chapter]);

    final chunk = Chunk()
      ..bookId = bookId
      ..chapterId = chapter.id
      ..text = 'Freedom is the core theme of this text. Justice follows.'
      ..orderInChapter = 0
      ..embedding = List.filled(8, 0.2);
    await chunkRepo.addChunks([chunk]);
    return bookId;
  }

  test('StudioArtifactRepository saves and lists artifacts', () async {
    final bookId = await seedBook();
    final artifact = StudioArtifact()
      ..bookId = bookId
      ..type = StudioArtifactType.quiz
      ..title = 'Saved Quiz'
      ..scope = StudioArtifactScope.book
      ..payloadJson = '{"title":"Saved Quiz","questions":[]}'
      ..createdAt = DateTime.now();

    final id = await artifactRepo.saveArtifact(artifact);
    expect(id, greaterThan(0));

    final all = await artifactRepo.getArtifactsForBook(bookId);
    expect(all.length, 1);
    expect(all.single.title, 'Saved Quiz');

    await artifactRepo.deleteArtifact(id);
    expect(await artifactRepo.getArtifactsForBook(bookId), isEmpty);
  });

  test('StudioService generates and persists quiz from model JSON', () async {
    final bookId = await seedBook();
    final fake = _FakeAiProvider('''
{
  "title": "Freedom Quiz",
  "questions": [
    {
      "question": "What is the core theme?",
      "choices": ["War", "Freedom", "Wealth", "Silence"],
      "correctIndex": 1,
      "explanation": "The excerpt states freedom is the core theme."
    }
  ]
}
''');

    final service = StudioService(
      bookRepository: bookRepo,
      chapterRepository: chapterRepo,
      chunkRepository: chunkRepo,
      artifactRepository: artifactRepo,
      retrievalService: RetrievalService(chunkRepo, fake),
      aiProvider: fake,
    );

    final artifact = await service.generate(
      bookId: bookId,
      type: StudioArtifactType.quiz,
    );

    expect(artifact.id, greaterThan(0));
    expect(artifact.type, StudioArtifactType.quiz);
    expect(artifact.title, 'Freedom Quiz');
    expect(artifact.payloadJson.contains('Freedom'), isTrue);
    expect(fake.completeCalls, 1);

    final saved = await artifactRepo.getArtifactsForBook(bookId);
    expect(saved.length, 1);
  });

  test('StudioService retries once when first response is invalid JSON', () async {
    final bookId = await seedBook();
    var call = 0;
    final provider = _RetryAiProvider(() {
      call++;
      if (call == 1) return 'broken';
      return '''
{
  "cards": [
    {"front": "Theme", "back": "Freedom"}
  ]
}
''';
    });

    final service = StudioService(
      bookRepository: bookRepo,
      chapterRepository: chapterRepo,
      chunkRepository: chunkRepo,
      artifactRepository: artifactRepo,
      retrievalService: RetrievalService(chunkRepo, provider),
      aiProvider: provider,
    );

    final artifact = await service.generate(
      bookId: bookId,
      type: StudioArtifactType.flashcards,
    );

    expect(artifact.type, StudioArtifactType.flashcards);
    expect(artifact.payloadJson.contains('Theme'), isTrue);
    expect(provider.completeCalls, 2);
  });
}

class _RetryAiProvider implements AiProvider {
  _RetryAiProvider(this.responseBuilder);

  final String Function() responseBuilder;
  int completeCalls = 0;

  @override
  Future<List<double>> embed(String text) async => List.filled(8, 0.1);

  @override
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    completeCalls++;
    yield responseBuilder();
  }
}
