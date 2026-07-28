import 'package:flutter/material.dart';
import 'package:lyrical/core/constants/app_strings.dart';

/// Brand mark for Lyrical (book + sprout), transparent background.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.showTitle = false,
    this.titleStyle,
    this.spacing = 12,
  });

  /// Width/height of the square mark.
  final double size;

  /// When true, shows the "Lyrical" wordmark under the mark.
  final bool showTitle;

  final TextStyle? titleStyle;
  final double spacing;

  static const String assetPath = 'logo/lyrical_mark.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Image.asset(
      assetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: AppStrings.appTitle,
    );

    if (!showTitle) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: spacing),
        Text(
          AppStrings.appTitle,
          style:
              titleStyle ??
              theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
