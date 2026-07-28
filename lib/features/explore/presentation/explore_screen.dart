import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/app/router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/navigation/open_author_profile.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/app_section_header.dart';
import 'package:lyrical/core/widgets/compact_poem_card.dart';
import 'package:lyrical/core/widgets/featured_poem_card.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:lyrical/features/explore/providers/explore_providers.dart';
import 'package:lyrical/features/notifications/providers/notification_providers.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  void _openPoem(BuildContext context, String poemId) {
    context.push('/app/poems/$poemId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final anonymousName = profileAsync.asData?.value.anonymousName;
    final poemOfTheDayAsync = ref.watch(poemOfTheDayProvider);
    final discoveryAsync = ref.watch(discoveryPoemsProvider);
    final monthlyAsync = ref.watch(monthlySelectionProvider);
    final recentAsync = ref.watch(recentPoemsProvider);
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadAsync.asData?.value ?? 0;

    return Scaffold(
      body: AppPage(
        child: RefreshIndicator(
          onRefresh: () => refreshExplorerProviders(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.appTitle,
                            style: theme.textTheme.headlineSmall,
                          ),
                          if (anonymousName != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${AppStrings.exploreGreetingPrefix} $anonymousName',
                              style: theme.textTheme.bodyLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: AppStrings.notificationsBadgeSemantic(unreadCount),
                      child: IconButton(
                        onPressed: () =>
                            context.pushNamed(AppRouteNames.notifications),
                        tooltip: AppStrings.notificationsTooltip,
                        icon: Badge(
                          isLabelVisible: unreadCount > 0,
                          label: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                          ),
                          child: Icon(
                            unreadCount > 0
                                ? Icons.notifications
                                : Icons.notifications_none_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const ContainedSliver(child: SizedBox(height: AppSpacing.lg)),
              const ContainedSliver(
                child: AppSectionHeader(title: AppStrings.poemOfTheDay),
              ),
              ContainedSliver(
                child: _AsyncSection<PublicPoem?>(
                  async: poemOfTheDayAsync,
                  onRetry: () => ref.invalidate(poemOfTheDayProvider),
                  builder: (poem) {
                    if (poem == null) {
                      return const _SectionMessage(
                        AppStrings.exploreEmptySection,
                      );
                    }
                    return FeaturedPoemCard(
                      poem: poem.toCardViewData(),
                      onTap: () => _openPoem(context, poem.id),
                      onAuthorTap: () =>
                          openAuthorProfile(context, ref, poem.authorId),
                    );
                  },
                ),
              ),
              const ContainedSliver(child: SizedBox(height: AppSpacing.xl)),
              const ContainedSliver(
                child: AppSectionHeader(title: AppStrings.discoverSomethingNew),
              ),
              ContainedSliver(
                child: _AsyncSection<List<PublicPoem>>(
                  async: discoveryAsync,
                  onRetry: () => ref.invalidate(discoveryPoemsProvider),
                  builder: (poems) {
                    if (poems.isEmpty) {
                      return const _SectionMessage(
                        AppStrings.exploreEmptySection,
                      );
                    }
                    return SizedBox(
                      height: 230,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: poems.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final poem = poems[index];
                          return CompactPoemCard(
                            poem: poem.toCardViewData(),
                            compact: true,
                            onTap: () => _openPoem(context, poem.id),
                            onAuthorTap: () =>
                                openAuthorProfile(context, ref, poem.authorId),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const ContainedSliver(child: SizedBox(height: AppSpacing.xl)),
              const ContainedSliver(
                child: AppSectionHeader(title: AppStrings.monthlySelection),
              ),
              ..._monthlySlivers(context, ref, monthlyAsync),
              const ContainedSliver(child: SizedBox(height: AppSpacing.xl)),
              const ContainedSliver(
                child: AppSectionHeader(title: AppStrings.recentPublications),
              ),
              ..._recentSlivers(context, ref, recentAsync),
              const ContainedSliver(child: SizedBox(height: AppSpacing.lg)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _monthlySlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<PublicPoem>> monthlyAsync,
  ) {
    return monthlyAsync.when(
      loading: () => [const ContainedSliver(child: _SectionLoading())],
      error: (error, _) => [
        ContainedSliver(
          child: _SectionError(
            message: PoemErrorMapper.map(error),
            onRetry: () => ref.invalidate(monthlySelectionProvider),
          ),
        ),
      ],
      data: (poems) {
        if (poems.isEmpty) {
          return [
            const ContainedSliver(
              child: _SectionMessage(AppStrings.exploreEmptySection),
            ),
          ];
        }
        return [
          ContainedSliver(
            child: Column(
              children: [
                for (var i = 0; i < poems.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  CompactPoemCard(
                    poem: poems[i].toCardViewData(),
                    onTap: () => _openPoem(context, poems[i].id),
                    onAuthorTap: () =>
                        openAuthorProfile(context, ref, poems[i].authorId),
                  ),
                ],
              ],
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _recentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<RecentPoemsState> recentAsync,
  ) {
    return recentAsync.when(
      loading: () => [const ContainedSliver(child: _SectionLoading())],
      error: (error, _) => [
        ContainedSliver(
          child: _SectionError(
            message: PoemErrorMapper.map(error),
            onRetry: () => ref.read(recentPoemsProvider.notifier).refresh(),
          ),
        ),
      ],
      data: (state) {
        if (state.items.isEmpty) {
          return [
            const ContainedSliver(
              child: _SectionMessage(AppStrings.exploreEmptyPoems),
            ),
          ];
        }

        return [
          ContainedSliver(
            child: Column(
              children: [
                for (var i = 0; i < state.items.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  CompactPoemCard(
                    poem: state.items[i].toCardViewData(),
                    onTap: () => _openPoem(context, state.items[i].id),
                    onAuthorTap: () => openAuthorProfile(
                      context,
                      ref,
                      state.items[i].authorId,
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (state.hasMore)
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.read(recentPoemsProvider.notifier).loadMore(),
                      child: const Text(AppStrings.loadMorePoems),
                    ),
                  ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

/// Local alias so Explorer can wrap section bodies as slivers.
class ContainedSliver extends StatelessWidget {
  const ContainedSliver({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    required this.async,
    required this.builder,
    required this.onRetry,
  });

  final AsyncValue<T> async;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const _SectionLoading(),
      error: (error, _) =>
          _SectionError(message: PoemErrorMapper.map(error), onRetry: onRetry),
      data: builder,
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onRetry,
            child: const Text(AppStrings.retryButton),
          ),
        ],
      ),
    );
  }
}
