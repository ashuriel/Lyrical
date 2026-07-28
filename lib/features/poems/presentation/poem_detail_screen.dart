import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/core/widgets/poetry_type_badge.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:lyrical/features/poems/domain/poem_status.dart';
import 'package:lyrical/features/poems/providers/poem_providers.dart';

class PoemDetailScreen extends ConsumerStatefulWidget {
  const PoemDetailScreen({super.key, required this.poemId});

  final String poemId;

  @override
  ConsumerState<PoemDetailScreen> createState() => _PoemDetailScreenState();
}

class _PoemDetailScreenState extends ConsumerState<PoemDetailScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(currentUserPoemProvider(widget.poemId));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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

  void _showActionError(String fallback) {
    final error = ref.read(poemActionControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error == null ? fallback : PoemErrorMapper.map(error)),
      ),
    );
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
      _showActionError('No se pudo ocultar el poema. Inténtalo de nuevo.');
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
      _showActionError('No se pudo mostrar el poema. Inténtalo de nuevo.');
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
      _showActionError('No se pudo eliminar el poema. Inténtalo de nuevo.');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.deletePoemSuccess)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final poemAsync = ref.watch(currentUserPoemProvider(widget.poemId));
    final actionState = ref.watch(poemActionControllerProvider);
    final busy = actionState.isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.poemDetailTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.retryButton,
            onPressed: () =>
                ref.invalidate(currentUserPoemProvider(widget.poemId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: poemAsync.when(
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: PoemErrorMapper.map(error),
          onRetry: () => ref.invalidate(currentUserPoemProvider(widget.poemId)),
        ),
        data: (poem) {
          return AppPage(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentUserPoemProvider(widget.poemId));
                await ref.read(currentUserPoemProvider(widget.poemId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(poem.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PoetryTypeBadge(label: poem.poetryTypeName),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(poem), size: 18),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${AppStrings.statusLabel}: ${poem.displayStatusLabel}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${AppStrings.createdAtLabel}: ${_formatDate(poem.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (poem.publishedAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${AppStrings.publishedAtLabel}: ${_formatDate(poem.publishedAt!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SelectableText(
                    poem.content,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (poem.status == PoemStatus.approved && !poem.isHidden)
                        FilledButton.tonal(
                          onPressed: busy ? null : () => _hide(poem),
                          child: const Text(AppStrings.hidePoem),
                        ),
                      if (poem.status == PoemStatus.approved && poem.isHidden)
                        FilledButton.tonal(
                          onPressed: busy ? null : () => _unhide(poem),
                          child: const Text(AppStrings.unhidePoem),
                        ),
                      OutlinedButton(
                        onPressed: busy ? null : () => _delete(poem),
                        child: const Text(AppStrings.deletePoem),
                      ),
                    ],
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
