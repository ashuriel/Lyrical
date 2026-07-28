import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/mock/mock_poems.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/app_section_header.dart';
import 'package:lyrical/core/widgets/compact_poem_card.dart';
import 'package:lyrical/core/widgets/featured_poem_card.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final anonymousName = profileAsync.asData?.value.anonymousName;

    return Scaffold(
      body: AppPage(
        child: CustomScrollView(
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
                  IconButton(
                    onPressed: () {},
                    tooltip: AppStrings.notificationsTooltip,
                    icon: const Icon(Icons.notifications_none_outlined),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: AppSectionHeader(title: AppStrings.poemOfTheDay),
            ),
            SliverToBoxAdapter(
              child: FeaturedPoemCard(poem: MockPoems.poemOfTheDay),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            SliverToBoxAdapter(
              child: AppSectionHeader(title: AppStrings.discoverSomethingNew),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 230,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: MockPoems.discovery.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    return CompactPoemCard(
                      poem: MockPoems.discovery[index],
                      compact: true,
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            SliverToBoxAdapter(
              child: AppSectionHeader(title: AppStrings.monthlySelection),
            ),
            SliverList.separated(
              itemCount: MockPoems.monthlySelection.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                return CompactPoemCard(poem: MockPoems.monthlySelection[index]);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            SliverToBoxAdapter(
              child: AppSectionHeader(title: AppStrings.recentPublications),
            ),
            ...MockPoems.recent.map(
              (poem) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CompactPoemCard(poem: poem),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          ],
        ),
      ),
    );
  }
}
