import 'package:flutter/material.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_avatar.dart';
import 'package:lyrical/core/widgets/poem_card_view_data.dart';
import 'package:lyrical/core/widgets/poetry_type_badge.dart';

class CompactPoemCard extends StatelessWidget {
  const CompactPoemCard({
    super.key,
    required this.poem,
    this.onTap,
    this.onAuthorTap,
    this.compact = false,
  });

  final PoemCardViewData poem;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateLabel =
        '${poem.publishedAt.day.toString().padLeft(2, '0')}/'
        '${poem.publishedAt.month.toString().padLeft(2, '0')}/'
        '${poem.publishedAt.year}';

    return Card(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          width: compact ? 240 : double.infinity,
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                PoetryTypeBadge(label: poem.poetryType),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  poem.title,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        poem.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: PoetryTypeBadge(label: poem.poetryType)),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                poem.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.65,
                  fontSize: 15.5,
                  color: scheme.onSurface.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            AppAvatar(
                              imageUrl: poem.authorAvatarUrl,
                              size: 28,
                              semanticLabel:
                                  'Autor ${poem.authorAnonymousName}',
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                poem.authorAnonymousName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(dateLabel, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
