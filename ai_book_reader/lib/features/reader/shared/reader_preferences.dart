import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderThemeMode {
  light(
    name: 'Light',
    description: 'Clean paper white',
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1E293B),
    cardColor: Color(0xFFF1F5F9),
    borderColor: Color(0xFFE2E8F0),
    accentColor: Color(0xFF4F46E5),
  ),
  sepia(
    name: 'Sepia',
    description: 'Warm book parchment',
    backgroundColor: Color(0xFFF7EFE2),
    textColor: Color(0xFF3D2E1E),
    cardColor: Color(0xFFEFE4D2),
    borderColor: Color(0xFFE5D5BF),
    accentColor: Color(0xFF9A5B2D),
  ),
  cream(
    name: 'Cream',
    description: 'Eye-care solarized',
    backgroundColor: Color(0xFFFDF6E3),
    textColor: Color(0xFF3B484E),
    cardColor: Color(0xFFF5EACF),
    borderColor: Color(0xFFE9DCBA),
    accentColor: Color(0xFF2AA198),
  ),
  dark(
    name: 'Dark',
    description: 'Charcoal night',
    backgroundColor: Color(0xFF1A1D24),
    textColor: Color(0xFFE2E8F0),
    cardColor: Color(0xFF242934),
    borderColor: Color(0xFF2E3442),
    accentColor: Color(0xFF6366F1),
  ),
  amoled(
    name: 'AMOLED',
    description: 'Pure pitch black for OLED',
    backgroundColor: Color(0xFF000000),
    textColor: Color(0xFFEDEDED),
    cardColor: Color(0xFF121212),
    borderColor: Color(0xFF262626),
    accentColor: Color(0xFF818CF8),
  ),
  slate(
    name: 'Raider Slate',
    description: 'Deep navy midnight',
    backgroundColor: Color(0xFF0F172A),
    textColor: Color(0xFFF8FAFC),
    cardColor: Color(0xFF1E293B),
    borderColor: Color(0xFF334155),
    accentColor: Color(0xFF38BDF8),
  );

  final String name;
  final String description;
  final Color backgroundColor;
  final Color textColor;
  final Color cardColor;
  final Color borderColor;
  final Color accentColor;

  const ReaderThemeMode({
    required this.name,
    required this.description,
    required this.backgroundColor,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    required this.accentColor,
  });
}

enum ReaderFontFamily {
  system(name: 'System Sans', label: 'Default clean font'),
  serif(name: 'System Serif', label: 'Classic book serif'),
  literata(name: 'Literata', label: 'Designed for digital reading'),
  merriweather(name: 'Merriweather', label: 'Warm editorial serif'),
  lora(name: 'Lora', label: 'Contemporary literary serif'),
  roboto(name: 'Roboto', label: 'Modern balanced sans'),
  openSans(name: 'Open Sans', label: 'Neutral high legibility'),
  firaCode(name: 'Fira Code', label: 'Clean monospace'),
  dyslexic(name: 'Dyslexic Friendly', label: 'High contrast & distinct weights');

  final String name;
  final String label;

  const ReaderFontFamily({
    required this.name,
    required this.label,
  });
}

class ReaderPreferences {
  final ReaderThemeMode themeMode;
  final ReaderFontFamily fontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final int fontWeightIndex; // 0: Normal, 1: Medium, 2: Semi-Bold, 3: Bold
  final bool isJustified;
  final double horizontalPadding;

  const ReaderPreferences({
    this.themeMode = ReaderThemeMode.slate,
    this.fontFamily = ReaderFontFamily.system,
    this.fontSize = 17.0,
    this.lineHeight = 1.6,
    this.letterSpacing = 0.0,
    this.fontWeightIndex = 0,
    this.isJustified = false,
    this.horizontalPadding = 20.0,
  });

  FontWeight get fontWeight {
    switch (fontWeightIndex) {
      case 1:
        return FontWeight.w500;
      case 2:
        return FontWeight.w600;
      case 3:
        return FontWeight.w700;
      default:
        return FontWeight.w400;
    }
  }

  TextStyle getTextStyle({Color? overrideColor, double? overrideFontSize}) {
    final color = overrideColor ?? themeMode.textColor;
    final size = overrideFontSize ?? fontSize;
    final weight = fontWeight;
    final height = lineHeight;
    final spacing = fontFamily == ReaderFontFamily.dyslexic
        ? (letterSpacing + 0.8)
        : letterSpacing;

    final baseStyle = TextStyle(
      color: color,
      fontSize: size,
      fontWeight: fontFamily == ReaderFontFamily.dyslexic ? FontWeight.w500 : weight,
      height: height,
      letterSpacing: spacing,
      wordSpacing: fontFamily == ReaderFontFamily.dyslexic ? 2.5 : null,
    );

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return baseStyle.copyWith(fontFamily: fontFamily.name);
    }

