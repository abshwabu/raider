import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/ai_settings_service.dart';
import '../ai/provider/ai_provider.dart';
import '../ai/provider/ai_provider_factory.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
  }

  Future<void> _loadCurrentKey() async {
    final aiSettings = ref.read(aiSettingsServiceProvider);
    final key = await aiSettings.getByokKey();
    if (mounted) {
      if (key != null) {
        _keyController.text = key;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final aiSettings = ref.read(aiSettingsServiceProvider);
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      await aiSettings.clearByokKey();
    } else {
      await aiSettings.setByokKey(key);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      // Temporarily set key in storage to test
      final aiSettings = ref.read(aiSettingsServiceProvider);
      await aiSettings.setByokKey(key);

      final provider = ref.read(aiProvider);
      final embedding = await provider.embed('test connection');

      if (mounted) {
        if (embedding.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection successful! Gemini API key is working.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test completed but no embedding values returned.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _clearKey() async {
    final aiSettings = ref.read(aiSettingsServiceProvider);
    await aiSettings.clearByokKey();
    _keyController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key cleared.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI & BYOK Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bring Your Own Key (BYOK)',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your personal Gemini API key to enable AI-powered book Q&A and semantic search. Your key is stored securely on your device using encrypted storage.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            'Get a free Gemini API key at:\nhttps://aistudio.google.com/app/apikey',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Gemini API Key',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: 'AIzaSy...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureKey = !_obscureKey;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTesting ? null : _saveKey,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save Key'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.bolt_rounded),
                          label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isTesting ? null : _clearKey,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      label: const Text('Clear Key', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
