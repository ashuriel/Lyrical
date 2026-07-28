import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

/// Authenticated gate: loads profile while the router decides welcome vs app.
class EntryScreen extends ConsumerWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const _EntryLoadingView(),
      error: (error, _) => _EntryErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(currentProfileProvider),
        onSignOut: () => ref.read(signOutControllerProvider.notifier).signOut(),
        isSigningOut: ref.watch(signOutControllerProvider).isLoading,
      ),
      data: (_) => const _EntryLoadingView(),
    );
  }
}

class _EntryLoadingView extends StatelessWidget {
  const _EntryLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(AppStrings.appTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryErrorView extends StatelessWidget {
  const _EntryErrorView({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
    required this.isSigningOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;
  final bool isSigningOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),
              Text(AppStrings.appTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 20),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSigningOut ? null : onRetry,
                  child: const Text(AppStrings.retryButton),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isSigningOut ? null : onSignOut,
                  child: isSigningOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.signOutButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
