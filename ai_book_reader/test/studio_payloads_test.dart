import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/studio_artifact.dart';
import 'package:ai_book_reader/features/ai/chat/prompt_builder.dart';
import 'package:ai_book_reader/features/ai/studio/studio_payloads.dart';

void main() {
  group('studio payloads', () {
    test('extractJsonObject strips fences and surrounding prose', () {
      const raw = '''
Here you go:
```json
{"title":"Quiz","questions":[]}
```
''';
      final json = extractJsonObject(raw);
      expect(jsonDecode(json)['title'], 'Quiz');
    });

    test('QuizPayload parses questions', () {
      final quiz = QuizPayload.fromJson({
        'title': 'Chapter 1 Quiz',
        'questions': [
          {
            'question': 'What is X?',
            'choices': ['A', 'B', 'C', 'D'],
            'correctIndex': 2,
            'explanation': 'Because C',
          },
        ],
      });
      expect(quiz.title, 'Chapter 1 Quiz');
      expect(quiz.questions.single.correctIndex, 2);
      expect(quiz.questions.single.choices.length, 4);
    });

    test('StudyGuidePayload accepts raw markdown', () {
      final guide = StudyGuidePayload.fromRaw('# Hello\n\n## Briefing');
      expect(guide.markdown.contains('Briefing'), isTrue);
    });

    test('MindMapPayload parses nested tree', () {
      final map = MindMapPayload.fromJson({
        'root': {
          'label': 'Book',
          'children': [
            {
              'label': 'Theme',
              'children': [
                {'label': 'Freedom', 'children': []},
              ],
            },
          ],
        },
      });
      expect(map.root.label, 'Book');
      expect(map.root.children.single.children.single.label, 'Freedom');
    });
  });

  group('PromptBuilder studio prompts', () {
    test('includes JSON schema for quiz', () {
      final book = Book()
        ..title = 'Demo'
        ..author = 'Author'
        ..format = 'txt'
        ..filePath = '/tmp/demo.txt'
        ..addedAt = DateTime.now();

      final chunks = [
        Chunk()
          ..bookId = 1
          ..chapterId = 1
          ..text = 'Excerpt text about freedom.'
          ..orderInChapter = 0,
      ];

      final builder = PromptBuilder();
      final system = builder.buildStudioSystemPrompt(
        book: book,
        type: StudioArtifactType.quiz,
        scope: StudioArtifactScope.book,
      );
      final user = builder.buildStudioUserPrompt(
        type: StudioArtifactType.quiz,
        excerpts: chunks,
      );

      expect(system.contains('Demo'), isTrue);
      expect(user.contains('correctIndex'), isTrue);
      expect(user.contains('Excerpt text about freedom.'), isTrue);
    });
  });
}
