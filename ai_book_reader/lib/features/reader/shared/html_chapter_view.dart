import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/reading_position_service.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import 'selection/html_plain_text.dart';
import 'selection/selectable_annotated_text.dart';

class HtmlChapterView extends ConsumerStatefulWidget {
  final Book book;
  final List<Chapter> chapters;
  final String emptyMessage;
  final ValueChanged<int>? onChapterChanged;
  final bool showControls;
  final VoidCallback? onTapBody;

  const HtmlChapterView({
    super.key,
    required this.book,
    required this.chapters,
    this.emptyMessage = 'Book has no chapters.',
    this.onChapterChanged,
    this.showControls = true,
    this.onTapBody,
  });

  @override
  ConsumerState<HtmlChapterView> createState() => HtmlChapterViewState();
}

class HtmlChapterViewState extends ConsumerState<HtmlChapterView> {
  late final ScrollController _scrollController;
  int _currentChapterIndex = 0;
  Timer? _debounceTimer;
  double _inChapterProgress = 0.0;

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
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 0) {
      final fraction = (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
      if ((fraction - _inChapterProgress).abs() > 0.01) {
        setState(() {
          _inChapterProgress = fraction;
        });
      }
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), _saveCurrentPosition);
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
      if (maxExtent > 0) {
        setState(() {
          _inChapterProgress = (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
        });
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

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return Center(
        child: Text(widget.emptyMessage),
      );
    }

    final currentChapter = widget.chapters[_currentChapterIndex];
    final plainText = htmlToPlainText(currentChapter.content);
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTapBody,
            child: SingleChildScrollView(
              key: PageStorageKey('html_chapter_${widget.book.id}_$_currentChapterIndex'),
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentChapter.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Divider(height: 24),
                  SelectableAnnotatedText(
                    bookId: widget.book.id,
                    bookTitle: widget.book.title,
                    chapterId: currentChapter.id,
                    text: plainText,
                    onTap: widget.onTapBody,
                    style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ) ??
                        const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        // In-chapter reading progress and navigation controls (collapsible during reading)
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: widget.showControls
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _inChapterProgress.clamp(0.0, 1.0),
                      minHeight: 2.5,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary.withAlpha(200),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            tooltip: 'Previous Chapter',
                            onPressed: _currentChapterIndex > 0
                                ? () => jumpToChapter(_currentChapterIndex - 1)
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              'Chapter ${_currentChapterIndex + 1} of ${widget.chapters.length} · ${(_inChapterProgress * 100).round()}%',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: 'Next Chapter',
                            onPressed: _currentChapterIndex < widget.chapters.length - 1
                                ? () => jumpToChapter(_currentChapterIndex + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
