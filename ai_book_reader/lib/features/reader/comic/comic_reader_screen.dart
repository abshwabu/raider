import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/models/book.dart';

class ComicReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  final List<String> pagePaths;

  const ComicReaderScreen({
    super.key,
    required this.book,
    required this.pagePaths,
  });

  @override
  ConsumerState<ComicReaderScreen> createState() => ComicReaderScreenState();
}

class ComicReaderScreenState extends ConsumerState<ComicReaderScreen> {
  late final PageController _pageController;
  int _currentPageIndex = 0;

  int get currentPageIndex => _currentPageIndex;

  @override
  void initState() {
    super.initState();
    if (widget.pagePaths.isNotEmpty && widget.book.readingProgress > 0) {
      _currentPageIndex = (widget.book.readingProgress * widget.pagePaths.length)
          .floor()
          .clamp(0, widget.pagePaths.length - 1);
    }
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void jumpToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= widget.pagePaths.length) return;
    setState(() {
      _currentPageIndex = pageIndex;
    });
    _pageController.jumpToPage(pageIndex);
    _saveProgress();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    _saveProgress();
  }

  void _saveProgress() {
    if (widget.pagePaths.isNotEmpty) {
      final progress = ((_currentPageIndex + 1) / widget.pagePaths.length).clamp(0.0, 1.0);
      ref.read(bookRepositoryProvider).updateReadingProgress(widget.book.id, progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = widget.book.format.toLowerCase();

    if (format == 'cbr') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'CBR format is not supported yet',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please convert your RAR-compressed comic (.cbr) to ZIP-compressed (.cbz) format to read it.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (widget.pagePaths.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_not_supported_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No comic pages found in this file.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.pagePaths.length,
            itemBuilder: (context, index) {
              final path = widget.pagePaths[index];
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text('Failed to load image page.'),
                      );
                    },
                  ),
                ),
              );
            },
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
                tooltip: 'Previous Page',
                onPressed: _currentPageIndex > 0
                    ? () => jumpToPage(_currentPageIndex - 1)
                    : null,
              ),
              Text(
                'Page ${_currentPageIndex + 1} of ${widget.pagePaths.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next Page',
                onPressed: _currentPageIndex < widget.pagePaths.length - 1
                    ? () => jumpToPage(_currentPageIndex + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
