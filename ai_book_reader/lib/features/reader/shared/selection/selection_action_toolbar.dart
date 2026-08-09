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

typedef AnnotationsChanged = Future<void> Function();

/// Builds an adaptive selection toolbar with reader actions.
Widget buildSelectionActionToolbar({
  required BuildContext context,
  required EditableTextState editableTextState,
  required SelectionContext Function(String selected, int start, int end) buildContext,
  required AnnotationsChanged onAnnotationsChanged,
}) {
  final value = editableTextState.textEditingValue;
  final selection = value.selection;
  final buttonItems = <ContextMenuButtonItem>[
    ...editableTextState.contextMenuButtonItems,
  ];

  if (selection.isValid && !selection.isCollapsed) {
    final start = selection.start;
    final end = selection.end;
    final selected = value.text.substring(start, end);
    final selCtx = buildContext(selected, start, end);

    if (selCtx.isValid) {
      buttonItems.addAll([
        ContextMenuButtonItem(
          label: 'Highlight',
          onPressed: () async {
            ContextMenuController.removeAny();
            final color = await showHighlightColorPicker(context);
            if (color == null || !context.mounted) return;
            await _saveHighlight(context, selCtx, color);
            await onAnnotationsChanged();
          },
        ),
        ContextMenuButtonItem(
          label: 'Comment',
          onPressed: () async {
            ContextMenuController.removeAny();
            final saved = await showCommentSheet(
              context: context,
              selection: selCtx,
            );
            if (saved == true) await onAnnotationsChanged();
          },
        ),
        ContextMenuButtonItem(
          label: 'Translate',
          onPressed: () {
            ContextMenuController.removeAny();
            showTranslateSheet(
              context: context,
              selectedText: selCtx.selectedText,
            );
          },
        ),
        ContextMenuButtonItem(
          label: 'Dictionary',
          onPressed: () {
            ContextMenuController.removeAny();
            showDictionarySheet(
              context: context,
              selectedText: selCtx.selectedText,
            );
          },
        ),
        ContextMenuButtonItem(
          label: 'Ask AI',
          onPressed: () {
            ContextMenuController.removeAny();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AiChatScreen(
                bookId: selCtx.bookId,
                bookTitle: selCtx.bookTitle,
                selectedPassage: selCtx.selectedText,
                chapterId: selCtx.chapterId,
              ),
            );
          },
        ),
      ]);
    }
  }

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttonItems,
  );
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
