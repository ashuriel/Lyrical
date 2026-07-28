import 'package:flutter/material.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_logo.dart';

/// Calm splash shown while the initial auth state resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 120, showTitle: true, spacing: 20),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppStrings.splashTagline,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
