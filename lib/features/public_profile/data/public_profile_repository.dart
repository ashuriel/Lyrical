import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:lyrical/features/public_profile/domain/public_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public profiles and follow/unfollow via controlled RPCs.
class PublicProfileRepository {
  PublicProfileRepository(this._client);

  final SupabaseClient _client;

  static const int defaultAuthorPoemsPageSize = 20;

  static const String _authorPoemsSelect = '''
id,
author_id,
title,
content,
poetry_type_id,
published_at,
created_at,
poetry_types ( name, slug ),
profiles!poems_author_id_fkey ( anonymous_name, avatar_url )
''';

  Future<PublicProfile> fetchPublicProfile(String userId) async {
    try {
      final raw = await _client.rpc(
        'get_public_profile',
        params: {'p_user_id': userId},
      );
      return PublicProfile.fromJson(_asJsonMap(raw));
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos cargar este perfil.');
    } catch (error) {
      throw AppException(_mapProfileError(error, fallback: 'profile'));
    }
  }

  Future<({bool isFollowing, int followerCount})> followUser(
    String userId,
  ) async {
    try {
      final map = _asJsonMap(
        await _client.rpc('follow_user', params: {'p_followed_id': userId}),
      );
      return (
        isFollowing: _requireBool(map['is_following'], field: 'is_following'),
        followerCount: _requireCount(map['follower_count']),
      );
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos seguir esta identidad.');
    } catch (error) {
      throw AppException(_mapProfileError(error, fallback: 'follow'));
    }
  }

  Future<({bool isFollowing, int followerCount})> unfollowUser(
    String userId,
  ) async {
    try {
      final map = _asJsonMap(
        await _client.rpc('unfollow_user', params: {'p_followed_id': userId}),
      );
      return (
        isFollowing: _requireBool(map['is_following'], field: 'is_following'),
        followerCount: _requireCount(map['follower_count']),
      );
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos dejar de seguir esta identidad.');
    } catch (error) {
      throw AppException(_mapProfileError(error, fallback: 'unfollow'));
    }
  }

  Future<List<PublicPoem>> fetchPublicPoemsByAuthor({
    required String userId,
    required int limit,
    required int offset,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 50);
      final safeOffset = offset < 0 ? 0 : offset;

      final rows = await _client
          .from('poems')
          .select(_authorPoemsSelect)
          .eq('author_id', userId)
          .eq('status', 'approved')
          .eq('is_hidden', false)
          .isFilter('deleted_at', null)
          .not('published_at', 'is', null)
          .order('published_at', ascending: false)
          .order('id', ascending: false)
          .range(safeOffset, safeOffset + safeLimit - 1);

      return rows
          .map((row) => PublicPoem.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos cargar los poemas de esta identidad.',
      );
    } catch (error) {
      throw AppException(_mapProfileError(error, fallback: 'poems'));
    }
  }

  Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const FormatException('Profile RPC returned an invalid payload.');
  }

  bool _requireBool(Object? raw, {required String field}) {
    if (raw is bool) return raw;
    throw FormatException('Missing bool field: $field');
  }

  int _requireCount(Object? raw) {
    return switch (raw) {
      final int value => value,
      final num value => value.toInt(),
      _ => throw const FormatException('Missing count field.'),
    };
  }

  String _mapProfileError(Object error, {required String fallback}) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();
      if (message.contains('authentication required')) {
        return 'No hay una sesión activa.';
      }
      if (message.contains('profile not available') || code == 'P0002') {
        return 'No pudimos cargar este perfil.';
      }
      if (message.contains('cannot follow yourself') || code == 'P0001') {
        return 'No puedes seguirte a ti mismo.';
      }
      if (code == '42501' || message.contains('permission')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (code == 'PGRST202' ||
          message.contains('could not find the function')) {
        return 'Esta función no está disponible en este momento.';
      }
      if (message.contains('network') || message.contains('fetch')) {
        return 'No se pudo conectar. Comprueba tu conexión a internet.';
      }
    }

    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.' ||
        mapped == 'No se pudo completar la operación. Inténtalo de nuevo.') {
      return switch (fallback) {
        'follow' => 'No pudimos seguir esta identidad.',
        'unfollow' => 'No pudimos dejar de seguir esta identidad.',
        'poems' => 'No pudimos cargar los poemas de esta identidad.',
        _ => 'No pudimos cargar este perfil.',
      };
    }
    return mapped;
  }
}
