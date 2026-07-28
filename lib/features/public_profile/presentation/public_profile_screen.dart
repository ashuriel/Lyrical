import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_avatar.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/compact_poem_card.dart';
import 'package:lyrical/core/widgets/empty_state_view.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/public_profile/domain/public_profile.dart';
import 'package:lyrical/features/public_profile/providers/public_profile_providers.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  var _followBusy = false;

  String get userId => widget.userId;

  String? _genderLabel(String? gender) {
    switch (gender) {
      case 'female':
        return AppStrings.genderFemale;
      case 'male':
        return AppStrings.genderMale;
      default:
        return null;
    }
  }

  Future<void> _toggleFollow(PublicProfile profile) async {
    if (_followBusy || profile.isCurrentUser) return;
    final notifier = ref.read(publicProfileProvider(userId).notifier);

    if (profile.isFollowedByCurrentUser) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(AppStrings.unfollowConfirmTitle),
            content: const Text(AppStrings.unfollowConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(AppStrings.discardCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(AppStrings.unfollowConfirmAction),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    setState(() => _followBusy = true);
    try {
      if (profile.isFollowedByCurrentUser) {
        await notifier.unfollow();
      } else {
        await notifier.follow();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppException ? error.message : PoemErrorMapper.map(error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final poemsAsync = ref.watch(authorPoemsProvider(userId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.publicProfileTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.retryButton,
            onPressed: () {
              ref.invalidate(publicProfileProvider(userId));
              ref.invalidate(authorPoemsProvider(userId));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingStateView(),
        error: (error, _) {
          final message = error is AppException
              ? error.message
              : PoemErrorMapper.map(error);
          return ErrorStateView(
            message: message,
            onRetry: () {
              ref.invalidate(publicProfileProvider(userId));
              ref.invalidate(authorPoemsProvider(userId));
            },
          );
        },
        data: (profile) {
          final genderLabel = _genderLabel(profile.gender);
          final bio = profile.bio?.trim();

          return AppPage(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(publicProfileProvider(userId));
                await ref.read(authorPoemsProvider(userId).notifier).refresh();
                await ref.read(publicProfileProvider(userId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAvatar(
                        imageUrl: profile.avatarUrl,
                        size: 72,
                        semanticLabel: 'Avatar de ${profile.anonymousName}',
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.anonymousName,
                              style: theme.textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (genderLabel != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                genderLabel,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(bio, style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      _Stat(
                        label: AppStrings.publicProfilePoemsStat,
                        value: '${profile.publishedPoemCount}',
                      ),
                      _Stat(
                        label: AppStrings.publicProfileFollowersStat,
                        value: '${profile.followerCount}',
                      ),
                      _Stat(
                        label: AppStrings.publicProfileFollowingStat,
                        value: '${profile.followingCount}',
                      ),
                    ],
                  ),
                  if (!profile.isCurrentUser) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: profile.isFollowedByCurrentUser
                          ? OutlinedButton(
                              onPressed: _followBusy
                                  ? null
                                  : () => _toggleFollow(profile),
                              child: _followBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(AppStrings.followingButton),
                            )
                          : FilledButton(
                              onPressed: _followBusy
                                  ? null
                                  : () => _toggleFollow(profile),
                              child: _followBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(AppStrings.followButton),
                            ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.publicProfilePublishedPoems,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  poemsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                    error: (error, _) => ErrorStateView(
                      message: error is AppException
                          ? error.message
                          : PoemErrorMapper.map(error),
                      onRetry: () =>
                          ref.invalidate(authorPoemsProvider(userId)),
                    ),
                    data: (state) {
                      if (state.items.isEmpty) {
                        return const EmptyStateView(
                          title: AppStrings.publicProfileEmptyPoemsTitle,
                          message: AppStrings.publicProfileEmptyPoemsMessage,
                          icon: Icons.menu_book_outlined,
                        );
                      }

                      return Column(
                        children: [
                          for (var i = 0; i < state.items.length; i++) ...[
                            if (i > 0) const SizedBox(height: AppSpacing.md),
                            CompactPoemCard(
                              poem: state.items[i].toCardViewData(),
                              onTap: () => context.push(
                                '/app/poems/${state.items[i].id}',
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          if (state.isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          else if (state.hasMore)
                            TextButton(
                              onPressed: () => ref
                                  .read(authorPoemsProvider(userId).notifier)
                                  .loadMore(),
                              child: const Text(AppStrings.loadMorePoems),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
