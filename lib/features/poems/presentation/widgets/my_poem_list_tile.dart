import 'package:flutter/material.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/poetry_type_badge.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:lyrical/features/poems/domain/poem_status.dart';

class MyPoemListTile extends StatelessWidget {
  const MyPoemListTile({
    super.key,
    required this.poem,
    this.onView,
    this.onHide,
    this.onUnhide,
    this.onDelete,
    this.actionsEnabled = true,
  });

  final Poem poem;
  final VoidCallback? onView;
  final VoidCallback? onHide;
  final VoidCallback? onUnhide;
  final VoidCallback? onDelete;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = poem.publishedAt ?? poem.createdAt;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    poem.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PoetryTypeBadge(label: poem.poetryTypeName),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  _statusIcon(poem),
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    poem.displayStatusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(dateLabel, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              poem.preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (onView != null)
                  TextButton(
                    onPressed: actionsEnabled ? onView : null,
                    child: const Text(AppStrings.viewPoem),
                  ),
                if (onHide != null)
                  TextButton(
                    onPressed: actionsEnabled ? onHide : null,
                    child: const Text(AppStrings.hidePoem),
                  ),
                if (onUnhide != null)
                  TextButton(
                    onPressed: actionsEnabled ? onUnhide : null,
                    child: const Text(AppStrings.unhidePoem),
                  ),
                if (onDelete != null)
                  TextButton(
                    onPressed: actionsEnabled ? onDelete : null,
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    child: const Text(AppStrings.deletePoem),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(Poem poem) {
    if (poem.status == PoemStatus.approved && poem.isHidden) {
      return Icons.visibility_off_outlined;
    }
    switch (poem.status) {
      case PoemStatus.pending:
        return Icons.hourglass_empty;
      case PoemStatus.approved:
        return Icons.menu_book_outlined;
      case PoemStatus.rejected:
        return Icons.cancel_outlined;
    }
  }
}
