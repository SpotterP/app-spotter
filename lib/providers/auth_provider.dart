import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

// Función para hablar con la API. Por defecto es la de verdad (http_client.dart);
// los tests inyectan una falsa para no salir a la red.
typedef ApiRequest = Future<dynamic> Function(
  String path, {
  String method,
  Map<String, dynamic>? body,
  String? token,
});

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
      token = savedToken;
      refreshToken = await _storage.read(key: 'refreshToken');
      user = User.fromJson(jsonDecode(savedUser));
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
      final session = await AuthService.login(email, password);

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
        // La API solo devuelve _id, name y email: el rol lo mantenemos
        user = User.fromJson({...data['user'], 'role': user!.role});

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user!.toJson()));
      }
    } on ApiException catch (e) {
      profileError = e.message;
    }

    profileLoading = false;
    notifyListeners();
  }

  // Hace una petición a una ruta protegida con el token de la sesión.
  // El access token del backend dura 15 minutos: si la API responde 401, pedimos uno nuevo
  // con el refresh token y repetimos la petición una vez. Si tampoco se puede renovar,
  // la sesión ha caducado y se cierra (la app vuelve al login).
  Future<dynamic> authorizedRequest(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    try {
      return await _httpRequest(path, method: method, body: body, token: token);
    } on ApiException catch (e) {
      if (e.status != 401 || refreshToken == null) rethrow;
    }

    try {
      token = await AuthService.refresh(refreshToken!);
    } on ApiException {
      await logout();
      throw ApiException('La sesión ha caducado, inicia sesión otra vez', 401);
    }

    await _storage.write(key: 'token', value: token);

    return _httpRequest(path, method: method, body: body, token: token);
  }

  // Cierra la sesión: borra los datos guardados
  Future<void> logout() async {
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
