import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import 'import_service.dart';

final incomingFileServiceProvider = Provider<IncomingFileService>((ref) {
  ImportService? importService;
  try {
    importService = ref.watch(importServiceProvider);
  } catch (_) {}
  return IncomingFileService(importService: importService);
});

class IncomingFileService {
  final ImportService? importService;
  final MethodChannel channel;

  static const String channelName = 'com.aibookreader.ai_book_reader/incoming_files';

  IncomingFileService({
    this.importService,
    MethodChannel? channel,
  }) : channel = channel ?? const MethodChannel(channelName);

  /// Retrieves any file paths that launched the application (cold start).
  Future<List<String>> getInitialFiles() async {
    try {
      final List<dynamic>? files = await channel.invokeMethod<List<dynamic>>('getInitialFiles');
      if (files != null) {
        return files.map((e) => e.toString()).where((p) => p.trim().isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Sets up a listener for files opened while the application is running (warm/hot start).
  void setFileOpenListener(void Function(List<String> paths) onFilesOpened) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onFilesOpened') {
        final List<dynamic>? files = call.arguments is List ? call.arguments as List<dynamic> : null;
        if (files != null && files.isNotEmpty) {
          final paths = files.map((e) => e.toString()).where((p) => p.trim().isNotEmpty).toList();
          if (paths.isNotEmpty) {
            onFilesOpened(paths);
          }
        }
      }
    });
  }

  /// Imports or retrieves existing books from incoming paths.
  /// Automatically cleans up temporary cache copies inside 'incoming_books'.
  Future<List<Book>> processFiles(List<String> paths) async {
    final service = importService;
    if (service == null) return [];

    final books = <Book>[];
    for (final path in paths) {
      try {
        final book = await service.importOrGetExisting(path);
        books.add(book);

        // Delete temporary cache file if it came from the incoming_books cache
        if (path.contains('incoming_books')) {
          try {
            final f = File(path);
            if (await f.exists()) {
              await f.delete();
            }
          } catch (_) {}
        }
      } catch (e) {
        // If single file failed, rethrow for user notification
        if (paths.length == 1) rethrow;
      }
    }
    return books;
  }
}
