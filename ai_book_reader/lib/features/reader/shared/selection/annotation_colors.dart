import 'package:flutter/material.dart';
import '../../../../data/models/annotation.dart';

extension AnnotationColorX on AnnotationColor {
  Color get fillColor {
    switch (this) {
      case AnnotationColor.yellow:
        return const Color(0x66FFEB3B);
      case AnnotationColor.green:
        return const Color(0x664CAF50);
      case AnnotationColor.blue:
        return const Color(0x662196F3);
      case AnnotationColor.pink:
        return const Color(0x66E91E63);
    }
  }

  Color get swatchColor {
    switch (this) {
      case AnnotationColor.yellow:
        return const Color(0xFFFFEB3B);
      case AnnotationColor.green:
        return const Color(0xFF4CAF50);
      case AnnotationColor.blue:
        return const Color(0xFF2196F3);
      case AnnotationColor.pink:
        return const Color(0xFFE91E63);
    }
  }

  String get label {
    switch (this) {
      case AnnotationColor.yellow:
        return 'Yellow';
      case AnnotationColor.green:
        return 'Green';
      case AnnotationColor.blue:
        return 'Blue';
      case AnnotationColor.pink:
        return 'Pink';
    }
  }
}
