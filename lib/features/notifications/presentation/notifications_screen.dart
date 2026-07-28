import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/navigation/open_author_profile.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_avatar.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/empty_state_view.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/notifications/domain/app_notification.dart';
import 'package:lyrical/features/notifications/providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _message(AppNotification notification) {
    final actor = notification.actorAnonymousName?.trim();
    final poem = notification.poemTitle?.trim();
    final actorLabel = (actor == null || actor.isEmpty)
        ? AppStrings.notificationUnknownActor
        : actor;
    final poemLabel = (poem == null || poem.isEmpty)
        ? AppStrings.notificationUnknownPoem
        : poem;

    switch (notification.type) {
      case AppNotificationType.newFollower:
        return AppStrings.notificationNewFollower(actorLabel);
      case AppNotificationType.poemLiked:
        return AppStrings.notificationPoemLiked(actorLabel, poemLabel);
      case AppNotificationType.poemApproved:
        return AppStrings.notificationPoemApproved(poemLabel);
      case AppNotificationType.poemRejected:
        return AppStrings.notificationPoemRejected(poemLabel);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return AppStrings.notificationJustNow;
    if (diff.inMinutes < 60) {
      return AppStrings.notificationMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return AppStrings.notificationHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return AppStrings.notificationDaysAgo(diff.inDays);
    }

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    await ref
        .read(notificationsProvider.notifier)
        .markAsReadBestEffort(notification.id);

    if (!context.mounted) return;

    switch (notification.type) {
      case AppNotificationType.newFollower:
        final actorId = notification.actorId;
        if (actorId == null || actorId.isEmpty) {
          _showSnack(context, AppStrings.notificationDestinationUnavailable);
          return;
        }
        openAuthorProfile(context, ref, actorId);
        return;
      case AppNotificationType.poemLiked:
      case AppNotificationType.poemApproved:
      case AppNotificationType.poemRejected:
        final poemId = notification.poemId;
        if (poemId == null || poemId.isEmpty) {
          _showSnack(context, AppStrings.notificationDestinationUnavailable);
          return;
        }
        context.push('/app/poems/$poemId');
        return;
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsProvider.notifier).markAllAsRead();
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(
        context,
        error is AppException ? error.message : PoemErrorMapper.map(error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notificationsTitle),
        actions: [
          TextButton(
            onPressed: async.asData == null
                ? null
                : () => _markAll(context, ref),
            child: const Text(AppStrings.notificationsMarkAllRead),
          ),
        ],
      ),
      body: AppPage(
        child: async.when(
          loading: () => const LoadingStateView(),
          error: (error, _) => ErrorStateView(
            message: PoemErrorMapper.map(error),
            onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
          ),
          data: (state) {
            if (state.items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(notificationsProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: AppSpacing.xl),
                    EmptyStateView(
                      title: AppStrings.notificationsEmptyTitle,
                      message: AppStrings.notificationsEmptyMessage,
                      icon: Icons.notifications_none_outlined,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount:
                    state.items.length +
                    (state.hasMore || state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
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
                    return TextButton(
                      onPressed: () =>
                          ref.read(notificationsProvider.notifier).loadMore(),
                      child: const Text(AppStrings.loadMorePoems),
                    );
                  }

                  final notification = state.items[index];
                  return _NotificationTile(
                    notification: notification,
                    message: _message(notification),
                    dateLabel: _formatDate(notification.createdAt),
                    onTap: () => _onTap(context, ref, notification),
                    theme: theme,
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.message,
    required this.dateLabel,
    required this.onTap,
    required this.theme,
  });

  final AppNotification notification;
  final String message;
  final String dateLabel;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final isModeration =
        notification.type == AppNotificationType.poemApproved ||
        notification.type == AppNotificationType.poemRejected;

    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: notification.isRead
            ? Colors.transparent
            : scheme.tertiaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isModeration)
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.tertiaryContainer,
                  child: Icon(
                    notification.type == AppNotificationType.poemApproved
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: scheme.onTertiaryContainer,
                  ),
                )
              else
                AppAvatar(
                  imageUrl: notification.actorAvatarUrl,
                  size: 40,
                  semanticLabel: notification.actorAnonymousName == null
                      ? AppStrings.notificationsTitle
                      : 'Avatar de ${notification.actorAnonymousName}',
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(dateLabel, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (!notification.isRead) ...[
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  label: 'Sin leer',
                  child: Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
