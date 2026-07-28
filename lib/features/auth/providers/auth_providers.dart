import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/auth_error_mapper.dart';
import 'package:lyrical/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// High-level authentication status used by routing.
enum AppAuthStatus { loading, authenticated, unauthenticated }

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Emits auth status from Supabase auth state changes.
///
/// Starts as [AsyncLoading] until the first auth event arrives.
final authStateProvider = StreamProvider<AppAuthStatus>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges.map((authState) {
    return authState.session != null
        ? AppAuthStatus.authenticated
        : AppAuthStatus.unauthenticated;
  });
});

final loginControllerProvider =
    AutoDisposeAsyncNotifierProvider<LoginController, void>(
      LoginController.new,
    );

final registerControllerProvider =
    AutoDisposeAsyncNotifierProvider<RegisterController, AuthResponse?>(
      RegisterController.new,
    );

final resendEmailControllerProvider =
    AutoDisposeAsyncNotifierProvider<ResendEmailController, void>(
      ResendEmailController.new,
    );

final signOutControllerProvider =
    AutoDisposeAsyncNotifierProvider<SignOutController, void>(
      SignOutController.new,
    );

class LoginController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(authRepositoryProvider)
            .signInWithEmail(email: email, password: password);
      } catch (error) {
        throw AuthFailure(AuthErrorMapper.map(error));
      }
    });
  }
}

class RegisterController extends AutoDisposeAsyncNotifier<AuthResponse?> {
  @override
  Future<AuthResponse?> build() async => null;

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    AuthResponse? response;
    state = await AsyncValue.guard(() async {
      try {
        response = await ref
            .read(authRepositoryProvider)
            .signUpWithEmail(email: email, password: password);
        return response;
      } catch (error) {
        throw AuthFailure(AuthErrorMapper.map(error));
      }
    });
    return state.asData?.value;
  }
}

class ResendEmailController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> resend({required String email}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(authRepositoryProvider)
            .resendSignupConfirmation(email: email);
      } catch (error) {
        throw AuthFailure(AuthErrorMapper.map(error));
      }
    });
  }
}

class SignOutController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (error) {
        throw AuthFailure(AuthErrorMapper.map(error));
      }
    });
  }
}

/// Friendly auth failure for UI display (never raw Supabase text).
class AuthFailure implements Exception {
  AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
