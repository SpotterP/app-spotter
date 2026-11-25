// Este archivo usa widgets de material.dart, que Flutter 3.50 marca como obsoleto (el mismo aviso que
// tiene el resto de la app). Se silencia aquí para que este test no sume incidencias nuevas.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:app_spotter/providers/auth_provider.dart';
import 'package:app_spotter/screens/exercise_picker_screen.dart';
import 'package:app_spotter/services/http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El selector de ejercicios: buscador, filtro por categoría y carga de más ejercicios al llegar al
// final de la lista. La petición se sustituye por una falsa que hace lo mismo que GET /exercises
// (page, limit=20, search y category) para no salir a la red.
void main() {
  // El catálogo de la API falsa: 45 ejercicios. Los 5 primeros son de piernas, el resto de core
  final catalog = [
    for (var i = 0; i < 45; i++)
      {
        '_id': 'e$i',
        'name': i < 5 ? 'Sentadilla ${i + 1}' : 'Plancha ${i + 1}',
        'category': i < 5 ? 'LEGS' : 'CORE',
      },
  ];

  // La respuesta de GET /exercises para una petición: filtra y pagina como lo hace el backend
  Map<String, dynamic> apiResponse(String path) {
    final query = Uri.parse(path).queryParameters;
    final page = int.parse(query['page']!);
    final limit = int.parse(query['limit']!);
    final search = (query['search'] ?? '').toLowerCase();
    final category = query['category'];

    final found = catalog
        .where((e) => (category == null || e['category'] == category) && (e['name'] as String).toLowerCase().contains(search))
        .toList();
    final from = (page - 1) * limit;
    final items = found.skip(from).take(limit).toList();

    return {
      'exercises': items,
      'pagination': {'page': page, 'limit': limit, 'total': found.length, 'hasNextPage': from + limit < found.length},
    };
  }

  // Una sesión abierta, igual que en los otros tests: el token no se valida, sólo viaja
  AuthProvider loggedIn(Future<dynamic> Function(String path) answer, List<String> called) {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'token': 'token-ana', 'refreshToken': 'refresh-ana'});

    final auth = AuthProvider(httpRequest: (path, {method = 'GET', body, token}) async {
      called.add(path);
      return answer(path);
    });
    auth.token = 'token-ana';
    auth.refreshToken = 'refresh-ana';
    return auth;
  }

  Future<void> openPicker(WidgetTester tester, AuthProvider auth, {Set<String> selected = const {}}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(home: ExercisePickerScreen(selectedIds: selected)),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Baja por la lista hasta el final
  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListTile).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('al abrirlo pide la primera página con limit=20 y enseña los ejercicios', (tester) async {
    final called = <String>[];
    await openPicker(tester, loggedIn((path) async => apiResponse(path), called));

    expect(called, ['/exercises?limit=20&page=1&sort=name&order=asc']);
    expect(find.text('Sentadilla 1'), findsOneWidget);
    // Cada ejercicio enseña su categoría en español
    expect(find.text('Piernas'), findsWidgets);
  });

  testWidgets('al llegar al final de la lista carga la página siguiente y no pide de más', (tester) async {
    final called = <String>[];
    await openPicker(tester, loggedIn((path) async => apiResponse(path), called));

    await scrollToEnd(tester);

    // 45 ejercicios con 20 por página son 3 páginas: ni una petición más
    expect(called, [
      '/exercises?limit=20&page=1&sort=name&order=asc',
      '/exercises?limit=20&page=2&sort=name&order=asc',
      '/exercises?limit=20&page=3&sort=name&order=asc',
    ]);
    expect(find.text('Plancha 45'), findsOneWidget);
  });

  testWidgets('al elegir una categoría vuelve a la primera página y solo salen ejercicios de ella', (tester) async {
    final called = <String>[];
    await openPicker(tester, loggedIn((path) async => apiResponse(path), called));

    await tester.tap(find.text('Piernas').first);
    await tester.pumpAndSettle();

    expect(called.last, '/exercises?limit=20&page=1&sort=name&order=asc&category=LEGS');
    expect(find.text('Sentadilla 1'), findsOneWidget);
    expect(find.textContaining('Plancha'), findsNothing);
  });

  testWidgets('el buscador espera a que se deje de escribir y filtra por el texto', (tester) async {
    final called = <String>[];
    await openPicker(tester, loggedIn((path) async => apiResponse(path), called));
    called.clear();

    await tester.enterText(find.byType(TextField), 'sent');
    // A los 300 ms todavía no se ha pedido nada: se sigue esperando
    await tester.pump(const Duration(milliseconds: 300));
    expect(called, isEmpty);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(called, ['/exercises?limit=20&page=1&sort=name&order=asc&search=sent']);
    expect(find.text('Sentadilla 1'), findsOneWidget);
    expect(find.textContaining('Plancha'), findsNothing);
  });

  testWidgets('si no hay ejercicios con esos filtros lo dice', (tester) async {
    await openPicker(tester, loggedIn((path) async => apiResponse(path), []));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('No hay ejercicios con esos filtros'), findsOneWidget);
  });

  testWidgets('si la API falla enseña el mensaje de error', (tester) async {
    await openPicker(tester, loggedIn((path) async => throw ApiException('sin conexión', 0), []));

    expect(find.textContaining('sin conexión'), findsOneWidget);
  });

  testWidgets('los ejercicios que ya están en la rutina salen marcados y no se pueden elegir', (tester) async {
    await openPicker(tester, loggedIn((path) async => apiResponse(path), []), selected: {'e0'});

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sentadilla 1')).enabled, isFalse);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sentadilla 2')).enabled, isTrue);
  });

  testWidgets('al tocar un ejercicio el selector se cierra y lo devuelve', (tester) async {
    final auth = loggedIn((path) async => apiResponse(path), []);
    Object? chosen;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => chosen = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExercisePickerScreen())),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sentadilla 2'));
    await tester.pumpAndSettle();

    expect((chosen as dynamic).name, 'Sentadilla 2');
  });

  testWidgets('teclear rápido no deja los resultados de una búsqueda anterior', (tester) async {
    // La búsqueda "sent" tarda en contestar; la siguiente, "plan", contesta enseguida
    final slowSent = Completer<dynamic>();
    final auth = loggedIn((path) {
      if (path.endsWith('search=sent')) return slowSent.future;
      return Future.value(apiResponse(path));
    }, []);
    await openPicker(tester, auth);

    await tester.enterText(find.byType(TextField), 'sent');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(find.byType(TextField), 'plan');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Plancha 6'), findsOneWidget);

    // Ahora llega tarde la respuesta de "sent": no debe pisar la de "plan"
    slowSent.complete(apiResponse('/exercises?limit=20&page=1&search=sent'));
    await tester.pumpAndSettle();

    expect(find.text('Plancha 6'), findsOneWidget);
    expect(find.text('Sentadilla 1'), findsNothing);
  });

  testWidgets('una respuesta vieja tampoco cambia si hay más páginas en la búsqueda nueva', (tester) async {
    // "sent" (la API diría que hay otra página) sale primero y contesta tarde. Después sale
    // "sentadilla 5" (un solo resultado, sin otra página). Las dos contestan seguidas, la nueva
    // primero: si la respuesta vieja pisara el dato de "hay otra página", al repintarse la lista
    // se pediría una página 2 que no existe.
    final called = <String>[];
    final slowSent = Completer<dynamic>();
    final newSearch = Completer<dynamic>();
    final auth = loggedIn((path) {
      if (path.endsWith('search=sent')) return slowSent.future;
      if (path.contains('search=sentadilla')) return newSearch.future;
      return Future.value(apiResponse(path));
    }, called);
    await openPicker(tester, auth);

    await tester.enterText(find.byType(TextField), 'sent');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(find.byType(TextField), 'sentadilla 5');
    await tester.pump(const Duration(milliseconds: 450));

    newSearch.complete(apiResponse('/exercises?limit=20&page=1&search=sentadilla 5'));
    slowSent.complete({
      'exercises': catalog.take(20).toList(),
      'pagination': {'hasNextPage': true},
    });
    await tester.pumpAndSettle();

    expect(find.text('Sentadilla 5'), findsOneWidget);
    expect(called.where((p) => p.contains('page=2')), isEmpty);
  });
}
