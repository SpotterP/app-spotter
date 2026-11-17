import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

// Guarda la sesión del usuario (token y datos) y avisa a las pantallas cuando cambia.
// La sesión se guarda también en el móvil con SharedPreferences, para no tener que
// hacer login cada vez que se abre la app.
class AuthProvider extends ChangeNotifier {
  User? user;
  String? token;
  String? refreshToken;

  // true mientras se lee la sesión guardada al arrancar la app
  bool starting = true;

  // true mientras se espera la respuesta de la API (para desactivar el botón)
  bool loading = false;

  // Mensaje de error de la última acción, para enseñarlo en pantalla
  String? error;

  bool get isLoggedIn => user != null && token != null;

  // Lee la sesión guardada. Se llama una vez al crear el provider
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedUser = prefs.getString('user');

    if (savedToken != null && savedUser != null) {
      token = savedToken;
      refreshToken = prefs.getString('refreshToken');
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
      await prefs.setString('token', session.token);
      await prefs.setString('refreshToken', session.refreshToken);
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

  // Hace una petición a una ruta protegida con el token de la sesión.
  // El access token del backend dura 15 minutos: si la API responde 401, pedimos uno nuevo
  // con el refresh token y repetimos la petición una vez. Si tampoco se puede renovar,
  // la sesión ha caducado y se cierra (la app vuelve al login).
  Future<dynamic> authorizedRequest(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    try {
      return await request(path, method: method, body: body, token: token);
    } on ApiException catch (e) {
      if (e.status != 401 || refreshToken == null) rethrow;
    }

    try {
      token = await AuthService.refresh(refreshToken!);
    } on ApiException {
      await logout();
      throw ApiException('La sesión ha caducado, inicia sesión otra vez', 401);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token!);

    return request(path, method: method, body: body, token: token);
  }

  // Cierra la sesión: borra los datos guardados
  Future<void> logout() async {
    user = null;
    token = null;
    refreshToken = null;
    error = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('user');

    notifyListeners();
  }

  // Quita el mensaje de error (al cambiar de pantalla)
  void clearError() {
    error = null;
    notifyListeners();
  }
}
