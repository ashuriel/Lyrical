import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lyrical/app/theme.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/profile_error_mapper.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_avatar.dart';
import 'package:lyrical/core/widgets/app_logo.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/features/profile/data/profile_repository.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

/// Five-step first-login onboarding. Completes only on the final step.
///
/// Profile saves invalidate [currentProfileProvider]; this screen keeps page
/// state in this State and caches the last profile so reload never remounts
/// the flow back to step 1.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const int _pageCount = 5;

  final _pageController = PageController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();

  int _pageIndex = 0;
  String? _selectedGender;
  Uint8List? _localPreviewBytes;
  String? _avatarFeedback;
  bool _hydrated = false;
  Profile? _cachedProfile;

  @override
  void dispose() {
    _pageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _hydrateOnce(Profile profile) {
    if (_hydrated) return;
    _selectedGender = profile.gender;
    _bioController.text = profile.bio?.trim() ?? '';
    _hydrated = true;
  }

  bool get _busy {
    final saving = ref.read(updateProfileControllerProvider).isLoading;
    final uploading = ref.read(avatarUploadControllerProvider).isLoading;
    final completing = ref.read(completeOnboardingControllerProvider).isLoading;
    return saving || uploading || completing;
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _pageCount) return;
    setState(() => _pageIndex = index);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _saveProfileFields() async {
    await ref
        .read(updateProfileControllerProvider.notifier)
        .save(gender: _selectedGender, bio: _bioController.text);
  }

  Future<bool> _persistProfileOrShowError() async {
    await _saveProfileFields();
    if (!mounted) return false;
    final result = ref.read(updateProfileControllerProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ProfileErrorMapper.map(result.error!))),
      );
      return false;
    }
    return true;
  }

  Future<void> _onNext() async {
    if (_busy) return;

    // Persist gender when leaving step 3 (index 2).
    if (_pageIndex == 2) {
      final ok = await _persistProfileOrShowError();
      if (!ok) return;
    }

    // Persist bio when leaving step 4 (index 3).
    if (_pageIndex == 3) {
      final ok = await _persistProfileOrShowError();
      if (!ok) return;
    }

    if (_pageIndex < _pageCount - 1) {
      await _goTo(_pageIndex + 1);
      return;
    }

    await _finish();
  }

  Future<void> _onSkip() async {
    if (_busy) return;
    if (_pageIndex == 2 || _pageIndex == 3) {
      await _goTo(_pageIndex + 1);
    }
  }

  Future<void> _onBack() async {
    if (_busy || _pageIndex == 0) return;
    await _goTo(_pageIndex - 1);
  }

  Future<void> _finish() async {
    final controller = ref.read(completeOnboardingControllerProvider.notifier);
    if (ref.read(completeOnboardingControllerProvider).isLoading) return;

    await controller.complete();
    if (!mounted) return;

    final result = ref.read(completeOnboardingControllerProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error.toString())));
      return;
    }

    context.go('/app/explore');
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
      setState(() => _avatarFeedback = ProfileErrorMapper.map(error));
      return;
    }
    if (file == null) return;

    final extension = _extensionOf(file.name, file.path, file.mimeType);
    if (!_isSupportedExtension(extension)) {
      setState(() => _avatarFeedback = AppStrings.avatarUnsupportedFormat);
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > ProfileRepository.maxAvatarBytes) {
      setState(() => _avatarFeedback = AppStrings.avatarTooLarge);
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
    final profile = profileAsync.asData?.value ?? _cachedProfile;
    if (profileAsync.asData?.value != null) {
      _cachedProfile = profileAsync.asData!.value;
    }

    if (profile == null) {
      if (profileAsync.hasError) {
        return Scaffold(
          body: ErrorStateView(
            message: profileAsync.error.toString(),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        );
      }
      return const Scaffold(body: LoadingStateView());
    }

    _hydrateOnce(profile);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final saveState = ref.watch(updateProfileControllerProvider);
    final avatarState = ref.watch(avatarUploadControllerProvider);
    final completeState = ref.watch(completeOnboardingControllerProvider);
    final isBusy =
        saveState.isLoading || avatarState.isLoading || completeState.isLoading;
    final isLast = _pageIndex == _pageCount - 1;
    final canSkip = _pageIndex == 2 || _pageIndex == 3;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  if (_pageIndex > 0)
                    TextButton(
                      onPressed: isBusy ? null : _onBack,
                      child: const Text(AppStrings.onboardingBack),
                    )
                  else
                    const SizedBox(width: 72),
                  Expanded(
                    child: Text(
                      AppStrings.onboardingStepLabel(
                        _pageIndex + 1,
                        _pageCount,
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: _StepProgress(current: _pageIndex, total: _pageCount),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _pageIndex = index),
                children: [
                  _IntroPage(theme: theme),
                  _NamePage(theme: theme, anonymousName: profile.anonymousName),
                  _ProfilePage(
                    theme: theme,
                    anonymousName: profile.anonymousName,
                    avatarUrl: profile.avatarUrl,
                    localPreviewBytes: _localPreviewBytes,
                    isUploading: avatarState.isLoading,
                    selectedGender: _selectedGender,
                    avatarFeedback: _avatarFeedback,
                    enabled: !isBusy,
                    onGenderChanged: (value) {
                      setState(() => _selectedGender = value);
                    },
                    onPickAvatar: _pickAndUploadAvatar,
                  ),
                  _BioPage(
                    theme: theme,
                    controller: _bioController,
                    enabled: !isBusy,
                  ),
                  _ReadyPage(
                    theme: theme,
                    anonymousName: profile.anonymousName,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canSkip)
                    TextButton(
                      onPressed: isBusy ? null : _onSkip,
                      child: const Text(AppStrings.onboardingSkip),
                    ),
                  FilledButton(
                    onPressed: isBusy ? null : _onNext,
                    child: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isLast
                                ? AppStrings.welcomeEnterButton
                                : AppStrings.onboardingNext,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (index) {
        final active = index <= current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: active
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Center(child: AppLogo(size: 88, showTitle: true)),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            AppStrings.onboardingIntroTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.onboardingIntroBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.65,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({required this.theme, required this.anonymousName});

  final ThemeData theme;
  final String anonymousName;

  @override
  Widget build(BuildContext context) {
    final extras = LyricalExtras.of(context);
    final scheme = theme.colorScheme;

    return _OnboardingScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppStrings.onboardingNameTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.onboardingNameBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.65,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppStrings.welcomeIdentityLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: extras.paperBorder),
            ),
            child: Text(
              anonymousName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: scheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.poeticIdentityImmutable,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.theme,
    required this.anonymousName,
    required this.avatarUrl,
    required this.localPreviewBytes,
    required this.isUploading,
    required this.selectedGender,
    required this.avatarFeedback,
    required this.enabled,
    required this.onGenderChanged,
    required this.onPickAvatar,
  });

  final ThemeData theme;
  final String anonymousName;
  final String? avatarUrl;
  final Uint8List? localPreviewBytes;
  final bool isUploading;
  final String? selectedGender;
  final String? avatarFeedback;
  final bool enabled;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return _OnboardingScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.onboardingProfileTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.onboardingProfileBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AppAvatar(
              imageUrl: avatarUrl,
              localBytes: localPreviewBytes,
              size: 96,
              isLoading: isUploading,
              semanticLabel: 'Avatar de $anonymousName',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: enabled ? onPickAvatar : null,
              icon: const Icon(Icons.photo_outlined),
              label: const Text(AppStrings.onboardingAddPhoto),
            ),
          ),
          if (avatarFeedback != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              avatarFeedback!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: avatarFeedback == AppStrings.avatarUploadSuccess
                    ? scheme.primary
                    : scheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.genderLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'female',
                label: Text(AppStrings.genderFemale),
              ),
              ButtonSegment(value: 'male', label: Text(AppStrings.genderMale)),
            ],
            selected: {?selectedGender},
            onSelectionChanged: enabled
                ? (selection) {
                    onGenderChanged(selection.isEmpty ? null : selection.first);
                  }
                : (_) {},
          ),
        ],
      ),
    );
  }
}

class _BioPage extends StatelessWidget {
  const _BioPage({
    required this.theme,
    required this.controller,
    required this.enabled,
  });

  final ThemeData theme;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return _OnboardingScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.onboardingBioTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.onboardingBioBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: controller,
            enabled: enabled,
            maxLength: 500,
            minLines: 5,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: AppStrings.bioLabel,
              hintText: AppStrings.onboardingBioHint,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage({required this.theme, required this.anonymousName});

  final ThemeData theme;
  final String anonymousName;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return _OnboardingScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Center(child: AppLogo(size: 72)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppStrings.onboardingReadyTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.onboardingReadyBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.65,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            anonymousName,
            style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingScroll extends StatelessWidget {
  const _OnboardingScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: child,
        ),
      ),
    );
  }
}
