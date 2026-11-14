import '../../../data/models/book.dart';
import '../../../data/models/chunk.dart';
import '../../../data/models/studio_artifact.dart';
import '../studio/studio_payloads.dart';

class PromptBuilder {
  /// Builds the system prompt grounding the model to answer only using provided excerpts.
  String buildSystemPrompt({required Book book}) {
    final authorStr = (book.author != null && book.author!.isNotEmpty)
        ? ' by ${book.author}'
        : '';

    return '''You are an intelligent, thoughtful reading companion for the book "${book.title}"$authorStr.

Your primary duty is to answer questions strictly using the provided book excerpts.

Guiding Principles:
1. Base your answer ONLY on the provided book excerpts.
2. If the excerpts do not contain enough information to answer the user's question, state clearly: "Based on the available excerpts from this book, I don't have enough information to answer that." Do NOT speculate or make up information outside of the excerpts.
3. Keep your tone helpful, clear, engaging, and appropriate for a literary reading companion.
4. When relevant, reference the context or chapter sections naturally.''';
  }

  /// Formats retrieved chunks as context alongside the user's question.
  String buildUserTurnWithContext({
    required String question,
    required List<Chunk> retrievedChunks,
    String? selectedPassage,
  }) {
    final buffer = StringBuffer();

    if (selectedPassage != null && selectedPassage.trim().isNotEmpty) {
      buffer.writeln('Selected Passage (primary context):');
      buffer.writeln(selectedPassage.trim());
      buffer.writeln();
    }

    if (retrievedChunks.isEmpty) {
      if (selectedPassage == null || selectedPassage.trim().isEmpty) {
        buffer.writeln('No relevant excerpts were found for this query.');
        buffer.writeln();
      }
    } else {
      buffer.writeln('Relevant Book Excerpts:');
      buffer.writeln();

      for (int i = 0; i < retrievedChunks.length; i++) {
        final chunk = retrievedChunks[i];
        buffer.writeln(
          '[Excerpt ${i + 1} | Chunk ID: ${chunk.id} | Chapter ID: ${chunk.chapterId}]',
        );
        buffer.writeln(chunk.text);
        buffer.writeln();
      }
    }

    buffer.writeln('User Question:');
    buffer.writeln(question.trim());

    return buffer.toString();
  }

  String buildSelectionSystemPrompt({
    required Book book,
    required String selectedPassage,
  }) {
    final authorStr = (book.author != null && book.author!.isNotEmpty)
        ? ' by ${book.author}'
        : '';

    return '''You are an intelligent, thoughtful reading companion for the book "${book.title}"$authorStr.

The reader has selected a specific passage. Treat that selected passage as the primary context for your answers. You may also use additional book excerpts when helpful.

Guiding Principles:
1. Prioritize the selected passage when answering.
2. Use additional book excerpts only to clarify or expand, and do not invent facts outside the provided material.
3. If the provided material is insufficient, say so clearly instead of speculating.
4. Keep your tone helpful, clear, and appropriate for a literary reading companion.
5. When relevant, quote or refer to the selected passage naturally.

Selected passage:
"""
${selectedPassage.trim()}
"""''';
  }

  String buildStudioSystemPrompt({
    required Book book,
    required StudioArtifactType type,
    required StudioArtifactScope scope,
  }) {
    final authorStr = (book.author != null && book.author!.isNotEmpty)
        ? ' by ${book.author}'
        : '';
    final scopeLabel =
        scope == StudioArtifactScope.chapter ? 'the selected chapter' : 'the whole book';

    return '''You are a study studio assistant for "${book.title}"$authorStr.

Create a high-quality ${type.name} learning artifact grounded ONLY in the provided excerpts from $scopeLabel.

Rules:
1. Use only the provided excerpts. Do not invent facts outside them.
2. If excerpts are thin, still produce the best possible artifact and keep claims modest.
3. Follow the output format exactly.
4. Prefer clear, exam-ready language.''';
  }

