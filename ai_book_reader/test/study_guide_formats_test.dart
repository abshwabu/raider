import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/studio_artifact.dart';
import 'package:ai_book_reader/features/ai/chat/prompt_builder.dart';
import 'package:ai_book_reader/features/ai/studio/studio_payloads.dart';
import 'package:ai_book_reader/features/studio/widgets/study_guide_format_sheet.dart';

void main() {
  group('CustomStudyGuideFormat & StudyGuidePayload', () {
    test('fromId returns correct format or defaults to executiveBrief', () {
      expect(
        CustomStudyGuideFormat.fromId('cornell_notes'),
        equals(CustomStudyGuideFormat.cornellNotes),
      );
      expect(
        CustomStudyGuideFormat.fromId('action_playbook'),
        equals(CustomStudyGuideFormat.actionPlaybook),
      );
      expect(
        CustomStudyGuideFormat.fromId('thematic_analysis'),
        equals(CustomStudyGuideFormat.thematicAnalysis),
      );
      expect(
        CustomStudyGuideFormat.fromId('quick_cheat_sheet'),
        equals(CustomStudyGuideFormat.quickCheatSheet),
      );
      expect(
        CustomStudyGuideFormat.fromId('book_summary'),
        equals(CustomStudyGuideFormat.bookSummary),
      );
      expect(
        CustomStudyGuideFormat.fromId('non_existent'),
        equals(CustomStudyGuideFormat.executiveBrief),
      );
      expect(
        CustomStudyGuideFormat.fromId(null),
        equals(CustomStudyGuideFormat.executiveBrief),
      );
    });

    test('StudyGuidePayload serializes and deserializes format correctly', () {
      const payload = StudyGuidePayload(
        markdown: '# Guide Content',
        format: CustomStudyGuideFormat.cornellNotes,
      );

      final json = payload.toJson();
      expect(json['markdown'], equals('# Guide Content'));
      expect(json['format'], equals('cornell_notes'));

      final restored = StudyGuidePayload.fromJson(json);
      expect(restored.markdown, equals('# Guide Content'));
      expect(restored.format, equals(CustomStudyGuideFormat.cornellNotes));
    });

    test('StudyGuidePayload.fromRaw parses raw string with format fallback', () {
      final payload = StudyGuidePayload.fromRaw(
        '# Just Markdown',
        CustomStudyGuideFormat.quickCheatSheet,
      );
      expect(payload.markdown, equals('# Just Markdown'));
      expect(payload.format, equals(CustomStudyGuideFormat.quickCheatSheet));
    });

    test('StudyGuidePayload.fromRaw decodes JSON object string if present', () {
      final jsonStr = '{"markdown": "## Real content", "format": "action_playbook"}';
      final payload = StudyGuidePayload.fromRaw(jsonStr);
      expect(payload.markdown, equals('## Real content'));
      expect(payload.format, equals(CustomStudyGuideFormat.actionPlaybook));
    });
  });

  group('PromptBuilder study guide formats', () {
    late PromptBuilder builder;
    late List<Chunk> chunks;
    late Book book;

    setUp(() {
      builder = PromptBuilder();
      chunks = [
        Chunk()
          ..bookId = 1
          ..chapterId = 1
          ..text = 'Philosophical passage on nature and mind.'
          ..orderInChapter = 0,
      ];
      book = Book()
        ..title = 'Meditations'
        ..author = 'Marcus Aurelius'
        ..format = 'epub'
        ..filePath = '/fake/meditations.epub'
        ..addedAt = DateTime.now();
    });

    test('builds Executive Brief format instructions', () {
      final prompt = builder.buildStudioUserPrompt(
        type: StudioArtifactType.studyGuide,
        excerpts: chunks,
        studyGuideFormat: CustomStudyGuideFormat.executiveBrief,
      );
      expect(prompt.contains('Executive Briefing & Deep Dive'), isTrue);
      expect(prompt.contains('Core Thesis & Executive Summary'), isTrue);
      expect(prompt.contains('Frequently Asked Questions (FAQ)'), isTrue);
      expect(prompt.contains('Essential Glossary'), isTrue);
    });

    test('builds Cornell Notes format instructions', () {
      final prompt = builder.buildStudioUserPrompt(
        type: StudioArtifactType.studyGuide,
        excerpts: chunks,
        studyGuideFormat: CustomStudyGuideFormat.cornellNotes,
      );
      expect(prompt.contains('Cornell Notes & Active Recall'), isTrue);
      expect(prompt.contains('Cue Column (Questions & Triggers)'), isTrue);
      expect(prompt.contains('Active Recall Self-Test'), isTrue);
    });

    test('builds Actionable Playbook format instructions', () {
      final prompt = builder.buildStudioUserPrompt(
        type: StudioArtifactType.studyGuide,
        excerpts: chunks,
        studyGuideFormat: CustomStudyGuideFormat.actionPlaybook,
      );
      expect(prompt.contains('Actionable Playbook & Implementation Guide'), isTrue);
      expect(prompt.contains('Core Philosophy & Foundational Rules'), isTrue);
      expect(prompt.contains('Execution Checklist'), isTrue);
    });

    test('builds Thematic Analysis format instructions', () {
      final prompt = builder.buildStudioUserPrompt(
        type: StudioArtifactType.studyGuide,
        excerpts: chunks,
        studyGuideFormat: CustomStudyGuideFormat.thematicAnalysis,
      );
      expect(prompt.contains('Thematic & Critical Analysis'), isTrue);
      expect(prompt.contains('Central Themes & Motif Exploration'), isTrue);
      expect(prompt.contains('Critical Counterarguments & Limitations'), isTrue);
    });

    test('builds Rapid Cheat Sheet format instructions', () {
      final prompt = builder.buildStudioUserPrompt(
        type: StudioArtifactType.studyGuide,
        excerpts: chunks,
        studyGuideFormat: CustomStudyGuideFormat.quickCheatSheet,
      );
      expect(prompt.contains('Rapid Study Cheat Sheet'), isTrue);
      expect(prompt.contains('60-Second TL;DR'), isTrue);
      expect(prompt.contains('Core Frameworks & Rules of Thumb'), isTrue);
    });

    test('builds Comprehensive Book Summary format instructions', () {
      final systemPrompt = builder.buildBookSummarySystemPrompt(book: book);
      expect(systemPrompt.contains('Marcus Aurelius'), isTrue);
      expect(systemPrompt.contains('executive book summary'), isTrue);

      final userPrompt = builder.buildBookSummaryUserPrompt(excerpts: chunks);
      expect(userPrompt.contains('Comprehensive Book Summary'), isTrue);
      expect(userPrompt.contains('Top 7 Transformative Insights'), isTrue);
    });
  });

  group('StudyGuideFormatSheet widget tests', () {
    testWidgets('renders all formats and selects chosen option', (tester) async {
      CustomStudyGuideFormat? picked;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  picked = await StudyGuideFormatSheet.show(
                    context,
                    initialFormat: CustomStudyGuideFormat.executiveBrief,
                  );
                },
                child: const Text('Choose Format'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Choose Format'));
      await tester.pumpAndSettle();

      expect(find.text('Study Guide Format'), findsOneWidget);
      expect(find.text('Executive Brief & Deep Dive'), findsOneWidget);
      expect(find.text('Cornell Notes & Active Recall'), findsOneWidget);
      expect(find.text('Actionable Playbook & Checklist'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Rapid Cheat Sheet / One-Pager'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Rapid Cheat Sheet / One-Pager'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Comprehensive Book Summary'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Comprehensive Book Summary'), findsOneWidget);

      await tester.tap(find.text('Comprehensive Book Summary'));
      await tester.pumpAndSettle();

      expect(picked, equals(CustomStudyGuideFormat.bookSummary));
      expect(find.text('Study Guide Format'), findsNothing);
    });
  });
}
