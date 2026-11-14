import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsStatus { stopped, playing, paused }

class TtsParagraphInfo {
  final int index;
  final int startOffset;
  final int endOffset;
  final String text;

  const TtsParagraphInfo({
    required this.index,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });
}

class TtsState {
  final TtsStatus status;
  final int? bookId;
  final int? chapterId;
  final String? chapterTitle;
  final List<TtsParagraphInfo> paragraphs;
  final int currentParagraphIndex;
  final double speedMultiplier; // 0.5x to 2.0x
  final double pitch; // 0.5 to 1.5
  final double volume; // 0.0 to 1.0
  final List<Map<String, String>> availableVoices;
  final Map<String, String>? selectedVoice;
  final TextRange? currentWordRange;

  const TtsState({
    this.status = TtsStatus.stopped,
    this.bookId,
    this.chapterId,
    this.chapterTitle,
    this.paragraphs = const [],
    this.currentParagraphIndex = 0,
    this.speedMultiplier = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.availableVoices = const [],
    this.selectedVoice,
    this.currentWordRange,
  });

  bool get isPlaying => status == TtsStatus.playing;
  bool get isPaused => status == TtsStatus.paused;
  bool get isStopped => status == TtsStatus.stopped;
  bool get hasContent => paragraphs.isNotEmpty;

  TtsParagraphInfo? get currentParagraph {
    if (currentParagraphIndex >= 0 && currentParagraphIndex < paragraphs.length) {
      return paragraphs[currentParagraphIndex];
    }
    return null;
  }

  double get progress {
    if (paragraphs.isEmpty) return 0.0;
    return (currentParagraphIndex + 1) / paragraphs.length;
  }

  TtsState copyWith({
    TtsStatus? status,
    int? bookId,
    int? chapterId,
    String? chapterTitle,
    List<TtsParagraphInfo>? paragraphs,
    int? currentParagraphIndex,
    double? speedMultiplier,
    double? pitch,
    double? volume,
    List<Map<String, String>>? availableVoices,
    Map<String, String>? selectedVoice,
    TextRange? currentWordRange,
    bool clearCurrentWordRange = false,
  }) {
    return TtsState(
      status: status ?? this.status,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      paragraphs: paragraphs ?? this.paragraphs,
      currentParagraphIndex: currentParagraphIndex ?? this.currentParagraphIndex,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      availableVoices: availableVoices ?? this.availableVoices,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      currentWordRange: clearCurrentWordRange
          ? null
          : (currentWordRange ?? this.currentWordRange),
    );
  }
}

class TtsService extends StateNotifier<TtsState> {
  static const _keySpeed = 'raider_tts_speed';
  static const _keyPitch = 'raider_tts_pitch';
  static const _keyVolume = 'raider_tts_volume';

  late final FlutterTts _flutterTts;
  bool _isInitialized = false;

  TtsService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts(),
        super(const TtsState()) {
    _initTts();
  }

  Future<void> _initTts() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSpeed = prefs.getDouble(_keySpeed) ?? 1.0;
      final savedPitch = prefs.getDouble(_keyPitch) ?? 1.0;
      final savedVolume = prefs.getDouble(_keyVolume) ?? 1.0;

      state = state.copyWith(
        speedMultiplier: savedSpeed,
        pitch: savedPitch,
        volume: savedVolume,
      );