  String buildStudioUserPrompt({
    required StudioArtifactType type,
    required List<Chunk> excerpts,
    String? chapterTitle,
    CustomStudyGuideFormat studyGuideFormat = CustomStudyGuideFormat.executiveBrief,
  }) {
    final buffer = StringBuffer();
    if (chapterTitle != null && chapterTitle.trim().isNotEmpty) {
      buffer.writeln('Scope: chapter "$chapterTitle"');
      buffer.writeln();
    }

    buffer.writeln('Book excerpts:');
    buffer.writeln();
    if (excerpts.isEmpty) {
      buffer.writeln('(No excerpts available)');
    } else {
      for (var i = 0; i < excerpts.length; i++) {
        final chunk = excerpts[i];
        buffer.writeln('[Excerpt ${i + 1} | Chapter ID: ${chunk.chapterId}]');
        buffer.writeln(chunk.text);
        buffer.writeln();
      }
    }

    buffer.writeln(_studioTaskInstruction(type, studyGuideFormat: studyGuideFormat));
    return buffer.toString();
  }

  /// Specialized system prompt for generating executive book/chapter summaries.
  String buildBookSummarySystemPrompt({
    required Book book,
    StudioArtifactScope scope = StudioArtifactScope.book,
  }) {
    final authorStr = (book.author != null && book.author!.isNotEmpty)
        ? ' by ${book.author}'
        : '';
    final scopeLabel =
        scope == StudioArtifactScope.chapter ? 'the selected chapter' : 'the whole book';

    return '''You are an expert literary synthesizer and executive analyst for "${book.title}"$authorStr.

Produce a comprehensive, rigorous executive book summary grounded ONLY in the provided excerpts from $scopeLabel.

Rules:
1. Base every claim and takeaway strictly on the provided excerpts.
2. Structure the summary logically for rapid comprehension and deep retention.
3. Write with crystalline clarity, intellectual depth, and executive precision.
4. Provide the summary directly in Markdown without enclosing JSON or outer code fences.''';
  }

  /// Specialized user prompt for generating executive book/chapter summaries.
  String buildBookSummaryUserPrompt({
    required List<Chunk> excerpts,
    String? chapterTitle,
  }) {
    return buildStudioUserPrompt(
      type: StudioArtifactType.studyGuide,
      excerpts: excerpts,
      chapterTitle: chapterTitle,
      studyGuideFormat: CustomStudyGuideFormat.bookSummary,
    );
  }

  String _studioTaskInstruction(
    StudioArtifactType type, {
    CustomStudyGuideFormat studyGuideFormat = CustomStudyGuideFormat.executiveBrief,
  }) {
    switch (type) {
      case StudioArtifactType.quiz:
        return '''Task: Create a multiple-choice quiz.
Return ONLY valid JSON with this shape:
{
  "title": "string",
  "questions": [
    {
      "question": "string",
      "choices": ["A", "B", "C", "D"],
      "correctIndex": 0,
      "explanation": "string"
    }
  ]
}
Requirements: 5 to 8 questions, exactly 4 choices each, correctIndex is 0-based.''';
      case StudioArtifactType.flashcards:
        return '''Task: Create study flashcards.
Return ONLY valid JSON with this shape:
{
  "cards": [
    { "front": "prompt or term", "back": "answer or definition" }
  ]
}
Requirements: 8 to 16 cards covering key ideas, terms, and relationships.''';
      case StudioArtifactType.studyGuide:
        return _studyGuideInstruction(studyGuideFormat);
      case StudioArtifactType.slides:
        return '''Task: Create a slideshow outline.
Return ONLY valid JSON with this shape:
{
  "title": "string",
  "slides": [
    {
      "heading": "string",
      "bullets": ["string"],
      "speakerNote": "optional string"
    }
  ]
}
Requirements: 6 to 10 slides, 3 to 5 bullets each, concise headings.''';
      case StudioArtifactType.mindMap:
        return '''Task: Create a hierarchical mind map.
Return ONLY valid JSON with this shape:
{
  "root": {
    "label": "central topic",
    "children": [
      {
        "label": "branch",
        "children": [
          { "label": "leaf", "children": [] }
        ]
      }
    ]
  }
}
Requirements: depth 2 to 4, clear short labels, grounded in the excerpts.''';
    }
  }

