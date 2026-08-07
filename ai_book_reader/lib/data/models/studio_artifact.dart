import 'package:isar/isar.dart';

part 'studio_artifact.g.dart';

enum StudioArtifactType {
  quiz,
  flashcards,
  studyGuide,
  slides,
  mindMap,
}

enum StudioArtifactScope {
  book,
  chapter,
}

@collection
class StudioArtifact {
  Id id = Isar.autoIncrement;

  @Index()
  late int bookId;

  @enumerated
  late StudioArtifactType type;

  late String title;

  @enumerated
  late StudioArtifactScope scope;

  int? chapterId;

  /// JSON payload for the artifact (study guide uses `{ "markdown": "..." }`).
  late String payloadJson;

  late DateTime createdAt;
}
