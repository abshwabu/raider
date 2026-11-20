import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/import/import_service.dart';
import '../../../../data/import/incoming_file_service.dart';
import '../../../../data/local/ai_settings_service.dart';
import '../../../../data/local/book_repository.dart';
import '../../../../data/local/reading_stats_repository.dart';
import '../../../../data/models/book.dart';
import '../../../stats/services/reading_reminder_service.dart';
import '../widgets/browse_books_sheet.dart';

final streakSummaryProvider = StreamProvider.autoDispose<ReadingStreakSummary>((ref) {
  final repo = ref.watch(readingStatsRepositoryProvider);
  return repo.watchStreakSummary();
});

enum BookSortOption {
  recentlyAdded('Recently Added'),
  recentlyOpened('Recently Opened'),
  titleAZ('Title A-Z');

  final String label;
  const BookSortOption(this.label);
}

enum LibraryViewMode {
  grid,
  list,
}

class LibraryViewModeNotifier extends StateNotifier<LibraryViewMode> {
  final SharedPreferences? _prefs;
  static const String _key = 'library_view_mode';

  LibraryViewModeNotifier(this._prefs)
      : super(_prefs?.getString(_key) == 'list'
            ? LibraryViewMode.list
            : LibraryViewMode.grid);

  void toggle() {
    state = state == LibraryViewMode.grid
        ? LibraryViewMode.list
        : LibraryViewMode.grid;
    _prefs?.setString(_key, state.name);
  }

  void setViewMode(LibraryViewMode mode) {
    state = mode;
    _prefs?.setString(_key, mode.name);
  }
}

final libraryViewModeProvider =
    StateNotifierProvider<LibraryViewModeNotifier, LibraryViewMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LibraryViewModeNotifier(prefs);
});

