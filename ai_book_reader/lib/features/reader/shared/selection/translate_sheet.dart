import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../ai/provider/ai_provider.dart';
import '../../selection/selection_ai_service.dart';

const _languages = <String>[
  'English',
  'Spanish',
  'French',
  'German',
  'Italian',
  'Portuguese',
  'Arabic',
  'Chinese',
  'Japanese',
  'Korean',
  'Hindi',
  'Russian',
  'Turkish',
  'Dutch',
  'Swedish',
];

Future<void> showTranslateSheet({
  required BuildContext context,
  required String selectedText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => TranslateSheet(selectedText: selectedText),
  );
}

class TranslateSheet extends ConsumerStatefulWidget {
  final String selectedText;

  const TranslateSheet({super.key, required this.selectedText});

  @override
  ConsumerState<TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends ConsumerState<TranslateSheet> {
  late String _targetLanguage;
  bool _loading = false;
  String? _result;
  String? _error;
  bool _needsApiKey = false;

  @override
  void initState() {
    super.initState();
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageName = _languageFromLocale(locale);
    _targetLanguage = _languages.contains(languageName) ? languageName : 'English';
    WidgetsBinding.instance.addPostFrameCallback((_) => _translate());
  }

  String _languageFromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'ar':
        return 'Arabic';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'hi':
        return 'Hindi';
      case 'ru':
        return 'Russian';
      case 'tr':
        return 'Turkish';
      case 'nl':
        return 'Dutch';
      case 'sv':
        return 'Swedish';
      default:
        return 'English';
    }
  }

  Future<void> _translate() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsApiKey = false;
      _result = null;
    });

    try {
      final result = await ref.read(selectionAiServiceProvider).translate(
            text: widget.selectedText,
            targetLanguage: _targetLanguage,
          );
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
            'Translate',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.selectedText,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Target language',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _targetLanguage,
                items: _languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _targetLanguage = value);
                        _translate();
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_needsApiKey)
            _ApiKeyPrompt(onOpenSettings: () {
              Navigator.pop(context);
              context.push('/settings');
            })
          else if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (_result != null)
            SelectableText(
              _result!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ApiKeyPrompt extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _ApiKeyPrompt({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Add a Gemini API key in Settings to use this feature.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onOpenSettings,
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}
