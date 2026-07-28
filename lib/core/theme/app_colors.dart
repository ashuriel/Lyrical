import 'package:flutter/material.dart';

/// Central color tokens for Lyrical light and dark themes.
abstract final class AppColors {
  // Light
  static const Color lightBackground = Color(0xFFF8F7F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF14213D);
  static const Color lightAccent = Color(0xFFD4A72C);
  static const Color lightText = Color(0xFF1C1C1C);
  static const Color lightMuted = Color(0xFF6B6B6B);
  static const Color lightBorder = Color(0xFFE2E0DA);

  // Dark
  static const Color darkBackground = Color(0xFF101521);
  static const Color darkSurface = Color(0xFF182030);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color darkAccent = Color(0xFFE0B84F);
  static const Color darkMuted = Color(0xFFB8BEC9);
  static const Color darkBorder = Color(0xFF30394A);
}
