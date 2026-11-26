import 'package:flutter/material.dart';

/// Centralized Spacing and Layout Scale for ExamPrep (Test 11).
/// All screens and widgets should use these constants instead of magic numbers.
class AppSpacing {
  AppSpacing._();

  /// 4.0 - Extra small spacing (badge insets, icon-to-text gap)
  static const double xs = 4.0;

  /// 8.0 - Small spacing (item gap, chip spacing, tight rows)
  static const double sm = 8.0;

  /// 12.0 - Medium-small spacing (card internal gap, sub-item margin)
  static const double md = 12.0;

  /// 16.0 - Standard screen & card padding
  static const double lg = 16.0;

  /// 24.0 - Large spacing (section divider, modal margins)
  static const double xl = 24.0;

  /// 32.0 - Extra large spacing (hero banners, empty state offsets)
  static const double xxl = 32.0;

  /// Standard screen edge padding
  static const double screenPadding = 16.0;
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(screenPadding);
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(horizontal: screenPadding);

  // Reusable SizedBox Spacers
  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);

  static const SizedBox vXs = SizedBox(height: xs);
  static const SizedBox vSm = SizedBox(height: sm);
  static const SizedBox vMd = SizedBox(height: md);
  static const SizedBox vLg = SizedBox(height: lg);
  static const SizedBox vXl = SizedBox(height: xl);
  static const SizedBox vXxl = SizedBox(height: xxl);
}
