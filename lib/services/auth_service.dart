import '../models/user.dart';
import 'http_client.dart';

// Función para hablar con la API. Por defecto es la de verdad (http_client.dart);
// los tests inyectan una falsa para no salir a la red.
typedef ApiRequest = Future<dynamic> Function(
  String path, {
  String method,
  Map<String, dynamic>? body,
  String? token,
});

// Lo que devuelve el login: los dos tokens y el usuario
class Session {
  final String token;
  final String refreshToken;
  final User user;

  Session({required this.token, required this.refreshToken, required this.user});
}

// Llamadas a la API de autenticación
class AuthService {
  // POST /auth/login. Si el email o la contraseña no son correctos, request() lanza un ApiException (401)
  static Future<Session> login(String email, String password, {ApiRequest? httpRequest}) async {
    final data = await (httpRequest ?? request)('/auth/login', method: 'POST', body: {'email': email, 'password': password});

    return Session(
      token: data['token'],
      refreshToken: data['refreshToken'],
      user: User.fromJson(data['user']),
    );
  }

  // POST /auth/refresh. Con el refresh token pide un access token nuevo.
  // Si el refresh token ha caducado, request() lanza un ApiException (401)
  static Future<String> refresh(String refreshToken, {ApiRequest? httpRequest}) async {
    final data = await (httpRequest ?? request)('/auth/refresh', method: 'POST', body: {'refreshToken': refreshToken});

    return data['token'];
  }

  // POST /auth/logout. Pide al servidor que cierre la sesión. Pide el access token, porque
  // el servidor tiene que saber de quién es la sesión. Sube la versión de tokens del usuario,
  // así que el access token y el refresh token dejan de valer al instante en este dispositivo
  // y en cualquier otro donde tuviera la sesión abierta. Responde 204, sin cuerpo.
  static Future<void> logout(String token, {ApiRequest? httpRequest}) async {
    await (httpRequest ?? request)('/auth/logout', method: 'POST', token: token);
  }

  // POST /auth/register. La API no devuelve token: después del registro hay que hacer login
  static Future<void> register(String name, String email, String password, {ApiRequest? httpRequest}) async {
    await (httpRequest ?? request)('/auth/register', method: 'POST', body: {'name': name, 'email': email, 'password': password});
  }
}
