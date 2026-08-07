import 'package:flutter/material.dart';
import '../../data/models/studio_artifact.dart';
import 'viewers/flashcards_viewer.dart';
import 'viewers/mind_map_viewer.dart';
import 'viewers/quiz_viewer.dart';
import 'viewers/slides_viewer.dart';
import 'viewers/study_guide_viewer.dart';

void openStudioArtifact(BuildContext context, StudioArtifact artifact) {
  Widget page;
  switch (artifact.type) {
    case StudioArtifactType.quiz:
      page = QuizViewer(payloadJson: artifact.payloadJson);
      break;
    case StudioArtifactType.flashcards:
      page = FlashcardsViewer(payloadJson: artifact.payloadJson);
      break;
    case StudioArtifactType.studyGuide:
      page = StudyGuideViewer(payloadJson: artifact.payloadJson);
      break;
    case StudioArtifactType.slides:
      page = SlidesViewer(payloadJson: artifact.payloadJson);
      break;
    case StudioArtifactType.mindMap:
      page = MindMapViewer(payloadJson: artifact.payloadJson);
      break;
  }

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => page),
  );
}

String studioTypeLabel(StudioArtifactType type) {
  switch (type) {
    case StudioArtifactType.quiz:
      return 'Quiz';
    case StudioArtifactType.flashcards:
      return 'Flashcards';
    case StudioArtifactType.studyGuide:
      return 'Study guide';
    case StudioArtifactType.slides:
      return 'Slideshow';
    case StudioArtifactType.mindMap:
      return 'Mind map';
  }
}

IconData studioTypeIcon(StudioArtifactType type) {
  switch (type) {
    case StudioArtifactType.quiz:
      return Icons.quiz_outlined;
    case StudioArtifactType.flashcards:
      return Icons.style_outlined;
    case StudioArtifactType.studyGuide:
      return Icons.menu_book_outlined;
    case StudioArtifactType.slides:
      return Icons.slideshow_outlined;
    case StudioArtifactType.mindMap:
      return Icons.account_tree_outlined;
  }
}
