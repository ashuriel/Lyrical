import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lyrical/core/theme/app_colors.dart';
import 'package:lyrical/core/theme/app_spacing.dart';

/// Calm, literary Material 3 theme for Lyrical (beige paper + forest green).
abstract final class AppTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    secondaryBackground: AppColors.lightSecondaryBackground,
    surface: AppColors.lightSurface,
    elevatedSurface: AppColors.lightSurface,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightOnPrimary,
    tertiary: AppColors.lightSage,
    tertiaryContainer: AppColors.lightSageSurface,
    onTertiaryContainer: AppColors.lightPrimary,
    text: AppColors.lightText,
    muted: AppColors.lightSecondaryText,
    subtle: AppColors.lightSubtleText,
    border: AppColors.lightBorder,
    paperBorder: AppColors.lightPaperBorder,
    divider: AppColors.lightDivider,
    error: AppColors.lightError,
    success: AppColors.lightSuccess,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    secondaryBackground: AppColors.darkSecondaryBackground,
    surface: AppColors.darkSurface,
    elevatedSurface: AppColors.darkElevated,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnPrimary,
    tertiary: AppColors.darkSecondary,
    tertiaryContainer: AppColors.darkElevated,
    onTertiaryContainer: AppColors.darkPrimary,
    text: AppColors.darkText,
    muted: AppColors.darkSecondaryText,
    subtle: AppColors.darkSecondaryText,
    border: AppColors.darkBorder,
    paperBorder: AppColors.darkPaperBorder,
    divider: AppColors.darkDivider,
    error: AppColors.darkError,
    success: AppColors.darkSuccess,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color secondaryBackground,
    required Color surface,
    required Color elevatedSurface,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color tertiary,
    required Color tertiaryContainer,
    required Color onTertiaryContainer,
    required Color text,
    required Color muted,
    required Color subtle,
    required Color border,
    required Color paperBorder,
    required Color divider,
    required Color error,
    required Color success,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: tertiaryContainer,
      onPrimaryContainer: onTertiaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: tertiaryContainer,
      onSecondaryContainer: onTertiaryContainer,
      tertiary: tertiary,
      onTertiary: onPrimary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onPrimary,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: paperBorder,
      surfaceContainerLowest: background,
      surfaceContainerLow: secondaryBackground,
      surfaceContainer: elevatedSurface,
      surfaceContainerHigh: elevatedSurface,
      surfaceContainerHighest: tertiaryContainer,
      inverseSurface: primary,
      onInverseSurface: onPrimary,
      inversePrimary: brightness == Brightness.light
          ? AppColors.darkPrimary
          : AppColors.lightSageSurface,
    );

    final softBorder = paperBorder.withValues(alpha: 0.85);
    final inputIdleBorder = paperBorder.withValues(alpha: 0.95);

    final baseSans = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ).textTheme.apply(bodyColor: text, displayColor: text);

    final literata = GoogleFonts.literataTextTheme(baseSans);

    final textTheme = literata.copyWith(
      headlineLarge: literata.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.05,
        color: text,
      ),
      headlineMedium: literata.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.28,
        color: text,
      ),
      headlineSmall: literata.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: text,
      ),
      titleLarge: literata.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: text,
      ),
      titleMedium: literata.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: text,
      ),
      titleSmall: literata.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: text,
      ),
      bodyLarge: literata.bodyLarge?.copyWith(
        height: 1.7,
        fontSize: 16.5,
        color: text,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: baseSans.bodyMedium?.copyWith(
        height: 1.55,
        color: muted,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: baseSans.bodySmall?.copyWith(
        height: 1.45,
        color: subtle,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: baseSans.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: text,
      ),
      labelMedium: baseSans.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelSmall: baseSans.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: subtle,
      ),
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      side: BorderSide(color: softBorder, width: 1),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider.withValues(alpha: 0.45),
      textTheme: textTheme,
      primaryColor: primary,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0.3,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: text.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: muted),
      ),
      dividerTheme: DividerThemeData(
        color: divider.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: inputIdleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: inputIdleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: subtle),
        labelStyle: textTheme.bodyMedium,
        errorStyle: textTheme.bodySmall?.copyWith(color: error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.7),
          minimumSize: const Size(64, AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(color: onPrimary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, AppSpacing.minTapTarget),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          side: BorderSide(color: primary.withValues(alpha: 0.55)),
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(color: primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: tertiaryContainer,
        elevation: 0,
        height: 70,
        overlayColor: WidgetStatePropertyAll(primary.withValues(alpha: 0.06)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? primary : muted,
            height: 1.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 22, color: selected ? primary : muted);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tertiaryContainer.withValues(alpha: 0.65),
        selectedColor: tertiaryContainer,
        disabledColor: secondaryBackground,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: onTertiaryContainer,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: onTertiaryContainer,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        checkmarkColor: primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: paperBorder.withValues(alpha: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light
            ? AppColors.lightPrimary
            : AppColors.darkElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.light
              ? AppColors.lightOnPrimary
              : AppColors.darkText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        elevation: 1,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: primary,
        textColor: onPrimary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      iconTheme: IconThemeData(color: muted, size: 22),
      primaryIconTheme: IconThemeData(color: primary, size: 22),
      extensions: <ThemeExtension<dynamic>>[
        LyricalExtras(
          success: success,
          subtleText: subtle,
          secondaryBackground: secondaryBackground,
          paperBorder: softBorder,
          readingMaxWidth: AppSpacing.maxReadingWidth,
        ),
      ],
    );
  }
}

/// Optional extras beyond ColorScheme (success, reading width, soft borders).
@immutable
class LyricalExtras extends ThemeExtension<LyricalExtras> {
  const LyricalExtras({
    required this.success,
    required this.subtleText,
    required this.secondaryBackground,
    required this.paperBorder,
    required this.readingMaxWidth,
  });

  final Color success;
  final Color subtleText;
  final Color secondaryBackground;
  final Color paperBorder;
  final double readingMaxWidth;

  static LyricalExtras of(BuildContext context) {
    return Theme.of(context).extension<LyricalExtras>()!;
  }

  @override
  LyricalExtras copyWith({
    Color? success,
    Color? subtleText,
    Color? secondaryBackground,
    Color? paperBorder,
    double? readingMaxWidth,
  }) {
    return LyricalExtras(
      success: success ?? this.success,
      subtleText: subtleText ?? this.subtleText,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      paperBorder: paperBorder ?? this.paperBorder,
      readingMaxWidth: readingMaxWidth ?? this.readingMaxWidth,
    );
  }

  @override
  LyricalExtras lerp(ThemeExtension<LyricalExtras>? other, double t) {
    if (other is! LyricalExtras) return this;
    return LyricalExtras(
      success: Color.lerp(success, other.success, t) ?? success,
      subtleText: Color.lerp(subtleText, other.subtleText, t) ?? subtleText,
      secondaryBackground:
          Color.lerp(secondaryBackground, other.secondaryBackground, t) ??
          secondaryBackground,
      paperBorder: Color.lerp(paperBorder, other.paperBorder, t) ?? paperBorder,
      readingMaxWidth: t < 0.5 ? readingMaxWidth : other.readingMaxWidth,
    );
  }
}
