import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/empty_state_view.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/moderation/domain/pending_moderation_poem.dart';
import 'package:lyrical/features/moderation/presentation/admin_gate.dart';
import 'package:lyrical/features/moderation/providers/moderation_providers.dart';

class ModerationListScreen extends ConsumerWidget {
  const ModerationListScreen({super.key});

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.moderationTitle),
          actions: [
            IconButton(
              tooltip: AppStrings.retryButton,
              onPressed: () =>
                  ref.read(pendingModerationListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _ModerationListBody(formatDate: _formatDate),
      ),
    );
  }
}

class _ModerationListBody extends ConsumerWidget {
  const _ModerationListBody({required this.formatDate});

  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(pendingModerationListProvider);
    final theme = Theme.of(context);

    return listAsync.when(
      loading: () => const LoadingStateView(),
      error: (error, _) => ErrorStateView(
        message: error is AppException
            ? error.message
            : AppStrings.moderationListError,
        onRetry: () =>
            ref.read(pendingModerationListProvider.notifier).refresh(),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(pendingModerationListProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                EmptyStateView(
                  title: AppStrings.moderationEmptyTitle,
                  message: AppStrings.moderationEmptyMessage,
                  icon: Icons.fact_check_outlined,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(pendingModerationListProvider.notifier).refresh(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                ref.read(pendingModerationListProvider.notifier).loadMore();
              }
              return false;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final poem = state.items[index];
                return _PendingPoemTile(
                  poem: poem,
                  dateLabel: formatDate(poem.createdAt),
                  onReview: () =>
                      context.push('/app/admin/moderation/${poem.poemId}'),
                  theme: theme,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PendingPoemTile extends StatelessWidget {
  const _PendingPoemTile({
    required this.poem,
    required this.dateLabel,
    required this.onReview,
    required this.theme,
  });

  final PendingModerationPoem poem;
  final String dateLabel;
  final VoidCallback onReview;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poem.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${poem.poetryTypeName} · ${poem.authorAnonymousName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              dateLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              poem.preview,
              style: theme.textTheme.bodyLarge,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onReview,
                child: const Text(AppStrings.moderationReviewAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
