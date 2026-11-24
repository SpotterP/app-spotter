import 'dart:async';
import 'dart:convert';

import 'package:app_spotter/models/user.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/services/auth_service.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Las carreras de la renovación del token: qué pasa cuando una renovación está en el aire y
// mientras tanto la sesión cambia (logout, otro login) o la renovación falla.
// Son las guardas que impiden cerrar una sesión sin motivo y escribir un token que ya no es de nadie.
void main() {
  const storage = FlutterSecureStorage();

  AuthProvider loggedIn(ApiRequest httpRequest) {
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

  // Deja correr lo pendiente hasta que las peticiones estén donde el test las espera
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('un logout y un login nuevo durante la renovación dejan intacta la sesión nueva', () async {
    final called = <String>[];
    final protegida = Completer<dynamic>();
    final renovacion = Completer<dynamic>();

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add('$method $path:$token');
      if (path == '/auth/refresh') return renovacion.future;
      if (path == '/auth/logout') return null;
      if (path == '/auth/login') {
        return {
          'token': 'token-b',
          'refreshToken': 'refresh-b',
          'user': {'_id': 'u2', 'name': 'Bea', 'email': 'bea@example.com', 'role': 'USER'},
        };
      }
      return protegida.future;
    });

    // Una petición que caduca y se queda esperando la renovación
    final enVuelo = auth.authorizedRequest('/users/me');
    await settle();
    protegida.completeError(ApiException('El token ha caducado', 401));
    await settle();

    // El usuario cierra sesión y entra con otra cuenta antes de que llegue el token nuevo
    await auth.logout();
    expect(await auth.login('bea@example.com', 'secreta'), isTrue);

    var avisos = 0;
    auth.addListener(() => avisos++);

    // Y ahora sí llega el token de la sesión vieja
    renovacion.complete({'token': 'token-tardio'});

    Object? error;
    try {
      await enVuelo;
    } catch (e) {
      error = e;
    }

    // Falla la petición vieja, pero la sesión nueva no se toca ni se vuelve a avisar a las pantallas
    expect(error, isA<ApiException>());
    expect((error as ApiException).status, 401);
    expect(auth.token, 'token-b');
    expect(auth.refreshToken, 'refresh-b');
    expect(auth.user, isNotNull);
    expect(await storage.read(key: 'token'), 'token-b');
    expect(avisos, 0);
    // Y no se ha pedido un segundo token: el que estaba en el aire era el único
    expect(called.where((c) => c.startsWith('POST /auth/refresh')).length, 1, reason: '$called');
  });

  test('un error que no es ApiException al renovar no deja la renovación pegada', () async {
    // Si la renovación revienta por algo que no es la API (una respuesta sin token, por ejemplo),
    // el estado en vuelo tiene que soltarse igual: la próxima caducidad debe poder renovar.
    var renovaciones = 0;

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      if (path == '/auth/refresh') {
        renovaciones++;
        if (renovaciones == 1) return {'sin': 'token'};
        return {'token': 'token-nuevo'};
      }
      if (token == 'token-nuevo') return {'ok': true};
      throw ApiException('El token ha caducado', 401);
    });

    Object? error;
    try {
      await auth.authorizedRequest('/primera');
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);

    await settle();

    // La siguiente petición renueva otra vez y termina bien
    expect(await auth.authorizedRequest('/segunda'), {'ok': true});
    expect(renovaciones, 2);
  });

  test('tras un fallo de renovación, un login nuevo y otro 401 vuelven a renovar', () async {
    var renovaciones = 0;

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      if (path == '/auth/refresh') {
        renovaciones++;
        // El refresh token de la sesión que caducó ya no vale; el de la sesión nueva sí
        if (body?['refreshToken'] == 'refresh-viejo') throw ApiException('refresh caducado', 401);
        return {'token': 'token-nuevo'};
      }
      if (path == '/auth/login') {
        return {
          'token': 'token-b',
          'refreshToken': 'refresh-b',
          'user': {'_id': 'u1', 'name': 'Ana', 'email': 'ana@example.com', 'role': 'USER'},
        };
      }
      if (token == 'token-nuevo') return {'ok': true};
      throw ApiException('El token ha caducado', 401);
    });

    await expectLater(auth.authorizedRequest('/primera'), throwsA(isA<ApiException>()));
    expect(auth.refreshToken, isNull);

    expect(await auth.login('ana@example.com', 'secreta'), isTrue);
    expect(await auth.authorizedRequest('/segunda'), {'ok': true});
    expect(renovaciones, 2);
  });

  test('un 401 que llega después del fallo no vuelve a cerrar la sesión', () async {
    final lenta = Completer<void>();
    var avisos = 0;

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      if (path == '/lenta') {
        await lenta.future;
        throw ApiException('El token ha caducado', 401);
      }
      throw ApiException('refresh caducado', 401);
    });
    auth.addListener(() => avisos++);

    // Una petición lenta y otra que provoca el fallo de la renovación y cierra la sesión
    final tardia = auth.authorizedRequest('/lenta');
    await expectLater(auth.authorizedRequest('/rapida'), throwsA(isA<ApiException>()));
    lenta.complete();

    Object? error;
    try {
      await tardia;
    } catch (e) {
      error = e;
    }

    // La sesión ya estaba cerrada: no se cierra otra vez ni se avisa dos veces
    expect(error, isA<ApiException>());
    expect((error as ApiException).status, 401);
    expect(avisos, 1);
  });

  test('dos peticiones esperando y un logout no escriben el token tardío', () async {
    final called = <String>[];
    final renovacion = Completer<dynamic>();

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add('$method $path:$token');
      if (path == '/auth/refresh') return renovacion.future;
      if (path == '/auth/logout') return null;
      throw ApiException('El token ha caducado', 401);
    });

    final primera = auth.authorizedRequest('/primera');
    final segunda = auth.authorizedRequest('/segunda');
    await settle();

    // El usuario cierra sesión mientras las dos esperan
    await auth.logout();
    renovacion.complete({'token': 'token-tardio'});

    final errores = <Object>[];
    for (final peticion in [primera, segunda]) {
      try {
        await peticion;
      } catch (e) {
        errores.add(e);
      }
    }

    // Las dos fallan con el aviso de sesión caducada y nada queda guardado
    expect(errores.length, 2);
    expect(errores.every((e) => e is ApiException && e.status == 401), isTrue);
    expect(auth.token, isNull);
    expect(await storage.read(key: 'token'), isNull);
    expect(called.where((c) => c.startsWith('POST /auth/refresh')).length, 1, reason: '$called');
    expect(called.where((c) => c.contains('token-tardio')), isEmpty);
  });
}
