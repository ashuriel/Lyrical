import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/moderation/domain/pending_moderation_poem.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Administrator moderation RPCs. Never trusts a client-supplied admin id.
class ModerationRepository {
  ModerationRepository(this._client);

  final SupabaseClient _client;

  static const int defaultPageSize = 20;

  Future<bool> isCurrentUserAdmin() async {
    try {
      final raw = await _client.rpc('is_current_user_admin');
      return switch (raw) {
        final bool value => value,
        'true' || 't' => true,
        'false' || 'f' => false,
        _ => false,
      };
    } catch (error, stack) {
      _logDebug('is_current_user_admin failed', error, stack);
      // Fail closed: treat errors as non-admin for UI gating.
      // Route/RPC calls still enforce authorization server-side.
      if (error is PostgrestException &&
          (error.code == 'PGRST202' ||
              error.message.toLowerCase().contains(
                'could not find the function',
              ))) {
        throw const AppException('Esta función aún no está configurada.');
      }
      throw AppException(_mapError(error, fallback: 'admin_check'));
    }
  }

  Future<List<PendingModerationPoem>> fetchPendingPoems({
    required int limit,
    required int offset,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 50);
      final safeOffset = offset < 0 ? 0 : offset;

      final rows = await _client.rpc(
        'get_pending_poems_for_moderation',
        params: {'p_limit': safeLimit, 'p_offset': safeOffset},
      );

      if (rows is! List) {
        throw const FormatException('Pending list payload invalid.');
      }

      return rows
          .map(
            (row) => PendingModerationPoem.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } on AppException {
      rethrow;
    } on FormatException catch (error, stack) {
      _logDebug('fetchPendingPoems parse failed', error, stack);
      throw const AppException('No pudimos cargar la cola de moderación.');
    } catch (error, stack) {
      _logDebug('fetchPendingPoems failed', error, stack);
      throw AppException(_mapError(error, fallback: 'list'));
    }
  }

  Future<PendingModerationPoem> fetchPendingPoem(String poemId) async {
    final trimmed = poemId.trim();
    if (trimmed.isEmpty) {
      throw const AppException(
        'Este poema ya fue revisado o ya no está disponible.',
      );
    }

    try {
      final raw = await _client.rpc(
        'get_pending_poem_for_moderation',
        params: {'p_poem_id': trimmed},
      );
      final map = _asJsonMap(raw);
      return PendingModerationPoem.fromJson(map);
    } on AppException {
      rethrow;
    } on FormatException catch (error, stack) {
      _logDebug('fetchPendingPoem parse failed', error, stack);
      throw const AppException('No pudimos cargar este poema para revisión.');
    } catch (error, stack) {
      _logDebug('fetchPendingPoem failed', error, stack);
      throw AppException(_mapError(error, fallback: 'detail'));
    }
  }

  Future<void> approvePoem(String poemId) async {
    try {
      final map = _asJsonMap(
        await _client.rpc('approve_poem', params: {'p_poem_id': poemId}),
      );
      final success = map['success'];
      if (success != true) {
        throw const FormatException('Approve payload missing success.');
      }
    } on AppException {
      rethrow;
    } on FormatException catch (error, stack) {
      _logDebug('approvePoem parse failed', error, stack);
      throw const AppException('No pudimos aprobar este poema.');
    } catch (error, stack) {
      _logDebug('approvePoem failed', error, stack);
      throw AppException(_mapError(error, fallback: 'approve'));
    }
  }

  Future<void> rejectPoem(String poemId) async {
    try {
      final map = _asJsonMap(
        await _client.rpc('reject_poem', params: {'p_poem_id': poemId}),
      );
      final success = map['success'];
      if (success != true) {
        throw const FormatException('Reject payload missing success.');
      }
    } on AppException {
      rethrow;
    } on FormatException catch (error, stack) {
      _logDebug('rejectPoem parse failed', error, stack);
      throw const AppException('No pudimos rechazar este poema.');
    } catch (error, stack) {
      _logDebug('rejectPoem failed', error, stack);
      throw AppException(_mapError(error, fallback: 'reject'));
    }
  }

  Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw == null) {
      throw const FormatException('Moderation RPC returned null.');
    }
    if (raw is String) {
      return _asJsonMap(jsonDecode(raw));
    }
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) {
      if (raw.isEmpty) {
        throw const FormatException('Moderation RPC returned an empty list.');
      }
      return _asJsonMap(raw.first);
    }
    throw FormatException(
      'Moderation RPC returned unsupported type: ${raw.runtimeType}',
    );
  }

  void _logDebug(String label, Object error, [StackTrace? stack]) {
    if (!kDebugMode) return;
    debugPrint('[ModerationRepository] $label: $error');
    if (error is PostgrestException) {
      debugPrint(
        '[ModerationRepository] code=${error.code} details=${error.details} '
        'hint=${error.hint}',
      );
    }
    if (stack != null) debugPrint('$stack');
  }

  String _mapError(Object error, {required String fallback}) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();
      final details = '${error.details}'.toLowerCase();
      final combined = '$message $details';

      if (message.contains('authentication required') ||
          combined.contains('jwt')) {
        return 'No hay una sesión activa.';
      }
      if (message.contains('administrator access required') ||
          (code == '42501' && combined.contains('administrator'))) {
        return 'No tienes permiso para acceder a esta sección.';
      }
      if (code == '42501' ||
          combined.contains('permission') ||
          combined.contains('row-level security')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (message.contains('already reviewed') ||
          message.contains('not available for moderation') ||
          code == 'P0002') {
        return 'Este poema ya fue revisado o ya no está disponible.';
      }
      if (code == 'PGRST202' ||
          combined.contains('could not find the function')) {
        return 'Esta función aún no está configurada.';
      }
      if (combined.contains('network') || combined.contains('fetch')) {
        return 'Comprueba tu conexión e inténtalo de nuevo.';
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
        'list' => 'No pudimos cargar la cola de moderación.',
        'detail' => 'No pudimos cargar este poema para revisión.',
        'approve' => 'No pudimos aprobar este poema.',
        'reject' => 'No pudimos rechazar este poema.',
        'admin_check' => 'No pudimos verificar tus permisos.',
        _ => 'Ocurrió un error inesperado. Inténtalo de nuevo.',
      };
    }
    return mapped;
  }
}
