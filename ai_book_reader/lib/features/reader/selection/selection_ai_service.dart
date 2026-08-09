import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_message.dart';
import '../../ai/provider/ai_provider.dart';
import '../../ai/provider/ai_provider_factory.dart';

final selectionAiServiceProvider = Provider<SelectionAiService>((ref) {
  return SelectionAiService(ref.watch(aiProvider));
});

class SelectionAiService {
  final AiProvider aiProvider;

  SelectionAiService(this.aiProvider);

  Future<String> translate({
    required String text,
    required String targetLanguage,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in aiProvider.chatCompletion(
      systemPrompt:
          'You are a precise translator. Translate the user text into $targetLanguage. '
          'Return only the translation, with no preface or commentary.',
      history: const <ChatMessage>[],
      userMessage: text,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  Future<String> define(String text) async {
    final buffer = StringBuffer();
    await for (final chunk in aiProvider.chatCompletion(
      systemPrompt: '''You are a concise dictionary and usage guide.
For the given word or phrase, respond in Markdown with these sections:
## Meaning
## Part of speech
## Synonyms
## Example
Keep each section short and clear. If the input is a multi-word phrase, define the phrase as a whole.''',
      history: const <ChatMessage>[],
      userMessage: text,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }
}
