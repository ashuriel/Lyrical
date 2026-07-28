import 'package:flutter/material.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/constants/poetry_type_options.dart';
import 'package:lyrical/core/mock/mock_poem.dart';
import 'package:lyrical/core/mock/mock_poems.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/compact_poem_card.dart';
import 'package:lyrical/core/widgets/empty_state_view.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  String? _selectedType;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<MockPoem> get _results {
    return MockPoems.search(
      query: _queryController.text,
      poetryType: _selectedType,
    );
  }

  void _clear() {
    setState(() {
      _queryController.clear();
      _selectedType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    final hasQuery =
        _queryController.text.trim().isNotEmpty || _selectedType != null;

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
                suffixIcon: hasQuery
                    ? IconButton(
                        onPressed: _clear,
                        tooltip: AppStrings.clearSearchTooltip,
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text(AppStrings.searchAllTypes),
                    selected: _selectedType == null,
                    onSelected: (_) => setState(() => _selectedType = null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ...PoetryTypeOptions.all.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: Text(type),
                        selected: _selectedType == type,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = selected ? type : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: results.isEmpty
                  ? const EmptyStateView(
                      title: AppStrings.searchEmptyTitle,
                      message: AppStrings.searchEmptyMessage,
                      icon: Icons.search_off,
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        return CompactPoemCard(
                          poem: results[index].toCardViewData(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
