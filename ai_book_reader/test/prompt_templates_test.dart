import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_book_reader/features/ai/chat/prompt_templates.dart';
import 'package:ai_book_reader/features/ai_chat/widgets/prompt_template_sheet.dart';

void main() {
  group('PromptTemplateLibrary tests', () {
    test('contains templates for all categories', () {
      expect(PromptTemplateLibrary.all.isNotEmpty, isTrue);

      for (final cat in PromptCategory.values) {
        final matching = PromptTemplateLibrary.byCategory(cat);
        expect(
          matching.isNotEmpty,
          isTrue,
          reason: 'Expected templates for ${cat.name}',
        );
      }
    });

    test('quickStarters contains curated starter chips', () {
      expect(PromptTemplateLibrary.quickStarters.length, greaterThanOrEqualTo(5));
      for (final starter in PromptTemplateLibrary.quickStarters) {
        expect(starter.title.isNotEmpty, isTrue);
        expect(starter.promptText.isNotEmpty, isTrue);
      }
    });

    test('getEffectivePrompt adapts when selectedPassage is provided', () {
      const template = PromptTemplate(
        id: 'test',
        title: 'Test',
        shortDescription: 'Desc',
        promptText: 'Explain the core idea.',
        category: PromptCategory.summaries,
        icon: Icons.star,
      );

      final defaultPrompt = template.getEffectivePrompt();
      expect(defaultPrompt, equals('Explain the core idea.'));

      final passagePrompt = template.getEffectivePrompt(
        selectedPassage: 'Call me Ishmael.',
      );
      expect(passagePrompt.contains('Regarding the selected passage:'), isTrue);
      expect(passagePrompt.contains('Explain the core idea.'), isTrue);
    });
  });

  group('PromptTemplateSheet widget tests', () {
    testWidgets('renders search field, category chips, and template cards', (
      tester,
    ) async {
      PromptTemplate? selected;
      PromptTemplate? sent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PromptTemplateSheet.show(
                    context,
                    onSelect: (t) => selected = t,
                    onSend: (t) => sent = t,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('AI Prompt Library'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Summaries & Key Ideas'), findsOneWidget);

      // Search filters items
      await tester.enterText(find.byType(TextField), 'Feynman');
      await tester.pumpAndSettle();

      expect(find.text('Feynman / Explain Simply'), findsOneWidget);
      expect(find.text('Executive Summary'), findsNothing);

      // Tap Insert
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, equals('feynman_simple'));
      expect(sent, isNull);
    });

    testWidgets('Ask AI button sends prompt and dismisses sheet', (
      tester,
    ) async {
      PromptTemplate? sent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PromptTemplateSheet.show(
                    context,
                    onSelect: (_) {},
                    onSend: (t) => sent = t,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Find first Ask AI button
      final askButtons = find.text('Ask AI');
      expect(askButtons, findsWidgets);

      await tester.tap(askButtons.first);
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(find.text('AI Prompt Library'), findsNothing);
    });
  });
}
