import 'package:flutter/material.dart';
import '../../ai/chat/prompt_templates.dart';

enum PromptTemplateAction { insert, send }

class PromptTemplateSheet extends StatefulWidget {
  final ValueChanged<PromptTemplate> onSelect;
  final ValueChanged<PromptTemplate>? onSend;

  const PromptTemplateSheet({
    super.key,
    required this.onSelect,
    this.onSend,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<PromptTemplate> onSelect,
    ValueChanged<PromptTemplate>? onSend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PromptTemplateSheet(
        onSelect: onSelect,
        onSend: onSend,
      ),
    );
  }

  @override
  State<PromptTemplateSheet> createState() => _PromptTemplateSheetState();
}

class _PromptTemplateSheetState extends State<PromptTemplateSheet> {
  PromptCategory? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PromptTemplate> get _filteredTemplates {
    return PromptTemplateLibrary.all.where((template) {
      if (_selectedCategory != null && template.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = template.title.toLowerCase().contains(query);
        final matchesDesc = template.shortDescription.toLowerCase().contains(query);
        final matchesPrompt = template.promptText.toLowerCase().contains(query);
        return matchesTitle || matchesDesc || matchesPrompt;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = _filteredTemplates;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
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
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Prompt Library',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Select a pre-crafted prompt for deep reading insights',
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
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search prompts...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedCategory == null,
                      label: const Text('All'),
                      onSelected: (_) => setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...PromptCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(category.icon, size: 16),
                        selected: isSelected,
                        label: Text(category.title),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected ? category : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            // Prompt template list
            Expanded(
              child: templates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No prompts match your search.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return _PromptTemplateCard(
                          template: template,
                          onInsert: () {
                            Navigator.of(context).pop();
                            widget.onSelect(template);
                          },
                          onSend: widget.onSend != null
                              ? () {
                                  Navigator.of(context).pop();
                                  widget.onSend!(template);
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptTemplateCard extends StatefulWidget {
  final PromptTemplate template;
  final VoidCallback onInsert;
  final VoidCallback? onSend;

  const _PromptTemplateCard({
    required this.template,
    required this.onInsert,
    this.onSend,
  });

  @override
  State<_PromptTemplateCard> createState() => _PromptTemplateCardState();
}

class _PromptTemplateCardState extends State<_PromptTemplateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = widget.template;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(70),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Icon(template.icon, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        template.shortDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  template.promptText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(_expanded ? 'Hide prompt' : 'Preview prompt'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: widget.onInsert,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Insert'),
                ),
                if (widget.onSend != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.onSend,
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('Ask AI'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
