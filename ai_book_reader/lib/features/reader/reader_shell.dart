import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/book_repository.dart';
import '../../data/local/chapter_repository.dart';
import '../../data/local/reading_position_service.dart';
import '../../data/local/reading_stats_repository.dart';
import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../ai/chunking/chunking_service.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../stats/services/reading_reminder_service.dart';
import '../studio/studio_hub_screen.dart';
import 'comic/comic_parser.dart';
import 'comic/comic_reader_screen.dart';
import 'docx/docx_parser.dart';
import 'docx/docx_reader_screen.dart';
import 'epub/epub_parser.dart';
import 'epub/epub_reader_screen.dart';
import 'mobi/mobi_parser.dart';
import 'mobi/mobi_reader_screen.dart';
import 'ocr/book_ocr_scanner.dart';
import 'ocr/ocr_service.dart';
import 'pdf/pdf_parser.dart';
import 'pdf/pdf_reader_screen.dart';
import 'shared/ai_speed_dial_fab.dart';
import 'shared/chapter_list_drawer.dart';
import 'shared/reader_preferences.dart';
import 'shared/reader_settings_sheet.dart';
import 'tts/tts_player_bar.dart';
import 'tts/tts_service.dart';
import 'txt/txt_parser.dart';
import 'txt/txt_reader_screen.dart';

class ReaderShell extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderShell({
    super.key,
    required this.bookId,
  });

  @override
  ConsumerState<ReaderShell> createState() => _ReaderShellState();
}

