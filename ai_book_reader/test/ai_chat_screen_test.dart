import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/chat_session.dart';
import 'package:ai_book_reader/data/models/chat_message.dart';
import 'package:ai_book_reader/data/local/isar_service.dart';
import 'package:ai_book_reader/data/local/ai_settings_service.dart';
import 'package:ai_book_reader/features/ai_chat/ai_chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_chat_test');
    isar = await Isar.open(
      [
        BookSchema,
        ChapterSchema,
        ChunkSchema,
        ChatSessionSchema,
        ChatMessageSchema,
      ],
      directory: tempDir.path,
    );
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('AiChatScreen displays Gemini API Key Required when no key is set', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(isar),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatScreen(
              bookId: 1,
              bookTitle: 'Test Book Title',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Gemini API Key Required'), findsOneWidget);
    expect(find.text('Configure API Key'), findsOneWidget);
  });
}
