import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/profile_error_mapper.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_avatar.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/profile/data/profile_repository.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedGender;
  String? _initialGender;
  String _initialBio = '';
  Uint8List? _localPreviewBytes;
  bool _initialized = false;
  String? _avatarFeedback;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    final bio = _bioController.text.trim();
    return _selectedGender != _initialGender || bio != _initialBio;
  }

  void _hydrateFromProfile(Profile profile) {
    if (_initialized) return;
    _selectedGender = profile.gender;
    _initialGender = profile.gender;
    _initialBio = profile.bio?.trim() ?? '';
    _bioController.text = _initialBio;
    _initialized = true;
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.discardProfileEditsTitle),
          content: const Text(AppStrings.discardProfileEditsBody),
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

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _avatarFeedback = null);

    final XFile? file;
    try {
      file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _avatarFeedback = ProfileErrorMapper.map(error);
      });
      return;
    }
    if (file == null) return;

    final extension = _extensionOf(file.name, file.path, file.mimeType);
    if (!_isSupportedExtension(extension)) {
      setState(() {
        _avatarFeedback = AppStrings.avatarUnsupportedFormat;
      });
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > ProfileRepository.maxAvatarBytes) {
      setState(() {
        _avatarFeedback = AppStrings.avatarTooLarge;
      });
      return;
    }

    setState(() => _localPreviewBytes = bytes);

    await ref
        .read(avatarUploadControllerProvider.notifier)
        .upload(
          bytes: bytes,
          fileExtension: extension,
          contentType: _contentTypeFor(extension),
        );

    if (!mounted) return;
    final uploadState = ref.read(avatarUploadControllerProvider);
    if (uploadState.hasError) {
      setState(() {
        _avatarFeedback = ProfileErrorMapper.map(uploadState.error!);
      });
      return;
    }

    setState(() {
      _localPreviewBytes = null;
      _avatarFeedback = AppStrings.avatarUploadSuccess;
    });
  }

  Future<void> _save() async {
    final saveState = ref.read(updateProfileControllerProvider);
    if (saveState.isLoading) return;

    await ref
        .read(updateProfileControllerProvider.notifier)
        .save(gender: _selectedGender, bio: _bioController.text);

    if (!mounted) return;
    final result = ref.read(updateProfileControllerProvider);
    if (result.hasError) return;

    _initialGender = _selectedGender;
    _initialBio = _bioController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.profileSaveSuccess)),
    );
    context.pop();
  }

  String _extensionOf(String name, String path, String? mimeType) {
    final fromName = name.contains('.')
        ? name.split('.').last
        : (path.contains('.') ? path.split('.').last : '');
    if (fromName.isNotEmpty) return fromName.toLowerCase();

    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return '';
    }
  }

  bool _isSupportedExtension(String extension) {
    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp';
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final saveState = ref.watch(updateProfileControllerProvider);
    final avatarState = ref.watch(avatarUploadControllerProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.editProfile),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _confirmDiscard();
              if (shouldPop && context.mounted) {
                context.pop();
              }
            },
          ),
        ),
        body: profileAsync.when(
          loading: () => const LoadingStateView(),
          error: (error, _) => ErrorStateView(
            message: error.toString(),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (profile) {
            _hydrateFromProfile(profile);
            final isSaving = saveState.isLoading;
            final isUploading = avatarState.isLoading;
            final saveError = saveState.hasError
                ? ProfileErrorMapper.map(saveState.error!)
                : null;

            return AppPage(
              child: ListView(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: AppAvatar(
                      imageUrl: profile.avatarUrl,
                      localBytes: _localPreviewBytes,
                      size: 96,
                      isLoading: isUploading,
                      semanticLabel: 'Avatar de ${profile.anonymousName}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: TextButton.icon(
                      onPressed: isUploading || isSaving
                          ? null
                          : _pickAndUploadAvatar,
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text(AppStrings.changePhoto),
                    ),
                  ),
                  if (_avatarFeedback != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _avatarFeedback!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _avatarFeedback == AppStrings.avatarUploadSuccess
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.poeticIdentityLabel,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    profile.anonymousName,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.poeticIdentityImmutable,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppStrings.genderLabel,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'female',
                        label: Text(AppStrings.genderFemale),
                      ),
                      ButtonSegment(
                        value: 'male',
                        label: Text(AppStrings.genderMale),
                      ),
                    ],
                    selected: {?_selectedGender},
                    onSelectionChanged: isSaving
                        ? (_) {}
                        : (selection) {
                            setState(() {
                              _selectedGender = selection.isEmpty
                                  ? null
                                  : selection.first;
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _bioController,
                    enabled: !isSaving,
                    maxLength: 500,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: AppStrings.bioLabel,
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (saveError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      saveError,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: isSaving || isUploading ? null : _save,
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.saveProfile),
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
