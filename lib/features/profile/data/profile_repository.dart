import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access for the current user's public profile.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _selectColumns =
      'id, anonymous_name, gender, bio, avatar_url, has_completed_onboarding';

  Future<Profile> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('No hay una sesión activa.');
    }

    try {
      final row = await _client
          .from('profiles')
          .select(_selectColumns)
          .eq('id', userId)
          .maybeSingle();

      if (row == null) {
        throw const AppException(
          'No se encontró tu perfil. Cierra sesión e inténtalo de nuevo.',
        );
      }

      return Profile.fromJson(row);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No se pudo leer tu perfil. Inténtalo de nuevo.',
      );
    } on PostgrestException {
      throw const AppException(
        'No se pudo cargar tu perfil. Inténtalo de nuevo.',
      );
    } catch (_) {
      throw const AppException(
        'No se pudo cargar tu perfil. Inténtalo de nuevo.',
      );
    }
  }

  /// Marks onboarding complete for the authenticated user only.
  Future<Profile> completeOnboarding() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('No hay una sesión activa.');
    }

    try {
      final row = await _client
          .from('profiles')
          .update({'has_completed_onboarding': true})
          .eq('id', userId)
          .select(_selectColumns)
          .maybeSingle();

      if (row == null) {
        throw const AppException(
          'No se pudo actualizar tu perfil. Inténtalo de nuevo.',
        );
      }

      return Profile.fromJson(row);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No se pudo actualizar tu perfil. Inténtalo de nuevo.',
      );
    } on PostgrestException {
      throw const AppException(
        'No se pudo actualizar tu perfil. Inténtalo de nuevo.',
      );
    } catch (_) {
      throw const AppException(
        'No se pudo actualizar tu perfil. Inténtalo de nuevo.',
      );
    }
  }
}
