import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';

class HtmlChapterView extends ConsumerStatefulWidget {
  final Book book;
  final List<Chapter> chapters;
  final String emptyMessage;

  const HtmlChapterView({
    super.key,
    required this.book,
    required this.chapters,
    this.emptyMessage = 'Book has no chapters.',
  });

  @override
  ConsumerState<HtmlChapterView> createState() => HtmlChapterViewState();
}

class HtmlChapterViewState extends ConsumerState<HtmlChapterView> {
  final ScrollController _scrollController = ScrollController();
  int _currentChapterIndex = 0;

  int get currentChapterIndex => _currentChapterIndex;

  @override
  void initState() {
    super.initState();
    if (widget.chapters.isNotEmpty && widget.book.readingProgress > 0) {
      _currentChapterIndex = (widget.book.readingProgress * widget.chapters.length)
          .floor()
          .clamp(0, widget.chapters.length - 1);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void jumpToChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    setState(() {
      _currentChapterIndex = index;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _saveProgress();
  }

  void _saveProgress() {
    if (widget.chapters.isNotEmpty) {
      final progress = ((_currentChapterIndex + 1) / widget.chapters.length).clamp(0.0, 1.0);
      ref.read(bookRepositoryProvider).updateReadingProgress(widget.book.id, progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return Center(
        child: Text(widget.emptyMessage),
      );
    }

    final currentChapter = widget.chapters[_currentChapterIndex];

    return Column(
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
                    ? () => jumpToChapter(_currentChapterIndex - 1)
                    : null,
              ),
              Text(
                'Chapter ${_currentChapterIndex + 1} of ${widget.chapters.length}',
                style: Theme.of(context).textTheme.bodyMedium,
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
    );
  }
}
