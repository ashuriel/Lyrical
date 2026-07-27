import 'package:flutter/material.dart';

/// Calm, literary Material 3 theme for Lyrical.
abstract final class AppTheme {
  static const Color _ink = Color(0xFF1E2A32);
  static const Color _paper = Color(0xFFF4F6F7);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFF4F6B75);
  static const Color _muted = Color(0xFF5C6B73);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.light,
      primary: _accent,
      onPrimary: Colors.white,
      secondary: _muted,
      onSecondary: Colors.white,
      surface: _surface,
      onSurface: _ink,
    );

    final textTheme = ThemeData(
      useMaterial3: true,
    ).textTheme.apply(bodyColor: _ink, displayColor: _ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _paper,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          height: 1.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.5, color: _muted),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: _paper,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: _accent.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? _accent : _muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 22, color: selected ? _accent : _muted);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: _ink.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }
}
