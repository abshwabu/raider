import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import '../shared/html_chapter_view.dart';

class EpubReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  final List<Chapter> chapters;
  final ValueChanged<int>? onChapterChanged;
  final bool showControls;
  final VoidCallback? onTapBody;

  const EpubReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
    this.onChapterChanged,
    this.showControls = true,
    this.onTapBody,
  });

  @override
  ConsumerState<EpubReaderScreen> createState() => EpubReaderScreenState();
}

class EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  final GlobalKey<HtmlChapterViewState> _htmlViewKey = GlobalKey<HtmlChapterViewState>();

  int get currentChapterIndex => _htmlViewKey.currentState?.currentChapterIndex ?? 0;

  String getCurrentChapterPlainText() =>
      _htmlViewKey.currentState?.getCurrentChapterPlainText() ?? '';

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
      showControls: widget.showControls,
      onTapBody: widget.onTapBody,
      emptyMessage: 'EPUB book has no chapters.',
    );
  }
}
