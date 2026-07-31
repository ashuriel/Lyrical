import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/app/theme.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_logo.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (error, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(error.toString(), textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
      data: (profile) => _WelcomeContent(profile: profile),
    );
  }
}

class _WelcomeContent extends ConsumerStatefulWidget {
  const _WelcomeContent({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_WelcomeContent> createState() => _WelcomeContentState();
}

class _WelcomeContentState extends ConsumerState<_WelcomeContent> {
  Future<void> _enter() async {
    final controller = ref.read(completeOnboardingControllerProvider.notifier);
    final current = ref.read(completeOnboardingControllerProvider);
    if (current.isLoading) return;

    await controller.complete();
    if (!mounted) return;

    final result = ref.read(completeOnboardingControllerProvider);
    if (result.hasError) return;

    context.go('/app/explore');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extras = LyricalExtras.of(context);
    final actionState = ref.watch(completeOnboardingControllerProvider);
    final isLoading = actionState.isLoading;
    final errorMessage = actionState.hasError
        ? actionState.error.toString()
        : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg + 4,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 96, showTitle: true)),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    AppStrings.welcomeHeading,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.welcomeIdentityLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: extras.paperBorder,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Text(
                      widget.profile.anonymousName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: scheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.welcomeDescription,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.65,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      errorMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  FilledButton(
                    onPressed: isLoading ? null : _enter,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.welcomeEnterButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
