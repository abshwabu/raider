import 'dart:convert';

class QuizQuestion {
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    var choices = (json['choices'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    var correctIndex = (json['correctIndex'] as num?)?.toInt() ?? 0;
    if (choices.isEmpty) {
      choices = ['No options provided'];
    }
    if (correctIndex < 0 || correctIndex >= choices.length) {
      correctIndex = 0;
    }
    return QuizQuestion(
      question: (json['question'] ?? '').toString(),
      choices: choices,
      correctIndex: correctIndex,
      explanation: (json['explanation'] ?? '').toString(),
    );
  }
}

class QuizPayload {
  final String title;
  final List<QuizQuestion> questions;

  const QuizPayload({required this.title, required this.questions});

  factory QuizPayload.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e)))
        .where((q) => q.question.trim().isNotEmpty)
        .toList();
    return QuizPayload(
      title: (json['title'] ?? 'Quiz').toString(),
      questions: questions,
    );
  }
}

class Flashcard {
  final String front;
  final String back;

  const Flashcard({required this.front, required this.back});

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      front: (json['front'] ?? '').toString(),
      back: (json['back'] ?? '').toString(),
    );
  }
}

class FlashcardsPayload {
  final List<Flashcard> cards;

  const FlashcardsPayload({required this.cards});

  factory FlashcardsPayload.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Flashcard.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.front.trim().isNotEmpty)
        .toList();
    return FlashcardsPayload(cards: cards);
  }
}

class SlideItem {
  final String heading;
  final List<String> bullets;
  final String? speakerNote;

  const SlideItem({
    required this.heading,
    required this.bullets,
    this.speakerNote,
  });

  factory SlideItem.fromJson(Map<String, dynamic> json) {
    return SlideItem(
      heading: (json['heading'] ?? '').toString(),
      bullets: (json['bullets'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      speakerNote: json['speakerNote']?.toString(),
    );
  }
}

class SlidesPayload {
  final String title;
  final List<SlideItem> slides;

  const SlidesPayload({required this.title, required this.slides});

  factory SlidesPayload.fromJson(Map<String, dynamic> json) {
    final slides = (json['slides'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => SlideItem.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.heading.trim().isNotEmpty)
        .toList();
    return SlidesPayload(
      title: (json['title'] ?? 'Slideshow').toString(),
      slides: slides,
    );
  }
}

class MindMapNode {
  final String label;
  final List<MindMapNode> children;

  const MindMapNode({required this.label, this.children = const []});

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    final children = (json['children'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => MindMapNode.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return MindMapNode(
      label: (json['label'] ?? '').toString(),
      children: children,
    );
  }
}

class MindMapPayload {
  final MindMapNode root;

  const MindMapPayload({required this.root});

  factory MindMapPayload.fromJson(Map<String, dynamic> json) {
    final rootJson = json['root'];
    if (rootJson is Map) {
      return MindMapPayload(
        root: MindMapNode.fromJson(Map<String, dynamic>.from(rootJson)),
      );
    }
    return const MindMapPayload(root: MindMapNode(label: 'Untitled'));
  }
}

class StudyGuidePayload {
  final String markdown;

  const StudyGuidePayload({required this.markdown});

  factory StudyGuidePayload.fromJson(Map<String, dynamic> json) {
    final raw = (json['markdown'] ?? '').toString();
    return StudyGuidePayload(markdown: cleanMarkdown(raw));
  }

  factory StudyGuidePayload.fromRaw(String raw) {
    return StudyGuidePayload(markdown: cleanMarkdown(raw));
  }

  /// Cleans and extracts the actual Markdown study guide from various possible formats:
  /// - Plain markdown text
  /// - Markdown wrapped in code fences (```markdown ... ``` or ``` ... ```)
  /// - JSON string with a "markdown" key (with or without ```json fences)
  /// - Malformed JSON where literal newlines/quotes caused jsonDecode to fail
  /// - Double-encoded JSON structures
  static String cleanMarkdown(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    // Unwrap up to 3 times to handle nested wrapping (e.g. JSON inside JSON or fences)
    for (var i = 0; i < 3; i++) {
      final unwrapped = _unwrapOnce(text);
      if (unwrapped == text) {
        break;
      }
      text = unwrapped.trim();
    }

    return text;
  }

  static String _unwrapOnce(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;

    // 1. Strip markdown code fences if wrapping the entire response
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1 && text.endsWith('```')) {
        final header = text.substring(0, firstNewline).trim().toLowerCase();
        final inner = text.substring(firstNewline + 1, text.length - 3).trim();
        if (header == '```json') {
          return _extractFromJson(inner);
        } else {
          // If inner content looks like JSON with a "markdown" key, extract it
          if (_looksLikeMarkdownJson(inner)) {
            return _extractFromJson(inner);
          }
          return inner;
        }
      }
    }

    // 2. Check if the text looks like a JSON object containing "markdown"
    if (_looksLikeMarkdownJson(text)) {
      return _extractFromJson(text);
    }

    return text;
  }

  static bool _looksLikeMarkdownJson(String text) {
    final trimmed = text.trim();
    final hasBrace = trimmed.startsWith('{') || trimmed.contains('{');
    final hasMarkdownKey = trimmed.contains(RegExp(r'"markdown"\s*:', caseSensitive: false));
    return hasBrace && hasMarkdownKey;
  }

  static String _extractFromJson(String jsonText) {
    final trimmed = jsonText.trim();

    // Try standard JSON decode
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded.containsKey('markdown')) {
        return (decoded['markdown'] ?? '').toString().trim();
      }
    } catch (_) {}

    // Try extracting JSON substring first in case of surrounding prose
    try {
      final objectStr = extractJsonObject(trimmed);
      final decoded = jsonDecode(objectStr);
      if (decoded is Map && decoded.containsKey('markdown')) {
        return (decoded['markdown'] ?? '').toString().trim();
      }
    } catch (_) {}

    // Fallback regex: extract content after "markdown": " until closing quote before }
    final regex = RegExp(
      r'"markdown"\s*:\s*"(.*)"\s*}?\s*$',
      dotAll: true,
      caseSensitive: false,
    );
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final extracted = match.group(1);
      if (extracted != null && extracted.isNotEmpty) {
        return _unescapeJsonString(extracted).trim();
      }
    }

    // Secondary fallback: find the index after "markdown":
    final marker = RegExp(r'"markdown"\s*:\s*', caseSensitive: false).firstMatch(trimmed);
    if (marker != null) {
      var content = trimmed.substring(marker.end).trim();
      if (content.startsWith('"')) {
        content = content.substring(1);
      }
      if (content.endsWith('}') && content.length > 1) {
        content = content.substring(0, content.length - 1).trim();
      }
      if (content.endsWith('"') && content.length > 1) {
        content = content.substring(0, content.length - 1);
      }
      return _unescapeJsonString(content).trim();
    }

    return trimmed;
  }

  static String _unescapeJsonString(String text) {
    return text
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\t', '\t');
  }
}

/// Extracts a JSON object from a model response that may include fences or prose.
String extractJsonObject(String raw) {
  var text = raw.trim();
  if (text.startsWith('```')) {
    final firstNewline = text.indexOf('\n');
    if (firstNewline != -1) {
      text = text.substring(firstNewline + 1);
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3).trim();
    }
  }

  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) {
    throw const FormatException('No JSON object found in model response');
  }
  return text.substring(start, end + 1);
}

Map<String, dynamic> decodeJsonObject(String raw) {
  final jsonText = extractJsonObject(raw);
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object');
  }
  return Map<String, dynamic>.from(decoded);
}
