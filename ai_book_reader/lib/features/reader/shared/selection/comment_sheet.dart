import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/annotation_repository.dart';
import '../../../../data/models/annotation.dart';
import 'annotation_colors.dart';
import 'highlight_color_picker.dart';
import 'selection_context.dart';

Future<bool?> showCommentSheet({
  required BuildContext context,
  required SelectionContext selection,
  Annotation? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => CommentSheet(
      selection: selection,
      existing: existing,
    ),
  );
}

Future<bool?> showAnnotationEditorSheet({
  required BuildContext context,
  required Annotation annotation,
  required String bookTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => CommentSheet(
      selection: SelectionContext(
        bookId: annotation.bookId,
        bookTitle: bookTitle,
        chapterId: annotation.chapterId,
        selectedText: annotation.selectedText,
        startOffset: annotation.startOffset,
        endOffset: annotation.endOffset,
      ),
      existing: annotation,
    ),
  );
}

class CommentSheet extends ConsumerStatefulWidget {
  final SelectionContext selection;
  final Annotation? existing;

  const CommentSheet({
    super.key,
    required this.selection,
    this.existing,
  });

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  late final TextEditingController _controller;
  late AnnotationColor _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.comment ?? '');
    _color = widget.existing?.color ?? AnnotationColor.yellow;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(annotationRepositoryProvider);
    final now = DateTime.now();
    final annotation = widget.existing ?? Annotation();
    annotation
      ..bookId = widget.selection.bookId
      ..chapterId = widget.selection.chapterId
      ..selectedText = widget.selection.selectedText
      ..startOffset = widget.selection.startOffset
      ..endOffset = widget.selection.endOffset
      ..color = _color
      ..comment = _controller.text.trim().isEmpty ? null : _controller.text.trim()
      ..createdAt = widget.existing?.createdAt ?? now
      ..updatedAt = now;

    await repo.save(annotation);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete highlight?'),
        content: const Text('This removes the highlight and any comment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(annotationRepositoryProvider).delete(existing.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final quote = widget.selection.selectedText;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add comment' : 'Edit highlight',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _color.fillColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              quote.length > 280 ? '${quote.substring(0, 280)}…' : quote,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Color', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showHighlightColorPicker(context);
                  if (picked != null) setState(() => _color = picked);
                },
                icon: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _color.swatchColor,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(_color.label),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write a note about this passage…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: const Text('Delete'),
                ),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
