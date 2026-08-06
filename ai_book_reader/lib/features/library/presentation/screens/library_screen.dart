import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/import/import_service.dart';
import '../../../../data/local/book_repository.dart';
import '../../../../data/models/book.dart';

enum BookSortOption {
  recentlyAdded('Recently Added'),
  recentlyOpened('Recently Opened'),
  titleAZ('Title A-Z');

  final String label;
  const BookSortOption(this.label);
}

final sortOptionProvider = StateProvider<BookSortOption>((ref) => BookSortOption.recentlyAdded);
final searchQueryProvider = StateProvider<String>((ref) => '');

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isSearching = false;
  bool _isImporting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Importing... this may take a moment'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final importService = ref.read(importServiceProvider);
      final importedBooks = await importService.pickAndImportBooks();

      if (mounted && importedBooks.isNotEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${importedBooks.length} book(s)'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteBook(Book book) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text("Are you sure you want to delete '${book.title}'? This will remove the book and its chapters."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final bookRepo = ref.read(bookRepositoryProvider);
      await bookRepo.deleteBook(book.id);

      messenger.showSnackBar(
        SnackBar(
          content: Text("'${book.title}' deleted"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<Book> _filterAndSortBooks(List<Book> books, String query, BookSortOption sortOption) {
    var filtered = books;
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = books.where((b) {
        final titleMatches = b.title.toLowerCase().contains(q);
        final authorMatches = b.author?.toLowerCase().contains(q) ?? false;
        return titleMatches || authorMatches;
      }).toList();
    } else {
      filtered = List<Book>.from(books);
    }

    switch (sortOption) {
      case BookSortOption.recentlyAdded:
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case BookSortOption.recentlyOpened:
        filtered.sort((a, b) {
          final aTime = a.lastOpenedAt ?? a.addedAt;
          final bTime = b.lastOpenedAt ?? b.addedAt;
          return bTime.compareTo(aTime);
        });
        break;
      case BookSortOption.titleAZ:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booksAsync = ref.watch(booksStreamProvider);
    final sortOption = ref.watch(sortOptionProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search books by title or author...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              )
            : const Text('My Library'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search Library',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            PopupMenuButton<BookSortOption>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort Books',
              initialValue: sortOption,
              onSelected: (option) {
                ref.read(sortOptionProvider.notifier).state = option;
              },
              itemBuilder: (context) => BookSortOption.values.map((option) {
                return PopupMenuItem<BookSortOption>(
                  value: option,
                  child: Row(
                    children: [
                      if (option == sortOption)
                        Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(option.label),
                    ],
                  ),
                );
              }).toList(),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                // Settings screen placeholder
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_isImporting)
            const LinearProgressIndicator(
              minHeight: 3,
            ),
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Failed to load library: $err'),
                  ],
                ),
              ),
              data: (books) {
                if (books.isEmpty) {
                  return _buildEmptyState(theme);
                }

                final displayBooks = _filterAndSortBooks(books, searchQuery, sortOption);

                if (displayBooks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No books matching "$searchQuery"',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildBookGrid(context, displayBooks, theme);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleImport,
        icon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_isImporting ? 'Importing...' : 'Import Book'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No books yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button below to import your first book',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleImport,
              icon: const Icon(Icons.add),
              label: const Text('Import Book'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookGrid(BuildContext context, List<Book> books, ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 6;
    } else if (screenWidth > 900) {
      crossAxisCount = 5;
    } else if (screenWidth > 600) {
      crossAxisCount = 4;
    } else if (screenWidth > 400) {
      crossAxisCount = 3;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.62,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _BookCard(
          book: book,
          onTap: () => context.push('/reader/${book.id}'),
          onDelete: () => _confirmDeleteBook(book),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCover = book.coverImagePath != null && File(book.coverImagePath!).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    Image.file(
                      File(book.coverImagePath!),
                      fit: BoxFit.cover,
                    )
                  else
                    _buildGeneratedCover(theme),

                  // Format Tag Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getFormatColor(book.format).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        book.format.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Overflow Menu Button
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Material(
                      type: MaterialType.transparency,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (book.author != null && book.author!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: book.readingProgress.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        book.readingProgress > 0
                            ? '${(book.readingProgress * 100).toInt()}%'
                            : 'Unread',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFormatColor(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade700;
      case 'epub':
        return Colors.indigo.shade700;
      case 'txt':
        return Colors.teal.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  Widget _buildGeneratedCover(ThemeData theme) {
    final format = book.format.toLowerCase();
    List<Color> gradientColors;

    switch (format) {
      case 'pdf':
        gradientColors = [const Color(0xFF8B0000), const Color(0xFFD32F2F)];
        break;
      case 'epub':
        gradientColors = [const Color(0xFF4A148C), const Color(0xFF7B1FA2)];
        break;
      case 'txt':
        gradientColors = [const Color(0xFF004D40), const Color(0xFF00796B)];
        break;
      default:
        gradientColors = [const Color(0xFF263238), const Color(0xFF455A64)];
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFormatIcon(format),
            size: 36,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFormatIcon(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'epub':
        return Icons.menu_book_rounded;
      case 'txt':
        return Icons.article_rounded;
      default:
        return Icons.book_rounded;
    }
  }
}
