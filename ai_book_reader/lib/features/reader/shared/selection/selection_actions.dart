import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/annotation_repository.dart';
import '../../../../data/models/annotation.dart';
import '../../../ai_chat/ai_chat_screen.dart';
import 'comment_sheet.dart';
import 'dictionary_sheet.dart';
import 'highlight_color_picker.dart';
import 'selection_context.dart';
import 'translate_sheet.dart';

enum SelectionAction {
  highlight,
  comment,
  translate,
  dictionary,
  askAi,
  copy,
}

/// Shared action chips used by text readers and PDF selection overlays.
class SelectionActionsBar extends StatelessWidget {
  final ValueChanged<SelectionAction> onAction;
  final bool compact;

  const SelectionActionsBar({
    super.key,
    required this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(SelectionAction, IconData, String)>[
      (SelectionAction.highlight, Icons.highlight_rounded, 'Highlight'),
      (SelectionAction.comment, Icons.comment_outlined, 'Comment'),
      (SelectionAction.translate, Icons.translate_rounded, 'Translate'),
      (SelectionAction.dictionary, Icons.menu_book_outlined, 'Dictionary'),
      (SelectionAction.askAi, Icons.auto_awesome_rounded, 'Ask AI'),
    ];

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: compact ? 4 : 6,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 4 : 8,
                      ),
                    ),
                    onPressed: () => onAction(item.$1),
                    icon: Icon(item.$2, size: compact ? 18 : 20),
                    label: Text(item.$3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> handleSelectionAction({
  required BuildContext context,
  required SelectionAction action,
  required SelectionContext selection,
  Future<void> Function()? onAnnotationsChanged,
  Future<void> Function(AnnotationColor color)? onHighlightVisual,
  VoidCallback? clearSelection,
}) async {
  if (!selection.isValid) return;

  switch (action) {
    case SelectionAction.copy:
      // Handled by platform when present.
      break;
    case SelectionAction.highlight:
      final color = await showHighlightColorPicker(context);
      if (color == null || !context.mounted) return;
      if (onHighlightVisual != null) {
        await onHighlightVisual(color);
      } else {
        await _saveHighlight(context, selection, color);
      }
      await onAnnotationsChanged?.call();
      clearSelection?.call();
      break;
    case SelectionAction.comment:
      final saved = await showCommentSheet(
        context: context,
        selection: selection,
      );
      if (saved == true) await onAnnotationsChanged?.call();
      clearSelection?.call();
      break;
    case SelectionAction.translate:
      clearSelection?.call();
      if (!context.mounted) return;
      await showTranslateSheet(
        context: context,
        selectedText: selection.selectedText,
      );
      break;
    case SelectionAction.dictionary:
      clearSelection?.call();
      if (!context.mounted) return;
      await showDictionarySheet(
        context: context,
        selectedText: selection.selectedText,
      );
      break;
    case SelectionAction.askAi:
      clearSelection?.call();
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AiChatScreen(
          bookId: selection.bookId,
          bookTitle: selection.bookTitle,
          selectedPassage: selection.selectedText,
          chapterId: selection.chapterId,
        ),
      );
      break;
  }
}

Future<void> _saveHighlight(
  BuildContext context,
  SelectionContext selCtx,
  AnnotationColor color,
) async {
  final container = ProviderScope.containerOf(context);
  final repo = container.read(annotationRepositoryProvider);
  final now = DateTime.now();
  final annotation = Annotation()
    ..bookId = selCtx.bookId
    ..chapterId = selCtx.chapterId
    ..selectedText = selCtx.selectedText
    ..startOffset = selCtx.startOffset
    ..endOffset = selCtx.endOffset
    ..color = color
    ..comment = null
    ..createdAt = now
    ..updatedAt = now;
  await repo.save(annotation);
}
