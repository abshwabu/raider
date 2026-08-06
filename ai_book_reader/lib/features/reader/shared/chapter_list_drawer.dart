import 'package:flutter/material.dart';
import '../../../data/models/chapter.dart';

class ChapterListDrawer extends StatelessWidget {
  final String bookTitle;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final Function(int index, Chapter chapter) onChapterSelected;

  const ChapterListDrawer({
    super.key,
    required this.bookTitle,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bookTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${chapters.length} chapters / sections',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: chapters.isEmpty
                ? const Center(child: Text('No chapters available'))
                : ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == currentChapterIndex;
                      final chapter = chapters[index];

                      return ListTile(
                        selected: isSelected,
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop(); // Close drawer
                          onChapterSelected(index, chapter);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
