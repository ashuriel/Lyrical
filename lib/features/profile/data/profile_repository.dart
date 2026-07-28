import 'dart:typed_data';

import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/profile_error_mapper.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access for the current user's public profile and avatar.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _selectColumns =
      'id, anonymous_name, gender, bio, avatar_url, has_completed_onboarding';

  static const String _avatarsBucket = 'avatars';
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  Future<Profile> fetchCurrentProfile() async {
    final userId = _requireUserId();

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
    } catch (error) {
      throw AppException(ProfileErrorMapper.map(error));
    }
  }

  /// Marks onboarding complete for the authenticated user only.
  Future<Profile> completeOnboarding() async {
    final userId = _requireUserId();

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
    } catch (error) {
      throw AppException(ProfileErrorMapper.map(error));
    }
  }

  /// Updates only gender and bio. Never touches anonymous_name or email.
  Future<Profile> updateCurrentProfile({
    required String? gender,
    required String? bio,
  }) async {
    final userId = _requireUserId();

    if (gender != null && gender != 'female' && gender != 'male') {
      throw const AppException('El valor de género no es válido.');
    }

    final trimmedBio = bio?.trim();
    final normalizedBio = (trimmedBio == null || trimmedBio.isEmpty)
        ? null
        : trimmedBio;

    if (normalizedBio != null && normalizedBio.length > 500) {
      throw const AppException(
        'La biografía no puede superar los 500 caracteres.',
      );
    }

    try {
      final row = await _client
          .from('profiles')
          .update({'gender': gender, 'bio': normalizedBio})
          .eq('id', userId)
          .select(_selectColumns)
          .maybeSingle();

      if (row == null) {
        throw const AppException(
          'No se pudo actualizar el perfil. Inténtalo de nuevo.',
        );
      }

      return Profile.fromJson(row);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(ProfileErrorMapper.map(error));
    }
  }

  /// Uploads an avatar into `<uid>/avatar.<ext>` then updates profiles.avatar_url.
  Future<Profile> uploadCurrentUserAvatar({
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  }) async {
    final userId = _requireUserId();
    final extension = fileExtension.toLowerCase().replaceAll('.', '');

    if (!_isSupportedAvatarExtension(extension)) {
      throw const AppException('Formato no admitido. Usa JPG, PNG o WEBP.');
    }
    if (bytes.lengthInBytes > maxAvatarBytes) {
      throw const AppException(
        'La imagen es demasiado grande. El máximo es 5 MB.',
      );
    }

    final objectPath = '$userId/avatar.$extension';
    var uploaded = false;

    try {
      await _client.storage
          .from(_avatarsBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
              cacheControl: '3600',
            ),
          );
      uploaded = true;

      final publicUrl = _client.storage
          .from(_avatarsBucket)
          .getPublicUrl(objectPath);
      final cacheBustedUrl =
          '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      try {
        final row = await _client
            .from('profiles')
            .update({'avatar_url': cacheBustedUrl})
            .eq('id', userId)
            .select(_selectColumns)
            .maybeSingle();

        if (row == null) {
          throw const AppException(
            'La imagen se subió, pero no se pudo actualizar el perfil. Inténtalo de nuevo.',
          );
        }

        return Profile.fromJson(row);
      } catch (error) {
        if (error is AppException) rethrow;
        throw AppException(
          'La imagen se subió, pero no se pudo actualizar el perfil. '
          '${ProfileErrorMapper.map(error)}',
        );
      }
    } on AppException {
      rethrow;
    } catch (error) {
      if (uploaded) {
        throw AppException(
          'La imagen se subió, pero no se pudo actualizar el perfil. '
          '${ProfileErrorMapper.map(error)}',
        );
      }
      throw AppException(ProfileErrorMapper.map(error));
    }
  }

  /// Removes the avatar object and clears profiles.avatar_url.
  Future<Profile> removeCurrentUserAvatar() async {
    final userId = _requireUserId();

    try {
      final existing = await fetchCurrentProfile();
      final currentUrl = existing.avatarUrl;
      if (currentUrl != null && currentUrl.isNotEmpty) {
        final objectPath = _objectPathFromPublicUrl(currentUrl, userId);
        if (objectPath != null) {
          await _client.storage.from(_avatarsBucket).remove([objectPath]);
        }
      }

      final row = await _client
          .from('profiles')
          .update({'avatar_url': null})
          .eq('id', userId)
          .select(_selectColumns)
          .maybeSingle();

      if (row == null) {
        throw const AppException(
          'No se pudo actualizar el perfil. Inténtalo de nuevo.',
        );
      }

      return Profile.fromJson(row);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(ProfileErrorMapper.map(error));
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('No hay una sesión activa.');
    }
    return userId;
  }

  bool _isSupportedAvatarExtension(String extension) {
    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp';
  }

  String? _objectPathFromPublicUrl(String url, String userId) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '$userId/avatar.jpg';

    final segments = uri.pathSegments;
    final avatarsIndex = segments.indexOf(_avatarsBucket);
    if (avatarsIndex == -1 || avatarsIndex + 1 >= segments.length) {
      return '$userId/avatar.jpg';
    }

    final relative = segments.sublist(avatarsIndex + 1).join('/');
    if (!relative.startsWith('$userId/')) {
      return null;
    }
    return relative;
  }
}
