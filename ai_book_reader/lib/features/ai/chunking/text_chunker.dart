import 'package:html/parser.dart' as html_parser;

class TextChunker {
  /// Strips HTML tags cleanly from a string, returning plain text.
  static String stripHtml(String input) {
    if (input.isEmpty) return '';
    if (!input.contains('<') && !input.contains('>')) {
      return input.trim();
    }
    try {
      final document = html_parser.parse(input);
      final text = document.body?.text ?? document.documentElement?.text ?? input;
      return text.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();
    } catch (_) {
      return input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
  }

  /// Approximates token count of a plain text string (~1.3 tokens per word).
  static int estimateTokenCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    final words = trimmed.split(RegExp(r'\s+'));
    return (words.length * 1.3).ceil();
  }

  /// Chunks plain text into blocks of ~[targetTokens] tokens with ~[overlapTokens] overlap.
  /// Ensures chunk boundaries do NOT split mid-sentence or mid-paragraph.
  List<String> chunkText(
    String text, {
    int targetTokens = 750,
    int overlapTokens = 100,
  }) {
    final plainText = stripHtml(text);
    if (plainText.isEmpty) return [];

    final totalTokens = estimateTokenCount(plainText);
    if (totalTokens <= targetTokens) {
      return [plainText];
    }

    // Step 1: Split into paragraphs (\n\n or \n)
    final rawParagraphs = plainText.split(RegExp(r'\n+'));

    // Step 2: Split long paragraphs into sentences if needed
    final sentences = <String>[];
    final sentenceEndPattern = RegExp(r'(?<=[.!?])\s+');

    for (final paragraph in rawParagraphs) {
      final trimmedPara = paragraph.trim();
      if (trimmedPara.isEmpty) continue;

      if (estimateTokenCount(trimmedPara) > targetTokens) {
        final splitSentences = trimmedPara.split(sentenceEndPattern);
        for (final s in splitSentences) {
          final trimmedSentence = s.trim();
          if (trimmedSentence.isNotEmpty) {
            sentences.add(trimmedSentence);
          }
        }
      } else {
        sentences.add(trimmedPara);
      }
    }

    if (sentences.isEmpty) {
      return [plainText];
    }

    final chunks = <String>[];
    int currentStartIndex = 0;

    while (currentStartIndex < sentences.length) {
      final currentChunkSentences = <String>[];
      int currentTokenCount = 0;

      int i = currentStartIndex;
      while (i < sentences.length) {
        final sentence = sentences[i];
        final sentenceTokens = estimateTokenCount(sentence);

        if (currentTokenCount > 0 && currentTokenCount + sentenceTokens > targetTokens) {
          break;
        }

        currentChunkSentences.add(sentence);
        currentTokenCount += sentenceTokens;
        i++;
      }

      // If a single sentence exceeds targetTokens, add it anyway to avoid an infinite loop
      if (currentChunkSentences.isEmpty && i < sentences.length) {
        currentChunkSentences.add(sentences[i]);
        i++;
      }

      final chunkString = currentChunkSentences.join(' ').trim();
      if (chunkString.isNotEmpty) {
        chunks.add(chunkString);
      }

      if (i >= sentences.length) {
        break;
      }

      // Calculate overlap: step back from index `i` until overlap token count is reached
      int nextStartIndex = i;
      int overlapAcc = 0;

      for (int j = i - 1; j > currentStartIndex; j--) {
        final sTokens = estimateTokenCount(sentences[j]);
        if (overlapAcc + sTokens > overlapTokens) {
          break;
        }
        overlapAcc += sTokens;
        nextStartIndex = j;
      }

      // Ensure index progress to prevent infinite loop
      if (nextStartIndex <= currentStartIndex) {
        nextStartIndex = currentStartIndex + 1;
      }

      currentStartIndex = nextStartIndex;
    }

    return chunks;
  }
}
