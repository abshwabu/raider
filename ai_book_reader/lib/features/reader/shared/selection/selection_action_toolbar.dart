import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'selection_actions.dart';
import 'selection_context.dart';

typedef AnnotationsChanged = Future<void> Function();

/// Builds a Material selection toolbar with reader actions.
Widget buildSelectionActionToolbar({
  required BuildContext context,
  required EditableTextState editableTextState,
  required SelectionContext Function(String selected, int start, int end)
      buildContext,
  required AnnotationsChanged onAnnotationsChanged,
}) {
  final value = editableTextState.textEditingValue;
  final selection = value.selection;

  SelectionContext? selCtx;
  if (selection.isValid && !selection.isCollapsed) {
    final start = selection.start;
    final end = selection.end;
    if (start >= 0 && end <= value.text.length && end > start) {
      final selected = value.text.substring(start, end);
      final built = buildContext(selected, start, end);
      if (built.isValid) selCtx = built;
    }
  }

  final anchors = editableTextState.contextMenuAnchors;
  final actions = <(SelectionAction, String)>[
    (SelectionAction.copy, 'Copy'),
    (SelectionAction.highlight, 'Highlight'),
    (SelectionAction.comment, 'Comment'),
    (SelectionAction.translate, 'Translate'),
    (SelectionAction.dictionary, 'Dictionary'),
    (SelectionAction.askAi, 'Ask AI'),
  ];

  Widget button(int index, int total, SelectionAction action, String label) {
    return TextSelectionToolbarTextButton(
      padding: TextSelectionToolbarTextButton.getPadding(index, total),
      onPressed: selCtx == null
          ? null
          : () async {
              ContextMenuController.removeAny();
              final ctx = selCtx!;
              if (action == SelectionAction.copy) {
                await Clipboard.setData(ClipboardData(text: ctx.selectedText));
                editableTextState.hideToolbar();
                return;
              }
              await handleSelectionAction(
                context: context,
                action: action,
                selection: ctx,
                onAnnotationsChanged: onAnnotationsChanged,
                clearSelection: () {
                  editableTextState.userUpdateTextEditingValue(
                    value.copyWith(
                      selection: TextSelection.collapsed(offset: selection.end),
                    ),
                    SelectionChangedCause.toolbar,
                  );
                  editableTextState.hideToolbar();
                },
              );
            },
      child: Text(label),
    );
  }

  return TextSelectionToolbar(
    anchorAbove: anchors.primaryAnchor,
    anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
    children: [
      for (var i = 0; i < actions.length; i++)
        button(i, actions.length, actions[i].$1, actions[i].$2),
    ],
  );
}
