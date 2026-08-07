import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/local/ai_settings_service.dart';
import '../../data/local/studio_artifact_repository.dart';
import '../../data/models/studio_artifact.dart';
import '../ai/embedding/embedding_service.dart';
import '../ai/provider/ai_provider.dart';
import '../ai/studio/studio_service.dart';
import 'studio_navigation.dart';

class StudioHubScreen extends ConsumerStatefulWidget {
  final int bookId;
  final String bookTitle;
  final int? currentChapterId;
  final String? currentChapterTitle;

  const StudioHubScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.currentChapterId,
    this.currentChapterTitle,
  });

  @override
  ConsumerState<StudioHubScreen> createState() => _StudioHubScreenState();
}

class _StudioHubScreenState extends ConsumerState<StudioHubScreen> {
  bool _useChapterScope = false;
  bool _isPreparing = false;
  bool _isGenerating = false;
  StudioArtifactType? _generatingType;
  String? _statusMessage;
  String? _errorMessage;
  int _embeddingCurrent = 0;
  int _embeddingTotal = 0;

  @override
  void initState() {
    super.initState();
    _useChapterScope = widget.currentChapterId != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareEmbeddings());
  }

  Future<void> _prepareEmbeddings() async {
    final settings = ref.read(aiSettingsServiceProvider);
    final key = await settings.getByokKey();
    if (key == null || key.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gemini API key required';
        });
      }
      return;
    }

    setState(() {
      _isPreparing = true;
      _errorMessage = null;
      _statusMessage = 'Preparing book embeddings...';
    });

    try {
      final embeddingService = ref.read(embeddingServiceProvider);
      await embeddingService.ensureEmbeddingsGenerated(
        widget.bookId,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _embeddingCurrent = current;
            _embeddingTotal = total;
            _statusMessage = 'Embedding chunks $current / $total';
          });
        },
      );
      if (mounted) {
        setState(() {
          _isPreparing = false;
          _statusMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPreparing = false;
          _errorMessage = e is NoApiKeyException
              ? 'Gemini API key required'
              : 'Failed to prepare embeddings: $e';
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _generate(StudioArtifactType type) async {
    if (_isGenerating || _isPreparing) return;

    final settings = ref.read(aiSettingsServiceProvider);
    final key = await settings.getByokKey();
    if (key == null || key.trim().isEmpty) {
      setState(() => _errorMessage = 'Gemini API key required');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatingType = type;
      _errorMessage = null;
      _statusMessage = 'Generating ${studioTypeLabel(type).toLowerCase()}...';
    });

    try {
      final chapterId = _useChapterScope ? widget.currentChapterId : null;
      final artifact = await ref.read(studioServiceProvider).generate(
            bookId: widget.bookId,
            type: type,
            chapterId: chapterId,
          );
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generatingType = null;
        _statusMessage = null;
      });
      openStudioArtifact(context, artifact);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generatingType = null;
        _statusMessage = null;
        _errorMessage = e is NoApiKeyException
            ? 'Gemini API key required'
            : 'Generation failed: $e';
      });
    }
  }

  Future<void> _deleteArtifact(StudioArtifact artifact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete artifact'),
        content: Text('Delete "${artifact.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(studioArtifactRepositoryProvider).deleteArtifact(artifact.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artifactsAsync = ref.watch(studioArtifactsProvider(widget.bookId));
    final canUseChapter = widget.currentChapterId != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
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
                            'Studio',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.bookTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_isPreparing || _isGenerating)
                LinearProgressIndicator(
                  value: _isPreparing && _embeddingTotal > 0
                      ? _embeddingCurrent / _embeddingTotal
                      : null,
                  minHeight: 3,
                ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (_errorMessage != null) ...[
                      Card(
                        color: theme.colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              if (_errorMessage!.contains('API key')) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).maybePop();
                                    context.push('/settings');
                                  },
                                  child: const Text('Configure API Key'),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _prepareEmbeddings,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_statusMessage != null) ...[
                      Text(
                        _statusMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Scope',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        const ButtonSegment(
                          value: false,
                          label: Text('Whole book'),
                          icon: Icon(Icons.menu_book_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          enabled: canUseChapter,
                          label: Text(
                            canUseChapter
                                ? (widget.currentChapterTitle ?? 'This chapter')
                                : 'This chapter',
                            overflow: TextOverflow.ellipsis,
                          ),
                          icon: const Icon(Icons.bookmark_outline),
                        ),
                      ],
                      selected: {_useChapterScope && canUseChapter},
                      onSelectionChanged: (values) {
                        setState(() {
                          _useChapterScope = values.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Generate',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: StudioArtifactType.values.map((type) {
                        final busy = _isGenerating && _generatingType == type;
                        return ActionChip(
                          avatar: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(studioTypeIcon(type), size: 18),
                          label: Text(studioTypeLabel(type)),
                          onPressed: (_isGenerating || _isPreparing)
                              ? null
                              : () => _generate(type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Saved artifacts',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    artifactsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Failed to load artifacts: $e'),
                      data: (artifacts) {
                        if (artifacts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No studio artifacts yet. Generate a quiz, study guide, slideshow, or mind map.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: artifacts.map((artifact) {
                            return Card(
                              child: ListTile(
                                leading: Icon(studioTypeIcon(artifact.type)),
                                title: Text(artifact.title),
                                subtitle: Text(
                                  '${studioTypeLabel(artifact.type)} · '
                                  '${artifact.scope == StudioArtifactScope.chapter ? 'Chapter' : 'Book'}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteArtifact(artifact),
                                ),
                                onTap: () => openStudioArtifact(context, artifact),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
