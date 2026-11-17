# Spotter (app)

App móvil de Spotter hecha en Flutter. Es la base de la app: ahora tiene **cuenta** (registro e inicio de sesión) y **perfil**. Las rutinas y los entrenamientos se irán añadiendo encima.

Usa la API de [backend-spotter](https://github.com/SpotterP/backend-spotter).

## Qué tiene

- **Registro** (`POST /auth/register`): nombre, email y contraseña (mínimo 8 caracteres). Después hay que iniciar sesión.
- **Login** (`POST /auth/login`): guarda los tokens en el almacenamiento seguro (`flutter_secure_storage`: Keychain en iOS, Keystore en Android) y el usuario en `shared_preferences`, así la sesión sigue al cerrar la app.
- **Perfil**: nombre, email y rol del usuario, y botón de cerrar sesión.
- Pantalla principal con barra de abajo: **Entrenar**, **Rutinas**, **Calendario**, **Progreso** y **Perfil**. Solo Perfil está hecha; las otras cuatro son un texto hasta que se hagan sus pantallas.

## Estructura

```
lib/
  config/environment.dart     URL de la API según la plataforma
  models/user.dart            modelo User (fromJson / toJson)
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

## Token

El access token del backend dura 15 minutos. Las pantallas que llamen a rutas protegidas tienen que usar `AuthProvider.authorizedRequest()`: si la API responde 401, pide un token nuevo con `POST /auth/refresh` y repite la petición; si el refresh token también ha caducado, cierra la sesión y la app vuelve al login.

## Pendiente

- Editar el perfil: la API todavía no deja que un usuario edite sus datos.
