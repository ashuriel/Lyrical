import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw const AppException('No encontramos esta identidad.');
    }

    try {
      final raw = await _client.rpc(
        'get_public_profile',
        params: {'p_user_id': trimmed},
      );

      if (raw == null) {
        throw const AppException('No encontramos esta identidad.');
      }

      // PostgREST may return a JSON object, a JSON string, or a one-row list.
      final map = _asJsonMap(raw);
      return PublicProfile.fromJson(map);
    } on AppException {
      rethrow;
    } on FormatException catch (error, stack) {
      _logDebug('get_public_profile parse failed', error, stack);
      throw const AppException('No pudimos cargar este perfil.');
    } catch (error, stack) {
      _logDebug('get_public_profile failed', error, stack);
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
        followerCount: PublicProfile.parseCount(map['follower_count']),
      );
    } on AppException {
      rethrow;
    } on FormatException catch (error, stack) {
      _logDebug('follow_user parse failed', error, stack);
      throw const AppException('No pudimos seguir esta identidad.');
    } catch (error, stack) {
      _logDebug('follow_user failed', error, stack);
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
        followerCount: PublicProfile.parseCount(map['follower_count']),
      );
    } on AppException {
      rethrow;
    } on FormatException catch (error, stack) {
      _logDebug('unfollow_user parse failed', error, stack);
      throw const AppException('No pudimos dejar de seguir esta identidad.');
    } catch (error, stack) {
      _logDebug('unfollow_user failed', error, stack);
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
    } on FormatException catch (error, stack) {
      _logDebug('fetchPublicPoemsByAuthor parse failed', error, stack);
      throw const AppException(
        'No pudimos cargar los poemas de esta identidad.',
      );
    } catch (error, stack) {
      _logDebug('fetchPublicPoemsByAuthor failed', error, stack);
      throw AppException(_mapProfileError(error, fallback: 'poems'));
    }
  }

  Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw == null) {
      throw const FormatException('Profile RPC returned null.');
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      return _asJsonMap(decoded);
    }
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) {
      if (raw.isEmpty) {
        throw const FormatException('Profile RPC returned an empty list.');
      }
      return _asJsonMap(raw.first);
    }
    throw FormatException(
      'Profile RPC returned unsupported type: ${raw.runtimeType}',
    );
  }

  bool _requireBool(Object? raw, {required String field}) {
    return PublicProfile.parseBool(raw, field: field);
  }

  void _logDebug(String label, Object error, [StackTrace? stack]) {
    if (!kDebugMode) return;
    debugPrint('[PublicProfileRepository] $label: $error');
    if (error is PostgrestException) {
      debugPrint(
        '[PublicProfileRepository] code=${error.code} details=${error.details} hint=${error.hint}',
      );
    }
    if (stack != null) {
      debugPrint('$stack');
    }
  }

  String _mapProfileError(Object error, {required String fallback}) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();
      final details = '${error.details}'.toLowerCase();
      final combined = '$message $details';

      if (message.contains('authentication required') ||
          combined.contains('jwt')) {
        return 'No hay una sesión activa.';
      }
      if (message.contains('profile not available') || code == 'P0002') {
        return 'No encontramos esta identidad.';
      }
      if (message.contains('cannot follow yourself') || code == 'P0001') {
        return 'No puedes seguirte a ti mismo.';
      }
      if (code == '42501' ||
          combined.contains('permission') ||
          combined.contains('row-level security')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      // Missing RPC / schema cache not reloaded after migration 009.
      if (code == 'PGRST202' ||
          combined.contains('could not find the function') ||
          combined.contains('function public.get_public_profile') ||
          combined.contains('function public.follow_user') ||
          combined.contains('function public.unfollow_user')) {
        return 'Esta función aún no está configurada.';
      }
      if (combined.contains('network') || combined.contains('fetch')) {
        return 'Comprueba tu conexión e inténtalo de nuevo.';
      }
      if (code == 'PGRST116' || combined.contains('0 rows')) {
        return 'No encontramos esta identidad.';
      }
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('clientexception') ||
        raw.contains('network')) {
      return 'Comprueba tu conexión e inténtalo de nuevo.';
    }

    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.' ||
        mapped == 'No se pudo completar la operación. Inténtalo de nuevo.' ||
        mapped == 'Esta función no está disponible en este momento.') {
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
