import 'dart:async';
import 'dart:convert';

import 'package:app_spotter/models/user.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/services/auth_service.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Cerrar sesión tiene que avisar al servidor para que los tokens dejen de servir,
// pero sin dejar al usuario atrapado dentro de la app si el aviso no llega.
void main() {
  const storage = FlutterSecureStorage();

  // Una sesión abierta: usuario en memoria, tokens y copia guardada en el móvil
  Future<AuthProvider> loggedIn(ApiRequest httpRequest) async {
    SharedPreferences.setMockInitialValues({
      'user': jsonEncode({'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'}),
    });
    FlutterSecureStorage.setMockInitialValues({'token': 'token-viejo', 'refreshToken': 'refresh-viejo'});

    final auth = AuthProvider(httpRequest: httpRequest);
    auth.user = User.fromJson({'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'});
    auth.token = 'token-viejo';
    auth.refreshToken = 'refresh-viejo';
    return auth;
  }

  // Lo que tiene que quedar después de cerrar sesión, pase lo que pase con la API
  Future<void> expectSignedOut(AuthProvider auth) async {
    expect(auth.user, isNull);
    expect(auth.token, isNull);
    expect(auth.refreshToken, isNull);
    expect(await storage.read(key: 'token'), isNull);
    expect(await storage.read(key: 'refreshToken'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user'), isNull);
  }

  test('cerrar sesión avisa al servidor con POST /auth/logout', () async {
    final called = <String>[];
    String? sentToken;

    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      called.add('$method $path');
      sentToken = token;
      return null;
    });

    await auth.logout();

    // El servidor necesita el access token para saber de quién es la sesión
    expect(called, ['POST /auth/logout']);
    expect(sentToken, 'token-viejo');
    await expectSignedOut(auth);
  });

  test('si el servidor no tiene el endpoint, la sesión se cierra igual', () async {
    // Un backend sin desplegar todavía responde 404; la app no puede quedarse dentro
    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      throw ApiException('Not Found', 404);
    });

    await auth.logout();

    await expectSignedOut(auth);
  });

  test('si el access token caducó, se renueva y se reintenta el logout', () async {
    final called = <String>[];

    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      called.add('$method $path');
      if (path == '/auth/refresh') return {'token': 'token-nuevo'};
      // El servidor sólo acepta cerrar la sesión con un token vivo
      if (token == 'token-nuevo') return null;
      throw ApiException('El token ha caducado', 401);
    });

    await auth.logout();

    expect(called, ['POST /auth/logout', 'POST /auth/refresh', 'POST /auth/logout']);
    await expectSignedOut(auth);
  });

  test('si el refresh token también caducó, se cierra en local igual', () async {
    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      throw ApiException('El token ha caducado', 401);
    });

    await auth.logout();

    await expectSignedOut(auth);
  });

  test('cuando la sesión caduca sola no se avisa al servidor', () async {
    final called = <String>[];

    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      called.add('$method $path');
      throw ApiException('El token ha caducado', 401);
    });

    // Una petición cualquiera con la sesión caducada: no hay nada que avisar al
    // servidor, porque ya no nos acepta ningún token
    await expectLater(auth.authorizedRequest('/users/me'), throwsA(isA<ApiException>()));
    expect(called, ['GET /users/me', 'POST /auth/refresh']);

    await expectSignedOut(auth);
  });

  test('un error que no es ApiException no impide cerrar en local', () async {
    // Un portal cautivo que contesta 200 con HTML revienta al leer el JSON, no con ApiException
    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      throw const FormatException('<html>portal cautivo</html>');
    });

    await auth.logout();

    await expectSignedOut(auth);
  });

  test('si el servidor no responde, la sesión se cierra en local igual', () async {
    // Una red que se queda colgada no puede dejar al usuario dentro de la app
    final auth = await loggedIn((path, {method = 'GET', body, token}) => Completer<dynamic>().future);

    await auth.logout().timeout(const Duration(seconds: 15));

    await expectSignedOut(auth);
  });

  test('con 401 permanente se renueva una sola vez y no hay bucle', () async {
    final called = <String>[];

    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      called.add('$path:$token');
      if (path == '/auth/refresh') return {'token': 'token-nuevo'};
      throw ApiException('El token ha caducado', 401);
    });

    await auth.logout();

    expect(called, ['/auth/logout:token-viejo', '/auth/refresh:null', '/auth/logout:token-nuevo']);
    await expectSignedOut(auth);
  });

  test('el servidor recibe el token guardado aunque el móvil ya se haya borrado', () async {
    // El orden importa: se cierra primero en el móvil y aun así el aviso lleva el token viejo
    late AuthProvider auth;
    String? tokenEnMemoria;
    String? tokenEnviado;

    auth = await loggedIn((path, {method = 'GET', body, token}) async {
      tokenEnMemoria = auth.token;
      tokenEnviado = token;
      return null;
    });

    await auth.logout();

    expect(tokenEnMemoria, isNull);
    expect(tokenEnviado, 'token-viejo');
    await expectSignedOut(auth);
  });

  test('dos logout a la vez avisan al servidor una sola vez', () async {
    final called = <String>[];

    final auth = await loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      return null;
    });

    await Future.wait([auth.logout(), auth.logout()]);

    expect(called, ['/auth/logout']);
    await expectSignedOut(auth);
  });
}
