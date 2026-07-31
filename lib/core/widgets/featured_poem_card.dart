import 'package:flutter/material.dart';
import 'package:lyrical/app/theme.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/poem_card_view_data.dart';
import 'package:lyrical/core/widgets/poetry_type_badge.dart';

class FeaturedPoemCard extends StatelessWidget {
  const FeaturedPoemCard({
    super.key,
    required this.poem,
    this.onTap,
    this.onAuthorTap,
  });

  final PoemCardViewData poem;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extras = LyricalExtras.of(context);

    return Card(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: extras.paperBorder, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PoetryTypeBadge(label: poem.poetryType),
              const SizedBox(height: AppSpacing.sm),
              Divider(
                height: AppSpacing.lg,
                thickness: 1,
                color: extras.paperBorder.withValues(alpha: 0.7),
              ),
              Text(
                poem.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.primary,
                  height: 1.28,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                poem.preview,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.8,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: onAuthorTap,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    poem.authorAnonymousName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
