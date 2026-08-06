import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import '../shared/html_chapter_view.dart';

class MobiReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  final List<Chapter> chapters;

  const MobiReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
  });

  @override
  ConsumerState<MobiReaderScreen> createState() => MobiReaderScreenState();
}

class MobiReaderScreenState extends ConsumerState<MobiReaderScreen> {
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
      emptyMessage: 'MOBI/AZW3 book has no chapters.',
    );
  }
}
