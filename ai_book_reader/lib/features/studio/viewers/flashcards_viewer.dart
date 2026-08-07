import 'dart:convert';
import 'package:flutter/material.dart';
import '../../ai/studio/studio_payloads.dart';

class FlashcardsViewer extends StatefulWidget {
  final String payloadJson;

  const FlashcardsViewer({super.key, required this.payloadJson});

  @override
  State<FlashcardsViewer> createState() => _FlashcardsViewerState();
}

class _FlashcardsViewerState extends State<FlashcardsViewer> {
  late final FlashcardsPayload _payload;
  late final PageController _controller;
  int _index = 0;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _payload = FlashcardsPayload.fromJson(
      Map<String, dynamic>.from(jsonDecode(widget.payloadJson) as Map),
    );
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = _payload.cards;

    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: cards.isEmpty
          ? const Center(child: Text('No flashcards'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_index + 1} / ${cards.length}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: cards.length,
                    onPageChanged: (i) {
                      setState(() {
                        _index = i;
                        _flipped = false;
                      });
                    },
                    itemBuilder: (context, i) {
                      final card = cards[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _flipped = !_flipped),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _flipped
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _flipped ? card.back : card.front,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Tap card to flip',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
