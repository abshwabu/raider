import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/book_repository.dart';
import '../../data/local/chapter_repository.dart';
import '../../data/local/reading_position_service.dart';
import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../ai/chunking/chunking_service.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../studio/studio_hub_screen.dart';
import 'comic/comic_parser.dart';
import 'comic/comic_reader_screen.dart';
import 'docx/docx_parser.dart';
import 'docx/docx_reader_screen.dart';
import 'epub/epub_parser.dart';
import 'epub/epub_reader_screen.dart';
import 'mobi/mobi_parser.dart';
import 'mobi/mobi_reader_screen.dart';
import 'pdf/pdf_parser.dart';
import 'pdf/pdf_reader_screen.dart';
import 'shared/ai_speed_dial_fab.dart';
import 'shared/chapter_list_drawer.dart';
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

class _ReaderShellState extends ConsumerState<ReaderShell> {
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
  int _currentChapterIndex = 0;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _loadBookAndChapters();
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

    return Scaffold(
      key: _scaffoldKey,
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
              actions: isComic
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted_rounded),
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
                  padding: const EdgeInsets.only(bottom: 58),
                  child: AiSpeedDialFab(
                    isVisible: _showChrome,
                    onOpenStudio: _openStudio,
                    onOpenChat: _openAiChat,
                  ),
                ),
              ),
            ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction != ScrollDirection.idle) {
            _hideChrome();
          }
          return false;
        },
        child: _buildFormatBody(),
      ),
    );
  }
}
