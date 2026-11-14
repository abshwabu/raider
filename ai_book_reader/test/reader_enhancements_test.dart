import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ai_book_reader/data/models/book.dart';
import 'package:ai_book_reader/data/models/chapter.dart';
import 'package:ai_book_reader/data/models/chunk.dart';
import 'package:ai_book_reader/data/models/annotation.dart';
import 'package:ai_book_reader/data/local/annotation_repository.dart';
import 'package:ai_book_reader/data/local/book_repository.dart';
import 'package:ai_book_reader/data/local/chapter_repository.dart';
import 'package:ai_book_reader/data/local/chunk_repository.dart';
import 'package:ai_book_reader/data/local/reading_position_service.dart';
import 'package:ai_book_reader/features/reader/reader_shell.dart';
import 'package:ai_book_reader/features/reader/shared/reader_preferences.dart';
import 'package:ai_book_reader/features/reader/shared/reader_settings_sheet.dart';
import 'package:ai_book_reader/features/reader/tts/tts_player_bar.dart';
import 'package:ai_book_reader/features/reader/tts/tts_service.dart';

class FakeFlutterTts extends Fake implements FlutterTts {
  void Function()? startHandler;
  void Function()? completionHandler;
  void Function()? cancelHandler;
  void Function()? pauseHandler;
  void Function()? continueHandler;
  void Function(dynamic msg)? errorHandler;
  void Function(String text, int start, int end, String word)? progressHandler;

  String? lastSpokenText;
  double? lastSpeechRate;
  double? lastPitch;
  double? lastVolume;
  bool isSpeaking = false;

  @override
  void setStartHandler(void Function() callback) => startHandler = callback;

  @override
  void setCompletionHandler(void Function() callback) => completionHandler = callback;

  @override
  void setCancelHandler(void Function() callback) => cancelHandler = callback;

  @override
  void setPauseHandler(void Function() callback) => pauseHandler = callback;

  @override
  void setContinueHandler(void Function() callback) => continueHandler = callback;

  @override
  void setErrorHandler(void Function(dynamic msg) callback) => errorHandler = callback;

  @override
  void setProgressHandler(void Function(String text, int start, int end, String word) callback) =>
      progressHandler = callback;

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    lastSpeechRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    lastPitch = pitch;
    return 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    lastVolume = volume;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    lastSpokenText = text;
    isSpeaking = true;
    startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> pause() async {
    isSpeaking = false;
    pauseHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    isSpeaking = false;
    cancelHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> get getVoices async => [
        {'name': 'en-us-x-sfg#female', 'locale': 'en-US'},
        {'name': 'en-us-x-tpd#male', 'locale': 'en-US'},
      ];
}

class FakeBookRepository extends Fake implements BookRepository {
  final Book book;
  FakeBookRepository(this.book);

  @override
  Future<Book?> getBook(int id) async => book;

  @override
  Future<void> updateReadingProgress(int bookId, double progress) async {}
}

class FakeChapterRepository extends Fake implements ChapterRepository {
  final List<Chapter> chapters;
  FakeChapterRepository(this.chapters);

  @override
  Future<List<Chapter>> getChaptersForBook(int bookId) async => chapters;
}

class FakeChunkRepository extends Fake implements ChunkRepository {
  @override
  Future<List<Chunk>> getChunksForBook(int bookId) async => [];

  @override
  Future<void> addChunks(List<Chunk> chunks) async {}
}

class FakeAnnotationRepository extends Fake implements AnnotationRepository {
  @override
  Future<List<Annotation>> getForChapter(int bookId, int chapterId) async => [];

  @override
  Future<List<Annotation>> getForBook(int bookId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ReaderPreferences Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default preferences match expected values', () {
      const prefs = ReaderPreferences();
      expect(prefs.themeMode, ReaderThemeMode.slate);
      expect(prefs.fontFamily, ReaderFontFamily.system);
      expect(prefs.fontSize, 17.0);
      expect(prefs.lineHeight, 1.6);
      expect(prefs.letterSpacing, 0.0);
      expect(prefs.fontWeightIndex, 0);
      expect(prefs.isJustified, false);
      expect(prefs.horizontalPadding, 20.0);
    });

