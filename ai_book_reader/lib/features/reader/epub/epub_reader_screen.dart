import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import 'epub_parser.dart';

class EpubReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const EpubReaderScreen({
    super.key,
    required this.bookId,
  });

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  Book? _book;
  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBookData() async {
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
      if (chapters.isEmpty) {
        chapters = await EpubParser.extractChapters(
          bookId: book.id,
          filePath: book.filePath,
          chapterRepository: chapterRepo,
          bookRepository: bookRepo,
        );
      }

      int initialChapterIndex = 0;
      if (chapters.isNotEmpty && book.readingProgress > 0) {
        initialChapterIndex = (book.readingProgress * chapters.length)
            .floor()
            .clamp(0, chapters.length - 1);
      }

      setState(() {
        _book = book;
        _chapters = chapters;
        _currentChapterIndex = initialChapterIndex;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    setState(() {
      _currentChapterIndex = index;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _saveProgress();
  }

  void _saveProgress() {
    if (_book != null && _chapters.isNotEmpty) {
      final progress = ((_currentChapterIndex + 1) / _chapters.length).clamp(0.0, 1.0);
      ref.read(bookRepositoryProvider).updateReadingProgress(_book!.id, progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading EPUB...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_book == null || _chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('EPUB book could not be loaded or has no chapters.'),
        ),
      );
    }

    final currentChapter = _chapters[_currentChapterIndex];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_book!.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted_rounded),
            tooltip: 'Table of Contents',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _book!.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_chapters.length} chapters',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentChapterIndex;
                  return ListTile(
                    selected: isSelected,
                    title: Text(
                      _chapters[index].title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      _goToChapter(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentChapter.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Divider(height: 24),
                  Html(
                    data: currentChapter.content,
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous Chapter',
                  onPressed: _currentChapterIndex > 0
                      ? () => _goToChapter(_currentChapterIndex - 1)
                      : null,
                ),
                Text(
                  'Chapter ${_currentChapterIndex + 1} of ${_chapters.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next Chapter',
                  onPressed: _currentChapterIndex < _chapters.length - 1
                      ? () => _goToChapter(_currentChapterIndex + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