    try {
      switch (fontFamily) {
        case ReaderFontFamily.literata:
          return GoogleFonts.literata(textStyle: baseStyle);
        case ReaderFontFamily.merriweather:
          return GoogleFonts.merriweather(textStyle: baseStyle);
        case ReaderFontFamily.lora:
          return GoogleFonts.lora(textStyle: baseStyle);
        case ReaderFontFamily.roboto:
          return GoogleFonts.roboto(textStyle: baseStyle);
        case ReaderFontFamily.openSans:
          return GoogleFonts.openSans(textStyle: baseStyle);
        case ReaderFontFamily.firaCode:
          return GoogleFonts.firaCode(textStyle: baseStyle);
        case ReaderFontFamily.serif:
          return baseStyle.copyWith(fontFamily: 'serif');
        case ReaderFontFamily.dyslexic:
          // Atkinson Hyperlegible or OpenDyslexic fallback
          return GoogleFonts.atkinsonHyperlegible(textStyle: baseStyle);
        case ReaderFontFamily.system:
          return baseStyle;
      }
    } catch (_) {
      // Fallback to base style if font downloading fails or is offline
      return baseStyle;
    }
  }

  ReaderPreferences copyWith({
    ReaderThemeMode? themeMode,
    ReaderFontFamily? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    int? fontWeightIndex,
    bool? isJustified,
    double? horizontalPadding,
  }) {
    return ReaderPreferences(
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontWeightIndex: fontWeightIndex ?? this.fontWeightIndex,
      isJustified: isJustified ?? this.isJustified,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
    );
  }
}

class ReaderPreferencesNotifier extends StateNotifier<ReaderPreferences> {
  static const _keyTheme = 'raider_reader_theme';
  static const _keyFont = 'raider_reader_font';
  static const _keyFontSize = 'raider_reader_font_size';
  static const _keyLineHeight = 'raider_reader_line_height';
  static const _keyLetterSpacing = 'raider_reader_letter_spacing';
  static const _keyFontWeight = 'raider_reader_font_weight';
  static const _keyJustified = 'raider_reader_justified';
  static const _keyPadding = 'raider_reader_padding';

  ReaderPreferencesNotifier() : super(const ReaderPreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeName = prefs.getString(_keyTheme);
      final fontName = prefs.getString(_keyFont);
      final fontSize = prefs.getDouble(_keyFontSize);
      final lineHeight = prefs.getDouble(_keyLineHeight);
      final letterSpacing = prefs.getDouble(_keyLetterSpacing);
      final fontWeight = prefs.getInt(_keyFontWeight);
      final isJustified = prefs.getBool(_keyJustified);
      final padding = prefs.getDouble(_keyPadding);

      ReaderThemeMode theme = ReaderThemeMode.slate;
      if (themeName != null) {
        for (final t in ReaderThemeMode.values) {
          if (t.name.toLowerCase() == themeName.toLowerCase()) {
            theme = t;
            break;
          }
        }
      }

      ReaderFontFamily font = ReaderFontFamily.system;
      if (fontName != null) {
        for (final f in ReaderFontFamily.values) {
          if (f.name.toLowerCase() == fontName.toLowerCase()) {
            font = f;
            break;
          }
        }
      }

      state = ReaderPreferences(
        themeMode: theme,
        fontFamily: font,
        fontSize: fontSize ?? 17.0,
        lineHeight: lineHeight ?? 1.6,
        letterSpacing: letterSpacing ?? 0.0,
        fontWeightIndex: fontWeight ?? 0,
        isJustified: isJustified ?? false,
        horizontalPadding: padding ?? 20.0,
      );
    } catch (_) {}
  }

  Future<void> updateTheme(ReaderThemeMode theme) async {
    state = state.copyWith(themeMode: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme.name);
  }

  Future<void> updateFont(ReaderFontFamily font) async {
    state = state.copyWith(fontFamily: font);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFont, font.name);
  }

  Future<void> updateFontSize(double size) async {
    state = state.copyWith(fontSize: size.clamp(12.0, 36.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, state.fontSize);
  }

  Future<void> updateLineHeight(double height) async {
    state = state.copyWith(lineHeight: height.clamp(1.2, 2.5));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLineHeight, state.lineHeight);
  }

  Future<void> updateLetterSpacing(double spacing) async {
    state = state.copyWith(letterSpacing: spacing.clamp(-0.5, 2.5));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLetterSpacing, state.letterSpacing);
  }

  Future<void> updateFontWeightIndex(int index) async {
    state = state.copyWith(fontWeightIndex: index.clamp(0, 3));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFontWeight, state.fontWeightIndex);
  }

  Future<void> toggleJustified() async {
    state = state.copyWith(isJustified: !state.isJustified);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyJustified, state.isJustified);
  }

  Future<void> updatePadding(double padding) async {
    state = state.copyWith(horizontalPadding: padding);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPadding, padding);
  }

  Future<void> resetToDefaults() async {
    state = const ReaderPreferences();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTheme);
    await prefs.remove(_keyFont);
    await prefs.remove(_keyFontSize);
    await prefs.remove(_keyLineHeight);
    await prefs.remove(_keyLetterSpacing);
    await prefs.remove(_keyFontWeight);
    await prefs.remove(_keyJustified);
    await prefs.remove(_keyPadding);
  }
}

final readerPreferencesProvider =
    StateNotifierProvider<ReaderPreferencesNotifier, ReaderPreferences>((ref) {
  return ReaderPreferencesNotifier();
});
