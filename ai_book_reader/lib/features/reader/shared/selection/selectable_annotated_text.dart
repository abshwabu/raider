import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/annotation_repository.dart';
import '../../../../data/models/annotation.dart';
import 'comment_sheet.dart';
import 'highlight_text_span_builder.dart';
import 'selection_action_toolbar.dart';
import 'selection_context.dart';

/// Selectable chapter body with persisted highlights and selection actions.
class SelectableAnnotatedText extends ConsumerStatefulWidget {
  final int bookId;
  final String bookTitle;
  final int chapterId;
  final String text;
  final TextStyle style;
  final VoidCallback? onTap;
  final TextRange? activeTtsRange;
  final Color? ttsHighlightColor;
  final TextAlign? textAlign;

  const SelectableAnnotatedText({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapterId,
    required this.text,
    required this.style,
    this.onTap,
    this.activeTtsRange,
    this.ttsHighlightColor,
    this.textAlign,
  });

  @override
  ConsumerState<SelectableAnnotatedText> createState() =>
      _SelectableAnnotatedTextState();
}

class _SelectableAnnotatedTextState
    extends ConsumerState<SelectableAnnotatedText> {
  List<Annotation> _annotations = [];
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
  }

  @override
  void didUpdateWidget(covariant SelectableAnnotatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.text != widget.text) {
      _loadAnnotations();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _loadAnnotations() async {
    final list = await ref
        .read(annotationRepositoryProvider)
        .getForChapter(widget.bookId, widget.chapterId);
    if (!mounted) return;
    setState(() {
      _annotations = list;
    });
  }

  Future<void> _onTapAnnotation(Annotation annotation) async {
    final changed = await showAnnotationEditorSheet(
      context: context,
      annotation: annotation,
      bookTitle: widget.bookTitle,
    );
    if (changed == true) await _loadAnnotations();
  }

  @override
  Widget build(BuildContext context) {
    final staleRecognizers = List<TapGestureRecognizer>.of(_recognizers);
    _recognizers.clear();
    final span = HighlightTextSpanBuilder.build(
      text: widget.text,
      annotations: _annotations,
      baseStyle: widget.style,
      onTapAnnotation: _onTapAnnotation,
      recognizersOut: _recognizers,
      activeTtsRange: widget.activeTtsRange,
      ttsHighlightColor: widget.ttsHighlightColor,
    );
    if (staleRecognizers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final r in staleRecognizers) {
          r.dispose();
        }
      });
    }

    // Always attach the custom menu (even while annotations are loading).
    return SelectableText.rich(
      span,
      onTap: widget.onTap,
      textAlign: widget.textAlign,
      contextMenuBuilder: (context, editableTextState) {
        return buildSelectionActionToolbar(
          context: context,
          editableTextState: editableTextState,
          buildContext: (selected, start, end) => SelectionContext(
            bookId: widget.bookId,
            bookTitle: widget.bookTitle,
            chapterId: widget.chapterId,
            selectedText: selected,
            startOffset: start,
            endOffset: end,
          ),
          onAnnotationsChanged: _loadAnnotations,
        );
      },
    );
  }
}
