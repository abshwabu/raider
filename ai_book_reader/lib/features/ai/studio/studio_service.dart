import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/local/chunk_repository.dart';
import '../../../data/local/studio_artifact_repository.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/studio_artifact.dart';
import '../chat/prompt_builder.dart';
import '../provider/ai_provider.dart';
import '../provider/ai_provider_factory.dart';
import '../retrieval/retrieval_service.dart';
import 'studio_context_gatherer.dart';
import 'studio_payloads.dart';

final studioServiceProvider = Provider<StudioService>((ref) {
  return StudioService(
    bookRepository: ref.watch(bookRepositoryProvider),
    chapterRepository: ref.watch(chapterRepositoryProvider),
    chunkRepository: ref.watch(chunkRepositoryProvider),
    artifactRepository: ref.watch(studioArtifactRepositoryProvider),
    retrievalService: ref.watch(retrievalServiceProvider),
    aiProvider: ref.watch(aiProvider),
  );
});

class StudioService {
  final BookRepository bookRepository;
  final ChapterRepository chapterRepository;
  final ChunkRepository chunkRepository;
  final StudioArtifactRepository artifactRepository;
  final RetrievalService retrievalService;
  final AiProvider aiProvider;
  final PromptBuilder promptBuilder;
  final StudioContextGatherer contextGatherer;

  StudioService({
    required this.bookRepository,
    required this.chapterRepository,
    required this.chunkRepository,
    required this.artifactRepository,
    required this.retrievalService,
    required this.aiProvider,
    PromptBuilder? promptBuilder,
    StudioContextGatherer? contextGatherer,
  })  : promptBuilder = promptBuilder ?? PromptBuilder(),
        contextGatherer = contextGatherer ??
            StudioContextGatherer(
              chunkRepository: chunkRepository,
              retrievalService: retrievalService,
            );

  Future<StudioArtifact> generate({
    required int bookId,
    required StudioArtifactType type,
    int? chapterId,
  }) async {
    final book = await bookRepository.getBook(bookId);
    if (book == null) {
      throw Exception('Book not found for ID $bookId');
    }

    final scope = chapterId != null
        ? StudioArtifactScope.chapter
        : StudioArtifactScope.book;

    String? chapterTitle;
    if (chapterId != null) {
      final chapters = await chapterRepository.getChaptersForBook(bookId);
      for (final chapter in chapters) {
        if (chapter.id == chapterId) {
          chapterTitle = chapter.title;
          break;
        }
      }
    }

    final excerpts = await contextGatherer.gather(
      bookId: bookId,
      chapterId: chapterId,
    );
    if (excerpts.isEmpty) {
      throw Exception(
        'No text excerpts available for Studio. Open or re-import this book first.',
      );
    }

    final systemPrompt = promptBuilder.buildStudioSystemPrompt(
      book: book,
      type: type,
      scope: scope,
    );
    final userPrompt = promptBuilder.buildStudioUserPrompt(
      type: type,
      excerpts: excerpts,
      chapterTitle: chapterTitle,
    );

    var raw = await _complete(
      systemPrompt: systemPrompt,
      userMessage: userPrompt,
    );

    Map<String, dynamic> payload;
    try {
      payload = _parseAndValidate(type, raw);
    } catch (_) {
      // One repair retry with stricter instructions.
      raw = await _complete(
        systemPrompt: systemPrompt,
        userMessage: '''$userPrompt

Your previous response was invalid. Return ONLY valid JSON matching the required schema, with no markdown fences or commentary.''',
      );
      payload = _parseAndValidate(type, raw);
    }

    final title = _titleFor(type, payload, book.title, chapterTitle);
    final artifact = StudioArtifact()
      ..bookId = bookId
      ..type = type
      ..title = title
      ..scope = scope
      ..chapterId = chapterId
      ..payloadJson = jsonEncode(payload)
      ..createdAt = DateTime.now();

    final id = await artifactRepository.saveArtifact(artifact);
    artifact.id = id;
    return artifact;
  }

  Future<String> _complete({
    required String systemPrompt,
    required String userMessage,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in aiProvider.chatCompletion(
      systemPrompt: systemPrompt,
      history: const <ChatMessage>[],
      userMessage: userMessage,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  Map<String, dynamic> _parseAndValidate(
    StudioArtifactType type,
    String raw,
  ) {
    switch (type) {
      case StudioArtifactType.studyGuide:
        final guide = StudyGuidePayload.fromRaw(raw);
        if (guide.markdown.trim().isEmpty) {
          throw const FormatException('Study guide markdown was empty');
        }
        return {'markdown': guide.markdown};
      case StudioArtifactType.quiz:
        final quiz = QuizPayload.fromJson(decodeJsonObject(raw));
        if (quiz.questions.isEmpty) {
          throw const FormatException('Quiz had no questions');
        }
        return {
          'title': quiz.title,
          'questions': quiz.questions
              .map(
                (q) => {
                  'question': q.question,
                  'choices': q.choices,
                  'correctIndex': q.correctIndex,
                  'explanation': q.explanation,
                },
              )
              .toList(),
        };
      case StudioArtifactType.flashcards:
        final cards = FlashcardsPayload.fromJson(decodeJsonObject(raw));
        if (cards.cards.isEmpty) {
          throw const FormatException('Flashcards payload was empty');
        }
        return {
          'cards': cards.cards
              .map((c) => {'front': c.front, 'back': c.back})
              .toList(),
        };
      case StudioArtifactType.slides:
        final slides = SlidesPayload.fromJson(decodeJsonObject(raw));
        if (slides.slides.isEmpty) {
          throw const FormatException('Slides payload was empty');
        }
        return {
          'title': slides.title,
          'slides': slides.slides
              .map(
                (s) => {
                  'heading': s.heading,
                  'bullets': s.bullets,
                  if (s.speakerNote != null) 'speakerNote': s.speakerNote,
                },
              )
              .toList(),
        };
      case StudioArtifactType.mindMap:
        final mindMap = MindMapPayload.fromJson(decodeJsonObject(raw));
        if (mindMap.root.label.trim().isEmpty) {
          throw const FormatException('Mind map root label was empty');
        }
        return {
          'root': _mindMapNodeToJson(mindMap.root),
        };
    }
  }

  Map<String, dynamic> _mindMapNodeToJson(MindMapNode node) {
    return {
      'label': node.label,
      'children': node.children.map(_mindMapNodeToJson).toList(),
    };
  }

  String _titleFor(
    StudioArtifactType type,
    Map<String, dynamic> payload,
    String bookTitle,
    String? chapterTitle,
  ) {
    final scopeSuffix =
        chapterTitle != null && chapterTitle.isNotEmpty ? ' · $chapterTitle' : '';
    switch (type) {
      case StudioArtifactType.quiz:
        return ((payload['title'] as String?)?.trim().isNotEmpty ?? false)
            ? payload['title'] as String
            : 'Quiz$scopeSuffix';
      case StudioArtifactType.flashcards:
        return 'Flashcards$scopeSuffix';
      case StudioArtifactType.studyGuide:
        return 'Study guide$scopeSuffix';
      case StudioArtifactType.slides:
        return ((payload['title'] as String?)?.trim().isNotEmpty ?? false)
            ? payload['title'] as String
            : 'Slideshow$scopeSuffix';
      case StudioArtifactType.mindMap:
        final root = payload['root'];
        if (root is Map && (root['label'] as String?)?.trim().isNotEmpty == true) {
          return 'Mind map: ${root['label']}';
        }
        return 'Mind map · $bookTitle$scopeSuffix';
    }
  }
}
