# Spotter (app)

App móvil de Spotter hecha en Flutter. Es la base de la app: ahora tiene **cuenta** (registro e inicio de sesión) y **perfil**. Las rutinas y los entrenamientos se irán añadiendo encima.

Usa la API de [backend-spotter](https://github.com/SpotterP/backend-spotter).

## Qué tiene

- **Registro** (`POST /auth/register`): nombre, email y contraseña (mínimo 8 caracteres). Después hay que iniciar sesión.
- **Login** (`POST /auth/login`): guarda los tokens en el almacenamiento seguro (`flutter_secure_storage`: Keychain en iOS, Keystore en Android) y el usuario en `shared_preferences`, así la sesión sigue al cerrar la app.
- **Perfil**: nombre, email y rol del usuario, y botón de cerrar sesión.
- Pantalla principal con barra de abajo: **Entrenar**, **Rutinas**, **Calendario**, **Progreso** y **Perfil**. Rutinas y Perfil están hechas; las otras tres son un texto hasta que se hagan sus pantallas.
- **Mis rutinas**: lista las rutinas del usuario con su número de ejercicios (`GET /users/me/workouts`), crea una nueva con su nombre (`POST /users/me/workouts`) y borra las que ya no usa, pidiendo confirmación (`DELETE /users/me/workouts/:id`). Al tocar una se abre para **editarla**: cambiar el nombre, añadir ejercicios con el selector, elegir series y repeticiones, cambiar el orden arrastrando, quitar ejercicios y guardar (`PUT /users/me/workouts/:id`).
- **Entrenar**: el botón de play propone las rutinas asignadas al día de hoy en el calendario y deja elegir otra rutina o empezar un entrenamiento vacío. En el entrenamiento se ven los ejercicios con lo previsto, se apuntan las series (repeticiones y peso), se pueden añadir ejercicios con el selector y, al finalizar, se guarda (`POST /users/me/sessions`). Cancelar pide confirmación y descarta el entrenamiento.
- **Selector de ejercicios** (`ExercisePickerScreen`): elige un ejercicio del catálogo (`GET /exercises`) con buscador por nombre, filtro por categoría y carga de más ejercicios al llegar al final de la lista. Es solo de lectura y se abre desde la edición de una rutina (y, más adelante, desde un entrenamiento).

## Estructura

```
lib/
  config/environment.dart     URL de la API según la plataforma
  models/user.dart            modelo User (fromJson / toJson)
  models/workout.dart         modelos Exercise, WorkoutExercise y Workout
  services/workout_service.dart  rutinas y ejercicios (rutas protegidas)
  services/http_client.dart   función request() para llamar a la API (con token opcional)
  services/auth_service.dart  login y registro
  providers/auth_provider.dart  estado de la sesión (Provider)
  screens/                    login, registro, principal y perfil
  theme/app_colors.dart       colores
  main.dart                   app, rutas (GetX) y AuthGate
```

`AuthGate` enseña el login si no hay sesión y la pantalla principal si la hay; cambia sola al hacer login o logout.

## Cómo arrancarlo

Hace falta el backend arrancado (puerto 1337) y [Flutter](https://docs.flutter.dev/get-started/install) 3.x.

```bash
flutter pub get
flutter run -d chrome   # en el navegador
flutter run             # en emulador o móvil
```

Usuario de prueba del seed del backend: `user@example.com` / `seminari7`.

Para otra URL de la API: `flutter run --dart-define=API_URL=http://192.168.1.10:1337`

## Linter y hook de Git

El linter es el de Dart: `flutter analyze` (con las reglas de `flutter_lints`, en `analysis_options.yaml`).

Hay un hook de Git (`.githooks/pre-commit`) que lo pasa antes de cada `git commit` y cancela el commit si encuentra problemas.
Como esta app no usa npm, el hook se activa una sola vez en cada clon:

```bash
git config core.hooksPath .githooks
```

Se puede saltar una vez con `git commit --no-verify`, pero lo normal es arreglar el aviso.

## Token

El access token del backend dura 15 minutos. Las pantallas que llamen a rutas protegidas tienen que usar `AuthProvider.authorizedRequest()`: si la API responde 401, pide un token nuevo con `POST /auth/refresh` y repite la petición; si el refresh token también ha caducado, cierra la sesión y la app vuelve al login.

## Pendiente

- Editar el perfil: la API todavía no deja que un usuario edite sus datos.
