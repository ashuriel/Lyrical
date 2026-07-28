import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:lyrical/features/poems/presentation/widgets/my_poem_list_tile.dart';
import 'package:lyrical/features/poems/providers/poem_providers.dart';

class MyPoemsScreen extends ConsumerStatefulWidget {
  const MyPoemsScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<MyPoemsScreen> createState() => _MyPoemsScreenState();
}

class _MyPoemsScreenState extends ConsumerState<MyPoemsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final index = widget.initialTabIndex.clamp(0, 3);
    _tabController = TabController(length: 4, vsync: this, initialIndex: index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.discardCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.discardConfirm),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _hide(Poem poem) async {
    final okConfirm = await _confirm(
      title: AppStrings.hidePoemTitle,
      body: AppStrings.hidePoemBody,
    );
    if (!okConfirm) return;

    final ok = await ref
        .read(poemActionControllerProvider.notifier)
        .hide(poem.id);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(poemActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'No se pudo ocultar el poema. Inténtalo de nuevo.'
                : PoemErrorMapper.map(error),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.hidePoemSuccess)));
  }

  Future<void> _unhide(Poem poem) async {
    final okConfirm = await _confirm(
      title: AppStrings.unhidePoemTitle,
      body: AppStrings.unhidePoemBody,
    );
    if (!okConfirm) return;

    final ok = await ref
        .read(poemActionControllerProvider.notifier)
        .unhide(poem.id);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(poemActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'No se pudo mostrar el poema. Inténtalo de nuevo.'
                : PoemErrorMapper.map(error),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.unhidePoemSuccess)));
  }

  Future<void> _delete(Poem poem) async {
    final okConfirm = await _confirm(
      title: AppStrings.deletePoemTitle,
      body: AppStrings.deletePoemBody,
    );
    if (!okConfirm) return;

    final ok = await ref
        .read(poemActionControllerProvider.notifier)
        .softDelete(poem.id);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(poemActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'No se pudo eliminar el poema. Inténtalo de nuevo.'
                : PoemErrorMapper.map(error),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.deletePoemSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(poemActionControllerProvider);
    final busy = actionState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myPoems),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: AppStrings.poemsInReview),
            Tab(text: AppStrings.poemsPublished),
            Tab(text: AppStrings.poemsHidden),
            Tab(text: AppStrings.poemsRejected),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PoemListTab(
            provider: currentUserPendingPoemsProvider,
            emptyMessage: AppStrings.emptyPendingPoems,
            actionsEnabled: !busy,
            onView: (poem) => context.push('/app/poems/${poem.id}'),
            onDelete: _delete,
          ),
          _PoemListTab(
            provider: currentUserPublishedPoemsProvider,
            emptyMessage: AppStrings.emptyPublishedPoems,
            actionsEnabled: !busy,
            onView: (poem) => context.push('/app/poems/${poem.id}'),
            onHide: _hide,
            onDelete: _delete,
          ),
          _PoemListTab(
            provider: currentUserHiddenPoemsProvider,
            emptyMessage: AppStrings.emptyHiddenPoems,
            actionsEnabled: !busy,
            onView: (poem) => context.push('/app/poems/${poem.id}'),
            onUnhide: _unhide,
            onDelete: _delete,
          ),
          _PoemListTab(
            provider: currentUserRejectedPoemsProvider,
            emptyMessage: AppStrings.emptyRejectedPoems,
            actionsEnabled: !busy,
            onView: (poem) => context.push('/app/poems/${poem.id}'),
            onDelete: _delete,
          ),
        ],
      ),
    );
  }
}

class _PoemListTab extends ConsumerWidget {
  const _PoemListTab({
    required this.provider,
    required this.emptyMessage,
    required this.actionsEnabled,
    required this.onView,
    required this.onDelete,
    this.onHide,
    this.onUnhide,
  });

  final FutureProvider<List<Poem>> provider;
  final String emptyMessage;
  final bool actionsEnabled;
  final void Function(Poem poem) onView;
  final void Function(Poem poem) onDelete;
  final void Function(Poem poem)? onHide;
  final void Function(Poem poem)? onUnhide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

    return async.when(
      loading: () => const LoadingStateView(),
      error: (error, _) => ErrorStateView(
        message: PoemErrorMapper.map(error),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (poems) {
        if (poems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        return AppPage(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(provider);
              await ref.read(provider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: poems.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final poem = poems[index];
                return MyPoemListTile(
                  poem: poem,
                  actionsEnabled: actionsEnabled,
                  onView: () => onView(poem),
                  onHide: onHide == null ? null : () => onHide!(poem),
                  onUnhide: onUnhide == null ? null : () => onUnhide!(poem),
                  onDelete: () => onDelete(poem),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
