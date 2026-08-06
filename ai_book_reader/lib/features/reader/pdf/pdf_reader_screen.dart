import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/local/chapter_repository.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import 'pdf_parser.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const PdfReaderScreen({
    super.key,
    required this.bookId,
  });

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Book? _book;
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _hasRestoredPosition = false;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadBookData();
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
        chapters = await PdfParser.extractChapters(
          bookId: book.id,
          filePath: book.filePath,
          chapterRepository: chapterRepo,
        );
      }
      setState(() {
        _book = book;
        _chapters = chapters;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    _totalPages = details.document.pages.count;
    if (!_hasRestoredPosition && _book != null && _book!.readingProgress > 0 && _totalPages > 0) {
      _hasRestoredPosition = true;
      final targetPage = (_book!.readingProgress * _totalPages).round().clamp(1, _totalPages);
      if (targetPage > 1) {
        Future.microtask(() {
          _pdfViewerController.jumpToPage(targetPage);
        });
      }
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    if (_totalPages > 0 && _book != null) {
      final progress = (details.newPageNumber / _totalPages).clamp(0.0, 1.0);
      ref.read(bookRepositoryProvider).updateReadingProgress(_book!.id, progress);
    }
  }

  int _parseStartPage(Chapter chapter) {
    final match = RegExp(r'(?:p\.\s*|Pages\s*)(\d+)').firstMatch(chapter.title);
    if (match != null) {
      final pStr = match.group(1);
      if (pStr != null) {
        return int.tryParse(pStr) ?? 1;
      }
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading PDF...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_book == null || !File(_book!.filePath).existsSync()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('PDF file could not be loaded or does not exist.'),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_book!.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted_rounded),
            tooltip: 'Chapters & Outlines',
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
                      '${_chapters.length} chapters / sections',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _chapters.isEmpty
                  ? const Center(child: Text('No chapter bookmarks available'))
                  : ListView.builder(
                      itemCount: _chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = _chapters[index];
                        final targetPage = _parseStartPage(chapter);

                        return ListTile(
                          title: Text(chapter.title),
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop(); // Close drawer
                            _pdfViewerController.jumpToPage(targetPage);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      body: SfPdfViewer.file(
        File(_book!.filePath),
        controller: _pdfViewerController,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: _onPageChanged,
      ),
    );
  }
}
