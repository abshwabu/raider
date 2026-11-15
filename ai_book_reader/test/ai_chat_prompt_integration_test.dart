import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_book_reader/data/local/ai_settings_service.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/local/chat_repository.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/data/local/isar_service.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/data/models/chat_session.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/features/ai/embedding/embedding_service.dart';
import 'package:ai_book_reader/features/ai_chat/ai_chat_screen.dart';
import 'package:ai_book_reader/features/studio/services/artifact_export_service.dart';
import 'package:ai_book_reader/features/studio/viewers/study_guide_viewer.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class FakeAiSettingsService extends AiSettingsService {
  @override
  Future<String?> getByokKey() async => 'fake-test-key';
}

class FakeEmbeddingService extends Fake implements EmbeddingService {
  @override
  Future<void> ensureEmbeddingsGenerated(
    int bookId, {
    bool force = false,
    void Function(int current, int total)? onProgress,
  }) async {}

  @override
  Future<List<double>> embedText(String text) async => [0.1, 0.2];

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async =>
      texts.map((_) => [0.1, 0.2]).toList();
}

class FakeChunkRepository extends Fake implements ChunkRepository {
  @override
  Future<bool> hasEmbeddings(int bookId) async => true;
  @override
  Future<List<Chunk>> getChunksForBook(int bookId) async => [];
}

class FakeChapterRepository extends Fake implements ChapterRepository {
  @override
  Future<List<Chapter>> getChaptersForBook(int bookId) async => [];
}

class FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<ChatSession> getOrCreateSession(int bookId) async =>
      ChatSession()
        ..id = 1
        ..bookId = bookId
        ..createdAt = DateTime.now();

  @override
  Future<List<ChatMessage>> getMessages(int sessionId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late Directory tempDir;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ai_features_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('AiChatScreen empty state displays suggested prompt chips and prompt template button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chapterRepositoryProvider.overrideWithValue(FakeChapterRepository()),
          chunkRepositoryProvider.overrideWithValue(FakeChunkRepository()),
          chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
          aiSettingsServiceProvider.overrideWithValue(FakeAiSettingsService()),
          embeddingServiceProvider.overrideWithValue(FakeEmbeddingService()),
        ],
        child: const MaterialApp(
          home: AiChatScreen(
            bookId: 1,
            bookTitle: 'Grounded Book',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Title & Suggested Prompts header
    expect(find.text('Ask AI — Grounded Book'), findsOneWidget);
    expect(find.text('Suggested Prompts'), findsOneWidget);

    // Verify starter chips exist
    expect(find.text('Executive Summary'), findsOneWidget);
    expect(find.text('Key Takeaways'), findsOneWidget);
    expect(find.text('Explain Simply'), findsOneWidget);
    expect(find.text('Action Checklist'), findsOneWidget);
    expect(find.text('Critical Analysis'), findsOneWidget);
    expect(find.text('Browse all prompts'), findsOneWidget);

    // Verify Prompt Templates icon button in input bar exists and open sheet
    expect(find.byTooltip('Prompt Templates'), findsOneWidget);
    await tester.tap(find.byTooltip('Prompt Templates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AI Prompt Library'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('StudyGuideViewer displays format badge, markdown, and export menu', (
    tester,
  ) async {
    const payloadJson =
        '{"markdown": "# Cornell Notes\\n\\n## Cue Column\\nWhat is truth?\\n\\n## Notes\\nTruth is reality.", "format": "cornell_notes"}';

    String? sharedData;
    final exportService = ArtifactExportService(
      getDirectory: () async => tempDir,
      shareText: (text, {subject}) async => sharedData = text,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudyGuideViewer(
          payloadJson: payloadJson,
          title: 'Philosophy Cornell Notes',
          exportService: exportService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Format Badge
    expect(find.text('Philosophy Cornell Notes'), findsOneWidget);
    expect(find.text('Cornell Notes & Active Recall'), findsOneWidget);
    expect(find.text('What is truth?'), findsOneWidget);

    // Verify action buttons exist in AppBar
    expect(find.byTooltip('Copy Markdown'), findsOneWidget);
    expect(find.byTooltip('Export & Share'), findsOneWidget);

    // Open export popup menu
    await tester.tap(find.byTooltip('Export & Share'));
    await tester.pumpAndSettle();

    expect(find.text('Copy Markdown'), findsOneWidget);
    expect(find.text('Copy Plain Text'), findsOneWidget);
    expect(find.text('Export as .md'), findsOneWidget);
    expect(find.text('Export as .txt'), findsOneWidget);
    expect(find.text('Share via...'), findsOneWidget);

    // Tap Share via...
    await tester.tap(find.text('Share via...'));
    await tester.pumpAndSettle();

    expect(sharedData, isNotNull);
    expect(sharedData!.contains('What is truth?'), isTrue);
  });
}
