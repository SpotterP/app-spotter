import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/services/auth_service.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:app_spotter/services/progress_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El historial de entrenamientos se pagina: el backend acepta page y limit
// (limit <= 100, page >= 1) y devuelve {sessions, pagination}. La app tiene que
// pedir la página que el backend diga que toca y juntarlas sin repetir ni perder
// ninguna sesión, también cuando las filas se desplazan porque el usuario guarda
// un entrenamiento nuevo mientras sigue bajando.
// La petición se sustituye por una falsa para no salir a la red.
void main() {
  // Un entrenamiento tal y como lo manda la API, sin ejercicios para no distraer
  Map<String, dynamic> apiSession(String id, int minutesAgo) => {
        '_id': id,
        'startedAt': DateTime.utc(2026, 3, 5, 12).subtract(Duration(minutes: minutesAgo)).toIso8601String(),
        'exercises': [],
      };

  // Una página con el mismo bloque pagination que construye buildPageInfo en el backend
  Map<String, dynamic> pageResponse({
    required List<Map<String, dynamic>> sessions,
    required int page,
    required int total,
    int limit = 100,
  }) {
    final totalPages = (total / limit).ceil();
    return {
      'sessions': sessions,
      'pagination': {
        'page': page,
        'limit': limit,
        'total': total,
        'totalPages': totalPages,
        'hasNextPage': page < totalPages,
        'hasPrevPage': page > 1,
      },
    };
  }

  // Una sesión abierta, igual que en logout_test: el token no se valida, sólo viaja
  AuthProvider loggedIn(ApiRequest httpRequest) {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'token': 'token-ana', 'refreshToken': 'refresh-ana'});

    final auth = AuthProvider(httpRequest: httpRequest);
    auth.token = 'token-ana';
    auth.refreshToken = 'refresh-ana';
    return auth;
  }

  // Ids de los entrenamientos que tiene el paginador ahora mismo
  List<String> ids(SessionsPager pager) => pager.sessions.map((s) => s.id).toList();

  test('la primera página se pide con page=1 y limit=100, que es lo que acepta la API', () async {
    final called = <String>[];

    final pager = SessionsPager(loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      return pageResponse(sessions: [apiSession('s1', 1)], page: 1, total: 1);
    }));

    await pager.loadNext();

    // limit=100 es el máximo del backend y page=1 su mínimo, así que la ruta es válida
    expect(called, ['/users/me/sessions?page=1&limit=100']);
    expect(ids(pager), ['s1']);
    expect(pager.hasMore, isFalse);
  });

  test('la segunda petición pide la página que devuelve el backend, no un contador propio', () async {
    final called = <String>[];

    final pager = SessionsPager(loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      if (called.length == 1) {
        // El backend dice que ésta es la página 3 de 5: la siguiente que toca es la 4,
        // aunque sea la segunda petición que hace la app
        return pageResponse(sessions: [apiSession('s3', 3)], page: 3, total: 450);
      }
      return pageResponse(sessions: [apiSession('s4', 4)], page: 4, total: 450);
    }));

    await pager.loadNext();
    expect(pager.nextPage, 4);

    await pager.loadNext();

    expect(called, ['/users/me/sessions?page=1&limit=100', '/users/me/sessions?page=4&limit=100']);
    expect(ids(pager), ['s3', 's4']);
  });

  test('juntar dos páginas da todas las sesiones una sola vez y en el mismo orden', () async {
    // Página 1 llena (100, el tope) y página 2 con las que quedan
    final firstPage = List.generate(100, (i) => apiSession('s${i + 1}', i + 1));
    final secondPage = [apiSession('s101', 101), apiSession('s102', 102), apiSession('s103', 103)];

    final called = <String>[];

    final pager = SessionsPager(loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      if (called.length == 1) return pageResponse(sessions: firstPage, page: 1, total: 103);
      return pageResponse(sessions: secondPage, page: 2, total: 103);
    }));

    await pager.loadNext();
    expect(pager.sessions.length, 100);

    await pager.loadNext();

    // Ni una repetida ni una perdida: las 103, en el orden del backend (más reciente primero)
    expect(pager.sessions.length, 103);
    expect(pager.sessions.map((s) => s.id).toSet().length, 103);
    expect(ids(pager), List.generate(103, (i) => 's${i + 1}'));
  });

  test('una sesión que aparece en dos páginas se queda una sola vez', () async {
    // El usuario guarda un entrenamiento mientras baja: las filas se desplazan y la última
    // de la página 1 vuelve a salir la primera en la página 2
    final firstPage = List.generate(100, (i) => apiSession('s${i + 1}', i + 1));
    final secondPage = [apiSession('s100', 100), apiSession('s101', 101), apiSession('s102', 102)];

    final called = <String>[];

    final pager = SessionsPager(loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      if (called.length == 1) return pageResponse(sessions: firstPage, page: 1, total: 102);
      return pageResponse(sessions: secondPage, page: 2, total: 102);
    }));

    await pager.loadNext();
    await pager.loadNext();

    expect(pager.sessions.length, 102);
    expect(ids(pager), List.generate(102, (i) => 's${i + 1}'));
    expect(ids(pager).where((id) => id == 's100').length, 1);
  });

  test('no se pide ninguna página más cuando el backend dice que ésta es la última', () async {
    final called = <String>[];

    final pager = SessionsPager(loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      // 5 entrenamientos y 100 por página: una sola página y hasNextPage false
      return pageResponse(sessions: List.generate(5, (i) => apiSession('s${i + 1}', i + 1)), page: 1, total: 5);
    }));

    await pager.loadNext();
    expect(pager.nextPage, isNull);
    expect(pager.hasMore, isFalse);

    // La pantalla puede llamar otra vez sin miedo: no sale ninguna petición de más
    await pager.loadNext();
    await pager.loadNext();

    expect(called, ['/users/me/sessions?page=1&limit=100']);
    expect(pager.sessions.length, 5);
  });

  test('el resumen de /users/me/progress se sigue pidiendo igual', () async {
    // El resumen de arriba no se toca: sigue siendo una sola llamada y se lee como antes
    final called = <String>[];

    final auth = loggedIn((path, {method = 'GET', body, token}) async {
      called.add('$method $path');
      return {
        'progress': {
          'totalSessions': 3,
          'trainedDays': ['2026-11-10'],
          'exercises': [
            {
              'exercise': {'_id': '1', 'name': 'Press banca'},
              'timesDone': 2,
            },
          ],
        },
      };
    });

    final progress = await ProgressService.progress(auth);

    expect(called, ['GET /users/me/progress']);
    expect(progress.totalSessions, 3);
    expect(progress.trainedDays, ['2026-11-10']);
  });

  test('un entrenamiento con el mismo id pero datos más nuevos no se duplica', () async {
    // Mismo caso que el desplazamiento, pero comprobando que el paginador no rompe con
    // un id que ya tenía y que la lista sigue siendo la misma de antes
    final firstPage = [apiSession('s1', 1), apiSession('s2', 2)];
    final secondPage = [apiSession('s2', 2), apiSession('s3', 3)];

    final called = <String>[];

    final pager = SessionsPager(loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      if (called.length == 1) return pageResponse(sessions: firstPage, page: 1, total: 3, limit: 2);
      return pageResponse(sessions: secondPage, page: 2, total: 3, limit: 2);
    }));

    await pager.loadNext();
    await pager.loadNext();

    // El paginador pide siempre el máximo de la API (100), y la página siguiente es la que dijo el backend
    expect(called, ['/users/me/sessions?page=1&limit=100', '/users/me/sessions?page=2&limit=100']);
    expect(ids(pager), ['s1', 's2', 's3']);
  });

  test('un error de la API al pedir la página siguiente no se traga', () async {
    // Si la red falla, la pantalla tiene que poder avisar y reintentar: el paginador
    // no puede dejar la página a medias como si se hubiera cargado
    final called = <String>[];

    final pager = SessionsPager(loggedIn((path, {method = 'GET', body, token}) async {
      called.add(path);
      if (called.length == 1) return pageResponse(sessions: [apiSession('s1', 1)], page: 1, total: 300);
      throw ApiException('No se puede conectar con la API', 0);
    }));

    await pager.loadNext();

    await expectLater(pager.loadNext(), throwsA(isA<ApiException>()));
    // La sesión que ya teníamos sigue ahí y la página que falló se puede volver a pedir
    expect(ids(pager), ['s1']);
    expect(pager.nextPage, 2);  });
}
