import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/chat_repository.dart';
import '../../../data/models/chat_message.dart';
import '../provider/ai_provider.dart';
import '../provider/ai_provider_factory.dart';
import '../retrieval/retrieval_service.dart';
import 'prompt_builder.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final retrievalService = ref.watch(retrievalServiceProvider);
  final provider = ref.watch(aiProvider);
  return ChatService(
    bookRepository: bookRepo,
    chatRepository: chatRepo,
    retrievalService: retrievalService,
    aiProvider: provider,
  );
});

class ChatService {
  final BookRepository bookRepository;
  final ChatRepository chatRepository;
  final RetrievalService retrievalService;
  final AiProvider aiProvider;
  final PromptBuilder promptBuilder;

  ChatService({
    required this.bookRepository,
    required this.chatRepository,
    required this.retrievalService,
    required this.aiProvider,
    PromptBuilder? promptBuilder,
  }) : promptBuilder = promptBuilder ?? PromptBuilder();

  /// Streams response text for a question about [bookId], retrieving relevant chunks
  /// and persisting both user and assistant ChatMessages.
  Stream<String> sendMessage({
    required int bookId,
    required String question,
  }) async* {
    final book = await bookRepository.getBook(bookId);
    if (book == null) {
      throw Exception('Book not found for ID $bookId');
    }

    final session = await chatRepository.getOrCreateSession(bookId);

    // Save user message to session history
    final userMsg = ChatMessage()
      ..sessionId = session.id
      ..role = ChatRole.user
      ..content = question.trim()
      ..citedChunkIds = []
      ..createdAt = DateTime.now();
    await chatRepository.addMessage(userMsg);

    // Retrieve relevant chunks via similarity search
    final chunks = await retrievalService.retrieveRelevantChunks(
      bookId: bookId,
      question: question,
      topK: 6,
    );

    final citedChunkIds = chunks.map((c) => c.id).toList();

    // Construct prompts
    final systemPrompt = promptBuilder.buildSystemPrompt(book: book);
    final userTurnWithContext = promptBuilder.buildUserTurnWithContext(
      question: question,
      retrievedChunks: chunks,
    );

    // Fetch prior messages for conversational context (cap at last 10)
    final allMessages = await chatRepository.getMessages(session.id);
    final previousHistory = allMessages.where((m) => m.id != userMsg.id).toList();
    final recentHistory = previousHistory.length > 10
        ? previousHistory.sublist(previousHistory.length - 10)
        : previousHistory;

    // Call AiProvider streaming chat completion
    final responseStream = aiProvider.chatCompletion(
      systemPrompt: systemPrompt,
      history: recentHistory,
      userMessage: userTurnWithContext,
    );

    final fullResponseBuffer = StringBuffer();

    await for (final chunk in responseStream) {
      fullResponseBuffer.write(chunk);
      yield chunk;
    }

    // Save assistant response to session history with citedChunkIds
    final assistantMsg = ChatMessage()
      ..sessionId = session.id
      ..role = ChatRole.assistant
      ..content = fullResponseBuffer.toString().trim()
      ..citedChunkIds = citedChunkIds
      ..createdAt = DateTime.now();

    await chatRepository.addMessage(assistantMsg);
  }
}
