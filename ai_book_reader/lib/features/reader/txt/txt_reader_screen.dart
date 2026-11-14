import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/reading_position_service.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import '../shared/reader_preferences.dart';
import '../shared/reader_settings_sheet.dart';
import '../shared/selection/selectable_annotated_text.dart';
import '../tts/tts_service.dart';

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

  int get currentChapterIndex => _currentChapterIndex;

  String getCurrentChapterPlainText() {
    if (_currentChapterIndex >= 0 && _currentChapterIndex < widget.chapters.length) {
      return widget.chapters[_currentChapterIndex].content;
    }
    return '';
  }

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
    showReaderSettingsSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return const Center(
        child: Text('Text file has no chapters.'),
      );
    }

    final currentChapter = widget.chapters[_currentChapterIndex];
    final prefs = ref.watch(readerPreferencesProvider);
    final ttsState = ref.watch(ttsServiceProvider);
    final themeMode = prefs.themeMode;

    TextRange? activeTtsRange;
    if (ttsState.chapterId == currentChapter.id &&
        ttsState.currentParagraph != null &&
        (ttsState.isPlaying || ttsState.isPaused)) {
      activeTtsRange = TextRange(
        start: ttsState.currentParagraph!.startOffset,
        end: ttsState.currentParagraph!.endOffset,
      );
    }

    return Container(
      color: themeMode.backgroundColor,
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
                padding: EdgeInsets.symmetric(
                  horizontal: prefs.horizontalPadding,
                  vertical: 14.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            currentChapter.title,
                            style: prefs
                                .getTextStyle(
                                  overrideFontSize: prefs.fontSize * 1.35,
                                )
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.text_format_rounded,
                            color: themeMode.textColor.withValues(alpha: 0.8),
                          ),
                          tooltip: 'Reader Appearance',
                          onPressed: showSettingsModal,
                        ),
                      ],
                    ),
                    Divider(
                      height: 24,
                      color: themeMode.borderColor,
                    ),
                    SelectableAnnotatedText(
                      bookId: widget.book.id,
                      bookTitle: widget.book.title,
                      chapterId: currentChapter.id,
                      text: currentChapter.content,
                      onTap: widget.onTapBody,
                      activeTtsRange: activeTtsRange,
                      ttsHighlightColor: themeMode.accentColor,
                      textAlign: prefs.isJustified
                          ? TextAlign.justify
                          : TextAlign.left,
                      style: prefs.getTextStyle(),
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
                    color: themeMode.cardColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: themeMode.textColor,
                          ),
                          tooltip: 'Previous Section',
                          onPressed: _currentChapterIndex > 0
                              ? () => jumpToChapter(_currentChapterIndex - 1)
                              : null,
                        ),
                        Text(
                          'Section ${_currentChapterIndex + 1} of ${widget.chapters.length}',
                          style: TextStyle(
                            color: themeMode.textColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: themeMode.textColor,
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
