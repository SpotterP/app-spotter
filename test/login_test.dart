import 'dart:convert';

import 'package:app_spotter/models/user.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El backend separa a propósito la app del backoffice: las rutas de datos de la app
// (/users/me/workouts, /users/me/sessions, /users/me/progress) exigen el rol USER.
// Si la app aceptara un ADMIN, entraría y se encontraría las cuatro pestañas vacías
// por un 403 sin explicación, así que el login tiene que rechazarlo y decirlo claro.
// La petición se sustituye por una falsa para no salir a la red.
void main() {
  const storage = FlutterSecureStorage();

  // Lo que devuelve la API al hacer login, con el rol que le pidamos
  Map<String, dynamic> loginResponse(String role) {
    return {
      'token': 'token-${role.toLowerCase()}',
      'refreshToken': 'refresh-${role.toLowerCase()}',
      'user': {'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': role},
    };
  }

  test('un login de administrador no entra en la app y avisa', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final called = <String>[];

    final auth = AuthProvider(
      httpRequest: (path, {method = 'GET', body, token}) async {
        called.add('$method $path');
        // Una sesión perfectamente válida... para el backoffice
        if (path == '/auth/login') return loginResponse('ADMIN');
        return null;
      },
    );

    final entro = await auth.login('jefe@example.com', 'secreta');

    // No entra: ni sesión en memoria, ni tokens ni usuario guardados en el móvil
    expect(entro, isFalse);
    expect(auth.user, isNull);
    expect(auth.token, isNull);
    expect(auth.refreshToken, isNull);
    expect(await storage.read(key: 'token'), isNull);
    expect(await storage.read(key: 'refreshToken'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user'), isNull);

    // Y se le explica por qué, en vez de dejarlo con las pestañas vacías
    expect(auth.error, contains('administrador'));
    expect(auth.error, contains('backoffice'));
    expect(auth.loading, isFalse);

    // Los tokens que creó el login se descartan sin más: no se guardan en ningún sitio.
    // Tampoco se cierran en el servidor, porque eso echaría al admin del backoffice en
    // todos sus dispositivos justo cuando va a entrar ahí.
    expect(called, ['POST /auth/login']);
  });

  test('una sesión de administrador ya guardada en el móvil no entra al arrancar', () async {
    // Pudo guardarse antes de que existiera esta regla: al abrir la app tampoco puede entrar
    SharedPreferences.setMockInitialValues({
      'user': jsonEncode({'_id': 'u1', 'name': 'Jefe', 'email': 'jefe@example.com', 'role': 'ADMIN'}),
    });
    FlutterSecureStorage.setMockInitialValues({'token': 'token-admin', 'refreshToken': 'refresh-admin'});

    final auth = AuthProvider(
      httpRequest: (path, {method = 'GET', body, token}) async => null,
    );

    await auth.loadSession();

    expect(auth.isLoggedIn, isFalse);
    expect(auth.user, isNull);
    expect(await storage.read(key: 'token'), isNull);
    expect(await storage.read(key: 'refreshToken'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user'), isNull);
    expect(auth.starting, isFalse);
  });

  test('una sesión de usuario normal guardada sigue entrando al arrancar', () async {
    // La otra cara de la regla: la puerta nueva no puede borrar la sesión de quien sí puede entrar
    SharedPreferences.setMockInitialValues({
      'user': jsonEncode({'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'}),
    });
    FlutterSecureStorage.setMockInitialValues({'token': 'token-ana', 'refreshToken': 'refresh-ana'});

    final auth = AuthProvider(
      httpRequest: (path, {method = 'GET', body, token}) async => null,
    );

    await auth.loadSession();

    expect(auth.isLoggedIn, isTrue);
    expect(auth.user!.name, 'Ana');
    expect(await storage.read(key: 'token'), 'token-ana');
    expect(await storage.read(key: 'refreshToken'), 'refresh-ana');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user'), isNotNull);
  });

  test('un login de usuario normal sigue entrando', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final called = <String>[];

    final auth = AuthProvider(
      httpRequest: (path, {method = 'GET', body, token}) async {
        called.add('$method $path');
        return loginResponse('USER');
      },
    );

    final entro = await auth.login('ana@example.com', 'secreta');

    // Entra como siempre, con la sesión guardada en el móvil para la próxima vez
    expect(entro, isTrue);
    expect(auth.user!.role, 'USER');
    expect(auth.token, 'token-user');
    expect(auth.refreshToken, 'refresh-user');
    expect(await storage.read(key: 'token'), 'token-user');
    expect(await storage.read(key: 'refreshToken'), 'refresh-user');
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('user')!)['email'], 'ana@example.com');
    expect(auth.error, isNull);
    expect(auth.loading, isFalse);

    // Y no se cierra ninguna sesión: sólo se ha pedido el login
    expect(called, ['POST /auth/login']);
  });

  test('un 403 no se confunde con un token caducado', () async {
    SharedPreferences.setMockInitialValues({
      'user': jsonEncode({'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'}),
    });
    FlutterSecureStorage.setMockInitialValues({'token': 'token-viejo', 'refreshToken': 'refresh-viejo'});

    final called = <String>[];

    final auth = AuthProvider(
      httpRequest: (path, {method = 'GET', body, token}) async {
        called.add('$method $path');
        // La API dice que esta cuenta no tiene el rol que la ruta pide: no es un token caducado
        throw ApiException('Necesitas el rol USER', 403);
      },
    );
    auth.user = User.fromJson({'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'});
    auth.token = 'token-viejo';
    auth.refreshToken = 'refresh-viejo';

    await expectLater(
      auth.authorizedRequest('/users/me/workouts'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Necesitas el rol USER')
            .having((e) => e.status, 'status', 403),
      ),
    );

    // Se avisa con el mensaje del servidor y no se toca la sesión: ni se renueva el token
    // ni se cierra a ciegas, porque la sesión sigue siendo buena
    expect(called, ['GET /users/me/workouts']);
    expect(auth.user, isNotNull);
    expect(auth.token, 'token-viejo');
    expect(auth.refreshToken, 'refresh-viejo');
    expect(await storage.read(key: 'token'), 'token-viejo');
    expect(auth.error, isNull);
  });
}
