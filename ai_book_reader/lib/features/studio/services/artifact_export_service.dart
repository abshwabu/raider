import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

typedef ShareTextFn = Future<void> Function(String text, {String? subject});
typedef ShareFilesFn = Future<void> Function(
  List<XFile> files, {
  String? text,
  String? subject,
});
typedef DirectoryProviderFn = Future<Directory> Function();

class ArtifactExportService {
  final ShareTextFn _shareText;
  final ShareFilesFn _shareFiles;
  final DirectoryProviderFn _getDirectory;

  ArtifactExportService({
    ShareTextFn? shareText,
    ShareFilesFn? shareFiles,
    DirectoryProviderFn? getDirectory,
  })  : _shareText = shareText ?? _defaultShareText,
        _shareFiles = shareFiles ?? _defaultShareFiles,
        _getDirectory = getDirectory ?? getApplicationDocumentsDirectory;

  static Future<void> _defaultShareText(String text, {String? subject}) {
    return SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
      ),
    );
  }

  static Future<void> _defaultShareFiles(
    List<XFile> files, {
    String? text,
    String? subject,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: files,
        text: text,
        subject: subject,
      ),
    );
  }

  /// Copies text to the system clipboard and notifies the user with a SnackBar.
  Future<void> copyToClipboard(
    BuildContext context,
    String content, {
    String message = 'Copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Converts markdown text into clean, unformatted plain text.
  static String markdownToPlainText(String markdown) {
    var text = markdown;

    // Normalize Windows CRLF to LF
    text = text.replaceAll('\r\n', '\n');

    // Remove code block fences (e.g., ```dart ... ``` -> contents)
    text = text.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '');
    text = text.replaceAll('```', '');

    // Replace Markdown headers with uppercase or spaced lines
    text = text.replaceAllMapped(
      RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true),
      (match) => '\n${match.group(2)?.trim()}\n',
    );

    // Replace Markdown links [text](url) -> text (url) or text
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (match) => '${match.group(1)}',
    );

    // Strip bold & italic markers: **bold**, *italic*, __bold__, _italic_
    text = text.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1]!);
    text = text.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1]!);
    text = text.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1]!);
    text = text.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m[1]!);
    text = text.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m[1]!);

    // Inline code `code` -> code
    text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);

    // Blockquote marker > -> indent
    text = text.replaceAllMapped(
      RegExp(r'^\s*>\s*(.+)$', multiLine: true),
      (match) => '  ${match.group(1)}',
    );

    // Bullet lists: - item or * item -> • item
    text = text.replaceAllMapped(
      RegExp(r'^\s*[-*+]\s+(.+)$', multiLine: true),
      (match) => '• ${match.group(1)}',
    );

    // Compress 3+ consecutive newlines into 2
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  /// Generates a sanitized file name from a title and extension.
  static String sanitizeFilename(String title, String extension) {
    final cleanTitle = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final base = cleanTitle.isEmpty ? 'study_artifact' : cleanTitle;
    return '$base.$ext';
  }

  /// Saves the content into a local file inside the application documents directory.
  Future<File> saveToFile({
    required String filename,
    required String content,
  }) async {
    final directory = await _getDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    return file;
  }

  /// Exports the content to a file and brings up the native system share sheet.
  Future<File> exportAndShare({
    BuildContext? context,
    required String title,
    required String content,
    String extension = 'md',
  }) async {
    final filename = sanitizeFilename(title, extension);
    final file = await saveToFile(filename: filename, content: content);

    if (context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Saved to ${file.path}'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => _shareFiles(
              [XFile(file.path)],
              text: title,
              subject: title,
            ),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      await _shareFiles([XFile(file.path)], text: title, subject: title);
    } catch (_) {
      // Fallback to text sharing if file sharing cannot open
      await _shareText(content, subject: title);
    }

    return file;
  }

  /// Shares content directly as text without writing to a persistent file.
  Future<void> shareText({
    required String content,
    String? subject,
  }) async {
    await _shareText(content, subject: subject);
  }
}
