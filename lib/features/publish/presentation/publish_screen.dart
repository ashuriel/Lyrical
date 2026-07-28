import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/poems/data/poem_repository.dart';
import 'package:lyrical/features/poems/domain/poetry_type.dart';
import 'package:lyrical/features/poems/providers/poem_providers.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(publishFormProvider);
    _titleController = TextEditingController(text: draft.title);
    _contentController = TextEditingController(text: draft.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _clearDraft() async {
    final draft = ref.read(publishFormProvider);
    if (!draft.hasUnsavedChanges) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.clearDraftTitle),
          content: const Text(AppStrings.clearDraftBody),
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
    if (confirmed != true || !mounted) return;

    ref.read(publishFormProvider.notifier).clear();
    _titleController.clear();
    _contentController.clear();
    setState(() {});
  }

  Future<void> _submit() async {
    if (ref.read(publishPoemControllerProvider).isLoading) return;

    ref.read(publishFormProvider.notifier).setTitle(_titleController.text);
    ref.read(publishFormProvider.notifier).setContent(_contentController.text);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(publishPoemControllerProvider.notifier).submit();
    if (!mounted) return;

    if (!ok) {
      final error = ref.read(publishPoemControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'No se pudo enviar el poema a revisión. Inténtalo de nuevo.'
                : PoemErrorMapper.map(error),
          ),
        ),
      );
      return;
    }

    _titleController.clear();
    _contentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.publishSuccessMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = ref.watch(publishFormProvider);
    final typesAsync = ref.watch(poetryTypesProvider);
    final submitState = ref.watch(publishPoemControllerProvider);
    final isSubmitting = submitState.isLoading;

    return Scaffold(
      body: AppPage(
        child: typesAsync.when(
          loading: () => const LoadingStateView(),
          error: (error, _) => ErrorStateView(
            message: PoemErrorMapper.map(error),
            onRetry: () => ref.invalidate(poetryTypesProvider),
          ),
          data: (types) {
            if (types.isEmpty) {
              return ErrorStateView(
                message: AppStrings.poetryTypesEmpty,
                onRetry: () => ref.invalidate(poetryTypesProvider),
              );
            }

            return Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.publishTitle,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      if (form.hasUnsavedChanges)
                        IconButton(
                          tooltip: AppStrings.clearDraftTooltip,
                          onPressed: isSubmitting ? null : _clearDraft,
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.publishDescription,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _titleController,
                    enabled: !isSubmitting,
                    maxLength: PoemRepository.maxTitleLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: AppStrings.poemTitleLabel,
                    ),
                    onChanged: (value) {
                      ref.read(publishFormProvider.notifier).setTitle(value);
                    },
                    validator: (_) => ref.read(publishFormProvider).titleError,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: form.poetryTypeId,
                    decoration: const InputDecoration(
                      labelText: AppStrings.poemTypeLabel,
                    ),
                    items: types
                        .map(
                          (PoetryType type) => DropdownMenuItem(
                            value: type.id,
                            child: Text(type.name),
                          ),
                        )
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (value) {
                            ref
                                .read(publishFormProvider.notifier)
                                .setPoetryTypeId(value);
                          },
                    validator: (_) =>
                        ref.read(publishFormProvider).poetryTypeError,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _contentController,
                    enabled: !isSubmitting,
                    maxLength: PoemRepository.maxContentLength,
                    minLines: 10,
                    maxLines: 18,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: AppStrings.poemContentLabel,
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) {
                      ref.read(publishFormProvider.notifier).setContent(value);
                    },
                    validator: (_) =>
                        ref.read(publishFormProvider).contentError,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${form.contentLength} / ${PoemRepository.maxContentLength}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.submitForReview),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
