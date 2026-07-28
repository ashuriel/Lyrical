import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps authentication failures to calm Spanish user-facing messages.
abstract final class AuthErrorMapper {
  static String map(Object error) {
    if (error is AuthException) {
      return _mapAuthException(error);
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused')) {
      return 'No se pudo conectar. Comprueba tu conexión a internet.';
    }
    return 'Ocurrió un error de autenticación. Inténtalo de nuevo.';
  }

  static String _mapAuthException(AuthException error) {
    final code = error.code?.toLowerCase();
    final message = error.message.toLowerCase();

    switch (code) {
      case 'invalid_credentials':
        return 'Correo o contraseña incorrectos.';
      case 'email_not_confirmed':
        return 'Debes verificar tu correo antes de iniciar sesión.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Ya existe una cuenta con este correo.';
      case 'weak_password':
        return 'La contraseña es demasiado débil.';
      case 'validation_failed':
        if (message.contains('email')) {
          return 'El correo electrónico no es válido.';
        }
        return 'Revisa los datos e inténtalo de nuevo.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Demasiados intentos. Espera un momento e inténtalo otra vez.';
      case 'user_not_found':
        return 'Correo o contraseña incorrectos.';
      default:
        break;
    }

    if (error is AuthWeakPasswordException) {
      return 'La contraseña es demasiado débil.';
    }
    if (error is AuthRetryableFetchException) {
      return 'No se pudo conectar. Comprueba tu conexión a internet.';
    }

    final status = error.statusCode;
    if (status == '400' || status == '401') {
      if (message.contains('email not confirmed') ||
          message.contains('not confirmed')) {
        return 'Debes verificar tu correo antes de iniciar sesión.';
      }
      if (message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        return 'Correo o contraseña incorrectos.';
      }
      if (message.contains('already registered') ||
          message.contains('already been registered') ||
          message.contains('user already registered')) {
        return 'Ya existe una cuenta con este correo.';
      }
    }
    if (status == '429') {
      return 'Demasiados intentos. Espera un momento e inténtalo otra vez.';
    }

    if (message.contains('network') || message.contains('failed host lookup')) {
      return 'No se pudo conectar. Comprueba tu conexión a internet.';
    }
    if (message.contains('invalid email')) {
      return 'El correo electrónico no es válido.';
    }

    return 'Ocurrió un error de autenticación. Inténtalo de nuevo.';
  }
}
