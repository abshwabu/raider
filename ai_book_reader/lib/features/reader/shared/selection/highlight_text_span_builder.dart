import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/annotation.dart';
import 'annotation_colors.dart';

class HighlightTextSpanBuilder {
  /// Builds a [TextSpan] tree with highlight backgrounds for [annotations].
  /// Overlapping ranges use last-writer-wins for the overlapping segment.
  ///
  /// Callers that pass [onTapAnnotation] should dispose [recognizersOut]
  /// when rebuilding or disposing the host widget.
  static TextSpan build({
    required String text,
    required List<Annotation> annotations,
    required TextStyle baseStyle,
    void Function(Annotation annotation)? onTapAnnotation,
    List<TapGestureRecognizer>? recognizersOut,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final ranges = annotations
        .where((a) => a.startOffset < a.endOffset)
        .map((a) => (
              start: a.startOffset.clamp(0, text.length),
              end: a.endOffset.clamp(0, text.length),
              annotation: a,
            ))
        .where((r) => r.start < r.end)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (ranges.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final children = <InlineSpan>[];

    final events = <_Event>[];
    for (final r in ranges) {
      events.add(_Event(r.start, true, r.annotation));
      events.add(_Event(r.end, false, r.annotation));
    }
    events.sort((a, b) {
      final byPos = a.pos.compareTo(b.pos);
      if (byPos != 0) return byPos;
      if (a.isStart != b.isStart) return a.isStart ? 1 : -1;
      return 0;
    });

    final active = <Annotation>[];
    var segmentStart = 0;

    void flush(int end) {
      if (end <= segmentStart) return;
      final slice = text.substring(segmentStart, end);
      final top = active.isEmpty ? null : active.last;
      if (top == null) {
        children.add(TextSpan(text: slice, style: baseStyle));
      } else {
        TapGestureRecognizer? recognizer;
        if (onTapAnnotation != null) {
          recognizer = TapGestureRecognizer()
            ..onTap = () => onTapAnnotation(top);
          recognizersOut?.add(recognizer);
        }
        children.add(
          TextSpan(
            text: slice,
            style: baseStyle.copyWith(
              backgroundColor: top.color.fillColor,
            ),
            recognizer: recognizer,
          ),
        );
      }
      segmentStart = end;
    }

    for (final event in events) {
      flush(event.pos);
      if (event.isStart) {
        active.add(event.annotation);
      } else {
        active.removeWhere((a) => a.id == event.annotation.id);
      }
    }
    flush(text.length);

    if (children.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    return TextSpan(style: baseStyle, children: children);
  }
}

class _Event {
  final int pos;
  final bool isStart;
  final Annotation annotation;

  _Event(this.pos, this.isStart, this.annotation);
}
