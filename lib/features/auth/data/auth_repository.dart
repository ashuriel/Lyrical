import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth access for the auth feature.
///
/// UI and providers must call this repository instead of Supabase directly.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Registers with email/password only. No public username or personal metadata.
  /// The database trigger creates the anonymous profile after signup.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signUp(email: email.trim(), password: password);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> resendSignupConfirmation({required String email}) async {
    await _auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
