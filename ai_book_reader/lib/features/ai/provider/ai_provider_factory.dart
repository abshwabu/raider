import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/ai_settings_service.dart';
import 'ai_provider.dart';
import 'gemini_direct_provider.dart';

final aiProvider = Provider<AiProvider>((ref) {
  final aiSettingsService = ref.watch(aiSettingsServiceProvider);
  return AiProviderFactory.create(aiSettingsService);
});

class AiProviderFactory {
  static AiProvider create(AiSettingsService aiSettingsService) {
    // Synchronous check or tier routing
    // Note: getAiTier is async in service, but default is 'free'.
    // Phase 4 will introduce backend-proxy provider for 'premium'.
    return GeminiDirectProvider(aiSettingsService);
  }

  static Future<AiProvider> createAsync(AiSettingsService aiSettingsService) async {
    final tier = await aiSettingsService.getAiTier();
    if (tier == 'premium') {
      throw UnimplementedError('Premium tier not yet available');
    }
    return GeminiDirectProvider(aiSettingsService);
  }
}
