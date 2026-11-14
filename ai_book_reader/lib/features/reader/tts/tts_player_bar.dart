import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/reader_preferences.dart';
import 'tts_service.dart';

class TtsPlayerBar extends ConsumerWidget {
  final VoidCallback? onClose;

  const TtsPlayerBar({
    super.key,
    this.onClose,
  });

  void _showTtsSettingsModal(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ttsServiceProvider.notifier);
    final prefs = ref.read(readerPreferencesProvider);
    final themeMode = prefs.themeMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentState = ref.watch(ttsServiceProvider);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: themeMode.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: themeMode.borderColor, width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: themeMode.textColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Text-To-Speech Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeMode.textColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: themeMode.textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reading Speed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Speech Rate (${currentState.speedMultiplier.toStringAsFixed(2)}x)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeMode.textColor,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: themeMode.accentColor,
                      thumbColor: themeMode.accentColor,
                      inactiveTrackColor: themeMode.borderColor,
                    ),
                    child: Slider(
                      value: currentState.speedMultiplier,
                      min: 0.5,
                      max: 2.5,
                      divisions: 8,
                      label: '${currentState.speedMultiplier.toStringAsFixed(2)}x',
                      onChanged: (val) {
                        notifier.setSpeedMultiplier(val);
                        setModalState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pitch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Voice Pitch (${currentState.pitch.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeMode.textColor,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: themeMode.accentColor,
                      thumbColor: themeMode.accentColor,
                      inactiveTrackColor: themeMode.borderColor,
                    ),
                    child: Slider(
                      value: currentState.pitch,
                      min: 0.5,
                      max: 1.5,
                      divisions: 10,
                      label: currentState.pitch.toStringAsFixed(1),
                      onChanged: (val) {
                        notifier.setPitch(val);
                        setModalState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Volume
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Speech Volume (${(currentState.volume * 100).toInt()}%)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeMode.textColor,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: themeMode.accentColor,
                      thumbColor: themeMode.accentColor,
                      inactiveTrackColor: themeMode.borderColor,
                    ),
                    child: Slider(
                      value: currentState.volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '${(currentState.volume * 100).toInt()}%',
                      onChanged: (val) {
                        notifier.setVolume(val);
                        setModalState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsServiceProvider);
    final ttsNotifier = ref.read(ttsServiceProvider.notifier);
    final prefs = ref.watch(readerPreferencesProvider);
    final themeMode = prefs.themeMode;

    if (!ttsState.hasContent && ttsState.isStopped) {
      return const SizedBox.shrink();
    }

    final currentPara = ttsState.currentParagraph;
    final paraText = currentPara?.text ?? '';
    final previewText = paraText.length > 90
        ? '${paraText.substring(0, 87)}...'
        : paraText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: themeMode.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeMode.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Bar at the very top of the bar
            LinearProgressIndicator(
              value: ttsState.progress,
              minHeight: 3,
              backgroundColor: themeMode.borderColor.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(themeMode.accentColor),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Chapter title, progress, speed pill, and dismiss
                  Row(
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        size: 16,
                        color: themeMode.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ttsState.chapterTitle ?? 'Reading Aloud',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: themeMode.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Paragraph count indicator
                      Text(
                        '${ttsState.currentParagraphIndex + 1}/${ttsState.paragraphs.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: themeMode.textColor.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Speed Cycle Pill
                      InkWell(
                        onTap: () => ttsNotifier.cycleSpeed(),
                        onLongPress: () => _showTtsSettingsModal(context, ref),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: themeMode.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeMode.accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${ttsState.speedMultiplier.toStringAsFixed(2)}x',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: themeMode.accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Fine-tuning settings button
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        color: themeMode.textColor.withValues(alpha: 0.7),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'TTS Settings',
                        onPressed: () => _showTtsSettingsModal(context, ref),
                      ),
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: themeMode.textColor.withValues(alpha: 0.7),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Stop & Close TTS',
                        onPressed: () {
                          ttsNotifier.stop();
                          onClose?.call();
                        },
                      ),
                    ],
                  ),

                  // Paragraph preview snippet
                  if (previewText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 22, right: 8),
                      child: Text(
                        previewText,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: themeMode.textColor.withValues(alpha: 0.75),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Playback Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous Paragraph
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        iconSize: 26,
                        color: ttsState.currentParagraphIndex > 0
                            ? themeMode.textColor
                            : themeMode.textColor.withValues(alpha: 0.25),
                        tooltip: 'Previous Paragraph',
                        onPressed: ttsState.currentParagraphIndex > 0
                            ? () => ttsNotifier.previousParagraph()
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // Stop
                      IconButton(
                        icon: const Icon(Icons.stop_rounded),
                        iconSize: 26,
                        color: themeMode.textColor.withValues(alpha: 0.8),
                        tooltip: 'Stop',
                        onPressed: () => ttsNotifier.stop(),
                      ),
                      const SizedBox(width: 8),
                      // Play / Pause Primary Action
                      Material(
                        color: themeMode.accentColor,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            if (ttsState.isPlaying) {
                              ttsNotifier.pause();
                            } else {
                              ttsNotifier.play();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Icon(
                              ttsState.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Next Paragraph
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        iconSize: 26,
                        color: ttsState.currentParagraphIndex <
                                ttsState.paragraphs.length - 1
                            ? themeMode.textColor
                            : themeMode.textColor.withValues(alpha: 0.25),
                        tooltip: 'Next Paragraph',
                        onPressed: ttsState.currentParagraphIndex <
                                ttsState.paragraphs.length - 1
                            ? () => ttsNotifier.nextParagraph()
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
