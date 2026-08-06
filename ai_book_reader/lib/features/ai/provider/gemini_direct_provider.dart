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
    final model = GenerativeModel(
      model: 'text-embedding-004',
      apiKey: apiKey,
    );

    try {
      final response = await model.embedContent(Content.text(text));
      return response.embedding.values;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('api_key') || errorStr.contains('unauthorized') || errorStr.contains('invalid')) {
        throw NoApiKeyException('Invalid Gemini API Key: $e');
      }
      rethrow;
    }
  }

  @override
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    final apiKey = await _getValidApiKey();
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    final contents = <Content>[];
    for (final msg in history) {
      if (msg.role == ChatRole.user) {
        contents.add(Content.text(msg.content));
      } else {
        contents.add(Content.model([TextPart(msg.content)]));
      }
    }
    contents.add(Content.text(userMessage));

    try {
      final responseStream = model.generateContentStream(contents);
      await for (final chunk in responseStream) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('api_key') || errorStr.contains('unauthorized') || errorStr.contains('invalid')) {
        throw NoApiKeyException('Invalid Gemini API Key: $e');
      }
      rethrow;
    }
  }
}
