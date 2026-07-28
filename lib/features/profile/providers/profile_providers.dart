import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/profile_error_mapper.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/profile/data/profile_repository.dart';
import 'package:lyrical/features/profile/domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Current authenticated user's profile.
///
/// Rebuilds when auth status changes. Invalidate after profile updates.
final currentProfileProvider = FutureProvider<Profile>((ref) async {
  final authStatus = await ref.watch(authStateProvider.future);
  if (authStatus != AppAuthStatus.authenticated) {
    throw const AppException('No hay una sesión activa.');
  }

  return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
});

final completeOnboardingControllerProvider =
    AutoDisposeAsyncNotifierProvider<CompleteOnboardingController, void>(
      CompleteOnboardingController.new,
    );

final updateProfileControllerProvider =
    AutoDisposeAsyncNotifierProvider<UpdateProfileController, void>(
      UpdateProfileController.new,
    );

final avatarUploadControllerProvider =
    AutoDisposeAsyncNotifierProvider<AvatarUploadController, void>(
      AvatarUploadController.new,
    );

class CompleteOnboardingController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> complete() async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(profileRepositoryProvider).completeOnboarding();
        ref.invalidate(currentProfileProvider);
        await ref.read(currentProfileProvider.future);
      } catch (error) {
        throw AppException(ProfileErrorMapper.map(error));
      }
    });
  }
}

class UpdateProfileController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save({required String? gender, required String? bio}) async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(profileRepositoryProvider)
            .updateCurrentProfile(gender: gender, bio: bio);
        ref.invalidate(currentProfileProvider);
        await ref.read(currentProfileProvider.future);
      } catch (error) {
        throw AppException(ProfileErrorMapper.map(error));
      }
    });
  }
}

class AvatarUploadController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> upload({
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  }) async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(profileRepositoryProvider)
            .uploadCurrentUserAvatar(
              bytes: bytes,
              fileExtension: fileExtension,
              contentType: contentType,
            );
        ref.invalidate(currentProfileProvider);
        await ref.read(currentProfileProvider.future);
      } catch (error) {
        throw AppException(ProfileErrorMapper.map(error));
      }
    });
  }

  Future<void> remove() async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(profileRepositoryProvider).removeCurrentUserAvatar();
        ref.invalidate(currentProfileProvider);
        await ref.read(currentProfileProvider.future);
      } catch (error) {
        throw AppException(ProfileErrorMapper.map(error));
      }
    });
  }
}
