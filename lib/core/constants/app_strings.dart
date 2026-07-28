/// Central Spanish UI strings for the current architecture phase.
abstract final class AppStrings {
  static const String appTitle = 'Lyrical';
  static const String splashTagline =
      'Poesía anónima para leer y compartir con calma.';

  static const String exploreLabel = 'Explorar';
  static const String publishLabel = 'Publicar';
  static const String searchLabel = 'Buscar';
  static const String profileLabel = 'Perfil';

  static const String exploreTitle = 'Explorar';
  static const String exploreDescription =
      'Descubre poemas aprobados de la comunidad.';

  static const String publishTitle = 'Publicar';
  static const String publishDescription =
      'Comparte un poema nuevo de forma anónima.';

  static const String searchTitle = 'Buscar';
  static const String searchDescription =
      'Encuentra poemas y perfiles anónimos.';

  static const String profileTitle = 'Perfil';
  static const String profileDescription =
      'Consulta y edita tu perfil anónimo.';

  static const String emailLabel = 'Correo electrónico';
  static const String passwordLabel = 'Contraseña';
  static const String confirmPasswordLabel = 'Confirmar contraseña';

  static const String loginTitle = 'Iniciar sesión';
  static const String loginSubtitle = 'Entra con tu correo privado.';
  static const String loginButton = 'Iniciar sesión';
  static const String goToRegister = 'Crear una cuenta';

  static const String registerTitle = 'Crear cuenta';
  static const String registerSubtitle =
      'Tu identidad pública será anónima. Solo usamos el correo para acceder.';
  static const String registerButton = 'Crear cuenta';
  static const String goToLogin = 'Ya tengo una cuenta';

  static const String verifyTitle = 'Verifica tu correo';
  static const String verifyBody =
      'Te enviamos un enlace de confirmación. Ábrelo para activar tu cuenta.';
  static const String verifyEmailSentTo = 'Correo enviado a';
  static const String resendEmailButton = 'Reenviar correo';
  static const String resendEmailSuccess =
      'Correo de verificación reenviado correctamente.';
  static const String backToLogin = 'Volver a iniciar sesión';

  static const String signOutButton = 'Cerrar sesión';
  static const String showPassword = 'Mostrar contraseña';
  static const String hidePassword = 'Ocultar contraseña';

  static const String retryButton = 'Reintentar';

  static const String welcomeHeading = 'Bienvenido a Lyrical';
  static const String welcomeIdentityLabel = 'Tu identidad poética es';
  static const String welcomeDescription =
      'En Lyrical, tu nombre real no importa. Aquí, tus palabras hablan por ti.';
  static const String welcomeEnterButton = 'Entrar a Lyrical';

  static const String poemOfTheDay = 'Poema del día';
  static const String discoverSomethingNew = 'Descubre algo nuevo';
  static const String monthlySelection = 'Selección del mes';
  static const String recentPublications = 'Publicaciones recientes';
  static const String exploreGreetingPrefix = 'Hola,';
  static const String notificationsTooltip = 'Notificaciones';

  static const String poemTitleLabel = 'Título';
  static const String poemTypeLabel = 'Tipo de poema';
  static const String poemContentLabel = 'Tu poema';
  static const String submitForReview = 'Enviar a revisión';
  static const String publishPrototypeMessage =
      'Esto es un prototipo visual. Todavía no se envía nada a Supabase.';
  static const String discardDraftTitle = '¿Descartar borrador?';
  static const String discardDraftBody =
      'Tienes un borrador sin enviar. Si continúas, se perderá.';
  static const String discardConfirm = 'Descartar';
  static const String discardCancel = 'Seguir editando';
  static const String titleRequired = 'El título es obligatorio.';
  static const String typeRequired = 'Selecciona un tipo de poema.';
  static const String contentRequired = 'El poema no puede estar vacío.';

  static const String searchHint = 'Buscar por título, contenido o autor';
  static const String searchAllTypes = 'Todos';
  static const String searchEmptyTitle = 'Sin resultados';
  static const String searchEmptyMessage =
      'Prueba con otras palabras o cambia el tipo de poema.';
  static const String clearSearchTooltip = 'Limpiar búsqueda';

  static const String editProfile = 'Editar perfil';
  static const String myPoems = 'Mis poemas';
  static const String poemsInReview = 'En revisión';
  static const String poemsPublished = 'Publicados';
  static const String poemsHidden = 'Ocultos';
  static const String settingsTooltip = 'Ajustes';
  static const String mockCountersNote = 'Contadores de demostración';
  static const String mockPublished = 'Publicados';
  static const String mockFollowers = 'Seguidores';
  static const String mockFollowing = 'Siguiendo';
  static const String genderFemale = 'Mujer';
  static const String genderMale = 'Hombre';

  static const String changePhoto = 'Cambiar foto';
  static const String poeticIdentityLabel = 'Identidad poética';
  static const String poeticIdentityImmutable =
      'Tu identidad poética no puede modificarse.';
  static const String genderLabel = 'Género';
  static const String bioLabel = 'Biografía';
  static const String saveProfile = 'Guardar cambios';
  static const String profileSaveSuccess = 'Perfil actualizado correctamente.';
  static const String discardProfileEditsTitle = '¿Descartar cambios?';
  static const String discardProfileEditsBody =
      'Tienes cambios sin guardar. Si sales ahora, se perderán.';
  static const String avatarUnsupportedFormat =
      'Formato no admitido. Usa JPG, PNG o WEBP.';
  static const String avatarTooLarge =
      'La imagen es demasiado grande. El máximo es 5 MB.';
  static const String avatarUploadSuccess = 'Foto actualizada correctamente.';
}
