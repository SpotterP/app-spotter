import 'dart:async';
import 'dart:convert';

import 'package:app_spotter/models/user.dart';
import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/services/auth_service.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El access token dura 15 minutos y la app puede tener varias peticiones en el aire cuando
// caduca (el perfil, el historial, un entrenamiento...). Si cada una pidiera su propia
// renovación, al backend le llegarían varios POST /auth/refresh a la vez; el día que rote el
// refresh token, la primera renovación dejaría sin valer el de las demás y se cerrarían
// sesiones sin explicación. Por eso la renovación se hace una sola vez y todas las
// peticiones que esperan reanudan con el mismo token nuevo, también cuando la renovación
// falla: la sesión se cierra una sola vez y todos reciben el mismo aviso.
// La petición se sustituye por una falsa para no salir a la red.
void main() {
  const storage = FlutterSecureStorage();

  // Una sesión abierta, igual que en logout_test: el token no se valida, sólo viaja
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

  // Lo que ve la API en cada llamada: método, ruta y el token con el que viaja.
  // 'sin-token' es la renovación, que no lleva access token: lleva el refresh token en el cuerpo.
  String seen(String method, String path, String? token) => '$method $path:${token ?? 'sin-token'}';

  // Cuántas veces se ha pedido un token nuevo: es lo que este arreglo tiene que dejar en una
  int refreshes(List<String> called) => called.where((c) => c.startsWith('POST /auth/refresh')).length;

  // Deja correr lo que esté pendiente hasta que las peticiones estén donde el test las espera.
  // Un temporizador de cero se ejecuta después de todas las tareas pendientes, así que a partir
  // de aquí las peticiones ya han recibido su 401 y han llegado a la renovación (o a esperarla).
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  // Ejecuta las peticiones sin lanzar: devuelve los errores, para poder comparar que todos los
  // que esperaban la misma renovación reciben lo mismo y ninguno se queda colgado esperando.
  Future<List<Object>> errorsOf(List<Future<dynamic>> requests) async {
    final errors = <Object>[];
    await Future.wait(requests.map((r) => r.then<void>((_) {}, onError: (Object e) => errors.add(e))));
    return errors;
  }

  test('dos peticiones que caducan a la vez renuevan el token una sola vez', () async {
    // Dos rutas protegidas que salen con el token viejo y se encuentran el 401 a la vez
    final called = <String>[];

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add(seen(method, path, token));
      if (path == '/auth/refresh') {
        // La renovación tarda lo suyo: la segunda petición llega mientras sigue en el aire
        await Future<void>.delayed(Duration.zero);
        return {'token': 'token-nuevo'};
      }
      if (token == 'token-nuevo') return {'ok': true};
      throw ApiException('El token ha caducado', 401);
    });

    final results = await Future.wait([
      auth.authorizedRequest('/users/me'),
      auth.authorizedRequest('/users/me/sessions'),
    ]);

    // Al backend le llega un solo POST /auth/refresh y las dos peticiones se reintentan con
    // el mismo token nuevo, en el orden en que salieron
    expect(called, [
      'GET /users/me:token-viejo',
      'GET /users/me/sessions:token-viejo',
      'POST /auth/refresh:sin-token',
      'GET /users/me:token-nuevo',
      'GET /users/me/sessions:token-nuevo',
    ]);
    expect(refreshes(called), 1);

    // Ninguna de las dos se queda por el camino: las dos terminan bien
    expect(results, [
      {'ok': true},
      {'ok': true},
    ]);
    expect(auth.token, 'token-nuevo');
    expect(await storage.read(key: 'token'), 'token-nuevo');
    expect(auth.refreshToken, 'refresh-viejo');
    expect(auth.user, isNotNull);
  });

  test('una petición que llega mientras se renueva espera y reutiliza la renovación', () async {
    // La tercera petición sale con la sesión todavía en el aire: no puede pedir otro token
    final called = <String>[];
    final renewal = Completer<void>();

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add(seen(method, path, token));
      if (path == '/auth/refresh') {
        await renewal.future;
        return {'token': 'token-nuevo'};
      }
      if (token == 'token-nuevo') return {'ok': true};
      throw ApiException('El token ha caducado', 401);
    });

    final first = auth.authorizedRequest('/users/me');
    final second = auth.authorizedRequest('/users/me/sessions');
    // Hasta aquí las dos han recibido su 401 y la renovación está en marcha, sin respuesta
    await settle();

    final third = auth.authorizedRequest('/users/me/workouts');

    renewal.complete();
    final results = await Future.wait([first, second, third]);

    expect(called, [
      'GET /users/me:token-viejo',
      'GET /users/me/sessions:token-viejo',
      'POST /auth/refresh:sin-token',
      'GET /users/me/workouts:token-viejo',
      'GET /users/me:token-nuevo',
      'GET /users/me/sessions:token-nuevo',
      'GET /users/me/workouts:token-nuevo',
    ]);
    expect(refreshes(called), 1);
    expect(results.every((r) => r is Map && r['ok'] == true), isTrue);
  });

  test('si la renovación falla, todos fallan con el mismo aviso y la sesión se cierra una vez', () async {
    // El refresh token también ha caducado: no hay forma de seguir dentro de la app
    final called = <String>[];
    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add(seen(method, path, token));
      throw ApiException('El token ha caducado', 401);
    });

    // Cada aviso a las pantallas es un cierre de sesión: sólo puede haber uno
    var notified = 0;
    auth.addListener(() => notified++);

    final errors = await errorsOf([
      auth.authorizedRequest('/users/me'),
      auth.authorizedRequest('/users/me/sessions'),
    ]);

    expect(refreshes(called), 1);
    expect(errors.length, 2);
    // El mismo aviso para los dos: nadie recibe un error distinto por haber llegado tarde
    for (final error in errors) {
      expect(error, isA<ApiException>());
      expect((error as ApiException).status, 401);
      expect(error.message, 'La sesión ha caducado, inicia sesión otra vez');
    }

    // La sesión queda cerrada y borrada, y se ha cerrado una sola vez
    expect(notified, 1);
    expect(auth.user, isNull);
    expect(auth.token, isNull);
    expect(auth.refreshToken, isNull);
    expect(await storage.read(key: 'token'), isNull);
    expect(await storage.read(key: 'refreshToken'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user'), isNull);
  });

  test('después de renovar, un 401 posterior vuelve a pedir un token nuevo', () async {
    // La renovación no se queda pegada: cuando el token nuevo también caduca, se renueva otra vez
    final called = <String>[];
    // Qué token acepta el servidor ahora mismo: al principio, ninguno de los que tiene la app
    var valid = 'ninguno-todavía';

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add(seen(method, path, token));
      if (path == '/auth/refresh') {
        valid = 'token-${refreshes(called)}';
        return {'token': valid};
      }
      if (token == valid) return {'ok': true};
      throw ApiException('El token ha caducado', 401);
    });

    await auth.authorizedRequest('/users/me');
    expect(auth.token, 'token-1');

    // Quince minutos después el token nuevo también ha caducado
    valid = 'caducado';

    await auth.authorizedRequest('/users/me/sessions');

    expect(called, [
      'GET /users/me:token-viejo',
      'POST /auth/refresh:sin-token',
      'GET /users/me:token-1',
      'GET /users/me/sessions:token-1',
      'POST /auth/refresh:sin-token',
      'GET /users/me/sessions:token-2',
    ]);
    expect(refreshes(called), 2);
    expect(auth.token, 'token-2');
  });

  test('un 401 que llega después de renovar se reintenta sin pedir otro token', () async {
    // Esta petición salió antes de la renovación y su 401 llega tarde: el token ya es otro,
    // así que con reintentar basta. Pedir otra renovación sería el segundo /auth/refresh.
    final called = <String>[];
    final slow = Completer<void>();

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add(seen(method, path, token));
      if (path == '/auth/refresh') return {'token': 'token-nuevo'};
      if (path == '/users/me' && token == 'token-viejo') {
        // El servidor tarda en contestar que el token viejo caducó
        await slow.future;
        throw ApiException('El token ha caducado', 401);
      }
      if (token == 'token-nuevo') return {'ok': true};
      throw ApiException('El token ha caducado', 401);
    });

    final late = auth.authorizedRequest('/users/me');
    await settle();

    // Mientras el 401 de la primera sigue de camino, otra petición renueva el token
    expect(await auth.authorizedRequest('/users/me/sessions'), {'ok': true});
    expect(auth.token, 'token-nuevo');

    slow.complete();
    expect(await late, {'ok': true});

    expect(called, [
      'GET /users/me:token-viejo',
      'GET /users/me/sessions:token-viejo',
      'POST /auth/refresh:sin-token',
      'GET /users/me/sessions:token-nuevo',
      'GET /users/me:token-nuevo',
    ]);
    expect(refreshes(called), 1);
  });

  test('un logout mientras se renueva no deja el token nuevo escrito', () async {
    // Si la renovación termina después de cerrar sesión, el token nuevo ya no es de nadie:
    // ni en memoria ni en el almacenamiento del móvil puede quedar rastro de esa sesión.
    final protegida = Completer<dynamic>();
    final renovacion = Completer<dynamic>();

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      if (path == '/auth/refresh') return renovacion.future;
      if (path == '/auth/logout') return null;
      return protegida.future;
    });

    // Una petición protegida que sale con el token viejo
    final enVuelo = auth.authorizedRequest('/users/me');
    await settle();

    // Caduca: se pone a renovar y se queda esperando la respuesta
    protegida.completeError(ApiException('El token ha caducado', 401));
    await settle();

    // Mientras espera, el usuario cierra sesión...
    await auth.logout();

    // ...y ahora sí llega el servidor con el token nuevo
    renovacion.complete({'token': 'token-tardio'});

    await expectLater(enVuelo, throwsA(isA<ApiException>()));

    expect(auth.token, isNull);
    expect(auth.refreshToken, isNull);
    expect(await storage.read(key: 'token'), isNull);
    expect(await storage.read(key: 'refreshToken'), isNull);
  });
}
