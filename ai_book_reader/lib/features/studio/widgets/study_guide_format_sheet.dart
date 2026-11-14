import 'package:flutter/material.dart';
import '../../ai/studio/studio_payloads.dart';

class StudyGuideFormatSheet extends StatelessWidget {
  final CustomStudyGuideFormat selectedFormat;
  final ValueChanged<CustomStudyGuideFormat> onFormatSelected;

  const StudyGuideFormatSheet({
    super.key,
    required this.selectedFormat,
    required this.onFormatSelected,
  });

  static Future<CustomStudyGuideFormat?> show(
    BuildContext context, {
    CustomStudyGuideFormat initialFormat = CustomStudyGuideFormat.executiveBrief,
  }) {
    return showModalBottomSheet<CustomStudyGuideFormat>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StudyGuideFormatSheet(
        selectedFormat: initialFormat,
        onFormatSelected: (format) => Navigator.of(sheetContext).pop(format),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study Guide Format',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose the structure and focus of your generated guide',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: CustomStudyGuideFormat.values.map((format) {
                  final isSelected = format == selectedFormat;
                  final icon = _iconForFormat(format);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withAlpha(90)
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withAlpha(80),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                        child: Icon(icon, size: 22),
                      ),
                      title: Text(
                        format.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          format.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => onFormatSelected(format),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