    test('theme palettes have valid contrast colors', () {
      for (final mode in ReaderThemeMode.values) {
        expect(mode.backgroundColor, isNotNull);
        expect(mode.textColor, isNotNull);
        expect(mode.cardColor, isNotNull);
        expect(mode.borderColor, isNotNull);
        expect(mode.accentColor, isNotNull);
      }
    });

    test('getTextStyle generates styles across font families without errors', () {
      for (final font in ReaderFontFamily.values) {
        final prefs = ReaderPreferences(fontFamily: font);
        final style = prefs.getTextStyle();
        expect(style.fontSize, 17.0);
        expect(style.height, 1.6);
      }
    });

    test('notifier updates preferences and persists correctly', () async {
      final notifier = ReaderPreferencesNotifier();

      await notifier.updateTheme(ReaderThemeMode.sepia);
      expect(notifier.state.themeMode, ReaderThemeMode.sepia);

      await notifier.updateFont(ReaderFontFamily.merriweather);
      expect(notifier.state.fontFamily, ReaderFontFamily.merriweather);

      await notifier.updateFontSize(22.0);
      expect(notifier.state.fontSize, 22.0);

      await notifier.updateLineHeight(1.9);
      expect(notifier.state.lineHeight, 1.9);

      await notifier.updateLetterSpacing(0.5);
      expect(notifier.state.letterSpacing, 0.5);

      await notifier.updateFontWeightIndex(2);
      expect(notifier.state.fontWeightIndex, 2);
      expect(notifier.state.fontWeight, FontWeight.w600);

      await notifier.toggleJustified();
      expect(notifier.state.isJustified, true);

      await notifier.updatePadding(32.0);
      expect(notifier.state.horizontalPadding, 32.0);

      await notifier.resetToDefaults();
      expect(notifier.state.themeMode, ReaderThemeMode.slate);
      expect(notifier.state.fontSize, 17.0);
      expect(notifier.state.isJustified, false);
    });
  });

  group('TtsService Unit Tests', () {
    late FakeFlutterTts fakeTts;
    late TtsService ttsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeTts = FakeFlutterTts();
      ttsService = TtsService(flutterTts: fakeTts);
    });

    test('parseTextIntoParagraphs splits double newlines correctly', () {
      const sample = 'First paragraph.\n\nSecond paragraph with details.\n\nThird paragraph.';
      final paras = ttsService.parseTextIntoParagraphs(sample);

      expect(paras.length, 3);
      expect(paras[0].text, 'First paragraph.');
      expect(paras[1].text, 'Second paragraph with details.');
      expect(paras[2].text, 'Third paragraph.');
      expect(paras[0].startOffset, 0);
    });

    test('speakChapter initializes playback and updates state', () async {
      const chapterText = 'Paragraph one.\n\nParagraph two.\n\nParagraph three.';
      await ttsService.speakChapter(
        bookId: 1,
        chapterId: 101,
        chapterTitle: 'Chapter 1',
        text: chapterText,
      );

      expect(ttsService.state.isPlaying, true);
      expect(ttsService.state.paragraphs.length, 3);
      expect(ttsService.state.currentParagraphIndex, 0);
      expect(fakeTts.lastSpokenText, 'Paragraph one.');
    });

    test('nextParagraph and previousParagraph advance through text', () async {
      const chapterText = 'First.\n\nSecond.\n\nThird.';
      await ttsService.speakChapter(
        bookId: 1,
        chapterId: 101,
        chapterTitle: 'Chapter 1',
        text: chapterText,
      );

      await ttsService.nextParagraph();
      expect(ttsService.state.currentParagraphIndex, 1);
      expect(fakeTts.lastSpokenText, 'Second.');

      await ttsService.nextParagraph();
      expect(ttsService.state.currentParagraphIndex, 2);
      expect(fakeTts.lastSpokenText, 'Third.');

      await ttsService.previousParagraph();
      expect(ttsService.state.currentParagraphIndex, 1);
      expect(fakeTts.lastSpokenText, 'Second.');
    });

    test('cycleSpeed toggles through speed presets', () async {
      await ttsService.setSpeedMultiplier(1.0);
      expect(ttsService.state.speedMultiplier, 1.0);

      await ttsService.cycleSpeed();
      expect(ttsService.state.speedMultiplier, 1.25);

      await ttsService.cycleSpeed();
      expect(ttsService.state.speedMultiplier, 1.5);
    });

    test('pause and resume control playback state', () async {
      const chapterText = 'One.\n\nTwo.';
      await ttsService.speakChapter(
        bookId: 1,
        chapterId: 101,
        chapterTitle: 'Chapter 1',
        text: chapterText,
      );

      await ttsService.pause();
      expect(ttsService.state.isPaused, true);

      await ttsService.resume();
      expect(ttsService.state.isPlaying, true);

      await ttsService.stop();
      expect(ttsService.state.isStopped, true);
    });
  });

  group('Widget & Integration Tests', () {
    late Directory tempDir;
    late String txtFilePath;
    late Book testBook;
    late List<Chapter> testChapters;
    late FakeBookRepository fakeBookRepo;
    late FakeChapterRepository fakeChapterRepo;
    late FakeChunkRepository fakeChunkRepo;
    late FakeFlutterTts fakeTts;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('reader_enhancements_test');
      final txtFile = File('${tempDir.path}/sample.txt');
      await txtFile.writeAsString('Welcome to Raider.\n\nEnjoy the enhanced reader experience.');
      txtFilePath = txtFile.path;

      testBook = Book()
        ..id = 1
        ..title = 'Raider Enhancements Book'
        ..format = 'txt'
        ..filePath = txtFilePath
        ..addedAt = DateTime.now();

      testChapters = [
        Chapter()
          ..id = 201
          ..bookId = 1
          ..title = 'Enhancement Chapter'
          ..order = 1
          ..content = 'Welcome to Raider.\n\nEnjoy the enhanced reader experience.',
      ];

      fakeBookRepo = FakeBookRepository(testBook);
      fakeChapterRepo = FakeChapterRepository(testChapters);
      fakeChunkRepo = FakeChunkRepository();
      fakeTts = FakeFlutterTts();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(fakeBookRepo),
          chapterRepositoryProvider.overrideWithValue(fakeChapterRepo),
          chunkRepositoryProvider.overrideWithValue(fakeChunkRepo),
          annotationRepositoryProvider.overrideWithValue(FakeAnnotationRepository()),
          readingPositionServiceProvider.overrideWithValue(ReadingPositionService(null)),
          ttsServiceProvider.overrideWith((ref) => TtsService(flutterTts: fakeTts)),
        ],
        child: const MaterialApp(
          home: ReaderShell(bookId: '1'),
        ),
      );
    }

    testWidgets('ReaderShell displays TTS and Themes & Fonts action buttons in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Raider Enhancements Book'), findsOneWidget);
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    });

    testWidgets('Tapping Themes & Fonts opens ReaderSettingsSheet with Themes and Typography tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap Appearance icon
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Reading Appearance'), findsOneWidget);
      expect(find.text('Themes'), findsOneWidget);
      expect(find.text('Typography'), findsOneWidget);
      expect(find.text('COLOR PALETTES'), findsOneWidget);

      // Verify palettes exist
      expect(find.text('Sepia'), findsOneWidget);
      expect(find.text('AMOLED'), findsOneWidget);
      expect(find.text('Raider Slate'), findsOneWidget);

      // Switch to Typography tab
      await tester.tap(find.text('Typography'));
      await tester.pumpAndSettle();

      expect(find.text('FONT FAMILY'), findsOneWidget);
      expect(find.text('FONT SIZE'), findsOneWidget);
      expect(find.text('LINE SPACING'), findsOneWidget);
      expect(find.text('PAGE MARGINS'), findsOneWidget);
    });

    testWidgets('Tapping TTS button launches TtsPlayerBar and starts reading', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap headphones icon in AppBar
      await tester.tap(find.byIcon(Icons.headphones_rounded));
      await tester.pumpAndSettle();

      // Verify TtsPlayerBar is shown
      expect(find.byType(TtsPlayerBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TtsPlayerBar),
          matching: find.text('Enhancement Chapter'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);

      // Tap pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap close button in TtsPlayerBar
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TtsPlayerBar), findsNothing);
    });
  });
}
