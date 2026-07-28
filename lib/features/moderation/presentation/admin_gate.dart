import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/moderation/providers/moderation_providers.dart';

/// Gates admin-only screens. Does not replace server-side RPC authorization.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminAsync = ref.watch(isCurrentUserAdminProvider);

    return adminAsync.when(
      loading: () => const Scaffold(body: LoadingStateView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.moderationTitle)),
        body: ErrorStateView(
          message: error is AppException
              ? error.message
              : AppStrings.moderationUnauthorized,
          onRetry: () => ref.invalidate(isCurrentUserAdminProvider),
        ),
      ),
      data: (isAdmin) {
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text(AppStrings.moderationTitle)),
            body: const ErrorStateView(
              message: AppStrings.moderationUnauthorized,
            ),
          );
        }
        return child;
      },
    );
  }
}
