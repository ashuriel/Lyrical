import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_avatar.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/moderation/domain/pending_moderation_poem.dart';
import 'package:lyrical/features/moderation/presentation/admin_gate.dart';
import 'package:lyrical/features/moderation/providers/moderation_providers.dart';

class ModerationDetailScreen extends ConsumerStatefulWidget {
  const ModerationDetailScreen({super.key, required this.poemId});

  final String poemId;

  @override
  ConsumerState<ModerationDetailScreen> createState() =>
      _ModerationDetailScreenState();
}

class _ModerationDetailScreenState
    extends ConsumerState<ModerationDetailScreen> {
  var _busy = false;

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.dialogCancel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _approve(PendingModerationPoem poem) async {
    if (_busy) return;
    final ok = await _confirm(
      title: AppStrings.moderationApproveTitle,
      body: AppStrings.moderationApproveBody,
      confirmLabel: AppStrings.moderationApproveAction,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(moderationActionControllerProvider.notifier)
          .approve(poem.poemId, authorId: poem.authorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.moderationApproveSuccess)),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppException
                ? error.message
                : AppStrings.moderationApproveError,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(PendingModerationPoem poem) async {
    if (_busy) return;
    final ok = await _confirm(
      title: AppStrings.moderationRejectTitle,
      body: AppStrings.moderationRejectBody,
      confirmLabel: AppStrings.moderationRejectAction,
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(moderationActionControllerProvider.notifier)
          .reject(poem.poemId, authorId: poem.authorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.moderationRejectSuccess)),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppException
                ? error.message
                : AppStrings.moderationRejectError,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poemAsync = ref.watch(pendingModerationPoemProvider(widget.poemId));

    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.moderationReviewTitle)),
        body: poemAsync.when(
          loading: () => const LoadingStateView(),
          error: (error, _) => ErrorStateView(
            message: error is AppException
                ? error.message
                : AppStrings.moderationDetailError,
            onRetry: () =>
                ref.invalidate(pendingModerationPoemProvider(widget.poemId)),
          ),
          data: (poem) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;

            return AppPage(
              child: ListView(
                children: [
                  Text(poem.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    poem.poetryTypeName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      AppAvatar(
                        imageUrl: poem.authorAvatarUrl,
                        size: 40,
                        semanticLabel: 'Avatar de ${poem.authorAnonymousName}',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              poem.authorAnonymousName,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              _formatDate(poem.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SelectableText(
                    poem.content,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.moderationIrreversibleWarning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : () => _approve(poem),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.moderationApproveAction),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _reject(poem),
                    child: const Text(AppStrings.moderationRejectAction),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
