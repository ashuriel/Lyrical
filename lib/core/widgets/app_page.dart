import 'package:flutter/material.dart';
import 'package:lyrical/core/theme/app_spacing.dart';

/// Centers content and caps width on unusually wide screens.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppSpacing.maxContentWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Readable maximum width; use [AppSpacing.maxReadingWidth] for poem detail.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding:
                padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                  vertical: AppSpacing.pageVertical,
                ),
            child: child,
          ),
        ),
      ),
    );
  }
}
