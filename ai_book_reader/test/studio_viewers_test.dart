import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_book_reader/features/studio/viewers/flashcards_viewer.dart';
import 'package:ai_book_reader/features/studio/viewers/quiz_viewer.dart';
import 'package:ai_book_reader/features/studio/viewers/slides_viewer.dart';

void main() {
  testWidgets('QuizViewer shows question and advances after answer', (tester) async {
    const payload = '''
{
  "title": "Demo Quiz",
  "questions": [
    {
      "question": "Capital of France?",
      "choices": ["Berlin", "Paris", "Rome", "Madrid"],
      "correctIndex": 1,
      "explanation": "Paris is the capital."
    }
  ]
}
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: QuizViewer(payloadJson: payload),
      ),
    );

    expect(find.text('Demo Quiz'), findsOneWidget);
    expect(find.text('Capital of France?'), findsOneWidget);

    await tester.tap(find.text('Paris'));
    await tester.pump();
    expect(find.text('Paris is the capital.'), findsOneWidget);

    await tester.tap(find.text('See score'));
    await tester.pump();
    expect(find.textContaining('Score:'), findsOneWidget);
  });

  testWidgets('FlashcardsViewer flips on tap', (tester) async {
    const payload = '''
{
  "cards": [
    {"front": "Front side", "back": "Back side"}
  ]
}
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: FlashcardsViewer(payloadJson: payload),
      ),
    );

    expect(find.text('Front side'), findsOneWidget);
    await tester.tap(find.text('Front side'));
    await tester.pumpAndSettle();
    expect(find.text('Back side'), findsOneWidget);
  });

  testWidgets('SlidesViewer shows heading and bullets', (tester) async {
    const payload = '''
{
  "title": "Deck",
  "slides": [
    {
      "heading": "Intro",
      "bullets": ["Point one", "Point two"],
      "speakerNote": "Say hello"
    }
  ]
}
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: SlidesViewer(payloadJson: payload),
      ),
    );

    expect(find.text('Deck'), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Point one'), findsOneWidget);
    expect(find.textContaining('Say hello'), findsOneWidget);
  });
}
