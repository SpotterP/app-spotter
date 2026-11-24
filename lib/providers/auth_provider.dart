import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

// Guarda la sesión del usuario (token y datos) y avisa a las pantallas cuando cambia.
// La sesión se guarda también en el móvil para no tener que hacer login cada vez que se abre la app:
// los tokens van en el almacenamiento seguro (Keychain en iOS, Keystore en Android) y los datos
// del usuario, que no son secretos, en SharedPreferences.
class AuthProvider extends ChangeNotifier {
  // Sin argumentos usa la API de verdad; los tests le pasan su propia función
  AuthProvider({ApiRequest? httpRequest}) : _httpRequest = httpRequest ?? request;

  final ApiRequest _httpRequest;

  // Almacenamiento seguro para los tokens
  final _storage = const FlutterSecureStorage();

  User? user;
  String? token;
  String? refreshToken;

  // true mientras se lee la sesión guardada al arrancar la app
  bool starting = true;

  // true mientras se espera la respuesta de la API (para desactivar el botón)
  bool loading = false;

  // Mensaje de error de la última acción, para enseñarlo en pantalla
  String? error;

  // Estado de la carga del perfil (GET /users/me)
  bool profileLoading = false;
  String? profileError;

  bool get isLoggedIn => user != null && token != null;

  // Lee la sesión guardada. Se llama una vez al crear el provider
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = await _storage.read(key: 'token');
    final savedUser = prefs.getString('user');

    if (savedToken != null && savedUser != null) {
      final savedAccount = User.fromJson(jsonDecode(savedUser));

      // Una sesión de administrador guardada antes de que existiera esta regla (o guardada a mano)
      // tampoco puede entrar: se borra aquí, que es donde se decide si la app arranca dentro o no.
      if (savedAccount.canUseApp) {
        token = savedToken;
        refreshToken = await _storage.read(key: 'refreshToken');
        user = savedAccount;
      } else {
        await _clearSession();
      }
    }

