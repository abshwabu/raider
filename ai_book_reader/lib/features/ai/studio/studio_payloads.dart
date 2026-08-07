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
    return StudyGuidePayload(
      markdown: (json['markdown'] ?? '').toString(),
    );
  }

  factory StudyGuidePayload.fromRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded['markdown'] != null) {
          return StudyGuidePayload(markdown: decoded['markdown'].toString());
        }
      } catch (_) {}
    }
    return StudyGuidePayload(markdown: trimmed);
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
