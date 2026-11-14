import 'package:flutter/material.dart';

enum PromptCategory {
  summaries(
    id: 'summaries',
    title: 'Summaries & Key Ideas',
    icon: Icons.summarize_outlined,
  ),
  deepLearning(
    id: 'deep_learning',
    title: 'Deep Understanding',
    icon: Icons.psychology_outlined,
  ),
  criticalAnalysis(
    id: 'critical_analysis',
    title: 'Analysis & Critique',
    icon: Icons.analytics_outlined,
  ),
  actionable(
    id: 'actionable',
    title: 'Actionable Takeaways',
    icon: Icons.checklist_outlined,
  ),
  themes(
    id: 'themes',
    title: 'Themes & Context',
    icon: Icons.auto_stories_outlined,
  );

  final String id;
  final String title;
  final IconData icon;

  const PromptCategory({
    required this.id,
    required this.title,
    required this.icon,
  });
}

class PromptTemplate {
  final String id;
  final String title;
  final String shortDescription;
  final String promptText;
  final PromptCategory category;
  final IconData icon;

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.promptText,
    required this.category,
    required this.icon,
  });

  /// Adapts the prompt if a specific passage is selected.
  String getEffectivePrompt({String? selectedPassage}) {
    if (selectedPassage != null && selectedPassage.trim().isNotEmpty) {
      return 'Regarding the selected passage:\n$promptText';
    }
    return promptText;
  }
}

class PromptTemplateLibrary {
  static const List<PromptTemplate> all = [
    // 1. Summaries & Key Ideas
    PromptTemplate(
      id: 'executive_summary',
      title: 'Executive Summary',
      shortDescription: 'Core thesis, key arguments, and overarching conclusion.',
      promptText:
          'Provide an executive summary of this material. Highlight the core thesis, the primary arguments supporting it, and the overarching takeaway.',
      category: PromptCategory.summaries,
      icon: Icons.article_outlined,
    ),
    PromptTemplate(
      id: 'key_takeaways',
      title: 'Key Takeaways',
      shortDescription: 'The 5 most crucial insights and principles.',
      promptText:
          'What are the 5 most important insights and takeaways from this text? Explain why each matters and how they connect.',
      category: PromptCategory.summaries,
      icon: Icons.lightbulb_outline,
    ),
    PromptTemplate(
      id: 'tldr_brief',
      title: '60-Second TL;DR',
      shortDescription: 'A rapid 3-bullet essence of the reading.',
      promptText:
          'Give me a concise 3-bullet TL;DR summary capturing the essence of this reading in under 60 seconds.',
      category: PromptCategory.summaries,
      icon: Icons.bolt_outlined,
    ),
    PromptTemplate(
      id: 'comprehensive_synthesis',
      title: 'Comprehensive Book Synthesis',
      shortDescription: 'High-level synthesis of narrative arc and themes.',
      promptText:
          'Synthesize the central message, narrative arc, and philosophical contribution of this work in a structured overview.',
      category: PromptCategory.summaries,
      icon: Icons.menu_book_outlined,
    ),

    // 2. Deep Understanding
    PromptTemplate(
      id: 'feynman_simple',
      title: 'Feynman / Explain Simply',
      shortDescription: 'Explain complex concepts in simple terms with an analogy.',
      promptText:
          'Explain the central concepts here in plain, beginner-friendly terms using the Feynman technique. Include a clear real-world analogy to illustrate the main idea.',
      category: PromptCategory.deepLearning,
      icon: Icons.child_care_outlined,
    ),
    PromptTemplate(
      id: 'socratic_dialogue',
      title: 'Socratic Inquiries',
      shortDescription: 'Test your comprehension with 3 probing questions.',
      promptText:
          'Act as a Socratic tutor. Pose 3 thought-provoking questions based on this text that challenge my understanding, then outline the key considerations for answering each.',
      category: PromptCategory.deepLearning,
      icon: Icons.question_answer_outlined,
    ),
    PromptTemplate(
      id: 'mental_models',
      title: 'Mental Models & Frameworks',
      shortDescription: 'Identify frameworks, heuristics, and reasoning models.',
      promptText:
          'Identify and break down any mental models, frameworks, or heuristics presented in this reading. How can they be applied to solve complex problems?',
      category: PromptCategory.deepLearning,
      icon: Icons.hub_outlined,
    ),
    PromptTemplate(
      id: 'analogies_metaphors',
      title: 'Core Metaphors & Imagery',
      shortDescription: 'Analyze the primary metaphors and analogies used.',
      promptText:
          'What are the primary metaphors, imagery, or analogies the author uses, and how do they deepen the meaning of the work?',
      category: PromptCategory.deepLearning,
      icon: Icons.brush_outlined,
    ),

    // 3. Analysis & Critique
    PromptTemplate(
      id: 'critical_critique',
      title: 'Critical Counterarguments',
      shortDescription: 'Unstated assumptions, limitations, and counter-perspectives.',
      promptText:
          'Critique the arguments made in this text. What unstated assumptions does the author rely upon, and what are the strongest counterarguments or limitations to their view?',
      category: PromptCategory.criticalAnalysis,
      icon: Icons.balance_outlined,
    ),
    PromptTemplate(
      id: 'rhetorical_analysis',
      title: "Author's Tone & Rhetoric",
      shortDescription: 'Analyze tone, stylistic choices, and persuasive intent.',
      promptText:
          "Analyze the author's tone, voice, and rhetorical strategies in this material. How does their style support or influence their intended message?",
      category: PromptCategory.criticalAnalysis,
      icon: Icons.record_voice_over_outlined,
    ),
    PromptTemplate(
      id: 'logical_structure',
      title: 'Argument Structure Breakdown',
      shortDescription: 'Dismantle premises, evidence, and conclusions.',
      promptText:
          'Break down the logical structure of this argument: premises, supporting evidence, logical leaps, and ultimate conclusion.',
      category: PromptCategory.criticalAnalysis,
      icon: Icons.account_tree_outlined,
    ),

    // 4. Actionable Takeaways
    PromptTemplate(
      id: 'actionable_checklist',
      title: 'Actionable Implementation Checklist',
      shortDescription: 'Turn insights into a concrete to-do checklist.',
      promptText:
          'Translate the key principles in this text into a concrete, actionable implementation checklist that I can execute immediately.',
      category: PromptCategory.actionable,
      icon: Icons.checklist_rtl_outlined,
    ),
    PromptTemplate(
      id: 'pitfalls_to_avoid',
      title: 'Pitfalls & Mistakes to Avoid',
      shortDescription: 'Misconceptions and failure modes warned against.',
      promptText:
          'What pitfalls, errors, or common misconceptions does this reading warn against, and what strategies does it suggest to prevent them?',
      category: PromptCategory.actionable,
      icon: Icons.warning_amber_outlined,
    ),
    PromptTemplate(
      id: 'real_world_application',
      title: 'Real-World Scenarios',
      shortDescription: '3 concrete applications in daily life or work.',
      promptText:
          'Provide 3 concrete, realistic scenarios illustrating how the lessons and insights from this text can be applied in everyday life or work.',
      category: PromptCategory.actionable,
      icon: Icons.work_outline,
    ),

    // 5. Themes & Context
    PromptTemplate(
      id: 'key_themes',
      title: 'Themes & Motifs',
      shortDescription: 'Recurring motifs, symbols, and underlying themes.',
      promptText:
          'Explore the major underlying themes, motifs, and symbolism in this text. How do they develop and interact across the reading?',
      category: PromptCategory.themes,
      icon: Icons.auto_stories_outlined,
    ),
    PromptTemplate(
      id: 'historical_context',
      title: 'Historical & Philosophical Context',
      shortDescription: 'Historical, cultural, or philosophical backdrop.',
      promptText:
          'Discuss the broader historical, cultural, or philosophical context surrounding this text and how it shapes its core ideas.',
      category: PromptCategory.themes,
      icon: Icons.history_edu_outlined,
    ),
  ];

