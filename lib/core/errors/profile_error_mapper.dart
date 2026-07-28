import 'package:lyrical/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps profile/avatar failures to Spanish user-facing messages.
abstract final class ProfileErrorMapper {
  static String map(Object error) {
    if (error is AppException) {
      return error.message;
    }

    if (error is StorageException) {
      final status = error.statusCode;
      final message = error.message.toLowerCase();
      if (status == '403' || message.contains('row-level security')) {
        return 'No tienes permiso para modificar este archivo.';
      }
      if (status == '413' ||
          message.contains('payload') ||
          message.contains('size')) {
        return 'La imagen es demasiado grande. El máximo es 5 MB.';
      }
      if (message.contains('network') || message.contains('fetch')) {
        return 'No se pudo conectar. Comprueba tu conexión a internet.';
      }
      return 'No se pudo subir la imagen. Inténtalo de nuevo.';
    }

    if (error is PostgrestException) {
      return 'No se pudo actualizar el perfil. Inténtalo de nuevo.';
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('photo_access_denied') ||
        raw.contains('access_denied') ||
        raw.contains('permission') ||
        raw.contains('notauthorized') ||
        raw.contains('not authorized')) {
      return 'Necesitamos permiso para acceder a tu galería.';
    }
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network') ||
        raw.contains('clientexception')) {
      return 'No se pudo conectar. Comprueba tu conexión a internet.';
    }
    if (raw.contains('jwt') ||
        raw.contains('not authenticated') ||
        raw.contains('sesión activa')) {
      return 'No hay una sesión activa.';
    }

    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }
}
