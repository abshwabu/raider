import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/annotation.dart';
import 'annotation_colors.dart';

class HighlightTextSpanBuilder {
  /// Builds a [TextSpan] tree with highlight backgrounds for [annotations]
  /// and optional [activeTtsRange] for text-to-speech reading.
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
    TextRange? activeTtsRange,
    Color? ttsHighlightColor,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final effectiveAnnotations = List<Annotation>.from(annotations);

    final ranges = effectiveAnnotations
        .where((a) => a.startOffset < a.endOffset)
        .map((a) => (
              start: a.startOffset.clamp(0, text.length),
              end: a.endOffset.clamp(0, text.length),
              annotation: a,
            ))
        .where((r) => r.start < r.end)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final hasTts = activeTtsRange != null &&
        activeTtsRange.start >= 0 &&
        activeTtsRange.end > activeTtsRange.start &&
        activeTtsRange.start < text.length;
    final ttsStart = hasTts ? activeTtsRange.start.clamp(0, text.length) : -1;
    final ttsEnd = hasTts ? activeTtsRange.end.clamp(0, text.length) : -1;
    final defaultTtsColor = (ttsHighlightColor ?? const Color(0xFF38BDF8)).withValues(alpha: 0.32);

    if (ranges.isEmpty && !hasTts) {
      return TextSpan(text: text, style: baseStyle);
    }

    final children = <InlineSpan>[];

    final splitPoints = <int>{0, text.length};
    for (final r in ranges) {
      splitPoints.add(r.start);
      splitPoints.add(r.end);
    }
    if (hasTts) {
      splitPoints.add(ttsStart);
      splitPoints.add(ttsEnd);
    }
    final sortedPoints = splitPoints.toList()..sort();

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final segStart = sortedPoints[i];
      final segEnd = sortedPoints[i + 1];
      if (segStart >= segEnd) continue;

      final slice = text.substring(segStart, segEnd);

      // Check if inside TTS range
      final isInsideTts = hasTts && segStart >= ttsStart && segEnd <= ttsEnd;

      // Check if inside any user annotations (last one wins)
      Annotation? topAnnotation;
      for (final r in ranges) {
        if (segStart >= r.start && segEnd <= r.end) {
          topAnnotation = r.annotation;
        }
      }

      Color? bgColor;
      if (topAnnotation != null) {
        bgColor = topAnnotation.color.fillColor;
      } else if (isInsideTts) {
        bgColor = defaultTtsColor;
      }

      TapGestureRecognizer? recognizer;
      if (topAnnotation != null && onTapAnnotation != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onTapAnnotation(topAnnotation!);
        recognizersOut?.add(recognizer);
      }

      TextStyle segStyle = baseStyle;
      if (bgColor != null) {
        segStyle = segStyle.copyWith(backgroundColor: bgColor);
      }
      if (isInsideTts && topAnnotation != null) {
        // Subtle underline when user highlight coincides with TTS speaking
        segStyle = segStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: defaultTtsColor,
          decorationThickness: 2.0,
        );
      }

      children.add(
        TextSpan(
          text: slice,
          style: segStyle,
          recognizer: recognizer,
        ),
      );
    }

    if (children.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    return TextSpan(style: baseStyle, children: children);
  }
}
