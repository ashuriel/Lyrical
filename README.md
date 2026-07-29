# Lyrical

Lyrical es una aplicación móvil desarrollada con Flutter para publicar, descubrir y compartir poesía de forma anónima.

Cada usuario recibe una identidad poética aleatoria, formada por un sustantivo y un adjetivo, con el objetivo de que los poemas sean valorados por su contenido y no por la identidad real del autor.

## Funciones principales

- Registro e inicio de sesión con correo electrónico.
- Verificación de cuenta.
- Identidad poética automática.
- Edición de perfil y avatar.
- Publicación de poemas.
- Clasificación por tipo de poesía.
- Moderación de poemas.
- Exploración y búsqueda de contenido.
- Me gusta y poemas guardados.
- Seguimiento de autores.
- Perfiles públicos.
- Notificaciones internas.
- Gestión de poemas propios.

## Tecnologías utilizadas

- Flutter
- Dart
- Supabase
- PostgreSQL
- Supabase Auth
- Supabase Storage
- Riverpod
- go_router
- Figma

## Arquitectura

El proyecto utiliza una estructura por funcionalidades.

```text
Interfaz
   ↓
Riverpod Provider
   ↓
Repository
   ↓
Supabase
   ↓
PostgreSQL / Auth / Storage

Base de datos

Las tablas principales son:

profiles
poems
poetry_types
poem_likes
poem_bookmarks
follows
notifications

La seguridad se controla mediante Row Level Security y funciones RPC.

Estados de los poemas

Los poemas pueden tener los siguientes estados:

pending: pendiente de revisión.
approved: aprobado.
rejected: rechazado.

Para esta versión académica, la moderación puede realizarse manualmente desde Supabase.

Operaciones CRUD

La aplicación permite:

Crear usuarios, perfiles, poemas, likes, favoritos y seguimientos.
Leer poemas, perfiles, notificaciones y resultados de búsqueda.
Actualizar perfiles, avatares, estados y visibilidad.
Eliminar likes, favoritos, seguimientos y poemas mediante soft delete.
Configuración

Clonar el repositorio:

git clone https://github.com/USUARIO/lyrical.git
cd lyrical

Instalar dependencias:

flutter pub get

Crear un archivo .env:

SUPABASE_URL=TU_URL
SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICA

Ejecutar la aplicación:

flutter run
Generar APK
flutter clean
flutter pub get
flutter build apk --release

El archivo se genera en:

build/app/outputs/flutter-apk/app-release.apk
Figma

Enlace al prototipo:

AGREGAR_ENLACE_DE_FIGMA
Limitaciones
Requiere conexión a Internet.
La moderación se realiza manualmente desde Supabase.
No incluye notificaciones push.
La versión iOS requiere macOS y Xcode.
Autor

Nombre: Xintao Feng

