import 'package:lyrical/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps poem/publish failures to Spanish user-facing messages.
abstract final class PoemErrorMapper {
  static String map(Object error) {
    if (error is AppException) {
      return error.message;
    }

    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();
      if (code == '42501' || message.contains('row-level security')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (code == 'PGRST116' || message.contains('0 rows')) {
        return 'No se encontró el poema.';
      }
      if (message.contains('network') || message.contains('fetch')) {
        return 'No se pudo conectar. Comprueba tu conexión a internet.';
      }
      return 'No se pudo completar la operación. Inténtalo de nuevo.';
    }

    final raw = error.toString().toLowerCase();
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
    if (raw.contains('not found') || raw.contains('no se encontró')) {
      return 'No se encontró el poema.';
    }

    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }
}
