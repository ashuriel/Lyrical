import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/navigation/open_author_profile.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/compact_poem_card.dart';
import 'package:lyrical/core/widgets/empty_state_view.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/poems/domain/poetry_type.dart';
import 'package:lyrical/features/poems/providers/poem_providers.dart';
import 'package:lyrical/features/search/providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _openPoem(String poemId) {
    context.push('/app/poems/$poemId');
  }

  void _clear() {
    _queryController.clear();
    ref.read(poemSearchProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final search = ref.watch(poemSearchProvider);
    final typesAsync = ref.watch(poetryTypesProvider);
    final showClear =
        _queryController.text.isNotEmpty || search.poetryTypeId != null;

    return Scaffold(
      body: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.searchTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: AppStrings.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: showClear
                    ? IconButton(
                        onPressed: _clear,
                        tooltip: AppStrings.clearSearchTooltip,
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(poemSearchProvider.notifier).setQuery(value);
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.md),
            typesAsync.when(
              loading: () => const SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => ref.invalidate(poetryTypesProvider),
                  child: const Text(AppStrings.retryButton),
                ),
              ),
              data: (types) => _PoetryTypeFilters(
                types: types,
                selectedId: search.poetryTypeId,
                onSelected: (id) {
                  ref.read(poemSearchProvider.notifier).setPoetryTypeId(id);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: _SearchBody(search: search, onOpenPoem: _openPoem),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoetryTypeFilters extends StatelessWidget {
  const _PoetryTypeFilters({
    required this.types,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PoetryType> types;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text(AppStrings.searchAllTypes),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: AppSpacing.sm),
          ...types.map((type) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: Text(type.name),
                selected: selectedId == type.id,
                onSelected: (selected) {
                  onSelected(selected ? type.id : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.search, required this.onOpenPoem});

  final PoemSearchState search;
  final ValueChanged<String> onOpenPoem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    switch (search.phase) {
      case PoemSearchPhase.idle:
        return const EmptyStateView(
          title: AppStrings.searchInitialTitle,
          message: AppStrings.searchInitialMessage,
          icon: Icons.search,
        );
      case PoemSearchPhase.debouncing:
      case PoemSearchPhase.loading:
        return const LoadingStateView();
      case PoemSearchPhase.empty:
        return const EmptyStateView(
          title: AppStrings.searchEmptyTitle,
          message: AppStrings.searchEmptyMessage,
          icon: Icons.search_off,
        );
      case PoemSearchPhase.error:
        return ErrorStateView(
          message: search.errorMessage ?? AppStrings.searchGenericError,
          onRetry: () => ref.read(poemSearchProvider.notifier).retry(),
        );
      case PoemSearchPhase.results:
        return RefreshIndicator(
          onRefresh: () => ref.read(poemSearchProvider.notifier).refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
                search.items.length +
                1 +
                (search.hasMore || search.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    AppStrings.searchResultCount(search.items.length),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final poemIndex = index - 1;
              if (poemIndex < search.items.length) {
                final poem = search.items[poemIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CompactPoemCard(
                    poem: poem.toCardViewData(),
                    onTap: () => onOpenPoem(poem.id),
                    onAuthorTap: () =>
                        openAuthorProfile(context, ref, poem.authorId),
                  ),
                );
              }

              if (search.isLoadingMore) {
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
                      ref.read(poemSearchProvider.notifier).loadMore(),
                  child: const Text(AppStrings.loadMorePoems),
                ),
              );
            },
          ),
        );
    }
  }
}
