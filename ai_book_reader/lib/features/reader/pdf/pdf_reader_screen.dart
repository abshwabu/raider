import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart' hide Annotation;
import '../../../data/local/annotation_repository.dart';
import '../../../data/local/book_repository.dart';
import '../../../data/models/annotation.dart';
import '../../../data/models/book.dart';
import '../../../data/models/chapter.dart';
import '../shared/selection/annotation_colors.dart';
import '../shared/selection/selection_actions.dart';
import '../shared/selection/selection_context.dart';

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
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  OverlayEntry? _selectionOverlay;
  String? _selectedText;
  int _totalPages = 0;
  bool _hasRestoredPosition = false;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = widget.pdfViewerController ?? PdfViewerController();
  }

  @override
  void dispose() {
    _removeSelectionOverlay();
    super.dispose();
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
      final targetPage =
          (widget.book.readingProgress * _totalPages).round().clamp(1, _totalPages);
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

  int _chapterIdForPage(int pageNumber) {
    if (widget.chapters.isEmpty) return pageNumber;
    for (final chapter in widget.chapters) {
      if (_parseStartPage(chapter) == pageNumber) return chapter.id;
    }
    // Prefer nearest earlier chapter start page.
    Chapter? best;
    for (final chapter in widget.chapters) {
      final start = _parseStartPage(chapter);
      if (start <= pageNumber &&
          (best == null || _parseStartPage(best) < start)) {
        best = chapter;
      }
    }
    return best?.id ?? widget.chapters.first.id;
  }

  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    final text = details.selectedText?.trim();
    if (text == null || text.isEmpty) {
      _selectedText = null;
      _removeSelectionOverlay();
      return;
    }

    _selectedText = details.selectedText;
    final region = details.globalSelectedRegion;
    if (region == null) return;

    _showSelectionOverlay(region);
  }

  void _removeSelectionOverlay() {
    _selectionOverlay?.remove();
    _selectionOverlay = null;
  }

  void _showSelectionOverlay(Rect globalRegion) {
    _removeSelectionOverlay();
    final overlay = Overlay.of(context);
    final media = MediaQuery.sizeOf(context);

    _selectionOverlay = OverlayEntry(
      builder: (context) {
        const barHeight = 56.0;
        final top = (globalRegion.top - barHeight - 8)
            .clamp(8.0, media.height - barHeight - 8);
        return Positioned(
          left: 8,
          right: 8,
          top: top,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SelectionActionsBar(
                compact: true,
                onAction: (action) => _onSelectionAction(action),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_selectionOverlay!);
  }

  Future<void> _onSelectionAction(SelectionAction action) async {
    final selected = _selectedText;
    if (selected == null || selected.trim().isEmpty) return;

    final lines = _pdfViewerKey.currentState?.getSelectedTextLines() ?? [];
    final pageNumber = lines.isNotEmpty
        ? lines.first.pageNumber
        : _pdfViewerController.pageNumber;
    final chapterId = _chapterIdForPage(pageNumber);
    final selection = SelectionContext(
      bookId: widget.book.id,
      bookTitle: widget.book.title,
      chapterId: chapterId,
      selectedText: selected,
      startOffset: 0,
      endOffset: selected.length,
    );

    await handleSelectionAction(
      context: context,
      action: action,
      selection: selection,
      onHighlightVisual: (color) async {
        await _applyPdfHighlight(color);
        await _persistPdfAnnotation(
          selection: selection,
          color: color,
          pageNumber: pageNumber,
        );
      },
      onAnnotationsChanged: () async {},
      clearSelection: () {
        _pdfViewerController.clearSelection();
        _removeSelectionOverlay();
        _selectedText = null;
      },
    );
  }

  Future<void> _applyPdfHighlight(AnnotationColor color) async {
    final lines = _pdfViewerKey.currentState?.getSelectedTextLines() ?? [];
    if (lines.isEmpty) return;
    final annotation = HighlightAnnotation(textBoundsCollection: lines);
    annotation.color = color.swatchColor;
    _pdfViewerController.addAnnotation(annotation);
  }

  Future<void> _persistPdfAnnotation({
    required SelectionContext selection,
    required AnnotationColor color,
    required int pageNumber,
  }) async {
    final now = DateTime.now();
    final annotation = Annotation()
      ..bookId = selection.bookId
      ..chapterId = selection.chapterId
      ..selectedText = selection.selectedText
      ..startOffset = pageNumber
      ..endOffset = pageNumber
      ..color = color
      ..comment = null
      ..createdAt = now
      ..updatedAt = now;
    await ref.read(annotationRepositoryProvider).save(annotation);
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
      key: _pdfViewerKey,
      controller: _pdfViewerController,
      canShowTextSelectionMenu: false,
      enableTextSelection: true,
      onDocumentLoaded: _onDocumentLoaded,
      onPageChanged: _onPageChanged,
      onTextSelectionChanged: _onTextSelectionChanged,
    );
  }
}
