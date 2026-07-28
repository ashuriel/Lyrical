/// Lightweight form validators for authentication screens.
abstract final class Validators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'El correo es obligatorio.';
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Introduce un correo válido.';
    }
    return null;
  }

  static String? requiredPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    return null;
  }

  static String? registrationPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    if (text.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Confirma tu contraseña.';
    }
    if (text != password) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }
}
