import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final aiSettingsServiceProvider = Provider<AiSettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AiSettingsService(sharedPreferences: prefs);
});

class AiSettingsService {
  final SharedPreferences sharedPreferences;
  final FlutterSecureStorage secureStorage;

  static const String _keyAiTier = 'ai_tier';
  static const String _keyByokProvider = 'byok_provider';
  static const String _keyByokGeminiKey = 'byok_gemini_api_key';

  AiSettingsService({
    required this.sharedPreferences,
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<String> getAiTier() async {
    return sharedPreferences.getString(_keyAiTier) ?? 'free';
  }

  Future<void> setAiTier(String tier) async {
    await sharedPreferences.setString(_keyAiTier, tier);
  }

  Future<String> getByokProvider() async {
    return sharedPreferences.getString(_keyByokProvider) ?? 'gemini';
  }

  Future<void> setByokProvider(String provider) async {
    await sharedPreferences.setString(_keyByokProvider, provider);
  }

  Future<String?> getByokKey() async {
    return await secureStorage.read(key: _keyByokGeminiKey);
  }

  Future<void> setByokKey(String key) async {
    await secureStorage.write(key: _keyByokGeminiKey, value: key);
  }

  Future<void> clearByokKey() async {
    await secureStorage.delete(key: _keyByokGeminiKey);
  }
}
