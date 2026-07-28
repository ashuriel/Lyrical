import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/navigation/open_author_profile.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/compact_poem_card.dart';
import 'package:lyrical/core/widgets/empty_state_view.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/engagement/providers/engagement_providers.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';

class SavedPoemsScreen extends ConsumerWidget {
  const SavedPoemsScreen({super.key});

  Future<void> _removeBookmark(
    BuildContext context,
    WidgetRef ref,
    PublicPoem poem,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.removeBookmarkTitle),
          content: const Text(AppStrings.removeBookmarkBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.discardCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.removeBookmarkConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      // Ensure engagement is loaded so the notifier can mutate.
      await ref.read(poemEngagementProvider(poem.id).future);
      await ref.read(poemEngagementProvider(poem.id).notifier).removeBookmark();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.removeBookmarkSuccess)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(PoemErrorMapper.map(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPoemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.savedPoemsTitle)),
      body: AppPage(
        child: savedAsync.when(
          loading: () => const LoadingStateView(),
          error: (error, _) => ErrorStateView(
            message: PoemErrorMapper.map(error),
            onRetry: () => ref.read(savedPoemsProvider.notifier).refresh(),
          ),
          data: (state) {
            if (state.items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(savedPoemsProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: AppSpacing.xl),
                    EmptyStateView(
                      title: AppStrings.savedPoemsEmptyTitle,
                      message: AppStrings.savedPoemsEmptyMessage,
                      icon: Icons.bookmark_border,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.read(savedPoemsProvider.notifier).refresh(),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount:
                    state.items.length +
                    (state.hasMore || state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.items.length) {
                    if (state.isLoadingMore) {
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
                    return Center(
                      child: TextButton(
                        onPressed: () =>
                            ref.read(savedPoemsProvider.notifier).loadMore(),
                        child: const Text(AppStrings.loadMorePoems),
                      ),
                    );
                  }

                  final poem = state.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CompactPoemCard(
                          poem: poem.toCardViewData(),
                          onTap: () => context.push('/app/poems/${poem.id}'),
                          onAuthorTap: () =>
                              openAuthorProfile(context, ref, poem.authorId),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                _removeBookmark(context, ref, poem),
                            child: Text(
                              AppStrings.removeBookmarkAction,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
