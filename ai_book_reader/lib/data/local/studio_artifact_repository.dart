import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/studio_artifact.dart';
import 'isar_service.dart';

final studioArtifactRepositoryProvider = Provider<StudioArtifactRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return StudioArtifactRepository(isar);
});

final studioArtifactsProvider =
    StreamProvider.family<List<StudioArtifact>, int>((ref, bookId) {
  final repo = ref.watch(studioArtifactRepositoryProvider);
  return repo.watchArtifactsForBook(bookId);
});

class StudioArtifactRepository {
  final Isar isar;

  StudioArtifactRepository(this.isar);

  Future<List<StudioArtifact>> getArtifactsForBook(int bookId) async {
    return await isar.studioArtifacts
        .filter()
        .bookIdEqualTo(bookId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<StudioArtifact>> watchArtifactsForBook(int bookId) {
    return isar.studioArtifacts
        .filter()
        .bookIdEqualTo(bookId)
        .watch(fireImmediately: true)
        .asyncMap((_) => getArtifactsForBook(bookId));
  }

  Future<StudioArtifact?> getArtifact(int id) async {
    return await isar.studioArtifacts.get(id);
  }

  Future<int> saveArtifact(StudioArtifact artifact) async {
    return await isar.writeTxn(() async {
      return await isar.studioArtifacts.put(artifact);
    });
  }

  Future<void> deleteArtifact(int id) async {
    await isar.writeTxn(() async {
      await isar.studioArtifacts.delete(id);
    });
  }
}
