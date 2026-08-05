import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';

final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden in ProviderScope');
});

class IsarService {
  static Future<Isar> init({String? directory}) async {
    final path = directory ?? (await getApplicationDocumentsDirectory()).path;
    if (Isar.instanceNames.isEmpty) {
      return await Isar.open(
        [BookSchema, ChapterSchema],
        directory: path,
        inspector: false,
      );
    }
    return Isar.getInstance()!;
  }
}
