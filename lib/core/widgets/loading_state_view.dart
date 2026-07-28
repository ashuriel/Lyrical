import 'package:flutter/material.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_logo.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 72, showTitle: true, spacing: 12),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
