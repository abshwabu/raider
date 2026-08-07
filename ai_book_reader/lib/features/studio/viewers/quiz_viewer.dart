import 'dart:convert';
import 'package:flutter/material.dart';
import '../../ai/studio/studio_payloads.dart';

class QuizViewer extends StatefulWidget {
  final String payloadJson;

  const QuizViewer({super.key, required this.payloadJson});

  @override
  State<QuizViewer> createState() => _QuizViewerState();
}

class _QuizViewerState extends State<QuizViewer> {
  late final QuizPayload _quiz;
  int _index = 0;
  int? _selected;
  int _score = 0;
  bool _revealed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _quiz = QuizPayload.fromJson(
      Map<String, dynamic>.from(jsonDecode(widget.payloadJson) as Map),
    );
  }

  void _select(int choiceIndex) {
    if (_revealed || _finished) return;
    setState(() {
      _selected = choiceIndex;
      _revealed = true;
      if (choiceIndex == _quiz.questions[_index].correctIndex) {
        _score++;
      }
    });
  }

  void _next() {
    if (_index >= _quiz.questions.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _revealed = false;
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _selected = null;
      _revealed = false;
      _score = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_quiz.title)),
      body: _finished
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Score: $_score / ${_quiz.questions.length}',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _restart,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Question ${_index + 1} of ${_quiz.questions.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _quiz.questions[_index].question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_quiz.questions[_index].choices.length, (i) {
                    final q = _quiz.questions[_index];
                    Color? bg;
                    if (_revealed) {
                      if (i == q.correctIndex) {
                        bg = Colors.green.withValues(alpha: 0.18);
                      } else if (i == _selected) {
                        bg = Colors.red.withValues(alpha: 0.18);
                      }
                    } else if (i == _selected) {
                      bg = theme.colorScheme.primaryContainer;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: bg ?? theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _select(i),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(q.choices[i]),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_revealed) ...[
                    const SizedBox(height: 8),
                    Text(
                      _quiz.questions[_index].explanation,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      child: Text(
                        _index >= _quiz.questions.length - 1
                            ? 'See score'
                            : 'Next',
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
