import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/notifications/domain/app_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app notifications via controlled RPCs.
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  static const int defaultPageSize = 20;

  Future<List<AppNotification>> fetchNotifications({
    required int limit,
    required int offset,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 50);
      final safeOffset = offset < 0 ? 0 : offset;

      final rows = await _client.rpc(
        'list_my_notifications',
        params: {'p_limit': safeLimit, 'p_offset': safeOffset},
      );

      if (rows is! List) {
        throw const AppException('No pudimos interpretar tus notificaciones.');
      }

      final list = <AppNotification>[];
      for (final row in rows) {
        try {
          list.add(
            AppNotification.fromJson(Map<String, dynamic>.from(row as Map)),
          );
        } on FormatException {
          // Skip legacy/unknown types rather than inventing a mapped type.
        }
      }
      return list;
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos interpretar tus notificaciones.');
    } catch (error) {
      throw AppException(_mapError(error, fallback: 'list'));
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final raw = await _client.rpc('get_unread_notification_count');
      return switch (raw) {
        final int value => value < 0 ? 0 : value,
        final num value => value.toInt().clamp(0, 1 << 30),
        _ => throw const FormatException('Unread count payload invalid.'),
      };
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos cargar el contador de notificaciones.',
      );
    } catch (error) {
      throw AppException(_mapError(error, fallback: 'count'));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_mapError(error, fallback: 'mark_one'));
    }
  }

  Future<int> markAllAsRead() async {
    try {
      final raw = await _client.rpc('mark_all_notifications_read');
      final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
      final count = map?['updated_count'];
      return switch (count) {
        final int value => value,
        final num value => value.toInt(),
        _ => 0,
      };
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_mapError(error, fallback: 'mark_all'));
    }
  }

  String _mapError(Object error, {required String fallback}) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();
      if (message.contains('authentication required')) {
        return 'No hay una sesión activa.';
      }
      if (message.contains('notification not available') || code == 'P0002') {
        return 'Esta notificación ya no está disponible.';
      }
      if (code == '42501' || message.contains('permission')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (code == 'PGRST202' ||
          message.contains('could not find the function')) {
        return 'Las notificaciones no están disponibles en este momento.';
      }
      if (message.contains('network') || message.contains('fetch')) {
        return 'No se pudo conectar. Comprueba tu conexión a internet.';
      }
    }

    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.' ||
        mapped == 'No se pudo completar la operación. Inténtalo de nuevo.') {
      return switch (fallback) {
        'count' => 'No pudimos cargar el contador de notificaciones.',
        'mark_one' => 'No pudimos marcar la notificación como leída.',
        'mark_all' => 'No pudimos marcar las notificaciones como leídas.',
        _ => 'No pudimos cargar tus notificaciones.',
      };
    }
    return mapped;
  }
}
