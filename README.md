<div align="center">

<img src="assets/images/lyrical_logo.png" width="120" alt="Logo de Lyrical">

# Lyrical

### Plataforma móvil para publicar, descubrir y compartir poesía de forma anónima

Cada usuario recibe una identidad poética aleatoria para que sus obras sean valoradas por el contenido y no por su identidad real.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)

</div>

---

## 📖 Descripción

**Lyrical** es una aplicación móvil desarrollada con Flutter para publicar y descubrir poesía dentro de una comunidad anónima.

Al registrarse, cada usuario recibe automáticamente una identidad poética formada por un sustantivo y un adjetivo, por ejemplo:

> **Luna Serena** · **Río Tranquilo** · **Jardín Silencioso**

---

## ✨ Funciones principales

- Registro e inicio de sesión con correo electrónico.
- Verificación de cuenta.
- Identidad poética generada automáticamente.
- Edición de perfil y avatar.
- Publicación y gestión de poemas.
- Clasificación por tipo de poesía.
- Exploración y búsqueda de contenido.
- Me gusta y poemas guardados.
- Seguimiento de autores.
- Perfiles públicos.
- Notificaciones internas.
- Moderación de poemas.

---

## 🛠️ Tecnologías utilizadas

| Área | Tecnología |
|---|---|
| Aplicación | Flutter y Dart |
| Backend | Supabase |
| Base de datos | PostgreSQL |
| Autenticación | Supabase Auth |
| Almacenamiento | Supabase Storage |
| Gestión de estado | Riverpod |
| Navegación | go_router |
| Diseño | Figma |

---

## 🧱 Arquitectura

El proyecto separa la interfaz, la gestión del estado y el acceso a los servicios.

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
```

---

## 🗄️ Base de datos

Las tablas principales son:

| Tabla | Función |
|---|---|
| `profiles` | Información pública de los usuarios |
| `poems` | Poemas y estados de moderación |
| `poetry_types` | Tipos de poesía disponibles |
| `poem_likes` | Relaciones de “me gusta” |
| `poem_bookmarks` | Poemas guardados |
| `follows` | Relaciones de seguimiento |
| `notifications` | Notificaciones internas |

La seguridad se controla mediante **Row Level Security (RLS)** y funciones **RPC**.

---

## 📝 Estados de los poemas

| Estado | Descripción |
|---|---|
| `pending` | Pendiente de revisión |
| `approved` | Aprobado y disponible públicamente |
| `rejected` | Rechazado |

> Para esta versión académica, la moderación se realiza manualmente desde Supabase.

---

## 🔄 Operaciones CRUD

- **Crear:** usuarios, perfiles, poemas, likes, favoritos y seguimientos.
- **Leer:** poemas, perfiles, notificaciones y resultados de búsqueda.
- **Actualizar:** perfiles, avatares, estados y visibilidad.
- **Eliminar:** likes, favoritos, seguimientos y poemas mediante soft delete.

---

## ⚙️ Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/ashuriel/lyrical.git
cd lyrical
```

### 2. Instalar las dependencias

```bash
flutter pub get
```

### 3. Configurar las variables de entorno

Crear un archivo `.env` en la raíz del proyecto:

```env
SUPABASE_URL=TU_URL
SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICA
```

> No se debe incluir la clave `service_role` ni publicar el archivo `.env`.

### 4. Ejecutar la aplicación

```bash
flutter run
```

---

## 📱 Generar el APK

Ejecutar los siguientes comandos:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --release
```

El archivo APK se genera en:

```text
build/app/outputs/flutter-apk/app-release.apk
```


## ⚠️ Limitaciones

- Requiere conexión a Internet.
- La moderación se realiza manualmente desde Supabase.
- No incluye notificaciones push del sistema operativo.

---

## 👤 Autor

**Xintao Feng**