  /// Curated quick-starter chips for empty chat state.
  static const List<PromptTemplate> quickStarters = [
    PromptTemplate(
      id: 'quick_summary',
      title: 'Executive Summary',
      shortDescription: 'High-level synthesis',
      promptText:
          'Provide an executive summary of this material. Highlight the core thesis, the primary arguments supporting it, and the overarching takeaway.',
      category: PromptCategory.summaries,
      icon: Icons.summarize_outlined,
    ),
    PromptTemplate(
      id: 'quick_takeaways',
      title: 'Key Takeaways',
      shortDescription: 'Top 5 takeaways',
      promptText:
          'What are the 5 most important insights and takeaways from this text? Explain why each matters and how they connect.',
      category: PromptCategory.summaries,
      icon: Icons.lightbulb_outline,
    ),
    PromptTemplate(
      id: 'quick_feynman',
      title: 'Explain Simply',
      shortDescription: 'Feynman technique with analogy',
      promptText:
          'Explain the central concepts here in plain, beginner-friendly terms using the Feynman technique. Include a clear real-world analogy to illustrate the main idea.',
      category: PromptCategory.deepLearning,
      icon: Icons.child_care_outlined,
    ),
    PromptTemplate(
      id: 'quick_checklist',
      title: 'Action Checklist',
      shortDescription: 'Practical action items',
      promptText:
          'Translate the key principles in this text into a concrete, actionable implementation checklist that I can execute immediately.',
      category: PromptCategory.actionable,
      icon: Icons.checklist_outlined,
    ),
    PromptTemplate(
      id: 'quick_critique',
      title: 'Critical Analysis',
      shortDescription: 'Assumptions and counterarguments',
      promptText:
          'Critique the arguments made in this text. What unstated assumptions does the author rely upon, and what are the strongest counterarguments or limitations to their view?',
      category: PromptCategory.criticalAnalysis,
      icon: Icons.balance_outlined,
    ),
    PromptTemplate(
      id: 'quick_themes',
      title: 'Themes & Motifs',
      shortDescription: 'Underlying motifs and themes',
      promptText:
          'Explore the major underlying themes, motifs, and symbolism in this text. How do they develop and interact across the reading?',
      category: PromptCategory.themes,
      icon: Icons.auto_stories_outlined,
    ),
  ];

  static List<PromptTemplate> byCategory(PromptCategory category) {
    return all.where((t) => t.category == category).toList();
  }
}
