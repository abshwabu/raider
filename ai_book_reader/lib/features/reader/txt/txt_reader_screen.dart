import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/reading_position_service.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import '../shared/selection/selectable_annotated_text.dart';

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
  final Book book;
  final List<Chapter> chapters;
  final ValueChanged<int>? onChapterChanged;
  final bool showControls;
  final VoidCallback? onTapBody;

  const TxtReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
    this.onChapterChanged,
    this.showControls = true,
    this.onTapBody,
  });

  @override
  ConsumerState<TxtReaderScreen> createState() => TxtReaderScreenState();
}

class TxtReaderScreenState extends ConsumerState<TxtReaderScreen> {
  late final ScrollController _scrollController;
  int _currentChapterIndex = 0;
  Timer? _debounceTimer;

  double _fontSize = 16.0;
  TxtReaderTheme _readerTheme = TxtReaderTheme.light;

  int get currentChapterIndex => _currentChapterIndex;

  @override
  void initState() {
    super.initState();
    final positionService = ref.read(readingPositionServiceProvider);

    if (widget.chapters.isNotEmpty) {
      _currentChapterIndex = positionService.getLastChapterIndexSync(
        widget.book.id,
        fallbackProgress: widget.book.readingProgress,
        totalChapters: widget.chapters.length,
      );
    }

    final initialOffset = positionService.getChapterScrollOffsetSync(
      widget.book.id,
      _currentChapterIndex,
    );
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollPosition();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveCurrentPosition();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), _saveCurrentPosition);
  }

  void _restoreScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    final positionService = ref.read(readingPositionServiceProvider);
    final savedOffset = positionService.getChapterScrollOffsetSync(
      widget.book.id,
      _currentChapterIndex,
    );
    final savedFraction = positionService.getChapterScrollFractionSync(
      widget.book.id,
      _currentChapterIndex,
    );

    void apply() {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0 && savedOffset <= 0) return;

      double target = savedOffset;
      if (maxExtent > 0 && savedFraction > 0) {
        target = (savedFraction * maxExtent).clamp(0.0, maxExtent);
      } else if (maxExtent > 0) {
        target = savedOffset.clamp(0.0, maxExtent);
      }

      if ((_scrollController.offset - target).abs() > 2.0) {
        _scrollController.jumpTo(target);
      }
    }

    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      apply();
    });
  }

  void jumpToChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    _saveCurrentPosition();

    setState(() {
      _currentChapterIndex = index;
    });

    widget.onChapterChanged?.call(index);

    final positionService = ref.read(readingPositionServiceProvider);
    final savedOffset = positionService.getChapterScrollOffsetSync(widget.book.id, index);

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(savedOffset);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollPosition();
    });

    _saveCurrentPosition();
  }

  void _saveCurrentPosition() {
    if (!_scrollController.hasClients || widget.chapters.isEmpty) return;
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final positionService = ref.read(readingPositionServiceProvider);

    positionService.savePositionSync(
      bookId: widget.book.id,
      chapterIndex: _currentChapterIndex,
      scrollOffset: offset,
      maxScrollExtent: maxExtent,
      totalChapters: widget.chapters.length,
    );

    final progress = ReadingPositionService.calculateOverallProgress(
      chapterIndex: _currentChapterIndex,
      scrollOffset: offset,
      maxScrollExtent: maxExtent,
      totalChapters: widget.chapters.length,
    );

    ref.read(bookRepositoryProvider).updateReadingProgress(widget.book.id, progress);
  }

  void showSettingsModal() {
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
    if (widget.chapters.isEmpty) {
      return const Center(
        child: Text('Text file has no chapters.'),
      );
    }

    final currentChapter = widget.chapters[_currentChapterIndex];

    return Container(
      color: _readerTheme.backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTapBody,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            currentChapter.title,
                            style: TextStyle(
                              fontSize: _fontSize * 1.3,
                              fontWeight: FontWeight.bold,
                              color: _readerTheme.textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.text_fields_rounded,
                            color: _readerTheme.textColor,
                          ),
                          tooltip: 'Font & Theme Settings',
                          onPressed: showSettingsModal,
                        ),
                      ],
                    ),
                    Divider(
                      height: 24,
                      color: _readerTheme.textColor.withValues(alpha: 0.3),
                    ),
                    SelectableAnnotatedText(
                      bookId: widget.book.id,
                      bookTitle: widget.book.title,
                      chapterId: currentChapter.id,
                      text: currentChapter.content,
                      onTap: widget.onTapBody,
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
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: widget.showControls
                ? Container(
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
                              ? () => jumpToChapter(_currentChapterIndex - 1)
                              : null,
                        ),
                        Text(
                          'Section ${_currentChapterIndex + 1} of ${widget.chapters.length}',
                          style: TextStyle(color: _readerTheme.textColor),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: _readerTheme.textColor,
                          ),
                          tooltip: 'Next Section',
                          onPressed: _currentChapterIndex < widget.chapters.length - 1
                              ? () => jumpToChapter(_currentChapterIndex + 1)
                              : null,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
