import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  String? _successMessage;

  Future<void> _resend() async {
    final email = widget.email?.trim();
    if (email == null || email.isEmpty) return;

    final resendState = ref.read(resendEmailControllerProvider);
    if (resendState.isLoading) return;

    setState(() => _successMessage = null);

    await ref.read(resendEmailControllerProvider.notifier).resend(email: email);

    if (!mounted) return;
    final current = ref.read(resendEmailControllerProvider);
    if (current.hasError) return;

    setState(() => _successMessage = AppStrings.resendEmailSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resendState = ref.watch(resendEmailControllerProvider);
    final isLoading = resendState.isLoading;
    final errorMessage = resendState.hasError
        ? resendState.error.toString()
        : null;
    final email = widget.email?.trim();
    final canResend = email != null && email.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.verifyTitle,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.verifyBody,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (canResend) ...[
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.verifyEmailSentTo,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _successMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: !canResend || isLoading ? null : _resend,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.resendEmailButton),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isLoading ? null : () => context.go('/login'),
                    child: const Text(AppStrings.backToLogin),
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
