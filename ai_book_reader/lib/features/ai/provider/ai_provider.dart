import '../../../data/models/chat_message.dart';

class NoApiKeyException implements Exception {
  final String message;
  NoApiKeyException([this.message = 'No Gemini API key set. Please configure your API key in Settings.']);

  @override
  String toString() => 'NoApiKeyException: $message';
}

abstract class AiProvider {
  /// Generates vector embedding for a given text string.
  Future<List<double>> embed(String text);

  /// Streams response chunks for a chat prompt with context/history.
  Stream<String> chatCompletion({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  });
}
