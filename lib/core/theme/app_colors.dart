import 'package:flutter/material.dart';

/// Literary beige / forest-green color tokens for Lyrical.
///
/// Prefer [ColorScheme] in widgets. Use these tokens only when building themes.
abstract final class AppColors {
  // —— Light ——
  static const Color lightBackground = Color(0xFFF4EFE5);
  static const Color lightSecondaryBackground = Color(0xFFEAE2D3);
  static const Color lightSurface = Color(0xFFFAF7F0);
  static const Color lightPrimary = Color(0xFF1F3A32);
  static const Color lightSecondary = Color(0xFF35594B);
  static const Color lightSage = Color(0xFF6F8578);
  static const Color lightSageSurface = Color(0xFFDDE6DF);
  static const Color lightText = Color(0xFF1D2722);
  static const Color lightSecondaryText = Color(0xFF667069);
  static const Color lightSubtleText = Color(0xFF7D857F);

  /// Ink-green edges and lines (not beige).
  static const Color lightBorder = Color(0xFF35594B);
  static const Color lightDivider = Color(0xFF6F8578);
  static const Color lightError = Color(0xFF8B3A3A);
  static const Color lightOnPrimary = Color(0xFFFAF7F0);
  static const Color lightSuccess = Color(0xFF35594B);

  // —— Dark (deep green-black) ——
  static const Color darkBackground = Color(0xFF101814);
  static const Color darkSecondaryBackground = Color(0xFF16211C);
  static const Color darkSurface = Color(0xFF1B2922);
  static const Color darkElevated = Color(0xFF223129);
  static const Color darkText = Color(0xFFEEE8DC);
  static const Color darkSecondaryText = Color(0xFFA8B0AA);
  static const Color darkPrimary = Color(0xFFA8BFAE);
  static const Color darkSecondary = Color(0xFF7F9B89);
  static const Color darkBorder = Color(0xFF32433A);
  static const Color darkDivider = Color(0xFF29382F);
  static const Color darkError = Color(0xFFC87878);
  static const Color darkOnPrimary = Color(0xFF101814);
  static const Color darkSuccess = Color(0xFF7F9B89);
}
