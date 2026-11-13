import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import '../shared/html_chapter_view.dart';

class EpubReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  final List<Chapter> chapters;
  final ValueChanged<int>? onChapterChanged;

  const EpubReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
    this.onChapterChanged,
  });

  @override
  ConsumerState<EpubReaderScreen> createState() => EpubReaderScreenState();
}

class EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  final GlobalKey<HtmlChapterViewState> _htmlViewKey = GlobalKey<HtmlChapterViewState>();

  int get currentChapterIndex => _htmlViewKey.currentState?.currentChapterIndex ?? 0;

  void jumpToChapter(int index) {
    _htmlViewKey.currentState?.jumpToChapter(index);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlChapterView(
      key: _htmlViewKey,
      book: widget.book,
      chapters: widget.chapters,
      onChapterChanged: widget.onChapterChanged,
      emptyMessage: 'EPUB book has no chapters.',
    );
  }
}
