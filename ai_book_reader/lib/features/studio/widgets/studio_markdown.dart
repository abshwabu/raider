import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class StudioMarkdown extends StatelessWidget {
  final String data;

  const StudioMarkdown({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.45) ??
        const TextStyle(fontSize: 14, height: 1.45);

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: baseStyle,
        h1: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
        h2: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        h3: baseStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        strong: baseStyle.copyWith(fontWeight: FontWeight.bold),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        listBullet: baseStyle,
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