      _flutterTts.setStartHandler(() {
        if (mounted) state = state.copyWith(status: TtsStatus.playing);
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) _onParagraphComplete();
      });

      _flutterTts.setCancelHandler(() {
        if (mounted) {
          state = state.copyWith(status: TtsStatus.stopped, clearCurrentWordRange: true);
        }
      });

      _flutterTts.setPauseHandler(() {
        if (mounted) state = state.copyWith(status: TtsStatus.paused);
      });

      _flutterTts.setContinueHandler(() {
        if (mounted) state = state.copyWith(status: TtsStatus.playing);
      });

      _flutterTts.setErrorHandler((dynamic msg) {
        debugPrint('TTS Error: $msg');
        if (mounted) state = state.copyWith(status: TtsStatus.stopped);
      });

      _flutterTts.setProgressHandler((String text, int start, int end, String word) {
        if (mounted) {
          state = state.copyWith(currentWordRange: TextRange(start: start, end: end));
        }
      });

      await _applyTtsSettings();

      // Retrieve available system voices
      try {
        final voices = await _flutterTts.getVoices;
        if (voices is List) {
          final mapped = <Map<String, String>>[];
          for (final v in voices) {
            if (v is Map) {
              mapped.add({
                'name': v['name']?.toString() ?? '',
                'locale': v['locale']?.toString() ?? '',
              });
            }
          }
          state = state.copyWith(availableVoices: mapped);
        }
      } catch (_) {}

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization warning: $e');
    }
  }

  Future<void> _applyTtsSettings() async {
    try {
      // In FlutterTTS, 0.5 is baseline normal speed (1.0x).
      final ttsRate = (state.speedMultiplier * 0.5).clamp(0.1, 1.0);
      await _flutterTts.setSpeechRate(ttsRate);
      await _flutterTts.setPitch(state.pitch.clamp(0.5, 1.5));
      await _flutterTts.setVolume(state.volume.clamp(0.0, 1.0));

      if (state.selectedVoice != null) {
        await _flutterTts.setVoice(state.selectedVoice!);
      }
    } catch (e) {
      debugPrint('Error applying TTS settings: $e');
    }
  }

  void _onParagraphComplete() {
    if (!mounted) return;
    if (state.currentParagraphIndex < state.paragraphs.length - 1) {
      final nextIndex = state.currentParagraphIndex + 1;
      state = state.copyWith(
        currentParagraphIndex: nextIndex,
        clearCurrentWordRange: true,
      );
      _speakCurrent();
    } else {
      // Finished all paragraphs
      state = state.copyWith(
        status: TtsStatus.stopped,
        clearCurrentWordRange: true,
      );
    }
  }

  List<TtsParagraphInfo> parseTextIntoParagraphs(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final result = <TtsParagraphInfo>[];
    final pattern = RegExp(r'\n\s*\n+|\r\n\s*\r\n+');
    final matches = pattern.allMatches(rawText).toList();

    int start = 0;
    int index = 0;

    void addSegment(int s, int e) {
      final sub = rawText.substring(s, e).trim();
      if (sub.isNotEmpty) {
        result.add(TtsParagraphInfo(
          index: index++,
          startOffset: s,
          endOffset: e,
          text: sub,
        ));
      }
    }

    for (final m in matches) {
      addSegment(start, m.start);
      start = m.end;
    }
    if (start < rawText.length) {
      addSegment(start, rawText.length);
    }

    // If text had no newlines, split by sentence boundaries for long text
    if (result.length <= 1 && rawText.length > 300) {
      result.clear();
      final sentencePattern = RegExp(r'(?<=[.!?])\s+');
      final sMatches = sentencePattern.allMatches(rawText).toList();
      int sStart = 0;
      int sIndex = 0;
      for (final sm in sMatches) {
        final sub = rawText.substring(sStart, sm.start).trim();
        if (sub.isNotEmpty) {
          result.add(TtsParagraphInfo(
            index: sIndex++,
            startOffset: sStart,
            endOffset: sm.start,
            text: sub,
          ));
        }
        sStart = sm.end;
      }
      if (sStart < rawText.length) {
        final sub = rawText.substring(sStart).trim();
        if (sub.isNotEmpty) {
          result.add(TtsParagraphInfo(
            index: sIndex++,
            startOffset: sStart,
            endOffset: rawText.length,
            text: sub,
          ));
        }
      }
    }

    return result;
  }

  Future<void> speakChapter({
    required int bookId,
    required int chapterId,
    required String chapterTitle,
    required String text,
    int startParagraph = 0,
  }) async {
    await _initTts();
    await stop();

    final parsed = parseTextIntoParagraphs(text);
    if (parsed.isEmpty) return;

    final targetIndex = startParagraph.clamp(0, parsed.length - 1);

    state = state.copyWith(
      bookId: bookId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      paragraphs: parsed,
      currentParagraphIndex: targetIndex,
      status: TtsStatus.playing,
      clearCurrentWordRange: true,
    );

    await _applyTtsSettings();
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    final curr = state.currentParagraph;
    if (curr == null) {
      if (mounted) state = state.copyWith(status: TtsStatus.stopped);
      return;
    }

    try {
      if (mounted) state = state.copyWith(status: TtsStatus.playing);
      await _flutterTts.speak(curr.text);
    } catch (e) {
      debugPrint('Error during TTS speak: $e');
      if (mounted) state = state.copyWith(status: TtsStatus.stopped);
    }
  }

  Future<void> play() async {
    if (state.isPaused) {
      await resume();
    } else if (state.isStopped && state.paragraphs.isNotEmpty) {
      await _speakCurrent();
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      if (mounted) state = state.copyWith(status: TtsStatus.paused);
    } catch (e) {
      debugPrint('Error pausing TTS: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _applyTtsSettings();
      await _speakCurrent();
    } catch (e) {
      debugPrint('Error resuming TTS: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      if (mounted) {
        state = state.copyWith(
          status: TtsStatus.stopped,
          clearCurrentWordRange: true,
        );
      }
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  Future<void> nextParagraph() async {
    if (state.currentParagraphIndex < state.paragraphs.length - 1) {
      final wasActive = state.isPlaying || state.isPaused;
      await _flutterTts.stop();
      if (mounted) {
        state = state.copyWith(
          currentParagraphIndex: state.currentParagraphIndex + 1,
          clearCurrentWordRange: true,
        );
      }
      if (wasActive) {
        await _speakCurrent();
      }
    }
  }

  Future<void> previousParagraph() async {
    if (state.currentParagraphIndex > 0) {
      final wasActive = state.isPlaying || state.isPaused;
      await _flutterTts.stop();
      if (mounted) {
        state = state.copyWith(
          currentParagraphIndex: state.currentParagraphIndex - 1,
          clearCurrentWordRange: true,
        );
      }
      if (wasActive) {
        await _speakCurrent();
      }
    }
  }

  Future<void> jumpToParagraph(int index) async {
    if (index >= 0 && index < state.paragraphs.length) {
      final wasActive = state.isPlaying || state.isPaused;
      await _flutterTts.stop();
      if (mounted) {
        state = state.copyWith(
          currentParagraphIndex: index,
          clearCurrentWordRange: true,
        );
      }
      if (wasActive) {
        await _speakCurrent();
      }
    }
  }

  Future<void> setSpeedMultiplier(double multiplier) async {
    final clamped = multiplier.clamp(0.5, 2.5);
    if (mounted) state = state.copyWith(speedMultiplier: clamped);
    await _applyTtsSettings();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeed, clamped);
  }

  Future<void> cycleSpeed() async {
    const speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    int nextIdx = 0;
    for (int i = 0; i < speeds.length; i++) {
      if ((speeds[i] - state.speedMultiplier).abs() < 0.05) {
        nextIdx = (i + 1) % speeds.length;
        break;
      }
    }
    await setSpeedMultiplier(speeds[nextIdx]);
  }

  Future<void> setPitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 1.5);
    if (mounted) state = state.copyWith(pitch: clamped);
    await _applyTtsSettings();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPitch, clamped);
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if (mounted) state = state.copyWith(volume: clamped);
    await _applyTtsSettings();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVolume, clamped);
  }

  Future<void> setVoice(Map<String, String> voice) async {
    if (mounted) state = state.copyWith(selectedVoice: voice);
    await _applyTtsSettings();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

final ttsServiceProvider = StateNotifierProvider<TtsService, TtsState>((ref) {
  return TtsService();
});
