import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';

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

  const TxtReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
  });

  @override
  ConsumerState<TxtReaderScreen> createState() => TxtReaderScreenState();
}

class TxtReaderScreenState extends ConsumerState<TxtReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentChapterIndex = 0;

  double _fontSize = 16.0;
  TxtReaderTheme _readerTheme = TxtReaderTheme.light;

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
            child: SingleChildScrollView(
              controller: _scrollController,
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
          ),
        ],
      ),
    );
  }
}
