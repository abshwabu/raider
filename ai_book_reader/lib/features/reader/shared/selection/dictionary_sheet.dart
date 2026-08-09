import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../ai/provider/ai_provider.dart';
import '../../selection/selection_ai_service.dart';

Future<void> showDictionarySheet({
  required BuildContext context,
  required String selectedText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DictionarySheet(selectedText: selectedText),
  );
}

class DictionarySheet extends ConsumerStatefulWidget {
  final String selectedText;

  const DictionarySheet({super.key, required this.selectedText});

  @override
  ConsumerState<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends ConsumerState<DictionarySheet> {
  bool _loading = true;
  String? _result;
  String? _error;
  bool _needsApiKey = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsApiKey = false;
      _result = null;
    });

    try {
      final result =
          await ref.read(selectionAiServiceProvider).define(widget.selectedText);
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e is NoApiKeyException) {
          _needsApiKey = true;
        } else {
          _error = e.toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dictionary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${widget.selectedText}"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_needsApiKey)
            Column(
              children: [
                const Text('Add a Gemini API key in Settings to use this feature.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (_result != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: Markdown(
                data: _result!,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
              ),
            ),
        ],
      ),
    );
  }
}
