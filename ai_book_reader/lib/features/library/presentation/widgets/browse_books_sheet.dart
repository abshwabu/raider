import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../data/import/import_service.dart';

/// Full-height sheet listing supported book files found in a folder.
/// Returns the list of selected file paths, or null/empty if cancelled.
class BrowseBooksSheet extends StatefulWidget {
  final List<DiscoverableBook> books;
  final String folderName;

  const BrowseBooksSheet({
    super.key,
    required this.books,
    required this.folderName,
  });

  static Future<List<String>?> show(
    BuildContext context, {
    required List<DiscoverableBook> books,
    required String folderName,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BrowseBooksSheet(
        books: books,
        folderName: folderName,
      ),
    );
  }

  @override
  State<BrowseBooksSheet> createState() => _BrowseBooksSheetState();
}

class _BrowseBooksSheetState extends State<BrowseBooksSheet> {
  late final Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Pre-select books that are not already in the library.
    _selected = {
      for (final book in widget.books)
        if (!book.alreadyImported) book.path,
    };
  }

  List<DiscoverableBook> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.books;
    return widget.books.where((book) {
      return book.title.toLowerCase().contains(q) ||
          book.format.contains(q) ||
          p.basename(book.path).toLowerCase().contains(q);
    }).toList();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _toggleAllVisible(bool select) {
    final visible = _filtered;
    setState(() {
      if (select) {
        for (final book in visible) {
          if (!book.alreadyImported) {
            _selected.add(book.path);
          }
        }
      } else {
        for (final book in visible) {
          _selected.remove(book.path);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final selectableCount =
        filtered.where((b) => !b.alreadyImported).length;
    final selectedVisibleCount =
        filtered.where((b) => _selected.contains(b.path)).length;
    final allVisibleSelected =
        selectableCount > 0 && selectedVisibleCount == selectableCount;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available books',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.books.length} supported file(s) in ${widget.folderName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Filter by title or format...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  Checkbox(
                    value: allVisibleSelected
                        ? true
                        : (selectedVisibleCount == 0 ? false : null),
                    tristate: true,
                    onChanged: selectableCount == 0
                        ? null
                        : (value) => _toggleAllVisible(value ?? false),
                  ),
                  Text(
                    allVisibleSelected ? 'Deselect all' : 'Select all',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${_selected.length} selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No supported books found in this folder'
                            : 'No books match "$_query"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final book = filtered[index];
                        final selected = _selected.contains(book.path);
                        final sizeLabel = _formatSize(book.sizeBytes);

                        return CheckboxListTile(
                          value: selected,
                          enabled: !book.alreadyImported,
                          onChanged: book.alreadyImported
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selected.add(book.path);
                                    } else {
                                      _selected.remove(book.path);
                                    }
                                  });
                                },
                          secondary: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              book.format.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              if (book.alreadyImported) 'Already in library',
                              if (sizeLabel.isNotEmpty) sizeLabel,
                              p.basename(book.path),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _selected.isEmpty
                            ? null
                            : () => Navigator.of(context)
                                .pop(_selected.toList(growable: false)),
                        icon: const Icon(Icons.library_add),
                        label: Text(
                          _selected.isEmpty
                              ? 'Add to library'
                              : 'Add ${_selected.length} to library',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
