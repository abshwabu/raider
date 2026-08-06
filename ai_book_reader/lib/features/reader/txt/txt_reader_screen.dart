import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import 'txt_parser.dart';

enum TxtReaderTheme {
  light(
    name: 'Light',
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1A1A1A),
  ),
  sepia(
    name: 'Sepia',
    backgroundColor: Color(0xFFFBF0D9),
    textColor: Color(0xFF5F4B32),
  ),
  dark(
    name: 'Dark',
    backgroundColor: Color(0xFF121212),
    textColor: Color(0xFFE0E0E0),
  );

  final String name;
  final Color backgroundColor;
  final Color textColor;

  const TxtReaderTheme({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
  });
}

class TxtReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const TxtReaderScreen({
    super.key,
    required this.bookId,
  });

  @override
  ConsumerState<TxtReaderScreen> createState() => _TxtReaderScreenState();
}

class _TxtReaderScreenState extends ConsumerState<TxtReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  Book? _book;
  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  bool _isLoading = true;

  double _fontSize = 16.0;
  TxtReaderTheme _readerTheme = TxtReaderTheme.light;

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
        chapters = await TxtParser.extractChapters(
          bookId: book.id,
          filePath: book.filePath,
          chapterRepository: chapterRepo,
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

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reader Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Font Size (${_fontSize.toInt()}pt)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12.0,
                          max: 28.0,
                          divisions: 8,
                          label: '${_fontSize.toInt()}pt',
                          onChanged: (val) {
                            setState(() => _fontSize = val);
                            setModalState(() {});
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Theme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: TxtReaderTheme.values.map((t) {
                      final isSelected = t == _readerTheme;
                      return ChoiceChip(
                        label: Text(t.name),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _readerTheme = t);
                            setModalState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Text...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_book == null || _chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Text file could not be loaded or has no chapters.'),
        ),
      );
    }

    final currentChapter = _chapters[_currentChapterIndex];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _readerTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: _readerTheme.backgroundColor,
        foregroundColor: _readerTheme.textColor,
        title: Text(_book!.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields_rounded),
            tooltip: 'Reader Settings',
            onPressed: _showSettingsModal,
          ),
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
                      '${_chapters.length} sections',
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
                      Navigator.of(context).pop();
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentChapter.title,
                    style: TextStyle(
                      fontSize: _fontSize * 1.3,
                      fontWeight: FontWeight.bold,
                      color: _readerTheme.textColor,
                    ),
                  ),
                  Divider(
                    height: 24,
                    color: _readerTheme.textColor.withValues(alpha: 0.3),
                  ),
                  SelectableText(
                    currentChapter.content,
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: 1.6,
                      color: _readerTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _readerTheme.backgroundColor == Colors.white
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : _readerTheme.textColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: _readerTheme.textColor,
                  ),
                  tooltip: 'Previous Section',
                  onPressed: _currentChapterIndex > 0
                      ? () => _goToChapter(_currentChapterIndex - 1)
                      : null,
                ),
                Text(
                  'Section ${_currentChapterIndex + 1} of ${_chapters.length}',
                  style: TextStyle(color: _readerTheme.textColor),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _readerTheme.textColor,
                  ),
                  tooltip: 'Next Section',
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
