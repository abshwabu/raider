import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  final List<Chapter> chapters;
  final PdfViewerController? pdfViewerController;

  const PdfReaderScreen({
    super.key,
    required this.book,
    required this.chapters,
    this.pdfViewerController,
  });

  @override
  ConsumerState<PdfReaderScreen> createState() => PdfReaderScreenState();
}

class PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  late final PdfViewerController _pdfViewerController;
  bool _hasRestoredPosition = false;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = widget.pdfViewerController ?? PdfViewerController();
  }

  void jumpToChapter(Chapter chapter) {
    final targetPage = _parseStartPage(chapter);
    _pdfViewerController.jumpToPage(targetPage);
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

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    _totalPages = details.document.pages.count;
    if (!_hasRestoredPosition && widget.book.readingProgress > 0 && _totalPages > 0) {
      _hasRestoredPosition = true;
      final targetPage = (widget.book.readingProgress * _totalPages).round().clamp(1, _totalPages);
      if (targetPage > 1) {
        Future.microtask(() {
          _pdfViewerController.jumpToPage(targetPage);
        });
      }
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    if (_totalPages > 0) {
      final progress = (details.newPageNumber / _totalPages).clamp(0.0, 1.0);
      ref.read(bookRepositoryProvider).updateReadingProgress(widget.book.id, progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!File(widget.book.filePath).existsSync()) {
      return const Center(
        child: Text('PDF file could not be loaded or does not exist.'),
      );
    }

    return SfPdfViewer.file(
      File(widget.book.filePath),
      controller: _pdfViewerController,
      onDocumentLoaded: _onDocumentLoaded,
      onPageChanged: _onPageChanged,
    );
  }
}
