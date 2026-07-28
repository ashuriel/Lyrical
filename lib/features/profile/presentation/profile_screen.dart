import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/theme/app_spacing.dart';
import 'package:lyrical/core/widgets/app_avatar.dart';
import 'package:lyrical/core/widgets/app_page.dart';
import 'package:lyrical/core/widgets/error_state_view.dart';
import 'package:lyrical/core/widgets/loading_state_view.dart';
import 'package:lyrical/core/widgets/profile_menu_tile.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final signOutState = ref.watch(signOutControllerProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: error.toString(),
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
        data: (profile) => _ProfileBody(
          profile: profile,
          genderLabel: _genderLabel(profile.gender),
          isSigningOut: signOutState.isLoading,
          signOutError: signOutState.hasError
              ? signOutState.error.toString()
              : null,
          onSignOut: () =>
              ref.read(signOutControllerProvider.notifier).signOut(),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.genderLabel,
    required this.isSigningOut,
    required this.onSignOut,
    this.signOutError,
  });

  final Profile profile;
  final String? genderLabel;
  final bool isSigningOut;
  final String? signOutError;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppPage(
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.profileTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: () {},
                tooltip: AppStrings.settingsTooltip,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
                      Text(genderLabel!, style: theme.textTheme.bodyMedium),
                    ],
                    if (profile.bio != null &&
                        profile.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(profile.bio!, style: theme.textTheme.bodyLarge),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.mockCountersNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _MockCounter(
                label: AppStrings.mockPublished,
                value: '0',
                color: scheme.onSurface,
              ),
              _MockCounter(
                label: AppStrings.mockFollowers,
                value: '0',
                color: scheme.onSurface,
              ),
              _MockCounter(
                label: AppStrings.mockFollowing,
                value: '0',
                color: scheme.onSurface,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonal(
            onPressed: () => context.push('/app/profile/edit'),
            child: const Text(AppStrings.editProfile),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.myPoems, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ProfileMenuTile(
            title: AppStrings.poemsInReview,
            leading: Icon(
              Icons.hourglass_empty,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => context.push('/app/profile/my-poems?tab=0'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileMenuTile(
            title: AppStrings.poemsPublished,
            leading: Icon(
              Icons.menu_book_outlined,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => context.push('/app/profile/my-poems?tab=1'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileMenuTile(
            title: AppStrings.poemsHidden,
            leading: Icon(
              Icons.visibility_off_outlined,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => context.push('/app/profile/my-poems?tab=2'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileMenuTile(
            title: AppStrings.poemsRejected,
            leading: Icon(
              Icons.cancel_outlined,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => context.push('/app/profile/my-poems?tab=3'),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (signOutError != null) ...[
            Text(
              signOutError!,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton(
            onPressed: isSigningOut ? null : onSignOut,
            child: isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.signOutButton),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _MockCounter extends StatelessWidget {
  const _MockCounter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
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
