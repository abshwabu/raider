import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OcrPageResult {
  final int pageIndex;
  final int pageNumber;
  final String text;

  const OcrPageResult({
    required this.pageIndex,
    required this.pageNumber,
    required this.text,
  });

  factory OcrPageResult.fromMap(Map<dynamic, dynamic> map) {
    return OcrPageResult(
      pageIndex: (map['pageIndex'] as num?)?.toInt() ?? 0,
      pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 1,
      text: (map['text'] as String?)?.trim() ?? '',
    );
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

class OcrService {
  static const MethodChannel _channel =
      MethodChannel('com.aibookreader.ai_book_reader/ocr');

  final MethodChannel channel;

  OcrService({MethodChannel? channel}) : channel = channel ?? _channel;

  /// Checks if OCR hardware/model is available on this device.
  Future<bool> isAvailable() async {
    try {
      final result = await channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Extracts text from PDF pages using native PDF rendering and Google ML Kit OCR.
  Future<List<OcrPageResult>> ocrPdf({
    required String filePath,
    int startPage = 0,
    int endPage = -1,
    int maxPages = 200,
  }) async {
    try {
      final result = await channel.invokeListMethod<dynamic>('ocrPdf', {
        'filePath': filePath,
        'startPage': startPage,
        'endPage': endPage,
        'maxPages': maxPages,
      });

      if (result == null) return [];

      return result
          .whereType<Map>()
          .map((item) => OcrPageResult.fromMap(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Extracts text from a standalone image file using Google ML Kit OCR.
  Future<String> ocrImage(String imagePath) async {
    try {
      final result = await channel.invokeMethod<String>('ocrImage', {
        'imagePath': imagePath,
      });
      return result?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }
}
