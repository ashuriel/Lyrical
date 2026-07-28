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
  static const String searchInitialTitle = 'Buscar';
  static const String searchInitialMessage =
      'Busca poemas, palabras o identidades poéticas.';
  static const String searchEmptyTitle = 'Sin resultados';
  static const String searchEmptyMessage =
      'No encontramos poemas con esos criterios.';
  static const String searchGenericError =
      'No pudimos completar la búsqueda. Inténtalo de nuevo.';
  static const String clearSearchTooltip = 'Limpiar búsqueda';

  static String searchResultCount(int count) {
    if (count == 1) return '1 resultado';
    return '$count resultados';
  }

  static const String editProfile = 'Editar perfil';
  static const String myPoems = 'Mis poemas';
  static const String poemsInReview = 'En revisión';
  static const String poemsPublished = 'Publicados';
  static const String poemsHidden = 'Ocultos';
  static const String poemsRejected = 'Rechazados';
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

  static const String publishSuccessMessage =
      'Tu poema fue enviado a revisión. Puedes consultar su estado en Mis poemas.';
  static const String clearDraftTooltip = 'Borrar borrador';
  static const String clearDraftTitle = '¿Borrar borrador?';
  static const String clearDraftBody =
      'Se borrarán el título, el tipo y el contenido del formulario.';
  static const String viewPoem = 'Ver';
  static const String hidePoem = 'Ocultar';
  static const String unhidePoem = 'Mostrar';
  static const String deletePoem = 'Eliminar';
  static const String hidePoemTitle = '¿Ocultar poema?';
  static const String hidePoemBody =
      'El poema dejará de mostrarse públicamente. Podrás volver a mostrarlo desde Ocultos.';
  static const String unhidePoemTitle = '¿Mostrar poema?';
  static const String unhidePoemBody =
      'El poema volverá a estar visible públicamente.';
  static const String deletePoemTitle = '¿Eliminar poema?';
  static const String deletePoemBody =
      'Esta acción no se puede deshacer desde la aplicación. El poema se eliminará de tus listas.';
  static const String hidePoemSuccess = 'Poema ocultado correctamente.';
  static const String unhidePoemSuccess = 'Poema visible de nuevo.';
  static const String deletePoemSuccess = 'Poema eliminado correctamente.';
  static const String emptyPendingPoems = 'Aún no tienes poemas en revisión.';
  static const String emptyPublishedPoems = 'Aún no tienes poemas publicados.';
  static const String emptyHiddenPoems = 'No tienes poemas ocultos.';
  static const String emptyRejectedPoems = 'No tienes poemas rechazados.';
  static const String poemDetailTitle = 'Poema';
  static const String createdAtLabel = 'Creado';
  static const String publishedAtLabel = 'Publicado';
  static const String statusLabel = 'Estado';
  static const String titleTooLong =
      'El título no puede superar los 100 caracteres.';
  static const String contentTooLong =
      'El poema no puede superar los 10000 caracteres.';
  static const String poetryTypesEmpty =
      'No hay tipos de poema disponibles en este momento.';

  static const String exploreLoadError =
      'No pudimos cargar los poemas. Inténtalo de nuevo.';
  static const String exploreEmptyPoems =
      'Aún no hay poemas públicos para mostrar.';
  static const String exploreEmptySection =
      'No hay poemas en esta sección todavía.';
  static const String loadMorePoems = 'Cargar más';
  static const String poemUnavailable = 'Este poema ya no está disponible.';

  static const String likePoemSemantic = 'Me gusta';
  static const String unlikePoemSemantic = 'Quitar Me gusta';
  static const String bookmarkPoemSemantic = 'Guardar poema';
  static const String removeBookmarkSemantic = 'Quitar de guardados';
  static const String likePoemError = 'No pudimos registrar tu Me gusta.';
  static const String unlikePoemError = 'No pudimos quitar tu Me gusta.';
  static const String bookmarkPoemError = 'No pudimos guardar este poema.';
  static const String removeBookmarkError =
      'No pudimos quitar este poema de guardados.';

  static const String myLibraryTitle = 'Mi biblioteca';
  static const String savedPoemsMenu = 'Guardados';
  static const String savedPoemsTitle = 'Guardados';
  static const String savedPoemsEmptyTitle = 'Sin guardados';
  static const String savedPoemsEmptyMessage =
      'Aún no has guardado ningún poema.';
  static const String removeBookmarkAction = 'Quitar de guardados';
  static const String removeBookmarkTitle = '¿Quitar de guardados?';
  static const String removeBookmarkBody =
      'El poema dejará de aparecer en tu biblioteca.';
  static const String removeBookmarkConfirm = 'Quitar';
  static const String removeBookmarkSuccess = 'Poema quitado de guardados.';

  static const String publicProfileTitle = 'Perfil';
  static const String followButton = 'Seguir';
  static const String followingButton = 'Siguiendo';
  static const String publicProfilePoemsStat = 'Poemas';
  static const String publicProfileFollowersStat = 'Seguidores';
  static const String publicProfileFollowingStat = 'Siguiendo';
  static const String publicProfilePublishedPoems = 'Poemas publicados';
  static const String publicProfileEmptyPoemsTitle = 'Sin poemas';
  static const String publicProfileEmptyPoemsMessage =
      'Esta identidad todavía no ha publicado poemas.';
  static const String unfollowConfirmTitle = 'Dejar de seguir';
  static const String unfollowConfirmBody =
      '¿Quieres dejar de seguir a esta identidad?';
  static const String unfollowConfirmAction = 'Dejar de seguir';
  static const String publicProfileUnavailable =
      'No pudimos abrir este perfil.';
}
