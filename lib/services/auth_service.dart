import '../models/user.dart';
import 'http_client.dart';

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
  static Future<Session> login(String email, String password) async {
    final data = await request('/auth/login', method: 'POST', body: {'email': email, 'password': password});

    return Session(
      token: data['token'],
      refreshToken: data['refreshToken'],
      user: User.fromJson(data['user']),
    );
  }

  // POST /auth/refresh. Con el refresh token pide un access token nuevo.
  // Si el refresh token ha caducado, request() lanza un ApiException (401)
  static Future<String> refresh(String refreshToken) async {
    final data = await request('/auth/refresh', method: 'POST', body: {'refreshToken': refreshToken});

    return data['token'];
  }

  // POST /auth/register. La API no devuelve token: después del registro hay que hacer login
  static Future<void> register(String name, String email, String password) async {
    await request('/auth/register', method: 'POST', body: {'name': name, 'email': email, 'password': password});
  }
}
