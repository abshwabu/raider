import 'package:html/parser.dart' as html_parser;

/// Strips HTML to plain text suitable for selection offsets and reading.
String htmlToPlainText(String html) {
  if (html.trim().isEmpty) return '';
  final document = html_parser.parse(html);
  final text = document.body?.text ?? document.documentElement?.text ?? '';
  return text.replaceAll(RegExp(r'\r\n?'), '\n').trim();
}