    starting = false;
    notifyListeners();
  }

  // Inicia sesión. Devuelve true si ha ido bien
  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final session = await AuthService.login(email, password, httpRequest: _httpRequest);

      // El login sólo se acepta si la cuenta puede usar la app. Un administrador tiene su
      // propio login en el backoffice; si entrara aquí, las cuatro pestañas de datos le
      // responderían 403 y no entendería por qué.
      if (!session.user.canUseApp) {
        // Los tokens que acaba de crear el backend no se guardan en ningún sitio: se quedan en
        // esta variable y se pierden. No pedimos cerrarlos en el servidor porque POST /auth/logout
        // sube la versión de tokens del usuario, y eso echaría al administrador del backoffice en
        // todos sus dispositivos justo cuando va a entrar ahí.
        await _clearSession();

        // Después de limpiar, porque _clearSession() borra el error
        error = session.user.role == 'ADMIN'
            ? 'Esta cuenta es de administrador: la app es para usuarios normales. '
                'Los administradores entran por el backoffice.'
            : 'Esta cuenta no puede usar la app: es para usuarios normales.';

        loading = false;
        notifyListeners();
        return false;
      }

      token = session.token;
      refreshToken = session.refreshToken;
      user = session.user;

      final prefs = await SharedPreferences.getInstance();
      await _storage.write(key: 'token', value: session.token);
      await _storage.write(key: 'refreshToken', value: session.refreshToken);
      await prefs.setString('user', jsonEncode(session.user.toJson()));

      loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
    }

    loading = false;
    notifyListeners();
    return false;
  }

  // Crea la cuenta. Devuelve true si ha ido bien (luego el usuario tiene que hacer login)
  Future<bool> register(String name, String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await AuthService.register(name, email, password);

      loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
    }

    loading = false;
    notifyListeners();
    return false;
  }

  // Pide el perfil actualizado a la API (GET /users/me) y lo guarda en la sesión.
  // Mientras tanto la pantalla enseña los datos que ya teníamos del login.
  Future<void> loadProfile() async {
    profileLoading = true;
    profileError = null;
    notifyListeners();

    try {
      final data = await authorizedRequest('/users/me');

      // Si mientras tanto se ha cerrado la sesión, no hacemos nada
      if (user != null) {
        // El perfil viene con su rol desde el servidor (GET /users/me), así que lo que llega
        // es lo que vale: no se re-mezcla el rol que se guardó en el login.
        user = User.fromJson(data['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user!.toJson()));
      }
    } on ApiException catch (e) {
      profileError = e.message;
    }

    profileLoading = false;
    notifyListeners();
  }

  // La renovación en curso, si la hay. La app puede tener varias peticiones en el aire cuando
  // caduca el token: todas esperan esta misma renovación en vez de pedir cada una la suya.
  Future<String>? _renewal;

  // Hace una petición a una ruta protegida con el token de la sesión.
  // El access token del backend dura 15 minutos: si la API responde 401, pedimos uno nuevo
  // con el refresh token y repetimos la petición una vez. Si tampoco se puede renovar,
  // la sesión ha caducado y se cierra (la app vuelve al login).
  Future<dynamic> authorizedRequest(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    // El token con el que sale esta petición, para saber luego si sigue siendo el de la sesión
    final sentToken = token;

    try {
      return await _httpRequest(path, method: method, body: body, token: sentToken);
    } on ApiException catch (e) {
      if (e.status != 401 || refreshToken == null) rethrow;

      // Si el token ya ha cambiado, otra petición lo ha renovado mientras ésta iba de camino:
      // su 401 habla del token viejo, así que basta con reintentar con el que hay ahora.
      // Pedir aquí otra renovación sería el segundo /auth/refresh que este arreglo evita, y
      // el día que el backend rote el refresh token la primera renovación dejaría sin valer
      // el que mandaría esta, y se cerraría la sesión sin motivo.
      if (token != sentToken) {
        return _httpRequest(path, method: method, body: body, token: token);
      }
    }

    final fresh = await _renewToken();

    return _httpRequest(path, method: method, body: body, token: fresh);
  }

  // Renueva el token una sola vez aunque la pidan varias peticiones a la vez: la primera
  // arranca la llamada y las demás se enganchan a la misma.
  Future<String> _renewToken() {
    final inFlight = _renewal;
    if (inFlight != null) return inFlight;

    // Se guarda antes de esperar nada, para que la siguiente petición que llegue lo encuentre
    final renewal = _renew();
    _renewal = renewal;

    // Se suelta al terminar, salga bien o mal: si se quedara guardado, la próxima caducidad
    // reutilizaría el resultado de la anterior en vez de volver a renovar.
    renewal.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_renewal, renewal)) _renewal = null;
    });

    return renewal;
  }

  // POST /auth/refresh. Va con la petición de siempre y no con authorizedRequest(), así que
  // la renovación no puede acabar esperándose a sí misma.
  Future<String> _renew() async {
    final currentRefreshToken = refreshToken;

    // La sesión se ha cerrado mientras esta petición llegaba (un logout, por ejemplo): no hay
    // nada que renovar y lo que ya está cerrado no se vuelve a cerrar.
    if (currentRefreshToken == null) {
      throw ApiException('La sesión ha caducado, inicia sesión otra vez', 401);
    }

    try {
      final fresh = await AuthService.refresh(currentRefreshToken, httpRequest: _httpRequest);

      // La sesión cambió mientras se renovaba (un logout, o un logout y un login nuevo). El token
      // nuevo no pertenece a la sesión que hay ahora: se descarta y no se escribe en el móvil, para
      // que un logout no deje un token guardado como si la sesión siguiera abierta.
      if (refreshToken != currentRefreshToken) {
        throw ApiException('La sesión ha caducado, inicia sesión otra vez', 401);
      }

      token = fresh;
      await _storage.write(key: 'token', value: fresh);
      return fresh;
    } on ApiException {
      // No se pudo renovar el token (caducado, revocado o sin conexión): damos la sesión por
      // perdida y la borramos del móvil una sola vez, aquí, para que no la cierren a la vez
      // todas las peticiones que estaban esperando. No se avisa al servidor porque no tenemos
      // ningún token que vaya a aceptar.
      // Si la sesión ya cambió, no la cerramos: la que hay ahora no es la que falló al renovarse.
      if (refreshToken == currentRefreshToken) await _clearSession();
      throw ApiException('La sesión ha caducado, inicia sesión otra vez', 401);
    }
  }

  // Cuánto esperamos al servidor para cerrar la sesión. Pasado ese tiempo cerramos igual:
  // nadie se queda dentro de la app esperando a una red que no responde.
  static const _logoutTimeout = Duration(seconds: 2);

  // Cierra la sesión en el móvil y avisa al servidor para que los tokens dejen de servir.
  // El aviso es lo segundo: primero la sesión se cierra aquí, así que un fallo de red (o un
  // backend que todavía no tiene el endpoint) no puede dejar a nadie atrapado dentro de la app.
  Future<void> logout() async {
    final currentToken = token;
    final currentRefreshToken = refreshToken;

    // Primero en el móvil: la app vuelve al login al instante, sin esperar a la red
    await _clearSession();

    if (currentToken == null) return;

    try {
      // Después, con los tokens que teníamos guardados, pedimos al servidor que los invalide:
      // sube la versión de tokens del usuario, así que mueren al instante y la sesión se cierra
      // también en sus otros dispositivos.
      // Da igual cómo falle (sin red, sin endpoint, tokens caducados, o una respuesta que no
      // es JSON): la sesión ya está cerrada aquí, así que no hay nada que hacer.
      await _logoutOnServer(currentToken, currentRefreshToken).timeout(_logoutTimeout);
    } catch (_) {
      // Sin aviso al servidor, pero el usuario está fuera
    }
  }

  // POST /auth/logout. Si el access token había caducado lo renovamos antes, porque el servidor
  // sólo cierra la sesión de quien le demuestra que el token es suyo.
  Future<void> _logoutOnServer(String accessToken, String? refreshToken) async {
    try {
      await AuthService.logout(accessToken, httpRequest: _httpRequest);
    } on ApiException catch (e) {
      if (e.status != 401 || refreshToken == null) rethrow;

      final fresh = await AuthService.refresh(refreshToken, httpRequest: _httpRequest);
      await AuthService.logout(fresh, httpRequest: _httpRequest);
    }
  }

  // Borra la sesión del móvil y avisa a las pantallas (la app vuelve al login)
  Future<void> _clearSession() async {
    user = null;
    token = null;
    refreshToken = null;
    error = null;

    final prefs = await SharedPreferences.getInstance();
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'refreshToken');
    await prefs.remove('user');

    notifyListeners();
  }

  // Quita el mensaje de error (al cambiar de pantalla)
  void clearError() {
    error = null;
    notifyListeners();
  }
}
