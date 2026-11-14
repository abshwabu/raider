import 'dart:convert';
import 'package:flutter/material.dart';
import '../../ai/studio/studio_payloads.dart';
import '../services/artifact_export_service.dart';
import '../widgets/studio_markdown.dart';

class StudyGuideViewer extends StatelessWidget {
  final String payloadJson;
  final String? title;
  final ArtifactExportService? exportService;

  const StudyGuideViewer({
    super.key,
    required this.payloadJson,
    this.title,
    this.exportService,
  });

  ArtifactExportService _getExportService() =>
      exportService ?? ArtifactExportService();

  IconData _iconForFormat(CustomStudyGuideFormat format) {
    switch (format) {
      case CustomStudyGuideFormat.executiveBrief:
        return Icons.menu_book_rounded;
      case CustomStudyGuideFormat.cornellNotes:
        return Icons.view_sidebar_rounded;
      case CustomStudyGuideFormat.actionPlaybook:
        return Icons.checklist_rtl_rounded;
      case CustomStudyGuideFormat.thematicAnalysis:
        return Icons.auto_awesome_motion_rounded;
      case CustomStudyGuideFormat.quickCheatSheet:
        return Icons.bolt_rounded;
      case CustomStudyGuideFormat.bookSummary:
        return Icons.summarize_rounded;
    }
  }

  void _copyMarkdown(BuildContext context, String markdown) {
    _getExportService().copyToClipboard(
      context,
      markdown,
      message: 'Markdown copied to clipboard',
    );
  }

  void _copyPlainText(BuildContext context, String markdown) {
    final plainText = ArtifactExportService.markdownToPlainText(markdown);
    _getExportService().copyToClipboard(
      context,
      plainText,
      message: 'Plain text copied to clipboard',
    );
  }

  Future<void> _exportMarkdown(
    BuildContext context,
    String title,
    String markdown,
  ) async {
    await _getExportService().exportAndShare(
      context: context,
      title: title,
      content: markdown,
      extension: 'md',
    );
  }

  Future<void> _exportPlainText(
    BuildContext context,
    String title,
    String markdown,
  ) async {
    final plainText = ArtifactExportService.markdownToPlainText(markdown);
    await _getExportService().exportAndShare(
      context: context,
      title: title,
      content: plainText,
      extension: 'txt',
    );
  }

  Future<void> _shareDirect(
    BuildContext context,
    String title,
    String markdown,
  ) async {
    await _getExportService().shareText(
      content: markdown,
      subject: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    StudyGuidePayload payload;
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map) {
        payload =
            StudyGuidePayload.fromJson(Map<String, dynamic>.from(decoded));
      } else {
        payload = StudyGuidePayload.fromRaw(payloadJson);
      }
    } catch (_) {
      payload = StudyGuidePayload.fromRaw(payloadJson);
    }

    final docTitle = title ?? 'Study guide';

    return Scaffold(
      appBar: AppBar(
        title: Text(docTitle),
        actions: [
          IconButton(
            tooltip: 'Copy Markdown',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copyMarkdown(context, payload.markdown),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export & Share',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (choice) {
              switch (choice) {
                case 'copy_md':
                  _copyMarkdown(context, payload.markdown);
                  break;
                case 'copy_txt':
                  _copyPlainText(context, payload.markdown);
                  break;
                case 'export_md':
                  _exportMarkdown(context, docTitle, payload.markdown);
                  break;
                case 'export_txt':
                  _exportPlainText(context, docTitle, payload.markdown);
                  break;
                case 'share':
                  _shareDirect(context, docTitle, payload.markdown);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy_md',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_copy_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Copy Markdown'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_txt',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_fields_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Copy Plain Text'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export_md',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save_alt_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Export as .md'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_txt',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Export as .txt'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Share via...'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Format Badge and description card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withAlpha(140),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(60),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _iconForFormat(payload.format),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payload.format.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        payload.format.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StudioMarkdown(data: payload.markdown),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
