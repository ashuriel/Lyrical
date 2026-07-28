import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/profile/data/profile_repository.dart';
import 'package:lyrical/features/profile/domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Current authenticated user's profile.
///
/// Rebuilds when auth status changes. Invalidate after onboarding completes.
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

class CompleteOnboardingController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> complete() async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).completeOnboarding();
      ref.invalidate(currentProfileProvider);
      await ref.read(currentProfileProvider.future);
    });
  }
}
