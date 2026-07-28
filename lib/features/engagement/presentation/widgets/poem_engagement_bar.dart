import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/features/engagement/domain/poem_engagement.dart';
import 'package:lyrical/features/engagement/providers/engagement_providers.dart';

/// Like + bookmark controls for a publicly visible poem.
///
/// Hidden for the poem author (no self-like; bookmark also hidden for consistency).
class PoemEngagementBar extends ConsumerWidget {
  const PoemEngagementBar({
    super.key,
    required this.poemId,
    required this.isOwner,
    required this.isPubliclyVisible,
  });

  final String poemId;
  final bool isOwner;
  final bool isPubliclyVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isPubliclyVisible || isOwner) {
      return const SizedBox.shrink();
    }

    final engagementAsync = ref.watch(poemEngagementProvider(poemId));

    return engagementAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => TextButton(
        onPressed: () => ref.invalidate(poemEngagementProvider(poemId)),
        child: const Text(AppStrings.retryButton),
      ),
      data: (engagement) =>
          _EngagementActions(poemId: poemId, engagement: engagement),
    );
  }
}

class _EngagementActions extends ConsumerStatefulWidget {
  const _EngagementActions({required this.poemId, required this.engagement});

  final String poemId;
  final PoemEngagement engagement;

  @override
  ConsumerState<_EngagementActions> createState() => _EngagementActionsState();
}

class _EngagementActionsState extends ConsumerState<_EngagementActions> {
  var _busy = false;

  Future<void> _run(Future<void> Function() action, String fallback) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : PoemErrorMapper.map(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? fallback : message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engagement = widget.engagement;
    final notifier = ref.read(poemEngagementProvider(widget.poemId).notifier);

    final likeLabel = engagement.isLiked
        ? AppStrings.unlikePoemSemantic
        : AppStrings.likePoemSemantic;
    final bookmarkLabel = engagement.isBookmarked
        ? AppStrings.removeBookmarkSemantic
        : AppStrings.bookmarkPoemSemantic;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => engagement.isLiked
                        ? notifier.unlike()
                        : notifier.like(),
                    engagement.isLiked
                        ? AppStrings.unlikePoemError
                        : AppStrings.likePoemError,
                  ),
            tooltip: likeLabel,
            icon: Icon(
              engagement.isLiked ? Icons.favorite : Icons.favorite_border,
            ),
          ),
          Semantics(
            label: '$likeLabel, ${engagement.likeCount}',
            child: Text(
              '${engagement.likeCount}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => engagement.isBookmarked
                        ? notifier.removeBookmark()
                        : notifier.bookmark(),
                    engagement.isBookmarked
                        ? AppStrings.removeBookmarkError
                        : AppStrings.bookmarkPoemError,
                  ),
            tooltip: bookmarkLabel,
            icon: Icon(
              engagement.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
        ],
      ),
    );
  }
}
