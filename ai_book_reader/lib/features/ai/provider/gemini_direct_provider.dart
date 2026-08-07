import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../data/local/ai_settings_service.dart';
import '../../../data/models/chat_message.dart';
import 'ai_provider.dart';

class GeminiDirectProvider implements AiProvider {
  final AiSettingsService aiSettingsService;

  GeminiDirectProvider(this.aiSettingsService);

  Future<String> _getValidApiKey() async {
    final key = await aiSettingsService.getByokKey();
    if (key == null || key.trim().isEmpty) {
      throw NoApiKeyException();
    }
    return key.trim();
  }

  @override
  Future<List<double>> embed(String text) async {
    final apiKey = await _getValidApiKey();

    // text-embedding-004 / embedding-001 were shut down; use current Gemini embedding models.
    final embeddingModels = ['gemini-embedding-001', 'gemini-embedding-2'];

    Object? lastError;

    for (final modelName in embeddingModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
        );
        final response = await model.embedContent(Content.text(text));
        return response.embedding.values;
      } catch (e) {
        lastError = e;
        final errorStr = e.toString().toLowerCase();

        // Throw NoApiKeyException immediately if auth/key issue
        if (errorStr.contains('api_key') ||
            errorStr.contains('unauthorized') ||
            errorStr.contains('invalid api key') ||
            errorStr.contains('api key not valid')) {
          throw NoApiKeyException('Invalid Gemini API Key: $e');
        }

        // If it's a model not found / not supported error, continue loop to try fallback model
        if (errorStr.contains('not found') ||
            errorStr.contains('not supported') ||
            errorStr.contains('404') ||
            errorStr.contains('models/')) {
          continue;
        }

        // Rethrow any other unexpected error
        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw Exception('Failed to generate embeddings with any available embedding model.');
  }

  @override
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    final apiKey = await _getValidApiKey();

    // Prefer current Flash models; fall back through recent stable IDs.
    final chatModels = [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-3.5-flash',
    ];

    final contents = <Content>[];
    for (final msg in history) {
      if (msg.role == ChatRole.user) {
        contents.add(Content.text(msg.content));
      } else {
        contents.add(Content.model([TextPart(msg.content)]));
      }
    }
    contents.add(Content.text(userMessage));

    Object? lastError;

    for (final modelName in chatModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: Content.system(systemPrompt),
        );

        final responseStream = model.generateContentStream(contents);
        await for (final chunk in responseStream) {
          if (chunk.text != null && chunk.text!.isNotEmpty) {
            yield chunk.text!;
          }
        }
        // Successfully completed stream with this model
        return;
      } catch (e) {
        lastError = e;
        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('api_key') ||
            errorStr.contains('unauthorized') ||
            errorStr.contains('invalid api key') ||
            errorStr.contains('api key not valid')) {
          throw NoApiKeyException('Invalid Gemini API Key: $e');
        }

        if (errorStr.contains('not found') ||
            errorStr.contains('not supported') ||
            errorStr.contains('404') ||
            errorStr.contains('models/')) {
          continue;
        }

        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }
}
