import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final signOutState = ref.watch(signOutControllerProvider);
    final isLoading = signOutState.isLoading;
    final errorMessage = signOutState.hasError
        ? signOutState.error.toString()
        : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.profileTitle,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.profileDescription,
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(),
              if (errorMessage != null) ...[
                Text(
                  errorMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(signOutControllerProvider.notifier)
                            .signOut(),
                  child: isLoading
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
