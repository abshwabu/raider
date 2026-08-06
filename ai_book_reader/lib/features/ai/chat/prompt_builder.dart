import '../../../data/models/book.dart';
import '../../../data/models/chunk.dart';

class PromptBuilder {
  /// Builds the system prompt grounding the model to answer only using provided excerpts.
  String buildSystemPrompt({required Book book}) {
    final authorStr = (book.author != null && book.author!.isNotEmpty)
        ? ' by ${book.author}'
        : '';

    return '''You are an intelligent, thoughtful reading companion for the book "${book.title}"$authorStr.

Your primary duty is to answer questions strictly using the provided book excerpts.

Guiding Principles:
1. Base your answer ONLY on the provided book excerpts.
2. If the excerpts do not contain enough information to answer the user's question, state clearly: "Based on the available excerpts from this book, I don't have enough information to answer that." Do NOT speculate or make up information outside of the excerpts.
3. Keep your tone helpful, clear, engaging, and appropriate for a literary reading companion.
4. When relevant, reference the context or chapter sections naturally.''';
  }

  /// Formats retrieved chunks as context alongside the user's question.
  String buildUserTurnWithContext({
    required String question,
    required List<Chunk> retrievedChunks,
  }) {
    if (retrievedChunks.isEmpty) {
      return '''No relevant excerpts were found for this query.

User Question: $question''';
    }

    final buffer = StringBuffer();
    buffer.writeln('Relevant Book Excerpts:');
    buffer.writeln();

    for (int i = 0; i < retrievedChunks.length; i++) {
      final chunk = retrievedChunks[i];
      buffer.writeln('[Excerpt ${i + 1} | Chunk ID: ${chunk.id} | Chapter ID: ${chunk.chapterId}]');
      buffer.writeln(chunk.text);
      buffer.writeln();
    }

    buffer.writeln('User Question:');
    buffer.writeln(question.trim());

    return buffer.toString();
  }
}
