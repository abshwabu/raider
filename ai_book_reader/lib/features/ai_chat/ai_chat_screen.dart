import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/local/ai_settings_service.dart';
import '../../data/local/chapter_repository.dart';
import '../../data/local/chat_repository.dart';
import '../../data/local/chunk_repository.dart';
import '../../data/models/chat_message.dart';
import '../ai/chat/chat_service.dart';
import '../ai/embedding/embedding_service.dart';
import '../ai/provider/ai_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final int bookId;
  final String bookTitle;

  const AiChatScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isInitializing = true;
  bool _needsApiKey = false;
  bool _isEmbedding = false;
  int _embeddingCurrent = 0;
  int _embeddingTotal = 0;

  bool _isStreaming = false;
  String _currentStreamingText = '';
  String? _errorMessage;

  List<ChatMessage> _messages = [];
  Map<int, String> _chapterTitleMap = {};

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isInitializing = true;
      _needsApiKey = false;
      _isEmbedding = false;
      _errorMessage = null;
    });

    try {
      final aiSettings = ref.read(aiSettingsServiceProvider);
      final key = await aiSettings.getByokKey();

      if (key == null || key.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _needsApiKey = true;
          });
        }
        return;
      }

      final chunkRepo = ref.read(chunkRepositoryProvider);
      final hasEmbeddings = await chunkRepo.hasEmbeddings(widget.bookId);

      if (!hasEmbeddings) {
        if (mounted) {
          setState(() {
            _isEmbedding = true;
          });
        }
        try {
          final embeddingService = ref.read(embeddingServiceProvider);
          await embeddingService.ensureEmbeddingsGenerated(
            widget.bookId,
            onProgress: (current, total) {
              if (mounted) {
                setState(() {
                  _embeddingCurrent = current;
                  _embeddingTotal = total;
                });
              }
            },
          );
        } catch (e) {
          if (e is NoApiKeyException) {
            if (mounted) {
              setState(() {
                _isInitializing = false;
                _needsApiKey = true;
                _isEmbedding = false;
              });
            }
            return;
          } else {
            if (mounted) {
              setState(() {
                _isInitializing = false;
                _isEmbedding = false;
                _errorMessage = 'Failed to generate embeddings: $e';
              });
            }
            return;
          }
        }
      }

      // Load chapters for citation labels
      final chapterRepo = ref.read(chapterRepositoryProvider);
      final chapters = await chapterRepo.getChaptersForBook(widget.bookId);
      final chapterMap = <int, String>{};
      for (final c in chapters) {
        chapterMap[c.id] = c.title;
      }

      // Load previous chat session messages
      final chatRepo = ref.read(chatRepositoryProvider);
      final session = await chatRepo.getOrCreateSession(widget.bookId);
      final existingMessages = await chatRepo.getMessages(session.id);

      if (mounted) {
        setState(() {
          _chapterTitleMap = chapterMap;
          _messages = existingMessages;
          _isInitializing = false;
          _isEmbedding = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isEmbedding = false;
          _errorMessage = 'Error initializing chat: $e';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textOverride]) async {
    final question = (textOverride ?? _textController.text).trim();
    if (question.isEmpty || _isStreaming) return;

    if (textOverride == null) {
      _textController.clear();
    }

    setState(() {
      _isStreaming = true;
      _currentStreamingText = '';
      _errorMessage = null;
    });

    _scrollToBottom();

    try {
      final chatService = ref.read(chatServiceProvider);
      final stream = chatService.sendMessage(
        bookId: widget.bookId,
        question: question,
      );

      await for (final chunkText in stream) {
        if (mounted) {
          setState(() {
            _currentStreamingText += chunkText;
          });
          _scrollToBottom();
        }
      }

      final chatRepo = ref.read(chatRepositoryProvider);
      final session = await chatRepo.getOrCreateSession(widget.bookId);
      final updatedMessages = await chatRepo.getMessages(session.id);

      if (mounted) {
        setState(() {
          _messages = updatedMessages;
          _isStreaming = false;
          _currentStreamingText = '';
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          if (e is NoApiKeyException) {
            _needsApiKey = true;
          } else {
            _errorMessage = 'Failed to get response: $e';
          }
        });
      }
    }
  }

  Future<List<String>> _getChapterNamesForChunks(List<int> chunkIds) async {
    if (chunkIds.isEmpty) return [];
    final chunkRepo = ref.read(chunkRepositoryProvider);
    final allChunks = await chunkRepo.getChunksForBook(widget.bookId);

    final titles = <String>{};
    for (final chunkId in chunkIds) {
      final chunk = allChunks.where((c) => c.id == chunkId).firstOrNull;
      if (chunk != null && _chapterTitleMap.containsKey(chunk.chapterId)) {
        titles.add(_chapterTitleMap[chunk.chapterId]!);
      }
    }

    return titles.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle & Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ask AI — ${widget.bookTitle}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: _buildBody(theme),
              ),

              // Input Bar (visible when ready)
              if (!_isInitializing && !_needsApiKey && !_isEmbedding)
                _buildInputBar(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isInitializing && !_isEmbedding) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_needsApiKey) {
      return _buildApiKeyPrompt(theme);
    }

    if (_isEmbedding) {
      return _buildEmbeddingProgress(theme);
    }

    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: _initializeChat,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _messages.isEmpty && _currentStreamingText.isEmpty
              ? _buildEmptyChatState(theme)
              : _buildMessageList(theme),
        ),
      ],
    );
  }

  Widget _buildApiKeyPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.key_rounded, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Gemini API Key Required',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'To chat with your books using AI, please configure a free Gemini API key in Settings.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Configure API Key'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddingProgress(ThemeData theme) {
    final progress = _embeddingTotal > 0 ? (_embeddingCurrent / _embeddingTotal) : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Preparing AI for this book...',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Generating vector embeddings for book chapters...',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 8),
            Text(
              '${(_embeddingCurrent)} of ${_embeddingTotal} chunks processed',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: theme.colorScheme.primary.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask anything about this book',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your questions will be answered using grounded excerpts directly from "${widget.bookTitle}".',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    final totalCount = _messages.length + (_isStreaming ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          final message = _messages[index];
          return _buildMessageBubble(theme, message);
        } else {
          // Streaming partial response bubble
          return _buildStreamingBubble(theme);
        }
      },
    );
  }

  Widget _buildMessageBubble(ThemeData theme, ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    final textColor =
        isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              )
            else
              _buildMarkdownBody(
                theme,
                message.content,
                textColor: textColor,
              ),
            if (!isUser && message.citedChunkIds.isNotEmpty)
              _buildSourcesRow(message.citedChunkIds),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingBubble(ThemeData theme) {
    final textColor = theme.colorScheme.onSurface;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: _currentStreamingText.isEmpty
            ? Text(
                'Thinking...',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              )
            : _buildMarkdownBody(
                theme,
                _currentStreamingText,
                textColor: textColor,
              ),
      ),
    );
  }

  Widget _buildMarkdownBody(
    ThemeData theme,
    String data, {
    required Color textColor,
  }) {
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontSize: 14,
          height: 1.4,
        ) ??
        TextStyle(color: textColor, fontSize: 14, height: 1.4);

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: baseStyle,
        a: baseStyle.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        h1: baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        h2: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        h3: baseStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
        h4: baseStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        h5: baseStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        h6: baseStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        strong: baseStyle.copyWith(fontWeight: FontWeight.bold),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        listBullet: baseStyle,
        blockquote: baseStyle.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        tableHead: baseStyle.copyWith(fontWeight: FontWeight.bold),
        tableBody: baseStyle,
        tableBorder: TableBorder.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildSourcesRow(List<int> citedChunkIds) {
    return FutureBuilder<List<String>>(
      future: _getChapterNamesForChunks(citedChunkIds),
      builder: (context, snapshot) {
        final titles = snapshot.data ?? [];
        if (titles.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sources:',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: titles.map((title) {
                  return Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.bookmark_outline, size: 14),
                    label: Text(
                      title,
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(100),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_isStreaming,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Ask a question about this book...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: _isStreaming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            color: theme.colorScheme.primary,
            onPressed: _isStreaming ? null : () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}
