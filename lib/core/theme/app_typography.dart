import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Typography & Trilingual Font Helper.
/// Ensures proper line heights (>= 1.4) and glyph support for Tamil & Hindi.
class AppTypography {
  AppTypography._();

  /// Returns font family based on language code:
  /// 'ta' -> Noto Sans Tamil
  /// 'hi' -> Noto Sans Devanagari
  /// default -> Noto Sans
  static TextStyle localizedStyle({
    required String languageCode,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double height = 1.4,
    TextOverflow? overflow,
    int? textLength,
  }) {
    // Automatic text size adjustment for long text (especially Tamil script)
    double effectiveSize = fontSize;
    if (textLength != null && textLength > 0) {
      if (languageCode == 'ta') {
        if (textLength > 60) {
          effectiveSize = (fontSize * 0.85).clamp(10.5, fontSize);
        } else if (textLength > 35) {
          effectiveSize = (fontSize * 0.92).clamp(11.0, fontSize);
        }
      } else {
        if (textLength > 70) {
          effectiveSize = (fontSize * 0.88).clamp(11.0, fontSize);
        }
      }
    }

    final effectiveHeight = (languageCode == 'ta' || languageCode == 'hi')
        ? (height < 1.4 ? 1.45 : height)
        : height;

    TextStyle base;
    if (languageCode == 'ta') {
      base = GoogleFonts.notoSansTamil(
        fontSize: effectiveSize,
        fontWeight: fontWeight,
        color: color,
        height: effectiveHeight,
      );
    } else if (languageCode == 'hi') {
      base = GoogleFonts.notoSansDevanagari(
        fontSize: effectiveSize,
        fontWeight: fontWeight,
        color: color,
        height: effectiveHeight,
      );
    } else {
      base = GoogleFonts.notoSans(
        fontSize: effectiveSize,
        fontWeight: fontWeight,
        color: color,
        height: effectiveHeight,
      );
    }

    if (overflow != null) {
      return base.copyWith(overflow: overflow);
    }
    return base;
  }
}