  String _studyGuideInstruction(CustomStudyGuideFormat format) {
    switch (format) {
      case CustomStudyGuideFormat.executiveBrief:
        return '''Task: Create an Executive Briefing & Deep Dive study guide in Markdown.
Provide the study guide directly in Markdown (do not wrap in JSON or code fences).
Include these sections:
# Executive Briefing & Study Guide
## Core Thesis & Executive Summary
## Key Ideas & Supporting Evidence
## In-Depth Analysis & Nuances
## Frequently Asked Questions (FAQ)
## Essential Glossary & Core Terminology''';

      case CustomStudyGuideFormat.cornellNotes:
        return '''Task: Create a Cornell Notes & Active Recall study guide in Markdown.
Provide the study guide directly in Markdown (do not wrap in JSON or code fences).
Include these sections:
# Cornell Notes & Active Recall Guide
## Overview & Setting
## Cue Column (Questions & Triggers)
List 5 to 8 trigger questions or cue keywords that test recall.
## Notes & Explanations (Main Column)
Provide concise, organized notes corresponding to the cue questions.
## Summary
A 2-3 paragraph synthesis capturing the heart of the reading.
## Active Recall Self-Test
5 recall questions with concise answers to test retention.''';

      case CustomStudyGuideFormat.actionPlaybook:
        return '''Task: Create an Actionable Playbook & Implementation Checklist in Markdown.
Provide the study guide directly in Markdown (do not wrap in JSON or code fences).
Include these sections:
# Actionable Playbook & Implementation Guide
## Core Philosophy & Foundational Rules
## Step-by-Step Implementation Framework
Detailed, practical steps to apply the principles in practice.
## Pitfalls & Common Mistakes to Avoid
What to watch out for and how to prevent failure.
## Execution Checklist
A concrete Markdown checklist (- [ ] task) ready to execute.''';

      case CustomStudyGuideFormat.thematicAnalysis:
        return '''Task: Create a Thematic & Critical Analysis study guide in Markdown.
Provide the study guide directly in Markdown (do not wrap in JSON or code fences).
Include these sections:
# Thematic & Critical Analysis
## Central Themes & Motif Exploration
Deep dive into underlying themes, symbolism, and philosophical ideas.
## Historical & Intellectual Context
The backdrop and traditions informing these ideas.
## Critical Counterarguments & Limitations
Critique the thesis, identifying assumptions and counterarguments.
## Socratic Discussion & Reflection Prompts
Thoughtful questions for seminar or personal reflection.''';

      case CustomStudyGuideFormat.quickCheatSheet:
        return '''Task: Create a Rapid Cheat Sheet / One-Pager in Markdown.
Provide the study guide directly in Markdown (do not wrap in JSON or code fences).
Include these sections:
# Rapid Study Cheat Sheet
## 60-Second TL;DR
3 high-yield bullet points summarizing the entire material.
## Core Frameworks & Rules of Thumb
Key mental models, heuristics, or formulas.
## Golden Quotes & Highlights
Memorable excerpts and their significance.
## 5-Minute High-Yield Review
Rapid bulleted list for quick pre-exam or pre-meeting review.''';

      case CustomStudyGuideFormat.bookSummary:
        return '''Task: Create a Comprehensive Book Summary in Markdown.
Provide the summary directly in Markdown (do not wrap in JSON or code fences).
Include these sections:
# Comprehensive Book Summary
## Executive Overview & Main Thesis
A high-level synthesis of what this work is about and why it matters.
## Key Chapters & Narrative Arc
Section-by-section breakdown of core arguments and progression.
## Top 7 Transformative Insights
The most vital lessons and breakthroughs from the book.
## Memorable Quotes & Explanations
Key quotes that encapsulate the author's message.
## Final Assessment & Practical Takeaway
Concluding synthesis and enduring impact.''';
    }
  }
}