class _ReaderShellState extends ConsumerState<ReaderShell> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<PdfReaderScreenState> _pdfKey = GlobalKey<PdfReaderScreenState>();
  final GlobalKey<EpubReaderScreenState> _epubKey = GlobalKey<EpubReaderScreenState>();
  final GlobalKey<TxtReaderScreenState> _txtKey = GlobalKey<TxtReaderScreenState>();
  final GlobalKey<DocxReaderScreenState> _docxKey = GlobalKey<DocxReaderScreenState>();
  final GlobalKey<ComicReaderScreenState> _comicKey = GlobalKey<ComicReaderScreenState>();
  final GlobalKey<MobiReaderScreenState> _mobiKey = GlobalKey<MobiReaderScreenState>();

  Book? _book;
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _isScannedPdfWithoutText = false;
  bool _isOcrScanning = false;
  int _currentChapterIndex = 0;
  bool _showChrome = true;

  Timer? _readingTimer;
  int _uncommittedSeconds = 0;
  bool _isTrackingActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startReadingSessionTimer();
    _loadBookAndChapters();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopReadingSessionTimer();
    _flushReadingStats();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isTrackingActive = false;
      _flushReadingStats();
    } else if (state == AppLifecycleState.resumed) {
      _isTrackingActive = true;
    }
  }

  void _startReadingSessionTimer() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isTrackingActive || _isLoading || _book == null) return;
      _uncommittedSeconds++;
      if (_uncommittedSeconds >= 10) {
        _flushReadingStats();
      }
    });
  }

  void _stopReadingSessionTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;
  }

  Future<void> _flushReadingStats({int pagesIncrement = 0}) async {
    final book = _book;
    final seconds = _uncommittedSeconds;
    if (book == null || (seconds <= 0 && pagesIncrement <= 0)) return;

    _uncommittedSeconds = 0;
    try {
      final statsRepo = ref.read(readingStatsRepositoryProvider);
      final justReachedGoal = await statsRepo.recordReadingTime(
        seconds: seconds,
        bookId: book.id,
        pagesIncrement: pagesIncrement,
      );

      final todayStat = await statsRepo.getOrCreateTodayStat();
      final reminderService = ref.read(readingReminderServiceProvider);
      unawaited(reminderService.syncGoalStatus(
        isGoalMet: todayStat.isGoalMet,
        activeSeconds: todayStat.activeSeconds,
        goalMinutes: todayStat.goalMinutes,
      ));

      if (justReachedGoal && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🎉 Goal Reached! You completed your ${todayStat.goalMinutes}-min daily reading goal today!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _recordPageTurn() {
    final book = _book;
    if (book == null) return;
    try {
      ref.read(readingStatsRepositoryProvider).recordPagesRead(
        pages: 1,
        bookId: book.id,
      );
    } catch (_) {}
  }

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }

  void _hideChrome() {
    if (_showChrome) {
      setState(() {
        _showChrome = false;
      });
    }
  }

  void _openStudio() {
    final chapter = _chapters.isNotEmpty &&
            _currentChapterIndex >= 0 &&
            _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex]
        : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudioHubScreen(
        bookId: _book!.id,
        bookTitle: _book!.title,
        currentChapterId: chapter?.id,
        currentChapterTitle: chapter?.title,
      ),
    );
  }

  void _openAiChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiChatScreen(
        bookId: _book!.id,
        bookTitle: _book!.title,
      ),
    );
  }

  Future<void> _loadBookAndChapters() async {
    try {
      final parsedId = int.tryParse(widget.bookId);
      if (parsedId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final bookRepo = ref.read(bookRepositoryProvider);
      final chapterRepo = ref.read(chapterRepositoryProvider);

      final book = await bookRepo.getBook(parsedId);
      if (book != null) {
        var chapters = await chapterRepo.getChaptersForBook(book.id);

        // Fallback extraction if chapters or comic page paths don't exist yet
        final format = book.format.toLowerCase();
        if (format == 'cbz' || format == 'cbr') {
          bool needsExtraction = book.pageImagePaths.isEmpty;
          if (!needsExtraction) {
            for (final path in book.pageImagePaths) {
              if (!File(path).existsSync()) {
                needsExtraction = true;
                break;
              }
            }
          }
          if (needsExtraction) {
            final extracted = await ComicParser.extractPageImagePaths(
              book: book,
              bookRepository: bookRepo,
            );
            book.pageImagePaths = extracted;
          }
        } else if (chapters.isEmpty) {
          if (format == 'pdf') {
            chapters = await PdfParser.extractChapters(
              bookId: book.id,
              filePath: book.filePath,
              chapterRepository: chapterRepo,
              ocrService: ref.read(ocrServiceProvider),
            );
          } else if (format == 'epub') {
            chapters = await EpubParser.extractChapters(
              bookId: book.id,
              filePath: book.filePath,
              chapterRepository: chapterRepo,
              bookRepository: bookRepo,
            );
          } else if (format == 'txt') {
            chapters = await TxtParser.extractChapters(
              bookId: book.id,
              filePath: book.filePath,
              chapterRepository: chapterRepo,
            );
          } else if (format == 'docx') {
            chapters = await DocxParser.extractChapters(
              bookId: book.id,
              filePath: book.filePath,
              chapterRepository: chapterRepo,
            );
          } else if (format == 'mobi' || format == 'azw3') {
            chapters = await MobiParser.extractChapters(
              bookId: book.id,
              filePath: book.filePath,
              chapterRepository: chapterRepo,
            );
          }
        }

        bool isScannedNoText = false;
        if (format == 'pdf') {
          isScannedNoText = await ref.read(bookOcrScannerProvider).isBookScannedWithoutText(book.id);
        }

        if (format != 'cbz' && format != 'cbr') {
          unawaited(ref.read(chunkingServiceProvider).chunkBook(book.id));
        }

        int initialChapterIndex = 0;
        if (chapters.isNotEmpty) {
          final positionService = ref.read(readingPositionServiceProvider);
          initialChapterIndex = positionService.getLastChapterIndexSync(
            book.id,
            fallbackProgress: book.readingProgress,
            totalChapters: chapters.length,
          );
        }

        if (mounted) {
          setState(() {
            _book = book;
            _chapters = chapters;
            _isScannedPdfWithoutText = isScannedNoText;
            _currentChapterIndex = initialChapterIndex;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e, st) {
      debugPrint('Error loading book: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onChapterSelected(int index, Chapter chapter) {
    if (_currentChapterIndex != index) {
      _recordPageTurn();
    }
    setState(() {
      _currentChapterIndex = index;
    });

    final format = _book?.format.toLowerCase();
    if (format == 'pdf') {
      _pdfKey.currentState?.jumpToChapter(chapter);
    } else if (format == 'epub') {
      _epubKey.currentState?.jumpToChapter(index);
    } else if (format == 'txt') {
      _txtKey.currentState?.jumpToChapter(index);
    } else if (format == 'docx') {
      _docxKey.currentState?.jumpToChapter(index);
    } else if (format == 'mobi' || format == 'azw3') {
      _mobiKey.currentState?.jumpToChapter(index);
    }

    // If TTS was active, switch TTS to the new chapter
    final ttsState = ref.read(ttsServiceProvider);
    if (!ttsState.isStopped) {
      _speakCurrentChapter(startFromBeginning: true);
    }
  }

  String _getCurrentChapterText() {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return '';
    }
    final format = _book?.format.toLowerCase();
    String text = '';
    if (format == 'epub') {
      text = _epubKey.currentState?.getCurrentChapterPlainText() ?? '';
    } else if (format == 'txt') {
      text = _txtKey.currentState?.getCurrentChapterPlainText() ?? '';
    } else if (format == 'docx') {
      text = _docxKey.currentState?.getCurrentChapterPlainText() ?? '';
    } else if (format == 'mobi' || format == 'azw3') {
      text = _mobiKey.currentState?.getCurrentChapterPlainText() ?? '';
    }
    if (text.isEmpty && _currentChapterIndex < _chapters.length) {
      text = _chapters[_currentChapterIndex].content;
    }
    return text;
  }

  void _toggleTts() {
    final ttsState = ref.read(ttsServiceProvider);
    final ttsNotifier = ref.read(ttsServiceProvider.notifier);

    if (ttsState.isPlaying) {
      ttsNotifier.pause();
    } else if (ttsState.isPaused) {
      ttsNotifier.resume();
    } else {
      _speakCurrentChapter(startFromBeginning: false);
    }
  }

  void _speakCurrentChapter({bool startFromBeginning = false}) {
    if (_book == null || _chapters.isEmpty) return;
    final currentChapter = _chapters[_currentChapterIndex];
    final text = _getCurrentChapterText();

    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No readable text found for this section.')),
      );
      return;
    }

    final ttsNotifier = ref.read(ttsServiceProvider.notifier);
    ttsNotifier.speakChapter(
      bookId: _book!.id,
      chapterId: currentChapter.id,
      chapterTitle: currentChapter.title,
      text: text,
      startParagraph: startFromBeginning ? 0 : 0,
    );
  }

  Future<void> _runOcrScan() async {
    if (_book == null || _isOcrScanning) return;

    setState(() {
      _isOcrScanning = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: Colors.amberAccent),
              SizedBox(width: 10),
              Text('Scanning Document', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Running on-device OCR on scanned pages so AI features (Chat, Studio, Summaries) and Text-to-Speech can read the document...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 20),
              LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );

    try {
      final scanner = ref.read(bookOcrScannerProvider);
      final result = await scanner.scanAndEnrichBook(_book!.id);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (result.success) {
          final chapters = await ref.read(chapterRepositoryProvider).getChaptersForBook(_book!.id);
          setState(() {
            _chapters = chapters;
            _isScannedPdfWithoutText = false;
            _isOcrScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Extracted text from ${result.pagesScanned} pages (${result.totalCharacters} characters)! AI features are now ready.',
              ),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          setState(() {
            _isOcrScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'OCR scanning completed with no text.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isOcrScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR error: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Widget _buildFormatBody() {
    final format = _book!.format.toLowerCase();

    switch (format) {
      case 'pdf':
        return PdfReaderScreen(
          key: _pdfKey,
          book: _book!,
          chapters: _chapters,
        );
      case 'epub':
        return EpubReaderScreen(
          key: _epubKey,
          book: _book!,
          chapters: _chapters,
          showControls: _showChrome,
          onTapBody: _toggleChrome,
          onChapterChanged: (index) {
            if (_currentChapterIndex != index) {
              _recordPageTurn();
              setState(() => _currentChapterIndex = index);
            }
          },
        );
      case 'txt':
        return TxtReaderScreen(
          key: _txtKey,
          book: _book!,
          chapters: _chapters,
          showControls: _showChrome,
          onTapBody: _toggleChrome,
          onChapterChanged: (index) {
            if (_currentChapterIndex != index) {
              _recordPageTurn();
              setState(() => _currentChapterIndex = index);
            }
          },
        );
      case 'docx':
        return DocxReaderScreen(
          key: _docxKey,
          book: _book!,
          chapters: _chapters,
          showControls: _showChrome,
          onTapBody: _toggleChrome,
          onChapterChanged: (index) {
            if (_currentChapterIndex != index) {
              _recordPageTurn();
              setState(() => _currentChapterIndex = index);
            }
          },
        );
      case 'cbz':
      case 'cbr':
        return ComicReaderScreen(
          key: _comicKey,
          book: _book!,
          pagePaths: _book!.pageImagePaths,
        );
      case 'mobi':
      case 'azw3':
        return MobiReaderScreen(
          key: _mobiKey,
          book: _book!,
          chapters: _chapters,
          showControls: _showChrome,
          onTapBody: _toggleChrome,
          onChapterChanged: (index) {
            if (_currentChapterIndex != index) {
              _recordPageTurn();
              setState(() => _currentChapterIndex = index);
            }
          },
        );
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_stories_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Reader for ${_book!.format.toUpperCase()} coming soon',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Book...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_book == null || !File(_book!.filePath).existsSync()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Book file could not be found or opened.'),
        ),
      );
    }

    final format = _book!.format.toLowerCase();
    final isComic = format == 'cbz' || format == 'cbr';
    final prefs = ref.watch(readerPreferencesProvider);
    final ttsState = ref.watch(ttsServiceProvider);
    final themeMode = prefs.themeMode;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeMode.backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_showChrome ? kToolbarHeight : 0),
        child: AnimatedSlide(
          offset: _showChrome ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _showChrome ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: AppBar(
              title: Text(_book!.title),
              backgroundColor: themeMode.cardColor,
              foregroundColor: themeMode.textColor,
              actions: isComic
                  ? null
                  : [
                      if (format == 'pdf')
                        IconButton(
                          icon: const Icon(Icons.document_scanner_rounded),
                          tooltip: 'Scan Document (OCR)',
                          onPressed: _runOcrScan,
                        ),
                      IconButton(
                        icon: Icon(
                          ttsState.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.headphones_rounded,
                          color: ttsState.isPlaying
                              ? themeMode.accentColor
                              : themeMode.textColor,
                        ),
                        tooltip: ttsState.isPlaying
                            ? 'Pause Speech'
                            : 'Read Aloud (TTS)',
                        onPressed: _toggleTts,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.tune_rounded,
                          color: themeMode.textColor,
                        ),
                        tooltip: 'Themes & Fonts',
                        onPressed: () => showReaderSettingsSheet(context),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.format_list_bulleted_rounded,
                          color: themeMode.textColor,
                        ),
                        tooltip: 'Table of Contents',
                        onPressed: () {
                          _scaffoldKey.currentState?.openEndDrawer();
                        },
                      ),
                    ],
            ),
          ),
        ),
      ),
      endDrawer: isComic
          ? null
          : ChapterListDrawer(
              bookTitle: _book!.title,
              chapters: _chapters,
              currentChapterIndex: _currentChapterIndex,
              onChapterSelected: _onChapterSelected,
            ),
      floatingActionButton: isComic
          ? null
          : AnimatedSlide(
              offset: _showChrome ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _showChrome ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: !ttsState.isStopped ? 155 : 58,
                  ),
                  child: AiSpeedDialFab(
                    isVisible: _showChrome,
                    onOpenStudio: _openStudio,
                    onOpenChat: _openAiChat,
                  ),
                ),
              ),
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle) {
                  _hideChrome();
                }
                return false;
              },
              child: _buildFormatBody(),
            ),
          ),
          if (_isScannedPdfWithoutText && _showChrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: const Color(0xFF2C2416),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.document_scanner_rounded, color: Colors.amberAccent, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Scanned pages detected. Scan with OCR for AI assistance & TTS.',
                          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _runOcrScan,
                        child: const Text('Scan OCR'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!ttsState.isStopped)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: TtsPlayerBar(
                  onClose: () {},
                ),
              ),
            ),
        ],
      ),
    );
  }
}