final sortOptionProvider = StateProvider<BookSortOption>((ref) => BookSortOption.recentlyAdded);
final searchQueryProvider = StateProvider<String>((ref) => '');

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with WidgetsBindingObserver {
  bool _isSearching = false;
  bool _isImporting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initIncomingFileHandler();
      _syncGoalToReminder();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(readingStatsRepositoryProvider).notifyStatsChanged();
      ref.invalidate(streakSummaryProvider);
      _syncGoalToReminder();
    }
  }

  Future<void> _syncGoalToReminder() async {
    try {
      final statsRepo = ref.read(readingStatsRepositoryProvider);
      final today = await statsRepo.getOrCreateTodayStat();
      final reminderService = ref.read(readingReminderServiceProvider);
      await reminderService.syncGoalStatus(
        isGoalMet: today.isGoalMet,
        activeSeconds: today.activeSeconds,
        goalMinutes: today.goalMinutes,
      );
    } catch (_) {}
  }

  Future<void> _initIncomingFileHandler() async {
    try {
      final incomingService = ref.read(incomingFileServiceProvider);

      // Listen for new incoming files when app is already alive
      incomingService.setFileOpenListener((paths) {
        if (mounted && paths.isNotEmpty) {
          _handleIncomingFiles(paths);
        }
      });

      // Check for initial files from cold start
      final initialPaths = await incomingService.getInitialFiles();
      if (mounted && initialPaths.isNotEmpty) {
        _handleIncomingFiles(initialPaths);
      }
    } catch (_) {}
  }

  Future<void> _handleIncomingFiles(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                paths.length == 1
                    ? 'Opening book...'
                    : 'Opening ${paths.length} books...',
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      final incomingService = ref.read(incomingFileServiceProvider);
      final books = await incomingService.processFiles(paths);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      if (books.isNotEmpty) {
        if (books.length == 1) {
          final book = books.first;
          messenger.showSnackBar(
            SnackBar(
              content: Text('Opened "${book.title}"'),
              duration: const Duration(seconds: 2),
            ),
          );
          await context.push('/reader/${book.id}');
          if (mounted) {
            ref.read(readingStatsRepositoryProvider).notifyStatsChanged();
            ref.invalidate(streakSummaryProvider);
          }
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Added ${books.length} books to your library'),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importSelectedPaths(List<String> paths) async {
    if (paths.isEmpty || _isImporting) return;

    setState(() {
      _isImporting = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          paths.length == 1
              ? 'Importing book...'
              : 'Importing ${paths.length} books...',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final importService = ref.read(importServiceProvider);
      final importedBooks = await importService.importFiles(paths);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (importedBooks.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Added ${importedBooks.length} book(s) to library'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('No books were imported')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _showBrowseResult(FolderScanResult scan, {String? label}) async {
    if (scan.books.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No supported books selected. Supported: pdf, epub, txt, docx, cbz, cbr, mobi, azw3',
          ),
        ),
      );
      return;
    }

    final folderName = label ??
        (p.basename(scan.folderPath).isEmpty
            ? scan.folderPath
            : p.basename(scan.folderPath));

    final selected = await BrowseBooksSheet.show(
      context,
      books: scan.books,
      folderName: folderName,
    );

    if (selected != null && selected.isNotEmpty && mounted) {
      await _importSelectedPaths(selected);
    }
  }

  Future<void> _handleBrowseBooks() async {
    if (_isImporting) return;

    final messenger = ScaffoldMessenger.of(context);
    final importService = ref.read(importServiceProvider);

    try {
      // Multi-select filtered to supported types — works when folder listing cannot.
      final scan = await importService.pickSupportedBooks();
      if (!mounted) return;
      if (scan == null) return;
      await _showBrowseResult(scan, label: 'selected files');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Browse failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleBrowseFolder() async {
    if (_isImporting) return;

    final messenger = ScaffoldMessenger.of(context);
    final importService = ref.read(importServiceProvider);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Choose a folder… if it cannot be listed, you can pick files next'),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final scan = await importService.pickFolderAndDiscoverBooks();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      if (scan == null) {
        return;
      }

      await _showBrowseResult(scan);
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Browse failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handlePickFiles() async {
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

  void _showAddBooksMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text('Browse books'),
                subtitle: const Text('See supported files and choose which to add'),
                onTap: () {
                  Navigator.pop(context);
                  _handleBrowseBooks();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Scan folder'),
                subtitle: const Text('Try listing a whole folder (may be limited by the OS)'),
                onTap: () {
                  Navigator.pop(context);
                  _handleBrowseFolder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Import files now'),
                subtitle: const Text('Pick files and add them immediately'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePickFiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
    final viewMode = ref.watch(libraryViewModeProvider);

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
          IconButton(
            key: const Key('switch_view_mode_button'),
            icon: Icon(
              viewMode == LibraryViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: viewMode == LibraryViewMode.grid
                ? 'Switch to list view'
                : 'Switch to grid view',
            onPressed: () {
              ref.read(libraryViewModeProvider.notifier).toggle();
            },
          ),
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
              icon: const Icon(Icons.insights_rounded),
              tooltip: 'Reading Goals & Stats',
              onPressed: () async {
                await context.push('/stats');
                if (mounted) {
                  ref.read(readingStatsRepositoryProvider).notifyStatsChanged();
                  ref.invalidate(streakSummaryProvider);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'AI & BYOK Settings',
              onPressed: () {
                context.push('/settings');
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
          _buildDailyGoalHeader(context, theme),
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

                return viewMode == LibraryViewMode.grid
                    ? _buildBookGrid(context, displayBooks, theme)
                    : _buildBookList(context, displayBooks, theme);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImporting ? null : _showAddBooksMenu,
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
        label: Text(_isImporting ? 'Importing...' : 'Add Books'),
      ),
    );
  }

  Widget _buildDailyGoalHeader(BuildContext context, ThemeData theme) {
    final streakAsync = ref.watch(streakSummaryProvider);

    return streakAsync.when(
      data: (summary) {
        final streak = summary.currentStreak;
        final mins = summary.todayMinutes;
        final goal = summary.todayGoalMinutes;
        final fraction = summary.todayProgressFraction;
        final isMet = summary.isTodayGoalMet;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Material(
            color: isMet
                ? Colors.teal.withValues(alpha: 0.08)
                : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isMet
                    ? Colors.teal.withValues(alpha: 0.3)
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await context.push('/stats');
                if (mounted) {
                  ref.read(readingStatsRepositoryProvider).notifyStatsChanged();
                  ref.invalidate(streakSummaryProvider);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: streak > 0 ? const Color(0xFFF05A28) : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      streak > 0 ? '$streak day streak' : 'Start streak',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: streak > 0 ? const Color(0xFFF05A28) : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '•',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isMet ? 'Goal Met 🎉' : '$mins / $goal mins',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isMet ? Colors.teal : theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${(fraction * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 4,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMet ? Colors.teal : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
              'Browse supported book files, then add the ones you want',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _handleBrowseBooks,
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('Browse books'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isImporting ? null : _handlePickFiles,
              child: const Text('Or import files immediately'),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
          onTap: () async {
            await context.push('/reader/${book.id}');
            if (mounted) {
              ref.read(readingStatsRepositoryProvider).notifyStatsChanged();
              ref.invalidate(streakSummaryProvider);
            }
          },
          onDelete: () => _confirmDeleteBook(book),
        );
      },
    );
  }

  Widget _buildBookList(BuildContext context, List<Book> books, ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 800 ? (screenWidth - 760) / 2 : 16.0;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 88),
      itemCount: books.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final book = books[index];
        return _BookListItem(
          book: book,
          onTap: () async {
            await context.push('/reader/${book.id}');
            if (mounted) {
              ref.read(readingStatsRepositoryProvider).notifyStatsChanged();
              ref.invalidate(streakSummaryProvider);
            }
          },
          onDelete: () => _confirmDeleteBook(book),
        );
      },
    );
  }
}

Color _getFormatColor(String format) {
  switch (format.toLowerCase()) {
    case 'pdf':
      return Colors.red.shade700;
    case 'epub':
      return Colors.indigo.shade700;
    case 'txt':
      return Colors.teal.shade700;
    case 'docx':
      return Colors.blue.shade700;
    case 'cbz':
    case 'cbr':
      return Colors.orange.shade800;
    case 'mobi':
    case 'azw3':
      return Colors.deepPurple.shade700;
    default:
      return Colors.blueGrey.shade700;
  }
}

List<Color> _getFormatGradient(String format) {
  switch (format.toLowerCase()) {
    case 'pdf':
      return [const Color(0xFF8B0000), const Color(0xFFD32F2F)];
    case 'epub':
      return [const Color(0xFF4A148C), const Color(0xFF7B1FA2)];
    case 'txt':
      return [const Color(0xFF004D40), const Color(0xFF00796B)];
    case 'docx':
      return [const Color(0xFF1565C0), const Color(0xFF1E88E5)];
    case 'cbz':
    case 'cbr':
      return [const Color(0xFFD84315), const Color(0xFFF4511E)];
    case 'mobi':
    case 'azw3':
      return [const Color(0xFF4527A0), const Color(0xFF5E35B1)];
    default:
      return [const Color(0xFF263238), const Color(0xFF455A64)];
  }
}

IconData _getFormatIcon(String format) {
  switch (format.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'epub':
      return Icons.menu_book_rounded;
    case 'txt':
      return Icons.article_rounded;
    case 'docx':
      return Icons.description_rounded;
    case 'cbz':
    case 'cbr':
      return Icons.photo_library_rounded;
    case 'mobi':
    case 'azw3':
      return Icons.auto_stories_rounded;
    default:
      return Icons.book_rounded;
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

  Widget _buildGeneratedCover(ThemeData theme) {
    final format = book.format.toLowerCase();
    final gradientColors = _getFormatGradient(format);

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
}

class _BookListItem extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookListItem({
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
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 72,
                  child: hasCover
                      ? Image.file(
                          File(book.coverImagePath!),
                          fit: BoxFit.cover,
                        )
                      : _buildListCover(theme),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
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
                        if (book.author != null && book.author!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              book.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
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
                        const SizedBox(width: 8),
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
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Book options',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCover(ThemeData theme) {
    final format = book.format.toLowerCase();
    final gradientColors = _getFormatGradient(format);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Icon(
          _getFormatIcon(format),
          size: 26,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
